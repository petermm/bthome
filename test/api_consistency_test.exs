defmodule BTHome.APIConsistencyTest do
  use ExUnit.Case, async: true

  @test_key <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
  @test_mac <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
  @test_counter 1

  describe "serialize/2 encryption API consistency" do
    setup do
      {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      {:ok, hum} = BTHome.measurement(:humidity, 67.8)
      measurements = [temp, hum]

      %{measurements: measurements}
    end

    test "format 1: encrypt as keyword list (recommended)", %{measurements: measurements} do
      opts = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]

      assert {:ok, binary} = BTHome.serialize(measurements, opts)
      assert is_binary(binary)

      # Check encryption flag is set
      <<device_info, _rest::binary>> = binary
      assert Bitwise.band(device_info, 0x01) == 1
    end

    test "format 2: encrypt as map", %{measurements: measurements} do
      opts = [encrypt: %{key: @test_key, mac_address: @test_mac, counter: @test_counter}]

      assert {:ok, binary} = BTHome.serialize(measurements, opts)
      assert is_binary(binary)

      # Check encryption flag is set
      <<device_info, _rest::binary>> = binary
      assert Bitwise.band(device_info, 0x01) == 1
    end

    test "both formats produce equivalent results", %{measurements: measurements} do
      opts1 = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]
      opts2 = [encrypt: %{key: @test_key, mac_address: @test_mac, counter: @test_counter}]

      {:ok, binary1} = BTHome.serialize(measurements, opts1)
      {:ok, binary2} = BTHome.serialize(measurements, opts2)

      # Both should produce the same result
      assert binary1 == binary2
    end

    test "no encrypt option disables encryption", %{measurements: measurements} do
      opts = []

      assert {:ok, binary} = BTHome.serialize(measurements, opts)
      assert is_binary(binary)

      # Check encryption flag is not set
      <<device_info, _rest::binary>> = binary
      assert Bitwise.band(device_info, 0x01) == 0
    end

    test "no encryption options defaults to unencrypted", %{measurements: measurements} do
      assert {:ok, binary} = BTHome.serialize(measurements)
      assert is_binary(binary)

      # Check encryption flag is not set
      <<device_info, _rest::binary>> = binary
      assert Bitwise.band(device_info, 0x01) == 0
    end
  end

  describe "packet builder API consistency" do
    test "packet with new encryption format" do
      opts = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]

      result =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.add_measurement(:humidity, 67.8)
        |> BTHome.serialize(opts)

      assert {:ok, binary} = result
      assert is_binary(binary)

      # Check encryption flag is set
      <<device_info, _rest::binary>> = binary
      assert Bitwise.band(device_info, 0x01) == 1
    end

    test "packet with serialize! and new encryption format" do
      opts = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]

      binary =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 23.45)
        |> BTHome.serialize!(opts)

      assert is_binary(binary)

      # Check encryption flag is set
      <<device_info, _rest::binary>> = binary
      assert Bitwise.band(device_info, 0x01) == 1
    end
  end

  describe "error handling" do
    test "invalid encrypt option format returns error" do
      {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      opts = [encrypt: "invalid"]

      assert {:error, _reason} = BTHome.serialize([temp], opts)
    end

    test "boolean encrypt option returns error" do
      {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      opts = [encrypt: []]

      assert {:error, _reason} = BTHome.serialize([temp], opts)
    end

    test "missing required encryption parameters returns error" do
      {:ok, temp} = BTHome.measurement(:temperature, 23.45)
      # Missing mac_address and counter
      opts = [encrypt: [key: @test_key]]

      assert {:error, _reason} = BTHome.serialize([temp], opts)
    end
  end
end
