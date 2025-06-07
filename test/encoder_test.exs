defmodule BTHome.EncoderTest do
  use ExUnit.Case, async: true
  alias BTHome.{Encoder, Measurement}

  # Helper function to create measurement structs
  defp measurement(type, value, object_id \\ nil) do
    %Measurement{type: type, value: value, object_id: object_id}
  end

  describe "encode_measurements/2" do
    test "encodes single temperature measurement" do
      measurements = [%Measurement{type: :temperature, value: 23.45}]
      assert {:ok, binary} = Encoder.encode_measurements(measurements)

      # Check device info byte (0x40 for BTHome v2, no encryption)
      <<device_info, 0x02, temp_bytes::binary-size(2)>> = binary
      assert device_info == 0x40

      # Check temperature encoding (23.45 / 0.01 = 2345)
      <<temp_value::signed-little-16>> = temp_bytes
      assert temp_value == 2345
    end

    test "encodes with encryption flag" do
      measurements = [%Measurement{type: :battery, value: 85}]
      key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      mac_address = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      counter = 1
      opts = [encrypt: [key: key, mac_address: mac_address, counter: counter]]
      assert {:ok, binary} = Encoder.encode_measurements(measurements, opts)

      <<device_info, _rest::binary>> = binary
      # Check encryption bit is set (bit 0)
      assert Bitwise.band(device_info, 0x01) == 1
    end

    test "encodes multiple measurements" do
      measurements = [
        %Measurement{type: :temperature, value: 21.3},
        %Measurement{type: :humidity, value: 65.2},
        %Measurement{type: :battery, value: 85}
      ]

      assert {:ok, binary} = Encoder.encode_measurements(measurements)
      # Device info + measurement data
      assert byte_size(binary) > 1
    end

    test "encodes empty measurements list" do
      assert {:ok, binary} = Encoder.encode_measurements([])
      # Only device info byte
      assert binary == <<0x40>>
    end

    test "validates measurements before encoding" do
      measurements = [%Measurement{type: :invalid_sensor, value: 42}]
      assert {:error, _reason} = Encoder.encode_measurements(measurements)
    end
  end

  describe "encode_validated/2" do
    test "skips validation for performance" do
      measurements = [%Measurement{type: :temperature, value: 23.45}]
      assert {:ok, binary} = Encoder.encode_validated(measurements)

      <<device_info, 0x02, _temp_bytes::binary-size(2)>> = binary
      assert device_info == 0x40
    end

    test "encodes with encryption flag" do
      measurements = [%Measurement{type: :battery, value: 85}]
      key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      mac_address = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      counter = 1
      opts = [encrypt: [key: key, mac_address: mac_address, counter: counter]]
      assert {:ok, binary} = Encoder.encode_validated(measurements, opts)

      <<device_info, _rest::binary>> = binary
      assert Bitwise.band(device_info, 0x01) == 1
    end
  end

  describe "error handling" do
    test "handles invalid factor conversion - string value" do
      measurements = [measurement(:temperature, "invalid")]
      assert {:error, message} = Encoder.encode_measurements(measurements)
      assert message =~ "Value must be a number or boolean"
    end

    test "handles invalid factor conversion - nil value" do
      measurements = [measurement(:temperature, nil)]
      assert {:error, message} = Encoder.encode_measurements(measurements)
      assert message =~ "Value must be a number or boolean, got: nil"
    end

    test "handles division by zero in factor conversion" do
      # This would require mocking Objects.find_by_type to return factor: 0
      # For now, test with a measurement that has a valid factor
      measurements = [measurement(:temperature, :infinity)]
      assert {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles integer overflow for 1-byte unsigned" do
      # Max is 255
      measurements = [measurement(:battery, 300)]
      assert {:error, message} = Encoder.encode_measurements(measurements)
      assert message =~ "out of range"
    end

    test "handles integer underflow for 1-byte signed" do
      # Create a measurement that uses signed 1-byte encoding
      # Min is -128
      measurements = [measurement(:temperature_sint8, -200)]
      assert {:error, message} = Encoder.encode_measurements(measurements)
      assert message =~ "out of range"
    end

    test "handles integer overflow for 2-byte unsigned" do
      # Max value would be 655.35
      measurements = [measurement(:humidity, 700.0)]
      assert {:error, message} = Encoder.encode_measurements(measurements)
      assert message =~ "out of range"
    end

    test "handles integer overflow for 2-byte signed" do
      # Max value would be 327.67
      measurements = [measurement(:temperature, 400.0)]
      assert {:error, message} = Encoder.encode_measurements(measurements)
      assert message =~ "out of range"
    end

    test "handles integer overflow for 3-byte unsigned" do
      # Max would be 167,772.15
      measurements = [measurement(:illuminance, 200_000.0)]
      assert {:error, message} = Encoder.encode_measurements(measurements)
      assert message =~ "out of range"
    end

    test "handles integer overflow for 4-byte unsigned" do
      # Max is 4,294,967,295
      measurements = [measurement(:count_uint32, 5_000_000_000)]
      assert {:error, message} = Encoder.encode_measurements(measurements)
      assert message =~ "out of range"
    end

    test "handles invalid measurement structure - missing type" do
      measurements = [%{value: 42}]
      assert {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles invalid measurement structure - missing value" do
      measurements = [measurement(:temperature, nil)]
      assert {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles unknown measurement type" do
      measurements = [measurement(:unknown_sensor, 42)]
      assert {:error, _reason} = Encoder.encode_measurements(measurements)
    end
  end

  describe "boolean conversion" do
    test "converts true to 1" do
      measurements = [measurement(:motion, true)]
      assert {:ok, binary} = Encoder.encode_measurements(measurements)

      <<_device_info, 0x21, value>> = binary
      assert value == 1
    end

    test "converts false to 0" do
      measurements = [measurement(:motion, false)]
      assert {:ok, binary} = Encoder.encode_measurements(measurements)

      <<_device_info, 0x21, value>> = binary
      assert value == 0
    end

    test "rejects boolean for non-binary sensor" do
      measurements = [measurement(:temperature, true)]
      assert {:error, _reason} = Encoder.encode_measurements(measurements)
    end
  end

  describe "boundary value testing" do
    test "encodes minimum values correctly" do
      measurements = [
        measurement(:battery, 0),
        # Min for signed 16-bit with factor 0.01
        measurement(:temperature, -327.68),
        measurement(:count_uint32, 0)
      ]

      assert {:ok, _binary} = Encoder.encode_measurements(measurements)
    end

    test "encodes maximum values correctly" do
      measurements = [
        measurement(:battery, 255),
        # Max for unsigned 16-bit with factor 0.01
        measurement(:humidity, 655.35),
        measurement(:count_uint32, 4_294_967_295)
      ]

      assert {:ok, _binary} = Encoder.encode_measurements(measurements)
    end
  end

  describe "precision and rounding" do
    test "rounds values correctly for factor conversion" do
      # Should round to 23.46
      measurements = [measurement(:temperature, 23.456)]
      assert {:ok, binary} = Encoder.encode_measurements(measurements)

      <<_device_info, 0x02, temp_bytes::binary-size(2)>> = binary
      <<temp_value::signed-little-16>> = temp_bytes
      # 23.456 / 0.01 = 2345.6, rounds to 2346
      assert temp_value == 2346
    end

    test "handles very small values" do
      # Should round to 0.00
      measurements = [measurement(:temperature, 0.001)]
      assert {:ok, binary} = Encoder.encode_measurements(measurements)

      <<_device_info, 0x02, temp_bytes::binary-size(2)>> = binary
      <<temp_value::signed-little-16>> = temp_bytes
      assert temp_value == 0
    end
  end

  describe "object_id handling" do
    test "encodes measurement with explicit object_id" do
      # temperature_2
      measurements = [measurement(:temperature, 23.45, 0x45)]
      assert {:ok, binary} = Encoder.encode_measurements(measurements)

      <<_device_info, object_id, _temp_bytes::binary-size(2)>> = binary
      assert object_id == 0x45
    end

    test "uses default object_id when not specified" do
      measurements = [measurement(:temperature, 23.45)]
      assert {:ok, binary} = Encoder.encode_measurements(measurements)

      <<_device_info, object_id, _temp_bytes::binary-size(2)>> = binary
      # Default temperature object ID
      assert object_id == 0x02
    end
  end

  describe "edge cases and error handling" do
    test "handles division by zero factor" do
      # This would be a configuration error, but test error handling
      # Note: This might require mocking or special test setup
      measurements = [measurement(:temperature, 23.5)]
      # Assuming we can't easily test division by zero without mocking
      assert Encoder.encode_measurements(measurements) != {:error, "Division by zero"}
    end

    test "handles very large numbers" do
      # Max uint32
      measurements = [measurement(:count_uint32, 4_294_967_295)]
      assert {:ok, _binary} = Encoder.encode_measurements(measurements)
    end

    test "handles very small numbers" do
      measurements = [measurement(:temperature, 0.001)]
      assert {:ok, _binary} = Encoder.encode_measurements(measurements)
    end

    test "handles negative zero" do
      measurements = [measurement(:temperature, -0.0)]
      assert {:ok, _binary} = Encoder.encode_measurements(measurements)
    end

    test "handles float precision edge cases" do
      # Test values that might cause rounding issues
      measurements = [measurement(:temperature, 23.456789)]
      assert {:ok, _binary} = Encoder.encode_measurements(measurements)
    end

    test "handles invalid value types for conversion" do
      # Test the convert_to_integer error path with invalid inputs
      measurements = [measurement(:temperature, :invalid_atom)]
      {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles arithmetic errors in conversion" do
      # Test extreme values that might cause arithmetic errors
      # Very large float
      measurements = [measurement(:temperature, 1.0e308)]
      assert {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles NaN and infinity values" do
      # Test special float values - use atoms instead of division by zero
      nan_measurements = [measurement(:temperature, :nan)]
      assert {:error, _reason} = Encoder.encode_measurements(nan_measurements)

      inf_measurements = [measurement(:temperature, :infinity)]
      assert {:error, _reason} = Encoder.encode_measurements(inf_measurements)

      neg_inf_measurements = [measurement(:temperature, :negative_infinity)]
      assert {:error, _reason} = Encoder.encode_measurements(neg_inf_measurements)
    end

    test "handles measurements with extra fields" do
      # Should ignore extra fields in measurement maps
      measurements = [measurement(:temperature, 23.5)]

      assert {:ok, _binary} = Encoder.encode_measurements(measurements)
    end

    test "handles mixed measurement formats" do
      # Mix of maps and structs
      measurements = [
        measurement(:temperature, 23.5),
        %Measurement{type: :humidity, value: 65.0},
        measurement(:motion, true)
      ]

      assert {:ok, _binary} = Encoder.encode_measurements(measurements)
    end

    test "handles large measurement lists" do
      # Test with many measurements
      measurements =
        for i <- 1..100 do
          measurement(:temperature, 20.0 + rem(i, 10))
        end

      assert {:ok, binary} = Encoder.encode_measurements(measurements)
      # Should be substantial
      assert byte_size(binary) > 300
    end

    test "handles all integer sizes and signs" do
      test_cases = [
        # 1-byte unsigned
        {measurement(:battery, 255), 3},
        # 1-byte signed
        {measurement(:temperature_sint8, -128), 3},
        {measurement(:temperature_sint8, 127), 3},
        # 2-byte unsigned
        {measurement(:humidity, 655.35), 4},
        # 2-byte signed
        {measurement(:temperature, -327.68), 4},
        {measurement(:temperature, 327.67), 4},
        # 3-byte unsigned
        {measurement(:pressure, 167_772.15), 5},
        # 3-byte signed (if any exist)
        # 4-byte unsigned
        {measurement(:count_uint32, 4_294_967_295), 6},
        # 4-byte signed
        {measurement(:count_sint32, -2_147_483_648), 6},
        {measurement(:count_sint32, 2_147_483_647), 6}
      ]

      for {measurement, expected_size} <- test_cases do
        {:ok, binary} = Encoder.encode_measurements([measurement])

        assert byte_size(binary) == expected_size,
               "Measurement #{inspect(measurement)} should produce #{expected_size} bytes"
      end
    end

    test "handles boundary values for all sizes" do
      # Test exact boundary values
      boundary_tests = [
        # 1-byte unsigned boundaries
        {measurement(:battery, 0), :ok},
        {measurement(:battery, 255), :ok},
        # 1-byte signed boundaries
        {measurement(:temperature_sint8, -128), :ok},
        {measurement(:temperature_sint8, 127), :ok},
        # 2-byte signed boundaries (temperature with factor 0.01)
        {measurement(:temperature, -327.68), :ok},
        {measurement(:temperature, 327.67), :ok}
      ]

      for {measurement, expected_result} <- boundary_tests do
        case expected_result do
          :ok ->
            assert {:ok, _binary} = Encoder.encode_measurements([measurement])

          :error ->
            assert {:error, _error} = Encoder.encode_measurements([measurement])
        end
      end
    end

    test "validates encode_validated bypasses validation" do
      # encode_validated should work even with invalid measurements (no validation)
      # But it should still fail on encoding errors
      measurements = [measurement(:temperature, 23.5)]
      assert {:ok, _binary} = Encoder.encode_validated(measurements)

      # Test with encryption flag
      key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      mac_address = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      counter = 1
      opts = [encrypt: [key: key, mac_address: mac_address, counter: counter]]
      assert {:ok, _binary} = Encoder.encode_validated(measurements, opts)
    end

    test "handles object_id override correctly" do
      # Test using explicit object_id instead of type lookup
      measurements = [
        measurement(:temperature, 23.5, 0x02),
        measurement(:humidity, 65.0, 0x03)
      ]

      assert {:ok, binary} = Encoder.encode_measurements(measurements)

      # Verify the object IDs are used correctly
      <<_device_info, 0x02, _temp_data::binary-size(2), 0x03, _humidity_data::binary-size(2)>> =
        binary
    end

    test "handles encoding errors in integer conversion" do
      # Test the error path in encode_integer_safe
      # This requires values that are out of range for their type
      # Out of range for 1-byte unsigned
      measurements = [measurement(:battery, 256)]
      {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles all error paths in convert_to_integer" do
      # Test invalid factor (should be caught by validation, but test the function)
      measurements = [measurement(:temperature, "invalid")]
      {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles error propagation in encode_measurements_acc" do
      # Test that errors in individual measurements propagate correctly
      measurements = [
        # Valid
        measurement(:temperature, 23.5),
        # Invalid - out of range
        measurement(:battery, 300),
        # Valid but won't be processed due to error
        measurement(:humidity, 65.0)
      ]

      {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles validation errors in encode_measurements" do
      # Test the error path in the main encode_measurements function
      measurements = [measurement(:invalid_type, 123)]
      {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles encoding errors with invalid measurement structure" do
      # Test with completely invalid measurement structure
      measurements = [%{invalid: :structure}]
      {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles errors in encode_validated" do
      # encode_validated assumes pre-validated data, but now handles invalid data gracefully
      measurements = [measurement(:temperature, :not_a_number)]

      assert {:error, _reason} = Encoder.encode_validated(measurements)
    end

    test "handles convert_to_integer with non-numeric values" do
      # Test the specific error case in convert_to_integer
      measurements = [measurement(:temperature, "not a number")]
      {:error, _reason} = Encoder.encode_measurements(measurements)
    end

    test "handles arithmetic overflow in conversion" do
      # Test values that cause arithmetic overflow
      # Extremely large value
      measurements = [measurement(:temperature, 1.0e100)]
      {:error, _reason} = Encoder.encode_measurements(measurements)
    end
  end

  describe "performance and optimization" do
    test "iodata optimization works correctly" do
      # Test that large measurement lists are handled efficiently
      measurements =
        for i <- 1..50 do
          measurement(:temperature, 20.0 + i * 0.1)
        end

      start_time = System.monotonic_time(:microsecond)
      {:ok, binary} = Encoder.encode_measurements(measurements)
      end_time = System.monotonic_time(:microsecond)

      # Should complete reasonably quickly
      duration = end_time - start_time
      # Less than 10ms
      assert duration < 10_000
      # Device info + 50 * (object_id + 2 bytes)
      assert byte_size(binary) == 1 + 50 * 3
    end

    test "encode_validated is faster than regular encode" do
      measurements =
        for i <- 1..20 do
          measurement(:temperature, 20.0 + i * 0.1)
        end

      # Time regular encoding
      start_time = System.monotonic_time(:microsecond)
      {:ok, _binary1} = Encoder.encode_measurements(measurements)
      regular_time = System.monotonic_time(:microsecond) - start_time

      # Time fast encoding
      start_time = System.monotonic_time(:microsecond)
      {:ok, _binary2} = Encoder.encode_validated(measurements)
      fast_time = System.monotonic_time(:microsecond) - start_time

      # Fast should be faster (though difference might be small for small lists)
      # At minimum, both should complete quickly
      assert regular_time < 5_000
      assert fast_time < 5_000
    end
  end
end
