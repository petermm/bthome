defmodule BTHome.PacketTest do
  use ExUnit.Case, async: true
  import Bitwise
  doctest BTHome.Packet

  alias BTHome.{Measurement, Packet}

  describe "new/0" do
    test "creates an empty packet" do
      packet = Packet.new()
      assert %Packet{measurements: [], error: nil} = packet
    end
  end

  describe "add_measurement/4" do
    test "adds a valid measurement to empty packet" do
      packet =
        Packet.new()
        |> Packet.add_measurement(:temperature, 23.45)

      assert %Packet{measurements: [measurement], error: nil} = packet
      assert %Measurement{type: :temperature, value: 23.45, unit: "°C"} = measurement
    end

    test "adds multiple measurements" do
      packet =
        Packet.new()
        |> Packet.add_measurement(:temperature, 23.45)
        |> Packet.add_measurement(:humidity, 67.8)
        |> Packet.add_measurement(:motion, true)

      assert %Packet{measurements: measurements, error: nil} = packet
      assert length(measurements) == 3

      types = Enum.map(measurements, & &1.type)
      assert :temperature in types
      assert :humidity in types
      assert :motion in types
    end

    test "captures error for invalid measurement type" do
      packet =
        Packet.new()
        |> Packet.add_measurement(:invalid_type, 42)

      assert %Packet{measurements: [], error: error} = packet
      assert is_binary(error)
    end

    test "stops processing after first error" do
      packet =
        Packet.new()
        # Valid
        |> Packet.add_measurement(:temperature, 23.45)
        # Invalid - should set error
        |> Packet.add_measurement(:invalid_type, 42)
        # Should be ignored due to error
        |> Packet.add_measurement(:humidity, 67.8)

      assert %Packet{measurements: [_temp], error: error} = packet
      assert is_binary(error)
      assert length(packet.measurements) == 1
    end

    test "supports custom options" do
      packet =
        Packet.new()
        |> Packet.add_measurement(:temperature, 74.21, unit: "°F")

      assert %Packet{measurements: [measurement], error: nil} = packet
      assert measurement.unit == "°F"
    end
  end

  describe "serialize/2" do
    test "serializes packet with single measurement" do
      result =
        Packet.new()
        |> Packet.add_measurement(:temperature, 23.45)
        |> Packet.serialize()

      assert {:ok, binary} = result
      assert is_binary(binary)
      assert byte_size(binary) > 0
    end

    test "serializes packet with multiple measurements" do
      result =
        Packet.new()
        |> Packet.add_measurement(:temperature, 23.45)
        |> Packet.add_measurement(:humidity, 67.8)
        |> Packet.add_measurement(:motion, true)
        |> Packet.serialize()

      assert {:ok, binary} = result
      assert is_binary(binary)
    end

    test "serializes with encryption flag" do
      key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      mac = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      opts = [encrypt: [key: key, mac_address: mac, counter: 1]]

      result =
        Packet.new()
        |> Packet.add_measurement(:temperature, 23.45)
        |> Packet.serialize(opts)

      assert {:ok, binary} = result
      # Check that encryption bit is set in device info byte
      <<device_info, _rest::binary>> = binary
      assert (device_info &&& 0x01) == 0x01
    end

    test "returns error when packet contains validation error" do
      result =
        Packet.new()
        |> Packet.add_measurement(:invalid_type, 42)
        |> Packet.serialize()

      assert {:error, _reason} = result
    end

    test "serializes empty packet" do
      result =
        Packet.new()
        |> Packet.serialize()

      assert {:ok, binary} = result
      # Should contain only device info byte
      assert binary == <<0x40>>
    end
  end

  describe "round trip with deserialize" do
    test "builder pattern data can be deserialized" do
      # Create packet using builder pattern
      {:ok, binary} =
        Packet.new()
        |> Packet.add_measurement(:temperature, 23.45)
        |> Packet.add_measurement(:humidity, 67.8)
        |> Packet.add_measurement(:motion, true)
        |> Packet.serialize()

      # Deserialize and verify
      assert {:ok, decoded} = BTHome.deserialize(binary)
      assert length(decoded.measurements) == 3

      # Check that values are preserved (within precision)
      temp_measurement = Enum.find(decoded.measurements, &(&1.type == :temperature))
      assert abs(temp_measurement.value - 23.45) < 0.01

      humidity_measurement = Enum.find(decoded.measurements, &(&1.type == :humidity))
      assert abs(humidity_measurement.value - 67.8) < 0.1

      motion_measurement = Enum.find(decoded.measurements, &(&1.type == :motion))
      assert motion_measurement.value == true
    end
  end
end
