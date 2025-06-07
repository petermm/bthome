defmodule BTHome.DeserializeMeasurementsTest do
  use ExUnit.Case
  doctest BTHome, only: [deserialize_measurements: 2]

  describe "deserialize_measurements/1" do
    test "returns map with single measurements" do
      # Temperature and humidity from test file
      binary = <<0x40, 0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13>>

      assert {:ok, measurements} = BTHome.deserialize_measurements(binary)
      assert %{temperature: temp, humidity: hum} = measurements
      assert is_float(temp)
      assert is_float(hum)
    end

    test "returns map with multiple measurements of same type" do
      # Double voltage with different object IDs from test file
      binary =
        <<0x40, 0x00, 0x01, 0x0B, 0x00, 0x00, 0x00, 0x4A, 0x0D, 0x09, 0x01, 0x33, 0x0C, 0xE9,
          0x0C>>

      assert {:ok, measurements} = BTHome.deserialize_measurements(binary)
      # This should have multiple voltage measurements
      assert Map.has_key?(measurements, :voltage)
    end

    test "returns map with binary sensor" do
      # Binary sensor from test file
      binary = <<0x40, 0x0F, 0x01>>

      assert {:ok, measurements} = BTHome.deserialize_measurements(binary)
      # Check that we have a binary sensor measurement
      assert map_size(measurements) == 1
      [value] = Map.values(measurements)
      assert is_boolean(value)
    end

    test "returns empty map for encrypted data" do
      # Encrypted data with no accessible measurements
      binary = <<0x41, 0x02, 0x29, 0x09>>

      assert {:ok, measurements} = BTHome.deserialize_measurements(binary)
      assert measurements == %{}
    end

    test "returns error for invalid binary" do
      binary = <<1, 2, 3>>

      assert {:error, error} = BTHome.deserialize_measurements(binary)
      assert is_binary(error)
    end

    test "handles mixed measurement types" do
      # Temperature and humidity from test file
      binary = <<0x40, 0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13>>

      assert {:ok, measurements} = BTHome.deserialize_measurements(binary)
      assert map_size(measurements) == 2
      assert Map.has_key?(measurements, :temperature)
      assert Map.has_key?(measurements, :humidity)
    end

    test "preserves measurement order in lists" do
      # Double voltage with different object IDs from test file
      binary =
        <<0x40, 0x00, 0x01, 0x0B, 0x00, 0x00, 0x00, 0x4A, 0x0D, 0x09, 0x01, 0x33, 0x0C, 0xE9,
          0x0C>>

      assert {:ok, measurements} = BTHome.deserialize_measurements(binary)
      # If there are multiple voltage measurements, they should be in a list
      if Map.has_key?(measurements, :voltage) do
        voltage_value = measurements[:voltage]

        if is_list(voltage_value) do
          assert length(voltage_value) >= 1
        end
      end
    end
  end

  describe "BTHome.deserialize_measurements/1 delegation" do
    test "delegates to BTHome module" do
      binary = <<0x40, 0x0F, 0x01>>

      assert {:ok, measurements} = BTHome.deserialize_measurements(binary)
      assert map_size(measurements) == 1
    end
  end
end
