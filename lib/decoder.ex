defmodule BTHome.Decoder do
  @moduledoc """
  Decoder for BTHome v2 format.

  This module provides functions to decode BTHome v2 binary data into structured
  measurement data.
  """

  alias BTHome.{
    ButtonEvent,
    Config,
    DecodedData,
    DimmerEvent,
    Encryption,
    Measurement,
    Objects,
    Validator
  }

  @doc "Decode BTHome v2 binary data"
  def decode_measurements(data, opts \\ []) do
    decode_measurements_with_options(data, opts)
  end

  @doc """
  Decode BTHome v2 binary data with decryption support.

  ## Options

  - `:key` - 16-byte encryption key (required for encrypted data)
  - `:mac_address` - 6-byte MAC address (required for encrypted data)

  ## Examples

      # Unencrypted data
      {:ok, decoded} = decode_measurements(data)

      # Encrypted data
      opts = [key: encryption_key, mac_address: device_mac]
      {:ok, decoded} = decode_measurements(encrypted_data, opts)
  """
  def decode_with_decryption(data, key, mac_address) do
    opts = [key: key, mac_address: mac_address]
    decode_measurements(data, opts)
  end

  defp decode_measurements_with_options(<<device_info, rest::binary>>, opts) do
    with :ok <- Validator.validate_device_info(device_info) do
      version =
        Bitwise.bsr(Bitwise.band(device_info, Config.version_mask()), Config.version_shift())

      trigger_based = Bitwise.band(device_info, Config.trigger_mask()) != 0
      encrypted = Bitwise.band(device_info, Config.encryption_mask()) != 0

      # Try to extract MAC address if present (only for unencrypted data)
      {mac_reversed, measurement_data} =
        if encrypted do
          # Don't extract MAC from encrypted data
          {nil, rest}
        else
          extract_mac_if_present(rest)
        end

      if encrypted do
        decode_encrypted_data(measurement_data, mac_reversed, version, trigger_based, opts)
      else
        case decode_stream(measurement_data) do
          {:error, reason} ->
            {:error, reason}

          measurements ->
            {:ok,
             %DecodedData{
               version: version,
               encrypted: encrypted,
               trigger_based: trigger_based,
               measurements: measurements,
               ciphertext: nil,
               mac_reversed: mac_reversed,
               counter: nil,
               mic: nil
             }}
        end
      end
    end
  end

  defp decode_measurements_with_options(_, _),
    do: {:error, "Invalid BTHome data format"}

  # Handle encrypted data decoding
  defp decode_encrypted_data(measurement_data, mac_reversed, version, trigger_based, opts) do
    # Extract counter and MIC from encrypted payload
    case extract_encryption_data(measurement_data) do
      {counter_bytes, mic, ciphertext} when not is_nil(counter_bytes) and not is_nil(mic) ->
        counter = :binary.decode_unsigned(counter_bytes, :little)

        # Try to decrypt if key and MAC are provided
        case decrypt_if_possible(ciphertext, mic, counter, mac_reversed, opts) do
          {:ok, decrypted_measurements} ->
            {:ok,
             %DecodedData{
               version: version,
               encrypted: true,
               trigger_based: trigger_based,
               measurements: decrypted_measurements,
               ciphertext: ciphertext,
               mac_reversed: mac_reversed,
               counter: counter,
               mic: mic
             }}

          {:error, reason} ->
            # Decryption failed, return the error
            {:error, reason}
        end

      _ ->
        # Could not extract encryption data properly
        {:ok,
         %DecodedData{
           version: version,
           encrypted: true,
           trigger_based: trigger_based,
           measurements: [],
           ciphertext: measurement_data,
           mac_reversed: mac_reversed,
           counter: nil,
           mic: nil
         }}
    end
  end

  # Attempt to decrypt data if key and MAC address are provided
  defp decrypt_if_possible(ciphertext, mic, counter, mac_reversed, opts) do
    key = Keyword.get(opts, :key)
    mac_address = Keyword.get(opts, :mac_address) || reverse_mac_if_present(mac_reversed)

    if key && mac_address do
      decrypt_and_decode(ciphertext, mic, key, mac_address, counter)
    else
      # No key provided, return empty measurements (not an error)
      {:ok, []}
    end
  end

  defp decrypt_and_decode(ciphertext, mic, key, mac_address, counter) do
    case Encryption.decrypt(ciphertext, mic, key, mac_address, counter) do
      {:ok, decrypted_data} ->
        case decode_stream(decrypted_data) do
          {:error, reason} -> {:error, reason}
          measurements -> {:ok, measurements}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Reverse MAC address bytes if present (BTHome stores MAC in reverse order)
  defp reverse_mac_if_present(nil), do: nil

  defp reverse_mac_if_present(mac_reversed) when byte_size(mac_reversed) == 6 do
    mac_reversed |> :binary.bin_to_list() |> Enum.reverse() |> :binary.list_to_bin()
  end

  defp reverse_mac_if_present(mac_reversed), do: mac_reversed

  # Extract MAC address if present (6 bytes before first valid object ID)
  # Only extract MAC if the first byte is NOT a valid object ID
  defp extract_mac_if_present(<<first_byte, _rest::binary>> = data) when byte_size(data) >= 7 do
    if Objects.get_definition(first_byte) do
      # First byte is a valid object ID, so no MAC present
      {nil, data}
    else
      # First byte is not a valid object ID, check if there's a MAC
      check_for_mac_address(data)
    end
  end

  defp extract_mac_if_present(data) do
    # Not enough data for MAC or fallback
    {nil, data}
  end

  # Check if data contains a MAC address (6 bytes + valid object ID + data)
  defp check_for_mac_address(data) do
    case data do
      <<mac::binary-size(6), object_id, _::binary>> = full_data when byte_size(full_data) >= 8 ->
        if Objects.get_definition(object_id) do
          # Valid object ID found after 6 bytes, so those 6 bytes are likely MAC
          <<_::binary-size(6), rest::binary>> = full_data
          {mac, rest}
        else
          # No valid object ID after 6 bytes, no MAC present
          {nil, data}
        end

      _ ->
        # Not enough data for MAC + object ID + data, no MAC present
        {nil, data}
    end
  end

  # Decoder using pattern matching and tail recursion
  defp decode_stream(data) do
    case decode_stream_acc(data, []) do
      {:ok, measurements} -> measurements
      {:error, reason} -> {:error, reason}
    end
  end

  # Base case: empty binary
  defp decode_stream_acc(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  # Pattern match for known object IDs with sufficient data
  defp decode_stream_acc(<<object_id, rest::binary>>, acc) when byte_size(rest) > 0 do
    case Objects.get_definition(object_id) do
      %{size: size} = definition when is_integer(size) and byte_size(rest) >= size ->
        decode_fixed_size_measurement(object_id, rest, definition, acc)

      %{size: :variable} = definition ->
        decode_variable_size_measurement(object_id, rest, definition, acc)

      %{size: size} = _definition when is_integer(size) ->
        # Insufficient data for this measurement
        {:error,
         "Insufficient data for measurement (object_id: #{object_id}, expected: #{size}, available: #{byte_size(rest)})"}

      nil ->
        # Unknown object ID - create unknown measurement with remaining data
        measurement = create_unknown_measurement(rest)
        {:ok, Enum.reverse([measurement | acc])}
    end
  end

  # Handle case where we have object ID but no data
  defp decode_stream_acc(<<_object_id>>, _acc) do
    {:error, "Object ID found but no measurement data"}
  end

  defp create_unknown_measurement(unknown_data) do
    %Measurement{
      type: :unknown,
      # Dummy value since it's required
      value: 0,
      unit: nil,
      object_id: nil,
      unknown: unknown_data
    }
  end

  # Optimized fixed-size measurement decoding with pattern matching
  defp decode_fixed_size_measurement(_object_id, binary, %{size: size} = definition, acc) do
    <<value_bytes::binary-size(size), rest::binary>> = binary

    case decode_measurement_value(value_bytes, definition) do
      {:ok, measurement} ->
        decode_stream_acc(rest, [measurement | acc])

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Optimized variable-size measurement decoding
  defp decode_variable_size_measurement(_object_id, binary, definition, acc) do
    case extract_variable_measurement(binary, definition) do
      {:ok, measurement, rest} ->
        decode_stream_acc(rest, [measurement | acc])

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Fast measurement value decoding using pattern matching
  defp decode_measurement_value(value_bytes, %{
         name: name,
         unit: unit,
         factor: factor,
         signed: signed,
         size: size
       }) do
    with {:ok, int_value} <- decode_integer(value_bytes, signed, size) do
      final_value = convert_measurement_value(name, int_value, factor)
      measurement = %Measurement{type: name, value: final_value, unit: unit}
      {:ok, measurement}
    end
  end

  defp extract_variable_measurement(binary, %{name: name, unit: unit}) do
    case name do
      :text -> extract_text_measurement(binary, name, unit)
      :raw -> extract_raw_measurement(binary, name, unit)
      _ -> {:error, "Unsupported variable-sized type: #{name}"}
    end
  end

  defp extract_text_measurement(binary, name, unit) do
    case binary do
      <<length, text_data::binary-size(length), rest::binary>> ->
        measurement = %Measurement{type: name, value: text_data, unit: unit}
        {:ok, measurement, rest}

      _ ->
        {:error, "Insufficient data for text"}
    end
  end

  defp extract_raw_measurement(binary, name, unit) do
    case binary do
      <<length, raw_data::binary-size(length), rest::binary>> ->
        measurement = %Measurement{type: name, value: raw_data, unit: unit}
        {:ok, measurement, rest}

      _ ->
        {:error, "Insufficient data for raw"}
    end
  end

  defp convert_measurement_value(name, int_value, factor) do
    cond do
      Objects.binary_sensor?(name) -> int_value != 0
      name == :button -> map_button_event(int_value)
      name == :dimmer -> build_dimmer_value(int_value)
      name == :firmware_version_uint32 -> extract_firmware_version_32(int_value)
      name == :firmware_version_uint24 -> extract_firmware_version_24(int_value)
      true -> int_value * factor
    end
  end

  defp build_dimmer_value(int_value) do
    event = map_dimmer_event(int_value)
    steps = extract_dimmer_steps(int_value)
    %{event: event, steps: steps}
  end

  # Integer decoding using direct pattern matching
  defp decode_integer(value_bytes, signed, size) do
    int_value = extract_integer(value_bytes, signed, size)
    {:ok, int_value}
  rescue
    MatchError -> {:error, "Invalid binary format for size #{size}"}
    _e -> {:error, "Failed to decode integer with size #{size}"}
  end

  # Direct pattern matching for integer extraction
  defp extract_integer(<<val::unsigned-8>>, false, 1), do: val
  defp extract_integer(<<val::signed-8>>, true, 1), do: val
  defp extract_integer(<<val::unsigned-little-16>>, false, 2), do: val
  defp extract_integer(<<val::signed-little-16>>, true, 2), do: val
  defp extract_integer(<<val::unsigned-little-24>>, false, 3), do: val
  defp extract_integer(<<val::signed-little-24>>, true, 3), do: val
  defp extract_integer(<<val::unsigned-little-32>>, false, 4), do: val
  defp extract_integer(<<val::signed-little-32>>, true, 4), do: val

  # Fallback for unsupported sizes
  defp extract_integer(_value_bytes, _signed, size) do
    raise ArgumentError, "Unsupported integer size: #{size}"
  end

  # Map button event values to atoms using ButtonEvent
  defp map_button_event(0), do: ButtonEvent.none()
  defp map_button_event(1), do: ButtonEvent.press()
  defp map_button_event(2), do: ButtonEvent.double_press()
  defp map_button_event(3), do: ButtonEvent.triple_press()
  defp map_button_event(4), do: ButtonEvent.long_press()
  defp map_button_event(5), do: ButtonEvent.long_double_press()
  defp map_button_event(6), do: ButtonEvent.long_triple_press()
  defp map_button_event(128), do: ButtonEvent.hold_press()
  defp map_button_event(254), do: ButtonEvent.hold_press()
  defp map_button_event(255), do: ButtonEvent.release()
  # fallback for unknown values to atoms
  defp map_button_event(value), do: value

  # Map dimmer event values to atoms using DimmerEvent
  # For 2-byte dimmer value in little-endian format: first byte is event, second byte is steps
  defp map_dimmer_event(value) when is_integer(value) do
    # Extract lower 8 bits (first byte - event type)
    event_type = value |> Bitwise.band(0xFF)

    case event_type do
      0 -> DimmerEvent.none()
      1 -> DimmerEvent.rotate_left()
      2 -> DimmerEvent.rotate_right()
      # fallback for unknown values
      _ -> event_type
    end
  end

  # Extract dimmer steps from the 2-byte dimmer value
  # For BTHome v2, dimmer is 2 bytes in little-endian: first byte is event type, second byte is steps
  defp extract_dimmer_steps(value) when is_integer(value) do
    # For 2-byte value in little-endian: second byte (upper 8 bits) contains steps
    # Extract upper 8 bits (steps)
    steps = Bitwise.bsr(value, 8) |> Bitwise.band(0xFF)
    steps
  end

  # Extract firmware version components from 32-bit value
  # Format: major.minor.patch.build (8.8.8.8 bits)
  defp extract_firmware_version_32(value) do
    major = Bitwise.bsr(value, 24) |> Bitwise.band(0xFF)
    minor = Bitwise.bsr(value, 16) |> Bitwise.band(0xFF)
    patch = Bitwise.bsr(value, 8) |> Bitwise.band(0xFF)
    build = value |> Bitwise.band(0xFF)

    %{
      fw_version_major: major,
      fw_version_minor: minor,
      fw_version_patch: patch,
      fw_version_build: build
    }
  end

  # Extract firmware version components from 24-bit value
  # Format: major.minor.patch (8.8.8 bits)
  defp extract_firmware_version_24(value) do
    major = Bitwise.bsr(value, 16) |> Bitwise.band(0xFF)
    minor = Bitwise.bsr(value, 8) |> Bitwise.band(0xFF)
    patch = value |> Bitwise.band(0xFF)

    %{
      fw_version_major: major,
      fw_version_minor: minor,
      fw_version_patch: patch
    }
  end

  # Extract encryption data from encrypted payload
  # Format: ciphertext + counter (4 bytes) + MIC (4 bytes)
  defp extract_encryption_data(data) when byte_size(data) >= 8 do
    mic_size = 4
    counter_size = 4
    min_size = mic_size + counter_size

    if byte_size(data) >= min_size do
      ciphertext_size = byte_size(data) - min_size

      <<ciphertext::binary-size(ciphertext_size), counter::binary-size(counter_size),
        mic::binary-size(mic_size)>> = data

      {counter, mic, ciphertext}
    else
      # Not enough data for counter + MIC
      {nil, nil, data}
    end
  end

  defp extract_encryption_data(data) do
    # Not enough data for proper encryption parsing
    {nil, nil, data}
  end
end
