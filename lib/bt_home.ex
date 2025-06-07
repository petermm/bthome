defmodule BTHome do
  @moduledoc """
  BTHome v2 main API module.

  This module provides the primary interface for working with BTHome v2 sensor data.
  It handles serialization to/from binary format, validation, and measurement creation
  with full type safety and error handling.

  ## Features

  - **Type Safety**: Uses structs for measurements and decoded data
  - **Validation**: Comprehensive validation of measurement types and values
  - **Error Handling**: Structured errors with context information
  - **Performance**: Compile-time optimizations for fast lookups
  - **Compatibility**: Struct-based input with map output for deserialization

  ## Supported Sensor Types

  ### Environmental Sensors
  - `:temperature` - Temperature in °C
  - `:humidity` - Relative humidity in %
  - `:pressure` - Atmospheric pressure in hPa
  - `:illuminance` - Light level in lux
  - `:battery` - Battery level in %
  - `:energy` - Energy consumption in kWh
  - `:power` - Power consumption in W
  - `:voltage` - Voltage in V

  ### Binary Sensors
  - `:motion` - Motion detection (true/false)
  - `:door` - Door state (open/closed)
  - `:window` - Window state (open/closed)
  - `:occupancy` - Room occupancy (occupied/vacant)
  - `:smoke` - Smoke detection (detected/clear)
  - `:battery_low` - Low battery warning (low/ok)

  ## Basic Usage

      # Create measurements using the struct API
      {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      {:ok, motion} = BTHome.measurement(:motion, true)

      # Serialize to binary
      {:ok, binary} = BTHome.serialize([temp, motion])

      # Deserialize back to structs
      {:ok, decoded} = BTHome.deserialize(binary)

  ## Deserialization Output

      # Deserialization returns convenient map format
      {:ok, binary} = BTHome.serialize([temp, motion])
      {:ok, %{measurements: measurements}} = BTHome.deserialize(binary)
      # measurements is a list of maps for easy access

  ## Validation

      # Validate before serialization
      case BTHome.validate_measurements(measurements) do
        :ok -> BTHome.serialize(measurements)
        {:error, reason} -> handle_error(reason)
      end

  ## Error Handling

  All functions return tagged tuples with structured errors:

      {:error, %BTHome.Error{
        type: :invalid_data,
        message: "Unsupported measurement type: :invalid",
        context: %{type: :invalid}
      }}
  """

  alias BTHome.{
    DecodedData,
    Decoder,
    Encoder,
    Encryption,
    Measurement,
    Objects,
    Packet,
    Validator
  }

  @doc """
  Serializes measurements into BTHome v2 binary format.

  ## Parameters
  - `measurements_or_packet` - List of measurements or a `Packet` struct
  - `opts` - Serialization options (keyword list)
    - `:encrypt` - Encryption options (keyword list or map, default: false)
      - `:key` - 16-byte encryption key (required)
      - `:mac_address` - 6-byte MAC address (required)
      - `:counter` - 4-byte counter value (required)

  ## Returns
  `{:ok, binary}` on success, `{:error, reason}` on failure.

  ## Examples
      # Basic usage
      iex> {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      iex> {:ok, binary} = BTHome.serialize([temp])
      iex> is_binary(binary)
      true

      # With encryption (keyword list - recommended)
      iex> {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      iex> key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      iex> mac = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      iex> opts = [encrypt: [key: key, mac_address: mac, counter: 1]]
      iex> {:ok, binary} = BTHome.serialize([temp], opts)
      iex> <<device_info, _rest::binary>> = binary
      iex> Bitwise.band(device_info, 0x01) == 1
      true

      # With encryption (map format)
      iex> {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      iex> key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      iex> mac = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      iex> opts = [encrypt: %{key: key, mac_address: mac, counter: 1}]
      iex> {:ok, binary} = BTHome.serialize([temp], opts)
      iex> is_binary(binary)
      true
  """
  @spec serialize([Measurement.t()] | Packet.t(), boolean() | keyword()) ::
          {:ok, binary()} | {:error, String.t()}
  def serialize(measurements_or_packet, opts \\ [])

  def serialize(measurements, opts) when is_list(measurements) do
    case normalize_serialize_opts(opts) do
      {:error, _} = error -> error
      normalized_opts -> Encoder.encode_measurements(measurements, normalized_opts)
    end
  end

  def serialize(%Packet{} = packet, opts) do
    case normalize_serialize_opts(opts) do
      {:error, _} = error -> error
      normalized_opts -> Packet.serialize(packet, normalized_opts)
    end
  end

  @doc """
  Serializes measurements or packet, raising on error.

  Similar to `serialize/2` but raises an exception instead of returning an error tuple.
  This is useful for pipeline operations where you want to fail fast on errors.

  ## Parameters
  - `measurements_or_packet` - List of measurements or a Packet struct
  - `opts` - Serialization options (same as `serialize/2`)

  ## Returns
  Binary BTHome v2 data on success, raises on error.

  ## Examples
      # Basic usage
      iex> {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      iex> binary = BTHome.serialize!([temp])
      iex> is_binary(binary)
      true

      # With builder pattern
      iex> binary = BTHome.new_packet()
      iex> |> BTHome.add_measurement(:temperature, 23.45)
      iex> |> BTHome.serialize!()
      iex> is_binary(binary)
      true

      # With encryption
      iex> {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      iex> key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      iex> mac = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      iex> opts = [encrypt: [key: key, mac_address: mac, counter: 1]]
      iex> binary = BTHome.serialize!([temp], opts)
      iex> is_binary(binary)
      true

  ## Raises
  `ArgumentError` if serialization fails.
  """
  @spec serialize!([Measurement.t()] | Packet.t(), boolean() | keyword()) :: binary()
  def serialize!(measurements_or_packet, opts \\ [])

  def serialize!(measurements, opts) when is_list(measurements) do
    case serialize(measurements, opts) do
      {:ok, binary} -> binary
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def serialize!(%Packet{} = packet, opts) do
    case serialize(packet, opts) do
      {:ok, binary} -> binary
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Deserializes BTHome v2 binary data into structured measurement data.

  Parses BTHome v2 binary format and returns a `DecodedData` struct containing
  protocol metadata and a list of `Measurement` structs. Handles error recovery
  for unknown object IDs by skipping invalid data.

  For encrypted data, provide decryption options to automatically decrypt measurements.

  ## Parameters
  - `binary` - Binary data containing BTHome v2 encoded measurements
  - `opts` - Options for decryption (optional)
    - `:key` - 16-byte encryption key
    - `:mac_address` - 6-byte MAC address

  ## Returns
  - `{:ok, decoded_data}` - Successfully parsed data with measurements
  - `{:error, error}` - Parsing failed with error details

  ## Examples
      # Basic deserialization
      iex> {:ok, result} = BTHome.deserialize(<<64, 2, 41, 9, 3, 124, 26>>)
      iex> result.version
      2
      iex> result.encrypted
      false
      iex> length(result.measurements)
      2

      # For encrypted data, provide key and MAC address
      # opts = [key: <<key_bytes>>, mac_address: <<mac_bytes>>]
      # BTHome.deserialize(encrypted_binary, opts)

      # With encryption flag
      iex> BTHome.deserialize(<<65, 2, 41, 9>>)
      {:ok, %BTHome.DecodedData{
        version: 2,
        encrypted: true,
        trigger_based: false,
        measurements: [],
        ciphertext: <<2, 41, 9>>
      }}

      # Invalid data
      iex> BTHome.deserialize(<<1, 2, 3>>)
      {:error, "Unsupported BTHome version: 0"}
  """
  @spec deserialize(binary(), keyword()) :: {:ok, DecodedData.t()} | {:error, String.t()}
  def deserialize(binary, opts \\ []) when is_binary(binary) do
    Decoder.decode_measurements(binary, opts)
  end

  @doc """
  Deserializes BTHome v2 binary data and returns measurements as a map.

  This is a convenience function that extracts measurements from the decoded data
  and returns them as a map where keys are measurement types and values are the
  measured values. For measurements with multiple instances (same type, different
  object IDs), the map will contain a list of values.

  ## Parameters
  - `binary` - The BTHome v2 binary data to deserialize

  ## Returns
  - `{:ok, map}` - A map of measurement types to values
  - `{:error, Error.t()}` - If deserialization fails

  ## Examples
      # Binary sensor measurement
      iex> binary = <<0x40, 0x0F, 0x01>>
      iex> BTHome.deserialize_measurements(binary)
      {:ok, %{generic_boolean: true}}

      # Temperature and humidity measurements
      iex> binary = <<0x40, 0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13>>
      iex> {:ok, measurements} = BTHome.deserialize_measurements(binary)
      iex> Map.has_key?(measurements, :temperature) and Map.has_key?(measurements, :humidity)
      true

      # Encrypted data (no measurements available)
      iex> binary = <<0x41, 0x02, 0x29, 0x09>>
      iex> BTHome.deserialize_measurements(binary)
      {:ok, %{}}
  """
  @spec deserialize_measurements(binary(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def deserialize_measurements(binary, opts \\ []) when is_binary(binary) do
    case deserialize(binary, opts) do
      {:ok, %DecodedData{measurements: measurements}} ->
        measurements_map = measurements_to_map(measurements)
        {:ok, measurements_map}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Deserializes BTHome v2 binary data and returns measurements as a map, raising on error.

  This is the recommended function for most use cases as it provides the most ergonomic
  API for accessing measurement data. It returns measurements as a map where keys are
  measurement types and values are the measured values.

  ## Parameters
  - `binary` - The BTHome v2 binary data to deserialize

  ## Returns
  A map of measurement types to values. Raises `ArgumentError` on failure.

  ## Examples
      # Binary sensor measurement
      iex> binary = <<0x40, 0x0F, 0x01>>
      iex> BTHome.deserialize_measurements!(binary)
      %{generic_boolean: true}

      # Temperature and humidity measurements
      iex> binary = <<0x40, 0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13>>
      iex> measurements = BTHome.deserialize_measurements!(binary)
      iex> Map.has_key?(measurements, :temperature) and Map.has_key?(measurements, :humidity)
      true

      # Invalid data raises an error
      iex> BTHome.deserialize_measurements!(<<1, 2, 3>>)
      ** (ArgumentError) Unsupported BTHome version: 0
  """
  @spec deserialize_measurements!(binary()) :: map() | no_return()
  def deserialize_measurements!(binary) when is_binary(binary) do
    case deserialize_measurements(binary) do
      {:ok, measurements} -> measurements
      {:error, error} -> raise ArgumentError, error
    end
  end

  # Convert list of measurements to a map
  defp measurements_to_map(measurements) do
    measurements
    |> Enum.group_by(& &1.type)
    |> Enum.into(%{}, fn {type, measurements_list} ->
      case measurements_list do
        [single_measurement] ->
          {type, single_measurement.value}

        multiple_measurements ->
          {type, Enum.map(multiple_measurements, & &1.value)}
      end
    end)
  end

  @doc """
  Returns all supported measurement types and their properties.

  Provides a map of measurement types to their complete definitions including
  units, scaling factors, data sizes, and other metadata.

  ## Returns
  A map where keys are measurement type atoms and values are definition maps.

  ## Examples
      iex> types = BTHome.supported_types()
      iex> Map.has_key?(types, :temperature)
      true
      iex> types[:temperature].unit
      "°C"
  """
  @spec supported_types() :: map()
  def supported_types do
    Objects.get_supported_types()
    |> Enum.map(fn type ->
      {_id, definition} = Objects.find_by_type(type)
      {type, definition}
    end)
    |> Map.new()
  end

  @doc """
  Validates a single measurement for serialization.

  Checks that the measurement type is supported and the value is valid
  for that type (correct data type and within acceptable range).

  ## Parameters
  - `measurement` - A measurement struct or map to validate

  ## Returns
  - `:ok` - Measurement is valid
  - `{:error, error}` - Validation failed with error details

  ## Examples
      iex> {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      iex> BTHome.validate_measurement(temp)
      :ok

      iex> invalid = %BTHome.Measurement{type: :invalid, value: 42}
      iex> BTHome.validate_measurement(invalid)
      {:error, "Unsupported measurement type: :invalid"}
  """
  @spec validate_measurement(Measurement.t()) :: :ok | {:error, String.t()}
  def validate_measurement(measurement) do
    Validator.validate_measurement(measurement)
  end

  @doc """
  Validates a list of measurements for serialization.

  Validates each measurement in the list and ensures the overall list
  is suitable for serialization.

  ## Parameters
  - `measurements` - List of measurement structs or maps to validate

  ## Returns
  - `:ok` - All measurements are valid
  - `{:error, error}` - Validation failed with error details

  ## Examples
      iex> {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      iex> {:ok, humidity} = BTHome.measurement(:humidity, 67.8)
      iex> BTHome.validate_measurements([temp, humidity])
      :ok

      iex> invalid = %BTHome.Measurement{type: :invalid, value: 42}
      iex> BTHome.validate_measurements([invalid])
      {:error, "Measurement 0: Unsupported measurement type: :invalid"}
  """
  @spec validate_measurements([Measurement.t()]) :: :ok | {:error, String.t()}
  def validate_measurements(measurements) do
    Validator.validate_measurements(measurements)
  end

  @doc """
  Creates a validated measurement struct.

  This is the recommended way to create measurements as it provides validation
  during creation and automatically looks up metadata like units.

  ## Parameters
  - `type` - The measurement type atom (must be supported)
  - `value` - The measurement value (number for sensors, boolean for binary sensors)
  - `opts` - Optional keyword list with `:unit` and `:object_id` overrides

  ## Returns
  - `{:ok, measurement}` - Successfully created and validated measurement
  - `{:error, error}` - Creation failed with error details

  ## Examples
      # Environmental sensor
      iex> BTHome.measurement(:temperature, 23.45)
      {:ok, %BTHome.Measurement{type: :temperature, value: 23.45, unit: "°C"}}

      # Binary sensor
      iex> BTHome.measurement(:motion, true)
      {:ok, %BTHome.Measurement{type: :motion, value: true, unit: nil}}

      # With custom unit
      iex> BTHome.measurement(:temperature, 74.21, unit: "°F")
      {:ok, %BTHome.Measurement{type: :temperature, value: 74.21, unit: "°F"}}

      # Invalid type
      iex> BTHome.measurement(:invalid, 42)
      {:error, "Unsupported measurement type: :invalid"}
  """
  @spec measurement(atom(), number() | boolean(), keyword()) ::
          {:ok, Measurement.t()} | {:error, String.t()}
  def measurement(type, value, opts \\ []) do
    Measurement.new(type, value, opts)
  end

  @doc """
  Creates a new packet builder for the fluent/builder pattern API.

  This function starts a new packet builder that can be used with the pipe
  operator to chain measurement additions and final serialization.

  ## Returns
  A new packet builder struct.

  ## Examples
      # Basic builder pattern usage
      {:ok, binary} = BTHome.new_packet()
      |> BTHome.add_measurement(:temperature, 23.45)
      |> BTHome.add_measurement(:motion, true)
      |> BTHome.serialize()

      # With encryption
      {:ok, binary} = BTHome.new_packet()
      |> BTHome.add_measurement(:temperature, 23.45)
      |> BTHome.serialize(true)
  """
  @spec new_packet() :: Packet.t()
  def new_packet do
    Packet.new()
  end

  @doc """
  Adds a measurement to a packet builder.

  This function is designed to work with the builder pattern, allowing you to
  chain multiple measurements using the pipe operator. If any measurement fails
  validation, the error is captured and will be returned when `serialize/1` is called.

  ## Parameters
  - `packet` - The packet builder struct (from `new_packet/0` or previous `add_measurement/4`)
  - `type` - The measurement type atom
  - `value` - The measurement value
  - `opts` - Optional keyword list (same options as `measurement/3`)

  ## Returns
  The updated packet builder struct.

  ## Examples
      # Single measurement
      packet = BTHome.new_packet()
      |> BTHome.add_measurement(:temperature, 23.45)

      # Multiple measurements
      packet = BTHome.new_packet()
      |> BTHome.add_measurement(:temperature, 23.45)
      |> BTHome.add_measurement(:humidity, 67.8)
      |> BTHome.add_measurement(:motion, true)

      # With custom options
      packet = BTHome.new_packet()
      |> BTHome.add_measurement(:temperature, 74.21, unit: "°F")
  """
  @spec add_measurement(Packet.t(), atom(), number() | boolean(), keyword()) :: Packet.t()
  def add_measurement(packet, type, value, opts \\ []) do
    Packet.add_measurement(packet, type, value, opts)
  end

  @doc """
  Serializes measurements with encryption.

  This is a convenience function for encrypting BTHome v2 data with the specified
  encryption parameters.

  ## Parameters
  - `measurements` - List of measurements to encrypt
  - `key` - 16-byte encryption key
  - `mac_address` - 6-byte MAC address
  - `counter` - 4-byte counter value

  ## Returns
  - `{:ok, binary}` - Successfully encrypted BTHome v2 binary data
  - `{:error, error}` - Encryption failed with error details

  ## Examples
      key = :crypto.strong_rand_bytes(16)
      mac = <<0x54, 0x48, 0xe6, 0x8f, 0x80, 0xa5>>
      {:ok, temp} = BTHome.measurement(:temperature, 23.45)

      {:ok, encrypted} = BTHome.serialize_encrypted([temp], key, mac, 1)
  """
  @spec serialize_encrypted([Measurement.t()], binary(), binary(), non_neg_integer()) ::
          {:ok, binary()} | {:error, String.t()}
  def serialize_encrypted(measurements, key, mac_address, counter) do
    opts = [encrypt: [key: key, mac_address: mac_address, counter: counter]]
    serialize(measurements, opts)
  end

  @doc """
  Deserializes encrypted BTHome v2 binary data.

  This is a convenience function for decrypting BTHome v2 data with the specified
  decryption parameters.

  ## Parameters
  - `binary` - Encrypted BTHome v2 binary data
  - `key` - 16-byte encryption key
  - `mac_address` - 6-byte MAC address

  ## Returns
  - `{:ok, decoded_data}` - Successfully decrypted data with measurements
  - `{:error, error}` - Decryption failed with error details

  ## Examples
      key = encryption_key
      mac = device_mac_address

      {:ok, decoded} = BTHome.deserialize_encrypted(encrypted_binary, key, mac)
  """
  @spec deserialize_encrypted(binary(), binary(), binary()) ::
          {:ok, DecodedData.t()} | {:error, String.t()}
  def deserialize_encrypted(binary, key, mac_address) do
    opts = [key: key, mac_address: mac_address]
    deserialize(binary, opts)
  end

  @doc """
  Generates a random encryption key for BTHome v2.

  ## Returns
  16-byte random encryption key suitable for AES-128.

  ## Examples
      key = BTHome.generate_encryption_key()
      byte_size(key)  # => 16
  """
  @spec generate_encryption_key() :: binary()
  def generate_encryption_key do
    Encryption.generate_key()
  end

  @doc """
  Creates encryption options for use with serialize/2.

  This convenience function creates properly formatted encryption options
  from individual parameters, reducing verbosity and potential errors.

  ## Parameters
  - `key` - 16-byte encryption key
  - `mac_address` - 6-byte MAC address
  - `counter` - 4-byte counter value

  ## Returns
  Keyword list with encryption options ready for use with serialize/2.

  ## Examples
      key = BTHome.generate_encryption_key()
      mac = <<0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC>>

      # Create encryption options
      opts = BTHome.encryption_opts(key, mac, 1)

      # Use with serialize/2
      {:ok, binary} = BTHome.serialize(measurements, opts)
  """
  @spec encryption_opts(binary(), binary(), non_neg_integer()) :: keyword()
  def encryption_opts(key, mac_address, counter) do
    [encrypt: [key: key, mac_address: mac_address, counter: counter]]
  end

  @doc """
  Creates encryption options from a device context map.

  This convenience function extracts encryption parameters from a device
  context map, making it easier to work with device management systems.

  ## Parameters
  - `device_context` - Map containing device information with keys:
    - `:key` or `:encryption_key` - 16-byte encryption key
    - `:mac_address` or `:mac` - 6-byte MAC address
    - `:counter` - 4-byte counter value

  ## Returns
  - `{:ok, opts}` - Successfully created encryption options
  - `{:error, error}` - Missing or invalid parameters

  ## Examples
      device = %{
        encryption_key: key,
        mac_address: mac,
        counter: 1
      }

      {:ok, opts} = BTHome.encryption_opts(device)
      {:ok, binary} = BTHome.serialize(measurements, opts)
  """
  @spec encryption_opts(map()) :: {:ok, keyword()} | {:error, String.t()}
  def encryption_opts(device_context) when is_map(device_context) do
    with {:ok, key} <- extract_key(device_context),
         {:ok, mac} <- extract_mac_address(device_context),
         {:ok, counter} <- extract_counter(device_context) do
      {:ok, encryption_opts(key, mac, counter)}
    end
  end

  @doc """
  Creates a new encrypted packet builder.

  This convenience function creates a packet builder that can be used
  with encryption. The encryption options are returned separately to be
  used with serialize/2.

  ## Parameters
  - `key` - 16-byte encryption key
  - `mac_address` - 6-byte MAC address
  - `counter` - 4-byte counter value

  ## Returns
  Tuple with packet struct and encryption options.

  ## Examples
      key = BTHome.generate_encryption_key()
      mac = <<0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC>>

      {packet, opts} = BTHome.new_encrypted_packet(key, mac, 1)

      {:ok, packet} = BTHome.add_measurement(packet, :temperature, 23.5)
      {:ok, binary} = BTHome.serialize(packet, opts)
  """
  @spec new_encrypted_packet(binary(), binary(), non_neg_integer()) :: {Packet.t(), keyword()}
  def new_encrypted_packet(key, mac_address, counter) do
    opts = encryption_opts(key, mac_address, counter)
    {%Packet{measurements: []}, opts}
  end

  @doc """
  Serializes an encrypted packet to binary format.

  This convenience function serializes a packet with the provided
  encryption options, providing a cleaner API for encrypted packets.

  ## Parameters
  - `packet` - Packet struct
  - `encryption_opts` - Encryption options from encryption_opts/3

  ## Returns
  - `{:ok, binary}` - Successfully serialized encrypted binary
  - `{:error, error}` - Serialization failed with error details

  ## Examples
      {packet, opts} = BTHome.new_encrypted_packet(key, mac, 1)
      {:ok, packet} = BTHome.add_measurement(packet, :temperature, 23.5)

      {:ok, binary} = BTHome.serialize_encrypted(packet, opts)
  """
  @spec serialize_encrypted(Packet.t(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def serialize_encrypted(%Packet{} = packet, encryption_opts) when is_list(encryption_opts) do
    serialize(packet, encryption_opts)
  end

  @doc """
  Quick serialization of measurements with encryption.

  This convenience function provides a one-liner for serializing measurements
  with encryption, reducing boilerplate code for simple use cases.

  ## Parameters
  - `measurements` - List of measurements (structs or maps)
  - `key` - 16-byte encryption key
  - `mac_address` - 6-byte MAC address
  - `counter` - 4-byte counter value

  ## Returns
  - `{:ok, binary}` - Successfully serialized encrypted binary
  - `{:error, error}` - Serialization failed with error details

  ## Examples
      {:ok, temp} = BTHome.measurement(:temperature, 23.5)
      {:ok, humidity} = BTHome.measurement(:humidity, 65.0)
      measurements = [temp, humidity]

      {:ok, binary} = BTHome.quick_serialize_encrypted(
        measurements, key, mac, 1
      )
  """
  @spec quick_serialize_encrypted(
          [Measurement.t() | map()],
          binary(),
          binary(),
          non_neg_integer()
        ) ::
          {:ok, binary()} | {:error, String.t()}
  def quick_serialize_encrypted(measurements, key, mac_address, counter) do
    opts = encryption_opts(key, mac_address, counter)
    serialize(measurements, opts)
  end

  @doc """
  Serializes measurements for a specific device.

  This convenience function integrates with device management by accepting
  a device context map containing encryption parameters.

  ## Parameters
  - `measurements` - List of measurements (structs or maps)
  - `device_context` - Map containing device information

  ## Returns
  - `{:ok, binary}` - Successfully serialized binary (encrypted if device has encryption)
  - `{:error, error}` - Serialization failed with error details

  ## Examples
      device = %{
        encryption_key: key,
        mac_address: mac,
        counter: 1
      }

      {:ok, temp} = BTHome.measurement(:temperature, 23.5)
      {:ok, binary} = BTHome.serialize_for_device([temp], device)
  """
  @spec serialize_for_device([Measurement.t()], map()) ::
          {:ok, binary()} | {:error, String.t()}
  def serialize_for_device(measurements, device_context) when is_map(device_context) do
    case encryption_opts(device_context) do
      {:ok, opts} -> serialize(measurements, opts)
      # Fall back to unencrypted if no encryption info
      {:error, _} -> serialize(measurements)
    end
  end

  @doc """
  Converts a hex string to an encryption key.

  ## Parameters
  - `hex_string` - 32-character hex string

  ## Returns
  - `{:ok, key}` - Successfully converted key
  - `{:error, error}` - Invalid hex string

  ## Examples
      {:ok, key} = BTHome.key_from_hex("231d39c1d7cc1ab1aee224cd096db932")
  """
  @spec key_from_hex(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def key_from_hex(hex_string) do
    Encryption.key_from_hex(hex_string)
  end

  @doc """
  Converts an encryption key to a hex string.

  ## Parameters
  - `key` - 16-byte encryption key

  ## Returns
  Hex string representation of the key.

  ## Examples
      hex = BTHome.key_to_hex(key)
  """
  @spec key_to_hex(binary()) :: String.t()
  def key_to_hex(key) do
    Encryption.key_to_hex(key)
  end

  # Private helper functions for device context extraction

  defp extract_key(%{key: key}) when is_binary(key) and byte_size(key) == 16, do: {:ok, key}

  defp extract_key(%{encryption_key: key}) when is_binary(key) and byte_size(key) == 16,
    do: {:ok, key}

  defp extract_key(_), do: {:error, "Missing or invalid encryption key"}

  defp extract_mac_address(%{mac_address: mac}) when is_binary(mac) and byte_size(mac) == 6,
    do: {:ok, mac}

  defp extract_mac_address(%{mac: mac}) when is_binary(mac) and byte_size(mac) == 6,
    do: {:ok, mac}

  defp extract_mac_address(_),
    do: {:error, "Missing or invalid MAC address"}

  defp extract_counter(%{counter: counter}) when is_integer(counter) and counter >= 0,
    do: {:ok, counter}

  defp extract_counter(_), do: {:error, "Missing or invalid counter"}

  # Normalize serialize options for backward compatibility
  defp normalize_serialize_opts(opts) when is_boolean(opts) do
    # Handle legacy boolean encryption parameter
    [encrypt: opts]
  end

  defp normalize_serialize_opts(opts) when is_list(opts) do
    case Keyword.get(opts, :encrypt) do
      # encrypt as keyword list or map
      encrypt_opts when is_list(encrypt_opts) or is_map(encrypt_opts) ->
        normalize_encrypt_option(encrypt_opts, opts)

      false ->
        Keyword.delete(opts, :encrypt)

      nil ->
        opts

      other ->
        {:error, "Invalid encrypt option: #{inspect(other)}. Must be a keyword list or map."}
    end
  end

  defp normalize_serialize_opts(opts) do
    {:error, "Invalid serialization options: #{inspect(opts)}"}
  end

  # Normalize encrypt option (keyword list or map)
  defp normalize_encrypt_option(encrypt_opts, opts) do
    # Convert map to keyword list if needed
    normalized_encrypt =
      if is_map(encrypt_opts) do
        Enum.into(encrypt_opts, [])
      else
        encrypt_opts
      end

    # Replace encrypt option with normalized version
    Keyword.put(opts, :encrypt, normalized_encrypt)
  end
end
