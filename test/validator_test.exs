defmodule BTHome.ValidatorTest do
  use ExUnit.Case, async: true
  alias BTHome.{Measurement, Validator}

  # Helper function to create measurement structs
  defp measurement(type, value, object_id \\ nil) do
    %Measurement{type: type, value: value, object_id: object_id}
  end

  describe "validate_measurements/1" do
    test "validates empty list" do
      assert Validator.validate_measurements([]) == :ok
    end

    test "validates single valid measurement" do
      measurements = [measurement(:temperature, 23.5)]
      assert Validator.validate_measurements(measurements) == :ok
    end

    test "validates multiple valid measurements" do
      measurements = [
        measurement(:temperature, 23.5),
        measurement(:humidity, 65.0),
        measurement(:motion, true)
      ]

      assert Validator.validate_measurements(measurements) == :ok
    end

    test "rejects non-list input" do
      {:error, message} =
        Validator.validate_measurements(measurement(:temperature, 23.5))

      assert message == "Measurements must be a list"
    end

    test "rejects list with invalid measurement" do
      measurements = [
        measurement(:temperature, 23.5),
        measurement(:invalid_type, 100)
      ]

      {:error, message} =
        Validator.validate_measurements(measurements)

      assert message =~ "Measurement 1:"
      assert message =~ "Unsupported measurement type"
    end

    test "includes measurement index in error" do
      measurements = [
        measurement(:temperature, 23.5),
        measurement(:humidity, 65.0),
        # Out of range
        measurement(:temperature, 999_999)
      ]

      {:error, message} =
        Validator.validate_measurements(measurements)

      assert message =~ "Measurement 2:"
    end
  end

  describe "validate_measurement/1 with maps" do
    test "validates valid measurement map" do
      measurement_struct = measurement(:temperature, 23.5)
      assert Validator.validate_measurement(measurement_struct) == :ok
    end

    test "rejects measurement without type" do
      measurement = measurement(nil, 23.5)

      {:error, message} =
        Validator.validate_measurement(measurement)

      assert message == "Unsupported measurement type: nil"
    end

    test "rejects measurement without value" do
      measurement = measurement(:temperature, nil)

      {:error, message} =
        Validator.validate_measurement(measurement)

      assert message == "Value must be a number or boolean, got: nil"
    end

    test "rejects measurement with nil type" do
      measurement = measurement(nil, 23.5)

      {:error, message} =
        Validator.validate_measurement(measurement)

      assert message == "Unsupported measurement type: nil"
    end

    test "rejects measurement with nil value" do
      measurement_struct = measurement(:temperature, nil)

      {:error, message} =
        Validator.validate_measurement(measurement_struct)

      assert message == "Value must be a number or boolean, got: nil"
    end

    test "rejects invalid measurement format" do
      {:error, message} =
        Validator.validate_measurement("invalid")

      assert message == "Invalid measurement format - must be a Measurement struct"
    end
  end

  describe "validate_measurement/1 with Measurement structs" do
    test "validates valid Measurement struct" do
      measurement = %Measurement{type: :temperature, value: 23.5}
      assert Validator.validate_measurement(measurement) == :ok
    end

    test "validates Measurement struct with binary sensor" do
      measurement = %Measurement{type: :motion, value: true}
      assert Validator.validate_measurement(measurement) == :ok
    end

    test "rejects Measurement struct with unsupported type" do
      measurement = %Measurement{type: :invalid_type, value: 23.5}

      {:error, message} =
        Validator.validate_measurement(measurement)

      assert message =~ "Unsupported measurement type"
    end
  end

  describe "type validation" do
    test "accepts all supported measurement types" do
      # Test a comprehensive list of supported types
      supported_types = [
        :temperature,
        :humidity,
        :pressure,
        :illuminance,
        :battery,
        :motion,
        :door,
        :window,
        :button,
        :count,
        :energy,
        :power
      ]

      for type <- supported_types do
        measurement = measurement(type, 1)
        # Should not fail on type validation (might fail on value validation)
        case Validator.validate_measurement(measurement) do
          :ok ->
            :ok

          {:error, message} ->
            refute message =~ "Unsupported measurement type",
                   "Type #{type} should be supported"
        end
      end
    end

    test "rejects unsupported measurement types" do
      unsupported_types = [:invalid_sensor, :unknown_type, :fake_measurement]

      for type <- unsupported_types do
        measurement = measurement(type, 1)

        {:error, message} =
          Validator.validate_measurement(measurement)

        assert message =~ "Unsupported measurement type"
      end
    end
  end

  describe "value type validation" do
    test "accepts numeric values for non-binary sensors" do
      numeric_types = [:temperature, :humidity, :pressure, :battery, :count]

      for type <- numeric_types do
        # Test integer
        measurement = measurement(type, 42)
        assert Validator.validate_measurement(measurement) == :ok

        # Test float
        measurement = measurement(type, 42.5)
        assert Validator.validate_measurement(measurement) == :ok
      end
    end

    test "accepts boolean values for binary sensors" do
      binary_types = [:motion, :door, :window, :occupancy, :presence]

      for type <- binary_types do
        # Test true
        measurement = measurement(type, true)
        assert Validator.validate_measurement(measurement) == :ok

        # Test false
        measurement = measurement(type, false)
        assert Validator.validate_measurement(measurement) == :ok
      end
    end

    test "rejects boolean values for non-binary sensors" do
      non_binary_types = [:temperature, :humidity, :pressure, :battery]

      for type <- non_binary_types do
        measurement = measurement(type, true)

        {:error, message} =
          Validator.validate_measurement(measurement)

        assert message =~ "Boolean values only allowed for binary sensors"
      end
    end

    test "rejects invalid value types" do
      invalid_values = ["string", :atom, [], %{}]

      for value <- invalid_values do
        measurement_struct = measurement(:temperature, value)

        {:error, message} =
          Validator.validate_measurement(measurement_struct)

        assert message =~ "Value must be a number or boolean"
      end
    end
  end

  describe "validate_measurement/1 with 4-byte sensor types" do
    test "validates uint32 sensor types within range" do
      # Test gas_volume_uint32
      measurement = measurement(:gas_volume_uint32, 1000.0)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates energy_uint32 within range" do
      measurement = measurement(:energy_uint32, 50_000.0)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates volume_liters_uint32 within range" do
      measurement = measurement(:volume_liters_uint32, 100_000.0)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates water sensor within range" do
      measurement = measurement(:water, 25_000.0)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates timestamp within range" do
      measurement = measurement(:timestamp, 1_640_995_200)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates volume_storage within range" do
      measurement = measurement(:volume_storage, 75_000.0)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates count_sint32 within range" do
      measurement = measurement(:count_sint32, -1_000_000)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates power_sint32 within range" do
      measurement = measurement(:power_sint32, -5000.0)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates count_uint32 within range" do
      measurement = measurement(:count_uint32, 3_000_000_000)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates firmware_version_uint32 within range" do
      measurement = measurement(:firmware_version_uint32, 16_909_060)

      assert :ok = Validator.validate_measurement(measurement)
    end
  end

  describe "validate_measurement/1 with 4-byte sensor types - edge cases" do
    test "validates uint32 at minimum value" do
      measurement = measurement(:count_uint32, 0)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates uint32 at maximum value" do
      measurement = measurement(:count_uint32, 4_294_967_295)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates sint32 at minimum value" do
      measurement = measurement(:count_sint32, -2_147_483_648)

      assert :ok = Validator.validate_measurement(measurement)
    end

    test "validates sint32 at maximum value" do
      measurement = measurement(:count_sint32, 2_147_483_647)

      assert :ok = Validator.validate_measurement(measurement)
    end
  end

  describe "validate_measurement/1 with 4-byte sensor types - out of range" do
    test "rejects uint32 value above maximum" do
      measurement = measurement(:count_uint32, 4_294_967_296)

      assert {:error, message} =
               Validator.validate_measurement(measurement)

      assert message =~ "Value 4294967296 out of range [0, 4294967295] for type count_uint32"
    end

    test "rejects uint32 negative value" do
      measurement = measurement(:count_uint32, -1)

      assert {:error, message} =
               Validator.validate_measurement(measurement)

      assert message =~ "Value -1 out of range [0, 4294967295] for type count_uint32"
    end

    test "rejects sint32 value above maximum" do
      measurement = measurement(:count_sint32, 2_147_483_648)

      assert {:error, message} =
               Validator.validate_measurement(measurement)

      assert message =~
               "Value 2147483648 out of range [-2147483648, 2147483647] for type count_sint32"
    end

    test "rejects sint32 value below minimum" do
      measurement = measurement(:count_sint32, -2_147_483_649)

      assert {:error, message} =
               Validator.validate_measurement(measurement)

      assert message =~
               "Value -2147483649 out of range [-2147483648, 2147483647] for type count_sint32"
    end
  end

  describe "validate_measurements/1 with mixed 4-byte types" do
    test "validates list of mixed 4-byte measurements" do
      measurements = [
        measurement(:gas_volume_uint32, 1000.0),
        measurement(:energy_uint32, 50_000.0),
        measurement(:count_sint32, -1_000_000),
        measurement(:power_sint32, 5000.0),
        measurement(:timestamp, 1_640_995_200)
      ]

      assert :ok = Validator.validate_measurements(measurements)
    end

    test "rejects list with one invalid 4-byte measurement" do
      measurements = [
        measurement(:gas_volume_uint32, 1000.0),
        # Invalid
        measurement(:count_uint32, 4_294_967_296),
        measurement(:energy_uint32, 50_000.0)
      ]

      assert {:error, message} =
               Validator.validate_measurements(measurements)

      assert message =~ "Value 4294967296 out of range [0, 4294967295] for type count_uint32"
    end

    test "rejects a list containing an invalid measurement" do
      measurements = [
        measurement(:gas_volume_uint32, 1000.0),
        measurement(:energy_uint32, 500.0),
        measurement(:volume_liters_uint32, 750.0),
        measurement(:water, 250.0),
        measurement(:timestamp, 1_640_995_200),
        measurement(:volume_storage, 100.0),
        measurement(:count_sint32, -1000),
        measurement(:power_sint32, -500),
        measurement(:count_uint32, 1000),
        measurement(:firmware_version_uint32, 123_456),
        # This should be invalid
        measurement(:gas_volume_uint32, 5_000_000_000.0)
      ]

      {:error, error} = Validator.validate_measurements(measurements)
      assert is_binary(error)
      assert error =~ "Measurement 10:"
      assert error =~ "out of range"
    end
  end

  describe "value range validation" do
    test "validates 1-byte unsigned values" do
      # Test battery (1-byte unsigned, factor 1)
      assert Validator.validate_measurement(measurement(:battery, 0)) == :ok
      assert Validator.validate_measurement(measurement(:battery, 255)) == :ok

      {:error, message} =
        Validator.validate_measurement(measurement(:battery, 256))

      assert message =~ "out of range"

      {:error, message} =
        Validator.validate_measurement(measurement(:battery, -1))

      assert message =~ "out of range"
    end

    test "validates 1-byte signed values" do
      # Test temperature_sint8 (1-byte signed, factor 1)
      assert Validator.validate_measurement(measurement(:temperature_sint8, -128)) == :ok
      assert Validator.validate_measurement(measurement(:temperature_sint8, 127)) == :ok

      {:error, message} =
        Validator.validate_measurement(measurement(:temperature_sint8, 128))

      assert message =~ "out of range"

      {:error, message} =
        Validator.validate_measurement(measurement(:temperature_sint8, -129))

      assert message =~ "out of range"
    end

    test "validates 2-byte unsigned values with factor" do
      # Test temperature (2-byte signed, factor 0.01)
      assert Validator.validate_measurement(measurement(:temperature, -327.68)) == :ok
      assert Validator.validate_measurement(measurement(:temperature, 327.67)) == :ok

      {:error, message} =
        Validator.validate_measurement(measurement(:temperature, 327.68))

      assert message =~ "out of range"

      {:error, message} =
        Validator.validate_measurement(measurement(:temperature, -327.69))

      assert message =~ "out of range"
    end

    test "validates 3-byte unsigned values" do
      # Test pressure (3-byte unsigned, factor 0.01)
      assert Validator.validate_measurement(measurement(:pressure, 0)) == :ok
      assert Validator.validate_measurement(measurement(:pressure, 167_772.15)) == :ok

      {:error, message} =
        Validator.validate_measurement(measurement(:pressure, 167_772.16))

      assert message =~ "out of range"

      {:error, message} =
        Validator.validate_measurement(measurement(:pressure, -0.01))

      assert message =~ "out of range"
    end

    test "validates boolean conversion to numeric range" do
      # Boolean true should convert to 1, false to 0
      assert Validator.validate_measurement(measurement(:motion, true)) == :ok
      assert Validator.validate_measurement(measurement(:motion, false)) == :ok
    end

    test "provides detailed range error information" do
      {:error, message} =
        Validator.validate_measurement(measurement(:temperature, 500.0))

      assert message =~ "Value 500.0 out of range"
      assert message =~ "for type temperature"
    end
  end

  describe "validate_device_info/1" do
    test "validates correct BTHome version" do
      # Assuming BTHome v2 (version 2)
      # Version 2 in upper 3 bits
      device_info = 0x40
      assert Validator.validate_device_info(device_info) == :ok
    end

    test "rejects incorrect BTHome version" do
      # Version 1 or 3
      # Version 1
      device_info_v1 = 0x20

      {:error, message} =
        Validator.validate_device_info(device_info_v1)

      assert message =~ "Unsupported BTHome version"

      # Version 3
      device_info_v3 = 0x60

      {:error, message} =
        Validator.validate_device_info(device_info_v3)

      assert message =~ "Unsupported BTHome version"
    end

    test "rejects non-integer device info" do
      {:error, message} =
        Validator.validate_device_info("invalid")

      assert message == "Device info must be an integer"

      {:error, message} =
        Validator.validate_device_info(nil)

      assert message == "Device info must be an integer"
    end
  end

  describe "edge cases and error handling" do
    test "handles rounding for factor-based values" do
      # Test that values are properly rounded when converted to integers
      # Temperature with factor 0.01: 23.456 should round to 2346 (23.46°C)
      assert Validator.validate_measurement(measurement(:temperature, 23.456)) == :ok
      assert Validator.validate_measurement(measurement(:temperature, 23.454)) == :ok
    end

    test "handles very small values" do
      assert Validator.validate_measurement(measurement(:temperature, 0.001)) == :ok
      assert Validator.validate_measurement(measurement(:humidity, 0.01)) == :ok
    end

    test "handles negative zero" do
      assert Validator.validate_measurement(measurement(:temperature, -0.0)) == :ok
    end

    test "handles float precision edge cases" do
      # Test values very close to boundaries
      assert Validator.validate_measurement(measurement(:temperature, 327.67)) == :ok

      {:error, _reason} =
        Validator.validate_measurement(measurement(:temperature, 327.68))
    end

    test "validates measurements with extra fields" do
      # Should ignore extra fields in measurement maps (now using struct)
      measurement = measurement(:temperature, 23.5)

      assert Validator.validate_measurement(measurement) == :ok
    end

    test "handles large lists efficiently" do
      # Test with a large number of measurements
      measurements =
        for i <- 1..1000 do
          measurement(:temperature, 20.0 + rem(i, 10))
        end

      assert Validator.validate_measurements(measurements) == :ok
    end

    test "stops validation on first error in list" do
      measurements = [
        measurement(:temperature, 23.5),
        # First error
        measurement(:invalid_type, 100),
        # Would also be an error
        measurement(:temperature, 999_999)
      ]

      {:error, message} =
        Validator.validate_measurements(measurements)

      # Should report the first error (index 1), not the second (index 2)
      assert message =~ "Measurement 1:"
    end
  end
end
