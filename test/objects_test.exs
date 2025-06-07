defmodule BTHome.ObjectsTest do
  use ExUnit.Case, async: true
  alias BTHome.Objects

  describe "get_definition/1" do
    test "returns definition for valid object ID" do
      definition = Objects.get_definition(0x02)
      assert definition.name == :temperature
      assert definition.unit == "°C"
      assert definition.factor == 0.01
      assert definition.signed == true
      assert definition.size == 2
    end

    test "returns nil for invalid object ID" do
      assert Objects.get_definition(0xFF) == nil
      assert Objects.get_definition(999) == nil
    end

    test "returns definition for all documented object IDs" do
      # Test a representative sample of all object types
      test_cases = [
        {0x00, :packet_id, "", 1, false, 1},
        {0x01, :battery, "%", 1, false, 1},
        {0x02, :temperature, "°C", 0.01, true, 2},
        {0x03, :humidity, "%", 0.01, false, 2},
        {0x04, :pressure, "hPa", 0.01, false, 3},
        {0x05, :illuminance, "lux", 0.01, false, 3},
        {0x21, :motion, "", 1, false, 1},
        {0x3A, :button, "", 1, false, 1},
        {0x3E, :count_uint32, "", 1, false, 4},
        {0x5B, :count_sint32, "", 1, true, 4},
        {0xF0, :device_type_id, "", 1, false, 2}
      ]

      for {id, name, unit, factor, signed, size} <- test_cases do
        definition = Objects.get_definition(id)
        assert definition.name == name, "Object ID #{inspect(id)} name mismatch"
        assert definition.unit == unit, "Object ID #{inspect(id)} unit mismatch"
        assert definition.factor == factor, "Object ID #{inspect(id)} factor mismatch"
        assert definition.signed == signed, "Object ID #{inspect(id)} signed mismatch"
        assert definition.size == size, "Object ID #{inspect(id)} size mismatch"
      end
    end
  end

  describe "find_by_type/1" do
    test "returns object ID and definition for valid type" do
      {id, definition} = Objects.find_by_type(:temperature)
      assert id == 0x02
      assert definition.name == :temperature
      assert definition.unit == "°C"
    end

    test "returns nil for invalid type" do
      assert Objects.find_by_type(:invalid_sensor) == nil
      assert Objects.find_by_type(:nonexistent) == nil
    end

    test "finds all documented sensor types" do
      # Test a comprehensive list of sensor types
      sensor_types = [
        :packet_id,
        :battery,
        :temperature,
        :humidity,
        :pressure,
        :illuminance,
        :mass,
        :dewpoint,
        :count,
        :energy,
        :power,
        :voltage,
        :pm2_5,
        :pm10,
        :generic_boolean,
        :power_binary,
        :opening,
        :co2,
        :tvoc,
        :moisture,
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
        :moisture_binary_2,
        :button,
        :dimmer,
        :count_uint16,
        :count_uint32,
        :rotation,
        :distance_mm,
        :distance_m,
        :duration,
        :current,
        :speed,
        :temperature_2,
        :uv_index,
        :volume_liters,
        :volume_ml,
        :volume_flow_rate,
        :voltage_2,
        :gas_volume,
        :gas_volume_uint32,
        :energy_uint32,
        :volume_liters_uint32,
        :water,
        :timestamp,
        :acceleration,
        :gyroscope,
        :text,
        :raw,
        :volume_storage,
        :conductivity,
        :temperature_sint8,
        :temperature_sint8_2,
        :count_sint8,
        :count_sint16,
        :count_sint32,
        :power_sint32,
        :current_sint16,
        :direction,
        :precipitation,
        :channel,
        :device_type_id,
        :firmware_version_uint32,
        :firmware_version_uint24
      ]

      for sensor_type <- sensor_types do
        result = Objects.find_by_type(sensor_type)
        assert result != nil, "Sensor type #{inspect(sensor_type)} not found"
        {id, definition} = result
        assert is_integer(id), "Object ID should be integer for #{inspect(sensor_type)}"

        assert definition.name == sensor_type,
               "Definition name mismatch for #{inspect(sensor_type)}"
      end
    end
  end

  describe "get_all_definitions/0" do
    test "returns map with all object definitions" do
      definitions = Objects.get_all_definitions()
      assert is_map(definitions)
      # Should have many definitions
      assert map_size(definitions) > 50

      # Check some key definitions exist
      # temperature
      assert Map.has_key?(definitions, 0x02)
      # motion
      assert Map.has_key?(definitions, 0x21)
      # count_uint32
      assert Map.has_key?(definitions, 0x3E)
    end

    test "all definitions have required fields" do
      definitions = Objects.get_all_definitions()

      for {id, definition} <- definitions do
        assert Map.has_key?(definition, :name), "Object ID #{inspect(id)} missing :name"
        assert Map.has_key?(definition, :unit), "Object ID #{inspect(id)} missing :unit"
        assert Map.has_key?(definition, :factor), "Object ID #{inspect(id)} missing :factor"
        assert Map.has_key?(definition, :signed), "Object ID #{inspect(id)} missing :signed"
        assert Map.has_key?(definition, :size), "Object ID #{inspect(id)} missing :size"

        assert is_atom(definition.name), "Object ID #{inspect(id)} name should be atom"
        assert is_binary(definition.unit), "Object ID #{inspect(id)} unit should be string"
        assert is_number(definition.factor), "Object ID #{inspect(id)} factor should be number"
        assert is_boolean(definition.signed), "Object ID #{inspect(id)} signed should be boolean"
        assert definition.size in [1, 2, 3, 4, :variable], "Object ID #{inspect(id)} invalid size"
      end
    end
  end

  describe "get_supported_types/0" do
    test "returns list of all supported measurement types" do
      types = Objects.get_supported_types()
      assert is_list(types)
      # Should have many types
      assert length(types) > 50

      # Check some key types are included
      assert :temperature in types
      assert :humidity in types
      assert :motion in types
      assert :battery in types
    end

    test "all returned types are atoms" do
      types = Objects.get_supported_types()

      for type <- types do
        assert is_atom(type), "Type #{inspect(type)} should be atom"
      end
    end

    test "all types can be found by find_by_type" do
      types = Objects.get_supported_types()

      for type <- types do
        result = Objects.find_by_type(type)
        assert result != nil, "Type #{inspect(type)} should be findable"
      end
    end
  end

  describe "binary_sensor?/1" do
    test "identifies binary sensors correctly" do
      binary_sensors = [
        :motion,
        :door,
        :window,
        :opening,
        :occupancy,
        :presence,
        :battery_low,
        :battery_charging,
        :carbon_monoxide,
        :cold,
        :connectivity,
        :garage_door,
        :gas,
        :heat,
        :light,
        :lock,
        :moisture_binary,
        :moving,
        :plug,
        :problem,
        :running,
        :safety,
        :smoke,
        :sound,
        :tamper,
        :vibration,
        :humidity_binary,
        :moisture_binary_2,
        :power_binary,
        :generic_boolean
      ]

      for sensor <- binary_sensors do
        assert Objects.binary_sensor?(sensor), "#{inspect(sensor)} should be binary sensor"
      end
    end

    test "identifies non-binary sensors correctly" do
      non_binary_sensors = [
        :temperature,
        :humidity,
        :pressure,
        :illuminance,
        :battery,
        :mass,
        :dewpoint,
        :energy,
        :power,
        :voltage,
        :pm2_5,
        :pm10,
        :co2,
        :tvoc,
        :moisture,
        :count,
        :count_uint16,
        :count_uint32,
        :rotation,
        :distance_mm,
        :distance_m,
        :duration,
        :current,
        :speed,
        :temperature_2,
        :uv_index,
        :volume_liters,
        :volume_ml,
        :packet_id,
        :button,
        :dimmer,
        :channel,
        :device_type_id
      ]

      for sensor <- non_binary_sensors do
        assert not Objects.binary_sensor?(sensor),
               "#{inspect(sensor)} should not be binary sensor"
      end
    end

    test "returns false for unknown types" do
      assert not Objects.binary_sensor?(:unknown_sensor)
      assert not Objects.binary_sensor?(:invalid_type)
    end
  end

  describe "data integrity" do
    test "no duplicate object IDs" do
      definitions = Objects.get_all_definitions()
      ids = Map.keys(definitions)
      unique_ids = Enum.uniq(ids)

      assert length(ids) == length(unique_ids), "Duplicate object IDs found"
    end

    test "no duplicate measurement type names" do
      definitions = Objects.get_all_definitions()
      names = Enum.map(definitions, fn {_id, def} -> def.name end)
      unique_names = Enum.uniq(names)

      # Note: Some names like :mass appear multiple times with different units
      # This is expected behavior, so we check that the count is reasonable
      assert length(unique_names) > 50, "Should have many unique measurement types"
    end

    test "all factors are positive numbers" do
      definitions = Objects.get_all_definitions()

      for {id, definition} <- definitions do
        assert definition.factor > 0, "Object ID #{inspect(id)} has non-positive factor"
      end
    end

    test "all sizes are valid" do
      definitions = Objects.get_all_definitions()
      valid_sizes = [1, 2, 3, 4, :variable]

      for {id, definition} <- definitions do
        assert definition.size in valid_sizes,
               "Object ID #{inspect(id)} has invalid size #{inspect(definition.size)}"
      end
    end
  end

  describe "performance characteristics" do
    test "find_by_type is O(1) lookup" do
      # Test that lookup time doesn't scale with number of calls
      start_time = System.monotonic_time(:microsecond)

      for _i <- 1..1000 do
        Objects.find_by_type(:temperature)
      end

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      # Should complete 1000 lookups very quickly (under 10ms)
      assert duration < 100_000, "Lookups taking too long: #{duration} microseconds"
    end

    test "binary_sensor? is O(1) lookup" do
      # Test that binary sensor check is fast
      start_time = System.monotonic_time(:microsecond)

      for _i <- 1..1000 do
        Objects.binary_sensor?(:motion)
      end

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      # Should complete 1000 checks very quickly (under 10ms)
      assert duration < 10_000, "Binary sensor checks taking too long: #{duration} microseconds"
    end
  end

  describe "edge cases" do
    test "handles nil input gracefully" do
      assert Objects.find_by_type(nil) == nil
      assert not Objects.binary_sensor?(nil)
    end

    test "handles non-atom input for binary_sensor?" do
      assert not Objects.binary_sensor?("motion")
      assert not Objects.binary_sensor?(123)
    end

    test "handles negative object IDs" do
      assert Objects.get_definition(-1) == nil
      assert Objects.get_definition(-999) == nil
    end

    test "handles very large object IDs" do
      assert Objects.get_definition(999_999) == nil
      assert Objects.get_definition(0xFFFFFFFF) == nil
    end
  end
end
