defmodule BTHomeRandomDataTest do
  @moduledoc """
  Comprehensive tests for BTHome v2 with randomly generated sensor data.

  This test suite validates the library's ability to handle a wide variety of
  sensor measurements by generating random data within valid ranges for each
  sensor type defined in the BTHome v2 specification.

  Based on BTHome v2 specification from https://bthome.io/format/
  """

  use ExUnit.Case
  doctest BTHome

  alias BTHome.Measurement
  alias BTHome.Objects

  # Helper function to create measurement structs
  defp measurement(type, value, object_id \\ nil) do
    %Measurement{type: type, value: value, object_id: object_id}
  end

  # Define realistic ranges for different sensor types based on BTHome v2 specification
  @sensor_ranges %{
    # Environmental sensors with BTHome v2 limits
    # °C with factor 0.01
    temperature: {-327.68, 327.67},
    # % with factor 0.01
    humidity: {0.0, 655.35},
    # hPa with factor 0.01
    pressure: {0.0, 167_772.15},
    # lux with factor 0.01
    illuminance: {0.0, 167_772.15},
    # kg with factor 0.01
    mass: {0.0, 655.35},
    # °C with factor 0.01
    dewpoint: {-327.68, 327.67},
    # uint8
    count: {0, 255},
    # kWh with factor 0.001
    energy: {0.0, 16_777.215},
    # W with factor 0.01
    power: {0.0, 167_772.15},
    # V with factor 0.001
    voltage: {0.0, 65.535},
    # µg/m³
    pm2_5: {0, 65_535},
    # µg/m³
    pm10: {0, 65_535},
    # ppm
    co2: {0, 65_535},
    # µg/m³
    tvoc: {0, 65_535},
    # % with factor 0.01
    moisture: {0.0, 655.35},
    # mm
    distance_mm: {0, 65_535},
    # m with factor 0.1
    distance_m: {0.0, 6553.5},
    # s with factor 0.001
    duration: {0.0, 16_777.215},
    # A with factor 0.001
    current: {0.0, 65.535},
    # m/s with factor 0.01
    speed: {0.0, 655.35},
    # °C with factor 0.1
    temperature_precise: {-3276.8, 3276.7},
    # with factor 0.1
    uv_index: {0.0, 25.5},
    # mL
    volume_ml: {0, 65_535},
    # L with factor 0.1
    volume_l: {0.0, 655.35},
    # m³/hr with factor 0.001
    volume_flow_rate: {0.0, 65.535},
    # V with factor 0.1
    voltage_precise: {0.0, 6553.5},
    # m³ with factor 0.001
    gas: {0.0, 16_777.215},
    # m/s² with factor 0.001
    acceleration: {0.0, 65.535},
    # °/s with factor 0.001
    gyroscope: {0.0, 65.535},
    count_uint16: {0, 65_535},
    count_uint32: {0, 4_294_967_295},
    # m³ with factor 0.001
    gas_volume_uint32: {0, 4_294_967.295},
    # kWh with factor 0.001
    energy_uint32: {0, 4_294_967.295},
    # L with factor 0.001
    volume_liters_uint32: {0, 4_294_967.295},
    # L with factor 0.001
    water: {0, 4_294_967.295},
    # Unix timestamp
    timestamp: {0, 4_294_967_295},
    # L with factor 0.001
    volume_storage: {0, 4_294_967.295},
    count_sint32: {-2_147_483_648, 2_147_483_647},
    # W with factor 0.01
    power_sint32: {-21_474_836.48, 21_474_836.47},
    firmware_version_uint32: {0, 4_294_967_295},
    # °C with factor 0.35
    temperature_sint8_2: {-44.8, 44.45},
    # ° with factor 0.1
    rotation: {0.0, 6553.5},
    # A with factor 0.001
    current_sint16: {-32.768, 32.767}
  }

  # Binary sensor types that should use boolean values
  @binary_sensors [
    :generic_boolean,
    :power_binary,
    :opening,
    :battery_low,
    :battery_charging,
    :carbon_monoxide,
    :cold,
    :connectivity,
    :door,
    :garage_door,
    :gas,
    :heat,
    :light,
    :lock,
    :moisture_binary,
    :motion,
    :moving,
    :occupancy,
    :plug,
    :presence,
    :problem,
    :running,
    :safety,
    :smoke,
    :sound,
    :tamper,
    :vibration,
    :window,
    :humidity_binary,
    :moisture_binary_2
  ]

  # Generate random value within the specified range for a sensor type
  defp generate_random_value(sensor_type) when sensor_type in @binary_sensors do
    Enum.random([true, false])
  end

  defp generate_random_value(sensor_type) do
    case Map.get(@sensor_ranges, sensor_type) do
      {min, max} when is_float(min) or is_float(max) ->
        # For float ranges, generate with appropriate precision
        (min + :rand.uniform() * (max - min))
        |> Float.round(3)

      {min, max} when is_integer(min) and is_integer(max) ->
        # For integer ranges
        Enum.random(min..max)

      nil ->
        # Default fallback for unknown sensor types
        :rand.uniform(1000) / 10.0
    end
  end

  # Generate a list of random measurements
  defp generate_random_measurements(sensor_types, count) do
    sensor_types
    |> Enum.take_random(count)
    |> Enum.map(fn sensor_type ->
      value = generate_random_value(sensor_type)
      measurement(sensor_type, value)
    end)
  end

  # Get all supported sensor types from the object definitions
  defp get_all_sensor_types do
    # Get all sensor types from object definitions, excluding variable size types
    unsupported_types = [
      # Exclude variable size types that don't have fixed validation ranges
      # 3-byte firmware version has special handling
      :firmware_version_uint24,
      # Variable size type that cannot be validated with fixed ranges
      :raw,
      # Variable size type that cannot be validated with fixed ranges
      :text
    ]

    Objects.get_supported_types()
    |> Enum.reject(&(&1 in unsupported_types))
  end

  test "serialize and deserialize random environmental sensor data" do
    environmental_sensors = [
      :battery,
      :temperature,
      :humidity,
      :pressure,
      :illuminance,
      :mass,
      :dewpoint,
      :energy,
      :power,
      :voltage,
      :pm2_5,
      :pm10
    ]

    for _iteration <- 1..100 do
      measurements = generate_random_measurements(environmental_sensors, 3)

      assert {:ok, binary} = BTHome.serialize(measurements)
      assert {:ok, decoded} = BTHome.deserialize(binary)

      # Verify we got the same number of measurements back
      assert length(decoded.measurements) == length(measurements)

      # Verify each measurement type is preserved
      original_types = Enum.map(measurements, & &1.type) |> Enum.sort()
      decoded_types = Enum.map(decoded.measurements, & &1.type) |> Enum.sort()
      assert original_types == decoded_types

      # Verify values are within reasonable precision (accounting for factor conversion)
      for {original, decoded_measurement} <- Enum.zip(measurements, decoded.measurements) do
        # Allow for small precision differences due to factor conversion
        assert abs(decoded_measurement.value - original.value) < 1.0
      end
    end
  end

  test "serialize and deserialize random binary sensor data" do
    for _iteration <- 1..100 do
      measurements = generate_random_measurements(@binary_sensors, 5)

      assert {:ok, binary} = BTHome.serialize(measurements)
      assert {:ok, decoded} = BTHome.deserialize(binary)

      # Verify binary sensors are properly encoded/decoded
      assert length(decoded.measurements) == length(measurements)

      for {original, decoded_measurement} <- Enum.zip(measurements, decoded.measurements) do
        assert decoded_measurement.type == original.type
        # Binary sensors should return boolean values
        assert is_boolean(decoded_measurement.value)
        # The boolean value should match the original
        assert decoded_measurement.value == original.value
      end
    end
  end

  test "serialize and deserialize random mixed sensor data" do
    all_types = get_all_sensor_types()

    for _iteration <- 1..100 do
      measurements = generate_random_measurements(all_types, 8)

      assert {:ok, binary} = BTHome.serialize(measurements)
      assert {:ok, decoded} = BTHome.deserialize(binary)

      # Basic validation
      assert length(decoded.measurements) == length(measurements)
      assert decoded.version == 2
      assert decoded.encrypted == false

      # Verify measurement integrity
      original_types = Enum.map(measurements, & &1.type) |> Enum.sort()
      decoded_types = Enum.map(decoded.measurements, & &1.type) |> Enum.sort()
      assert original_types == decoded_types
    end
  end

  test "handle edge case values for numeric sensors" do
    edge_cases = [
      # Minimum realistic temperature
      measurement(:temperature, -40.0),
      # Maximum realistic temperature
      measurement(:temperature, 80.0),
      # Minimum humidity
      measurement(:humidity, 0.0),
      # Maximum humidity
      measurement(:humidity, 100.0),
      # Empty battery
      measurement(:battery, 0),
      # Full battery
      measurement(:battery, 100),
      # Low pressure
      measurement(:pressure, 300.0),
      # High pressure
      measurement(:pressure, 1100.0)
    ]

    for measurement <- edge_cases do
      assert {:ok, binary} = BTHome.serialize([measurement])
      assert {:ok, decoded} = BTHome.deserialize(binary)

      [decoded_measurement] = decoded.measurements
      assert decoded_measurement.type == measurement.type
      # Allow for small floating point differences
      assert abs(decoded_measurement.value - measurement.value) < 0.1
    end
  end

  test "handle large datasets with many random measurements" do
    all_types = get_all_sensor_types()

    # Test with a large number of measurements
    measurements = generate_random_measurements(all_types, 20)

    assert {:ok, binary} = BTHome.serialize(measurements)
    assert {:ok, decoded} = BTHome.deserialize(binary)

    assert length(decoded.measurements) == length(measurements)

    # Verify all measurements are accounted for
    original_types = Enum.map(measurements, & &1.type) |> Enum.sort()
    decoded_types = Enum.map(decoded.measurements, & &1.type) |> Enum.sort()
    assert original_types == decoded_types
  end

  test "random data stress test with multiple iterations" do
    all_types = get_all_sensor_types()

    # Run many iterations to catch edge cases
    for iteration <- 1..100 do
      count = Enum.random(1..10)
      measurements = generate_random_measurements(all_types, count)

      case BTHome.serialize(measurements) do
        {:ok, binary} ->
          case BTHome.deserialize(binary) do
            {:ok, decoded} ->
              assert length(decoded.measurements) == length(measurements)

            {:error, reason} ->
              flunk("Deserialization failed on iteration #{iteration}: #{inspect(reason)}")
          end

        {:error, reason} ->
          flunk("Serialization failed on iteration #{iteration}: #{inspect(reason)}")
      end
    end
  end

  test "validate measurement ranges are respected" do
    # Test that our random generation respects the defined ranges
    for {sensor_type, {min, max}} <- @sensor_ranges do
      unless sensor_type in @binary_sensors do
        for _test <- 1..100 do
          value = generate_random_value(sensor_type)
          assert value >= min, "Generated value #{value} below minimum #{min} for #{sensor_type}"
          assert value <= max, "Generated value #{value} above maximum #{max} for #{sensor_type}"
        end
      end
    end
  end

  test "binary sensors generate only boolean values" do
    for sensor_type <- @binary_sensors do
      for _test <- 1..100 do
        value = generate_random_value(sensor_type)

        assert value in [true, false],
               "Binary sensor #{sensor_type} generated non-boolean value: #{inspect(value)}"
      end
    end
  end

  test "round trip precision for different factor types" do
    # Test sensors with different factor values to ensure precision is maintained
    precision_tests = [
      # factor 0.01
      measurement(:temperature, 23.45),
      # factor 0.001
      measurement(:energy, 12.345),
      # factor 0.1
      measurement(:rotation, 180.5),
      # factor 0.001
      measurement(:voltage, 3.300),
      # factor 0.1
      measurement(:uv_index, 7.2)
    ]

    assert {:ok, binary} = BTHome.serialize(precision_tests)
    assert {:ok, decoded} = BTHome.deserialize(binary)

    for {original, decoded_measurement} <- Enum.zip(precision_tests, decoded.measurements) do
      assert decoded_measurement.type == original.type
      # Allow for factor-based precision differences
      precision =
        case original.type do
          type when type in [:energy, :voltage] -> 0.001
          type when type in [:rotation, :uv_index] -> 0.1
          _ -> 0.01
        end

      assert abs(decoded_measurement.value - original.value) <= precision
    end
  end
end
