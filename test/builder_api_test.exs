defmodule BTHome.BuilderAPITest do
  use ExUnit.Case, async: true
  import Bitwise
  doctest BTHome

  alias BTHome.Measurement
  alias BTHome.Packet

  describe "new_packet/0" do
    test "creates a new packet builder" do
      packet = BTHome.new_packet()
      assert %Packet{measurements: [], error: nil} = packet
    end
  end

  describe "builder pattern API" do
    test "basic builder pattern with single measurement" do
      result =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.serialize()

      assert {:ok, binary} = result
      assert is_binary(binary)

      # Verify by deserializing
      {:ok, decoded} = BTHome.deserialize(binary)
      assert length(decoded.measurements) == 1
      [measurement] = decoded.measurements
      assert measurement.type == :temperature
      assert abs(measurement.value - 23.45) < 0.01
    end

    test "builder pattern with multiple measurements" do
      result =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.add_measurement(:humidity, 67.8)
        |> BTHome.add_measurement(:motion, true)
        |> BTHome.serialize()

      assert {:ok, binary} = result

      # Verify by deserializing
      {:ok, decoded} = BTHome.deserialize(binary)
      assert length(decoded.measurements) == 3

      types = Enum.map(decoded.measurements, & &1.type)
      assert :temperature in types
      assert :humidity in types
      assert :motion in types
    end

    test "builder pattern with encryption" do
      key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      mac_address = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      counter = 1
      opts = [encrypt: [key: key, mac_address: mac_address, counter: counter]]

      result =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.add_measurement(:motion, true)
        |> BTHome.serialize(opts)

      assert {:ok, binary} = result
      # Check encryption flag is set
      <<device_info, _rest::binary>> = binary
      assert (device_info &&& 0x01) == 0x01
    end

    test "builder pattern with custom measurement options" do
      result =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 74.21, unit: "°F")
        |> BTHome.serialize()

      assert {:ok, binary} = result
      assert is_binary(binary)
    end

    test "builder pattern handles validation errors gracefully" do
      result =
        BTHome.new_packet()
        # Valid
        |> BTHome.add_measurement(:temperature, 23.45)
        # Invalid
        |> BTHome.add_measurement(:invalid_type, 42)
        # Should be ignored
        |> BTHome.add_measurement(:humidity, 67.8)
        |> BTHome.serialize()

      assert {:error, error} = result
      assert is_binary(error)
    end

    test "empty packet serialization" do
      result =
        BTHome.new_packet()
        |> BTHome.serialize()

      assert {:ok, binary} = result
      # Just device info byte
      assert binary == <<0x40>>
    end
  end

  describe "comparison with traditional API" do
    test "builder pattern produces same result as traditional API" do
      # Traditional API
      {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      {:ok, humidity} = BTHome.measurement(:humidity, 67.8)
      {:ok, traditional_binary} = BTHome.serialize([temp, humidity])

      # Builder pattern API
      {:ok, builder_binary} =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.add_measurement(:humidity, 67.8)
        |> BTHome.serialize()

      # Should produce identical binary output
      assert traditional_binary == builder_binary
    end

    test "builder pattern with encryption matches traditional API" do
      # Traditional API with encryption
      {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      mac_address = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      counter = 1
      opts = [encrypt: [key: key, mac_address: mac_address, counter: counter]]
      {:ok, traditional_binary} = BTHome.serialize([temp], opts)

      # Builder pattern API with encryption
      {:ok, builder_binary} =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.serialize(opts)

      # Should produce identical binary output
      assert traditional_binary == builder_binary
    end
  end

  describe "error propagation" do
    test "error in first measurement stops chain" do
      result =
        BTHome.new_packet()
        |> BTHome.add_measurement(:invalid_type, 42)
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.serialize()

      assert {:error, _reason} = result
    end

    test "error in middle measurement stops chain" do
      result =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.add_measurement(:invalid_type, 42)
        |> BTHome.add_measurement(:humidity, 67.8)
        |> BTHome.serialize()

      assert {:error, _reason} = result
    end
  end

  describe "backwards compatibility" do
    test "traditional serialize still works with lists" do
      measurements = [
        %Measurement{type: :temperature, value: 23.45},
        %Measurement{type: :humidity, value: 67.8}
      ]

      assert {:ok, binary} = BTHome.serialize(measurements)
      assert is_binary(binary)
    end

    test "traditional measurement creation still works" do
      assert {:ok, measurement} = BTHome.measurement(:temperature, 23.45)
      assert measurement.type == :temperature
      assert measurement.value == 23.45
    end
  end
end
