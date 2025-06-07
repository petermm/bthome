defmodule BTHome.Objects do
  @moduledoc """
  BTHome v2 object definitions and metadata.

  This module centralizes all sensor type definitions according to the BTHome v2 specification
  and provides fast lookups. It includes metadata for each sensor type including units,
  scaling factors, data sizes, and signedness.

  ## Sensor Categories

  ### Environmental Sensors (0x01-0x0F)
  - Battery level, temperature, humidity, pressure, illuminance
  - Mass measurements, dewpoint, energy, power, voltage
  - Air quality sensors (PM2.5, PM10)

  ### Binary Sensors (0x10-0x2D)
  - Motion, door/window, occupancy, presence detection
  - Safety sensors (smoke, CO, gas, tamper)
  - Device state sensors (battery low, charging, connectivity)

  ## Performance Optimizations

  This module uses compile-time optimizations to provide O(1) lookups:
  - `@type_to_id_map` - Fast type-to-ID resolution
  - `@binary_sensor_types` - Set-based binary sensor detection
  - `@supported_types_map` - Efficient type validation

  ## Examples

      # Get definition by object ID
      iex> BTHome.Objects.get_definition(0x02)
      %{name: :temperature, unit: "°C", factor: 0.01, signed: true, size: 2}

      # Find by measurement type
      iex> BTHome.Objects.find_by_type(:temperature)
      {2, %{name: :temperature, unit: "°C", factor: 0.01, signed: true, size: 2}}

      # Check if binary sensor
      iex> BTHome.Objects.binary_sensor?(:motion)
      true
  """

  @object_definitions %{
    # Miscellaneous
    0x00 => %{name: :packet_id, unit: "", factor: 1, signed: false, size: 1},

    # Environmental sensors
    0x01 => %{name: :battery, unit: "%", factor: 1, signed: false, size: 1},
    0x02 => %{name: :temperature, unit: "°C", factor: 0.01, signed: true, size: 2},
    0x03 => %{name: :humidity, unit: "%", factor: 0.01, signed: false, size: 2},
    0x04 => %{name: :pressure, unit: "hPa", factor: 0.01, signed: false, size: 3},
    0x05 => %{name: :illuminance, unit: "lux", factor: 0.01, signed: false, size: 3},
    0x06 => %{name: :mass, unit: "kg", factor: 0.01, signed: false, size: 2},
    0x07 => %{name: :mass, unit: "lb", factor: 0.01, signed: false, size: 2},
    0x08 => %{name: :dewpoint, unit: "°C", factor: 0.01, signed: true, size: 2},
    0x09 => %{name: :count, unit: "", factor: 1, signed: false, size: 1},
    0x0A => %{name: :energy, unit: "kWh", factor: 0.001, signed: false, size: 3},
    0x0B => %{name: :power, unit: "W", factor: 0.01, signed: false, size: 3},
    0x0C => %{name: :voltage, unit: "V", factor: 0.001, signed: false, size: 2},
    0x0D => %{name: :pm2_5, unit: "µg/m³", factor: 1, signed: false, size: 2},
    0x0E => %{name: :pm10, unit: "µg/m³", factor: 1, signed: false, size: 2},
    0x0F => %{name: :generic_boolean, unit: "", factor: 1, signed: false, size: 1},

    # Binary sensors
    0x10 => %{name: :power_binary, unit: "", factor: 1, signed: false, size: 1},
    0x11 => %{name: :opening, unit: "", factor: 1, signed: false, size: 1},
    0x12 => %{name: :co2, unit: "ppm", factor: 1, signed: false, size: 2},
    0x13 => %{name: :tvoc, unit: "µg/m³", factor: 1, signed: false, size: 2},
    0x14 => %{name: :moisture, unit: "%", factor: 0.01, signed: false, size: 2},
    0x15 => %{name: :battery_low, unit: "", factor: 1, signed: false, size: 1},
    0x16 => %{name: :battery_charging, unit: "", factor: 1, signed: false, size: 1},
    0x17 => %{name: :carbon_monoxide, unit: "", factor: 1, signed: false, size: 1},
    0x18 => %{name: :cold, unit: "", factor: 1, signed: false, size: 1},
    0x19 => %{name: :connectivity, unit: "", factor: 1, signed: false, size: 1},
    0x1A => %{name: :door, unit: "", factor: 1, signed: false, size: 1},
    0x1B => %{name: :garage_door, unit: "", factor: 1, signed: false, size: 1},
    0x1C => %{name: :gas, unit: "", factor: 1, signed: false, size: 1},
    0x1D => %{name: :heat, unit: "", factor: 1, signed: false, size: 1},
    0x1E => %{name: :light, unit: "", factor: 1, signed: false, size: 1},
    0x1F => %{name: :lock, unit: "", factor: 1, signed: false, size: 1},
    0x20 => %{name: :moisture_binary, unit: "", factor: 1, signed: false, size: 1},
    0x21 => %{name: :motion, unit: "", factor: 1, signed: false, size: 1},
    0x22 => %{name: :moving, unit: "", factor: 1, signed: false, size: 1},
    0x23 => %{name: :occupancy, unit: "", factor: 1, signed: false, size: 1},
    0x24 => %{name: :plug, unit: "", factor: 1, signed: false, size: 1},
    0x25 => %{name: :presence, unit: "", factor: 1, signed: false, size: 1},
    0x26 => %{name: :problem, unit: "", factor: 1, signed: false, size: 1},
    0x27 => %{name: :running, unit: "", factor: 1, signed: false, size: 1},
    0x28 => %{name: :safety, unit: "", factor: 1, signed: false, size: 1},
    0x29 => %{name: :smoke, unit: "", factor: 1, signed: false, size: 1},
    0x2A => %{name: :sound, unit: "", factor: 1, signed: false, size: 1},
    0x2B => %{name: :tamper, unit: "", factor: 1, signed: false, size: 1},
    0x2C => %{name: :vibration, unit: "", factor: 1, signed: false, size: 1},
    0x2D => %{name: :window, unit: "", factor: 1, signed: false, size: 1},
    0x2E => %{name: :humidity_binary, unit: "", factor: 1, signed: false, size: 1},
    0x2F => %{name: :moisture_binary_2, unit: "", factor: 1, signed: false, size: 1},

    # Button events
    0x3A => %{name: :button, unit: "", factor: 1, signed: false, size: 1},
    0x3C => %{name: :dimmer, unit: "", factor: 1, signed: false, size: 2},
    0x3D => %{name: :count_uint16, unit: "", factor: 1, signed: false, size: 2},
    0x3E => %{name: :count_uint32, unit: "", factor: 1, signed: false, size: 4},

    # Rotation measurement
    0x3F => %{name: :rotation, unit: "°", factor: 0.1, signed: false, size: 2},

    # Extended measurements with different sizes
    0x40 => %{name: :distance_mm, unit: "mm", factor: 1, signed: false, size: 2},
    0x41 => %{name: :distance_m, unit: "m", factor: 0.1, signed: false, size: 2},
    0x42 => %{name: :duration, unit: "s", factor: 0.001, signed: false, size: 3},
    0x43 => %{name: :current, unit: "A", factor: 0.001, signed: false, size: 2},
    0x44 => %{name: :speed, unit: "m/s", factor: 0.01, signed: false, size: 2},
    0x45 => %{name: :temperature_2, unit: "°C", factor: 0.1, signed: true, size: 2},
    0x46 => %{name: :uv_index, unit: "-", factor: 0.1, signed: false, size: 1},
    0x47 => %{name: :volume_liters, unit: "L", factor: 0.1, signed: false, size: 2},
    0x48 => %{name: :volume_ml, unit: "mL", factor: 1, signed: false, size: 2},
    0x49 => %{name: :volume_flow_rate, unit: "m³/hr", factor: 0.001, signed: false, size: 2},
    0x4A => %{name: :voltage_2, unit: "V", factor: 0.1, signed: false, size: 2},
    0x4B => %{name: :gas_volume, unit: "m³", factor: 0.001, signed: false, size: 3},
    0x4C => %{name: :gas_volume_uint32, unit: "m³", factor: 0.001, signed: false, size: 4},
    0x4D => %{name: :energy_uint32, unit: "kWh", factor: 0.001, signed: false, size: 4},
    0x4E => %{name: :volume_liters_uint32, unit: "L", factor: 0.001, signed: false, size: 4},
    0x4F => %{name: :water, unit: "L", factor: 0.001, signed: false, size: 4},
    0x50 => %{name: :timestamp, unit: "", factor: 1, signed: false, size: 4},
    0x51 => %{name: :acceleration, unit: "m/s²", factor: 0.001, signed: false, size: 2},
    0x52 => %{name: :gyroscope, unit: "°/s", factor: 0.001, signed: false, size: 2},
    0x53 => %{name: :text, unit: "", factor: 1, signed: false, size: :variable},
    0x54 => %{name: :raw, unit: "", factor: 1, signed: false, size: :variable},
    0x55 => %{name: :volume_storage, unit: "L", factor: 0.001, signed: false, size: 4},
    0x56 => %{name: :conductivity, unit: "µS/cm", factor: 1, signed: false, size: 2},
    0x57 => %{name: :temperature_sint8, unit: "°C", factor: 1, signed: true, size: 1},
    0x58 => %{name: :temperature_sint8_2, unit: "°C", factor: 0.35, signed: true, size: 1},
    0x59 => %{name: :count_sint8, unit: "", factor: 1, signed: true, size: 1},
    0x5A => %{name: :count_sint16, unit: "", factor: 1, signed: true, size: 2},
    0x5B => %{name: :count_sint32, unit: "", factor: 1, signed: true, size: 4},
    0x5C => %{name: :power_sint32, unit: "W", factor: 0.01, signed: true, size: 4},
    0x5D => %{name: :current_sint16, unit: "A", factor: 0.001, signed: true, size: 2},
    0x5E => %{name: :direction, unit: "°", factor: 0.01, signed: false, size: 2},
    0x5F => %{name: :precipitation, unit: "mm", factor: 0.1, signed: false, size: 2},
    0x60 => %{name: :channel, unit: "", factor: 1, signed: false, size: 1},

    # Device information
    0xF0 => %{name: :device_type_id, unit: "", factor: 1, signed: false, size: 2},
    0xF1 => %{name: :firmware_version_uint32, unit: "", factor: 1, signed: false, size: 4},
    0xF2 => %{name: :firmware_version_uint24, unit: "", factor: 1, signed: false, size: 3}
  }

  # Compile-time optimizations for better performance
  @type_to_id_map @object_definitions
                  |> Enum.map(fn {id, %{name: name}} -> {name, {id, @object_definitions[id]}} end)
                  |> Map.new()

  # Binary sensors are those with empty units, size 1, and factor 1
  # but excluding specific non-binary sensors like packet_id, count, uv_index, etc.
  @non_binary_single_byte_sensors [
    :packet_id,
    :count,
    :count_uint16,
    :count_uint32,
    :uv_index,
    :channel,
    :device_type_id,
    :firmware_version_uint32,
    :firmware_version_uint24,
    :button,
    :dimmer
  ]

  @binary_sensor_types @object_definitions
                       |> Enum.filter(fn {_id,
                                          %{name: name, unit: unit, size: size, factor: factor}} ->
                         # Binary sensors have empty unit, size 1, factor 1, and are not in exclusion list
                         unit == "" and size == 1 and factor == 1 and
                           name not in @non_binary_single_byte_sensors
                       end)
                       |> Enum.map(fn {_id, %{name: name}} -> name end)
                       |> MapSet.new()

  @supported_types_map @object_definitions
                       |> Enum.map(fn {id, definition} ->
                         {definition.name, Map.put(definition, :object_id, id)}
                       end)
                       |> Map.new()

  @doc """
  Gets object definition by BTHome object ID.

  Returns the complete definition including name, unit, factor, signedness, and size.

  ## Examples

      iex> BTHome.Objects.get_definition(0x02)
      %{name: :temperature, unit: "°C", factor: 0.01, signed: true, size: 2}

      iex> BTHome.Objects.get_definition(0xFF)
      nil
  """
  @spec get_definition(integer()) :: map() | nil
  def get_definition(object_id), do: Map.get(@object_definitions, object_id)

  @doc """
  Finds object ID and definition by measurement type (O(1) lookup).

  Returns a tuple of {object_id, definition} or nil if not found.

  ## Examples

      iex> BTHome.Objects.find_by_type(:temperature)
      {2, %{name: :temperature, unit: "°C", factor: 0.01, signed: true, size: 2}}

      iex> BTHome.Objects.find_by_type(:invalid)
      nil
  """
  @spec find_by_type(atom()) :: {integer(), map()} | nil
  def find_by_type(type), do: Map.get(@type_to_id_map, type)

  @doc """
  Returns all object definitions as a map.

  ## Examples

      iex> definitions = BTHome.Objects.get_all_definitions()
      iex> Map.has_key?(definitions, 0x02)
      true
  """
  @spec get_all_definitions() :: map()
  def get_all_definitions, do: @object_definitions

  @doc """
  Returns all supported measurement types.

  ## Examples

      iex> types = BTHome.Objects.get_supported_types()
      iex> :temperature in types
      true
  """
  @spec get_supported_types() :: [atom()]
  def get_supported_types, do: Map.keys(@supported_types_map)

  @doc """
  Checks if a measurement type is a binary sensor (O(1) lookup).

  Binary sensors have empty units and 1-byte size, representing boolean states.

  ## Examples

      iex> BTHome.Objects.binary_sensor?(:motion)
      true

      iex> BTHome.Objects.binary_sensor?(:temperature)
      false
  """
  @spec binary_sensor?(atom()) :: boolean()
  def binary_sensor?(type), do: MapSet.member?(@binary_sensor_types, type)
end
