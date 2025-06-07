# BTHome v2 Parser/Serializer for Elixir

A comprehensive, type-safe implementation of the BTHome v2 protocol for Elixir. This library provides serialization and deserialization of sensor data according to the [BTHome v2 specification](https://bthome.io/).

## Features

- 🔒 **Type Safety** - Uses structs for measurements and decoded data
- ✅ **Validation** - Comprehensive validation of measurement types and values
- 🚨 **Error Handling** - Structured errors with context information
- ⚡ **Performance** - Compile-time optimizations for fast lookups
- 🔄 **Compatibility** - Supports both struct and map-based APIs
- 📊 **Complete Coverage** - Supports all BTHome v2 sensor types
- 🛡️ **Error Recovery** - Graceful handling of unknown object IDs

## Installation

Add `bthome` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bthome, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Create measurements using the builder pattern (recommended)
binary = BTHome.new_packet()
|> BTHome.add_measurement(:temperature, 23.45)
|> BTHome.add_measurement(:motion, true)
|> BTHome.serialize!()
# => <<64, 2, 41, 9, 33, 1>>

# Serialize to binary format
{:ok, binary} = BTHome.serialize([temp, motion])
# => {:ok, <<64, 2, 41, 9, 33, 1>>}

# Deserialize back to structs
{:ok, decoded} = BTHome.deserialize(binary)
# => {:ok, %BTHome.DecodedData{
#      version: 2,
#      encrypted: false,
#      trigger_based: false,
#      measurements: [
#        %BTHome.Measurement{type: :temperature, value: 23.45, unit: "°C"},
#        %BTHome.Measurement{type: :motion, value: true, unit: nil}
#      ]
#    }}
# Deserialize back (recommended)
measurements = BTHome.deserialize_measurements!(binary)
# => %{temperature: 23.45, motion: true}

# Direct access to values
temp = measurements.temperature  # 23.45
motion = measurements.motion     # true
```

## Supported Sensor Types

### Environmental Sensors

| Type | Unit | Description | Range |
|------|------|-------------|-------|
| `:temperature` | °C | Temperature | -327.68 to 327.67 °C |
| `:humidity` | % | Relative humidity | 0 to 655.35% |
| `:pressure` | hPa | Atmospheric pressure | 0 to 167772.15 hPa |
| `:illuminance` | lux | Light level | 0 to 167772.15 lux |
| `:battery` | % | Battery level | 0 to 255% |
| `:energy` | kWh | Energy consumption | 0 to 16777.215 kWh |
| `:power` | W | Power consumption | 0 to 167772.15 W |
| `:voltage` | V | Voltage | 0 to 65.535 V |
| `:pm2_5` | µg/m³ | PM2.5 particles | 0 to 65535 µg/m³ |
| `:pm10` | µg/m³ | PM10 particles | 0 to 65535 µg/m³ |
| `:co2` | ppm | CO2 concentration | 0 to 65535 ppm |
| `:tvoc` | µg/m³ | Total VOC | 0 to 65535 µg/m³ |

### Binary Sensors

| Type | Description |
|------|-------------|
| `:motion` | Motion detection |
| `:door` | Door state (open/closed) |
| `:window` | Window state (open/closed) |
| `:occupancy` | Room occupancy |
| `:presence` | Presence detection |
| `:smoke` | Smoke detection |
| `:gas_detected` | Gas detection |
| `:carbon_monoxide` | CO detection |
| `:battery_low` | Low battery warning |
| `:battery_charging` | Charging status |
| `:connectivity` | Connection status |
| `:problem` | Problem/fault status |
| `:safety` | Safety status |
| `:tamper` | Tamper detection |
| `:vibration` | Vibration detection |

## API Documentation

### Creating Measurements

```elixir
# Recommended: Using the measurement function with validation
{:ok, temp} = BTHome.measurement(:temperature, 23.45)
{:ok, motion} = BTHome.measurement(:motion, true)

# With custom unit override
{:ok, temp_f} = BTHome.measurement(:temperature, 74.21, unit: "°F")

# Direct struct creation (advanced)
%BTHome.Measurement{
  type: :temperature,
  value: 23.45,
  unit: "°C"
}
```

### Serialization

```elixir
# Basic serialization
measurements = [temp, motion]
{:ok, binary} = BTHome.serialize(measurements)

# With encryption flag
{:ok, encrypted_binary} = BTHome.serialize(measurements, true)

# Legacy map format (still supported)
legacy_measurements = [
  %{type: :temperature, value: 23.45},
  %{type: :humidity, value: 67.8}
]
{:ok, binary} = BTHome.serialize(legacy_measurements)
```

### Builder Pattern API

For a more fluent, pipeable approach to creating BTHome packets:

```elixir
# Create and serialize in a single pipeline
{:ok, binary} = BTHome.new_packet()
|> BTHome.add_measurement(:temperature, 23.45)
|> BTHome.add_measurement(:motion, true)
|> BTHome.add_measurement(:humidity, 67.8)
|> BTHome.serialize()

# With encryption
{:ok, encrypted_binary} = BTHome.new_packet()
|> BTHome.add_measurement(:temperature, 23.45)
|> BTHome.add_measurement(:battery, 85)
|> BTHome.serialize(true)

# Error handling with builder pattern
result = BTHome.new_packet()
|> BTHome.add_measurement(:temperature, 23.45)
|> BTHome.add_measurement(:invalid_type, 42)  # This will cause an error
|> BTHome.serialize()

case result do
  {:ok, binary} -> process_binary(binary)
  {:error, error} -> handle_error(error)
end

# Custom measurement options
{:ok, binary} = BTHome.new_packet()
|> BTHome.add_measurement(:temperature, 74.21, unit: "°F")
|> BTHome.add_measurement(:voltage, 3.3, object_id: 0x0C)
|> BTHome.serialize()
```

The builder pattern provides several advantages:
- **Fluent API**: Chain operations naturally with the pipe operator
- **Error Accumulation**: Invalid measurements are stored but don't break the chain
- **Validation**: Each measurement is validated when added
- **Flexibility**: Mix with existing APIs or use standalone

### Deserialization

**Recommended: Use `deserialize_measurements!/1` for the most ergonomic API:**

```elixir
# Simple, direct access to measurements
binary = <<64, 2, 202, 9, 3, 191, 19>>
measurements = BTHome.deserialize_measurements!(binary)

# Direct access to values
temp = measurements.temperature  # 25.06
humidity = measurements.humidity # 50.23

# Handle multiple measurements of the same type
measurements.voltage  # [3.1, 2.8] - list for multiple values

# Binary sensors
measurements.motion   # true/false
```

**Alternative: Use the tuple-returning version for explicit error handling:**

```elixir
case BTHome.deserialize_measurements(binary) do
  {:ok, measurements} -> 
    IO.puts("Temperature: #{measurements.temperature}°C")
  {:error, reason} -> 
    IO.puts("Failed to decode: #{reason}")
end
```

**Low-level: Access the full decoded structure:**

```elixir
{:ok, decoded} = BTHome.deserialize(binary)

# Access metadata
decoded.version        # => 2
decoded.encrypted      # => false
decoded.trigger_based  # => false

# Access measurements as structs
[temp_measurement, humidity_measurement] = decoded.measurements
temp_measurement.value  # 25.06
temp_measurement.unit   # "°C"
```

### Convenience Functions

#### `deserialize_measurements!/1` (Recommended)

The most ergonomic way to access measurement data. Returns measurements as a map and raises on error:

```elixir
# Simple, direct access - no pattern matching needed
binary = <<64, 2, 202, 9, 3, 191, 19>>
measurements = BTHome.deserialize_measurements!(binary)

# Direct access to values
temp = measurements.temperature  # 25.06
humidity = measurements.humidity # 50.23

# Handle multiple measurements of the same type
binary_with_multiple_temps = <<64, 2, 202, 9, 18, 2, 100, 5>>
measurements = BTHome.deserialize_measurements!(binary_with_multiple_temps)
measurements.temperature  # [25.06, 13.0] - returns list for multiple values

# Binary sensors
binary_sensor = <<64, 15, 1>>
measurements = BTHome.deserialize_measurements!(binary_sensor)
measurements.generic_boolean  # true
```

#### `deserialize_measurements/1`

For explicit error handling, use the tuple-returning version:

```elixir
case BTHome.deserialize_measurements(binary) do
  {:ok, measurements} -> 
    # Process measurements
    IO.puts("Temperature: #{measurements.temperature}°C")
  {:error, %BTHome.Error{message: message}} -> 
    IO.puts("Decoding failed: #{message}")
end
```

### Validation

```elixir
# Validate individual measurement
case BTHome.validate_measurement(measurement) do
  :ok -> IO.puts("Valid measurement")
  {:error, error} -> IO.puts("Invalid: #{error.message}")
end

# Validate list of measurements
case BTHome.validate_measurements(measurements) do
  :ok -> BTHome.serialize(measurements)
  {:error, error} -> handle_validation_error(error)
end
```

### Error Handling

All functions return structured errors with context:

```elixir
{:error, %BTHome.Error{
  type: :validation,  # :validation, :encoding, or :decoding
  message: "Unsupported measurement type: :invalid",
  context: %{type: :invalid}  # Additional debugging info
}}
```

## Advanced Usage

### Custom Object IDs

```elixir
# Override default object ID (advanced use case)
{:ok, measurement} = BTHome.measurement(:temperature, 23.45, object_id: 0x02)
```

### Backwards Compatibility

The library maintains backwards compatibility with the legacy API:

```elixir
BTHome.serialize(measurements)
BTHome.deserialize(binary)
BTHome.measurement(:temperature, 23.45)
```

### Performance Considerations

The library uses compile-time optimizations for maximum performance:

- O(1) type lookups using compile-time maps
- Set-based binary sensor detection
- Minimal runtime overhead for validation

### Error Recovery

The decoder includes error recovery for unknown object IDs:

```elixir
# If binary contains unknown object IDs, they are skipped
# and parsing continues with known measurements
{:ok, decoded} = BTHome.deserialize(binary_with_unknown_data)
# Successfully returns known measurements, skips unknown ones
```

## Examples

### IoT Sensor Data

```elixir
# Traditional approach
measurements = [
  %{type: :temperature, value: 22.5},
  %{type: :humidity, value: 45.0},
  %{type: :battery, value: 85}
]

{:ok, binary} = BTHome.serialize(measurements)
data = BTHome.deserialize_measurements!(binary)
# => %{temperature: 22.5, humidity: 45.0, battery: 85}

# IoT Sensor Data - Builder pattern approach
binary = BTHome.Packet.new()
|> BTHome.Packet.add_measurement(:temperature, 22.5)
|> BTHome.Packet.add_measurement(:humidity, 45.0)
|> BTHome.Packet.add_measurement(:battery, 85)
|> BTHome.Packet.serialize!()

data = BTHome.deserialize_measurements!(binary)
# => %{temperature: 22.5, humidity: 45.0, battery: 85}
```

### Home Automation

```elixir
# Traditional approach
measurements = [
  %{type: :motion, value: true},
  %{type: :door, value: false},
  %{type: :temperature, value: 21.0}
]

{:ok, binary} = BTHome.serialize(measurements)
data = BTHome.deserialize_measurements!(binary)
# => %{motion: true, door: false, temperature: 21.0}

# Home Automation - Builder pattern approach
binary = BTHome.Packet.new()
|> BTHome.Packet.add_measurement(:motion, true)
|> BTHome.Packet.add_measurement(:door, false)
|> BTHome.Packet.add_measurement(:temperature, 21.0)
|> BTHome.Packet.serialize!()

data = BTHome.deserialize_measurements!(binary)
# => %{motion: true, door: false, temperature: 21.0}
```

### Environmental Monitoring

```elixir
# Environmental Monitoring - Traditional approach
measurements = [
  %{type: :temperature, value: 23.1},
  %{type: :humidity, value: 58.3},
  %{type: :pressure, value: 1013.25},
  %{type: :pm2_5, value: 12},
  %{type: :pm10, value: 18},
  %{type: :co2, value: 420}
]

{:ok, binary} = BTHome.serialize(measurements)
data = BTHome.deserialize_measurements!(binary)
# => %{temperature: 23.1, humidity: 58.3, pressure: 1013.25, pm2_5: 12, pm10: 18, co2: 420}

# Environmental Monitoring - Builder pattern approach
binary = BTHome.Packet.new()
|> BTHome.Packet.add_measurement(:temperature, 23.1)
|> BTHome.Packet.add_measurement(:humidity, 58.3)
|> BTHome.Packet.add_measurement(:pressure, 1013.25)
|> BTHome.Packet.add_measurement(:pm2_5, 12)
|> BTHome.Packet.add_measurement(:pm10, 18)
|> BTHome.Packet.add_measurement(:co2, 420)
|> BTHome.Packet.serialize!()

data = BTHome.deserialize_measurements!(binary)
# => %{temperature: 23.1, humidity: 58.3, pressure: 1013.25, pm2_5: 12, pm10: 18, co2: 420}
```

## Testing

Run the test suite:

```bash
mix test
```

The library includes comprehensive tests covering:
- All sensor types and their ranges
- Serialization/deserialization round trips
- Validation edge cases
- Error recovery scenarios
- Backwards compatibility

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## References

- [BTHome v2 Specification](https://bthome.io/)
- [Bluetooth Low Energy](https://www.bluetooth.com/specifications/bluetooth-core-specification/)

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/bthome>.

