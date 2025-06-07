defmodule BTHome.EncryptionConvenienceTest do
  use ExUnit.Case, async: true

  alias BTHome.Measurement
  alias BTHome.Packet

  @key <<0x23, 0x1D, 0x39, 0xC1, 0xD7, 0xCC, 0x1A, 0xB1, 0xAE, 0xE2, 0x24, 0xCD, 0x09, 0x6D, 0xB9,
         0x32>>
  @mac <<0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC>>
  @counter 1

  @measurements [
    %Measurement{type: :temperature, value: 23.5},
    %Measurement{type: :humidity, value: 65.0}
  ]

  describe "encryption_opts/3" do
    test "creates proper encryption options" do
      opts = BTHome.encryption_opts(@key, @mac, @counter)

      assert opts == [encrypt: [key: @key, mac_address: @mac, counter: @counter]]
    end

    test "works with serialize/2" do
      opts = BTHome.encryption_opts(@key, @mac, @counter)

      assert {:ok, binary} = BTHome.serialize(@measurements, opts)
      assert is_binary(binary)
      assert byte_size(binary) > 0
    end
  end

  describe "encryption_opts/1 with device context" do
    test "extracts from device context with standard keys" do
      device = %{
        key: @key,
        mac_address: @mac,
        counter: @counter
      }

      assert {:ok, opts} = BTHome.encryption_opts(device)
      assert opts == [encrypt: [key: @key, mac_address: @mac, counter: @counter]]
    end

    test "extracts from device context with alternative keys" do
      device = %{
        encryption_key: @key,
        mac: @mac,
        counter: @counter
      }

      assert {:ok, opts} = BTHome.encryption_opts(device)
      assert opts == [encrypt: [key: @key, mac_address: @mac, counter: @counter]]
    end

    test "returns error for missing key" do
      device = %{
        mac_address: @mac,
        counter: @counter
      }

      assert {:error, "Missing or invalid encryption key"} =
               BTHome.encryption_opts(device)
    end

    test "returns error for missing mac address" do
      device = %{
        key: @key,
        counter: @counter
      }

      assert {:error, "Missing or invalid MAC address"} =
               BTHome.encryption_opts(device)
    end

    test "returns error for missing counter" do
      device = %{
        key: @key,
        mac_address: @mac
      }

      assert {:error, "Missing or invalid counter"} =
               BTHome.encryption_opts(device)
    end

    test "returns error for invalid key size" do
      device = %{
        # Wrong size
        key: <<1, 2, 3>>,
        mac_address: @mac,
        counter: @counter
      }

      assert {:error, "Missing or invalid encryption key"} =
               BTHome.encryption_opts(device)
    end

    test "returns error for invalid mac size" do
      device = %{
        key: @key,
        # Wrong size
        mac_address: <<1, 2, 3>>,
        counter: @counter
      }

      assert {:error, "Missing or invalid MAC address"} =
               BTHome.encryption_opts(device)
    end

    test "returns error for negative counter" do
      device = %{
        key: @key,
        mac_address: @mac,
        counter: -1
      }

      assert {:error, "Missing or invalid counter"} =
               BTHome.encryption_opts(device)
    end
  end

  describe "new_encrypted_packet/3" do
    test "creates packet with encryption options" do
      {packet, opts} = BTHome.new_encrypted_packet(@key, @mac, @counter)

      assert %Packet{} = packet
      assert packet.measurements == []
      assert opts == [encrypt: [key: @key, mac_address: @mac, counter: @counter]]
    end

    test "can be used with add_measurement/4" do
      {packet, _opts} = BTHome.new_encrypted_packet(@key, @mac, @counter)

      packet = BTHome.add_measurement(packet, :temperature, 23.5)
      assert length(packet.measurements) == 1
    end

    test "can be serialized" do
      {packet, opts} = BTHome.new_encrypted_packet(@key, @mac, @counter)
      packet = BTHome.add_measurement(packet, :temperature, 23.5)

      assert {:ok, binary} = BTHome.serialize(packet, opts)
      assert is_binary(binary)
    end
  end

  describe "serialize_encrypted/2 with packet" do
    test "serializes encrypted packet" do
      {packet, opts} = BTHome.new_encrypted_packet(@key, @mac, @counter)
      packet = BTHome.add_measurement(packet, :temperature, 23.5)

      assert {:ok, binary} = BTHome.serialize_encrypted(packet, opts)
      assert is_binary(binary)
      assert byte_size(binary) > 0
    end

    test "produces same result as serialize/2" do
      {packet, opts} = BTHome.new_encrypted_packet(@key, @mac, @counter)
      packet = BTHome.add_measurement(packet, :temperature, 23.5)

      {:ok, binary1} = BTHome.serialize_encrypted(packet, opts)
      {:ok, binary2} = BTHome.serialize(packet, opts)

      assert binary1 == binary2
    end
  end

  describe "quick_serialize_encrypted/4" do
    test "serializes measurements with encryption" do
      assert {:ok, binary} = BTHome.quick_serialize_encrypted(@measurements, @key, @mac, @counter)
      assert is_binary(binary)
      assert byte_size(binary) > 0
    end

    test "produces same result as serialize/2 with encryption options" do
      opts = BTHome.encryption_opts(@key, @mac, @counter)

      {:ok, binary1} = BTHome.quick_serialize_encrypted(@measurements, @key, @mac, @counter)
      {:ok, binary2} = BTHome.serialize(@measurements, opts)

      assert binary1 == binary2
    end

    test "can be deserialized" do
      {:ok, binary} = BTHome.quick_serialize_encrypted(@measurements, @key, @mac, @counter)

      assert {:ok, decoded} = BTHome.deserialize_encrypted(binary, @key, @mac)
      assert length(decoded.measurements) == 2
    end
  end

  describe "serialize_for_device/2" do
    test "serializes with encryption when device has encryption info" do
      device = %{
        encryption_key: @key,
        mac_address: @mac,
        counter: @counter
      }

      assert {:ok, binary} = BTHome.serialize_for_device(@measurements, device)
      assert is_binary(binary)

      # Should be encrypted (can be decrypted)
      assert {:ok, _decoded} = BTHome.deserialize_encrypted(binary, @key, @mac)
    end

    test "falls back to unencrypted when device lacks encryption info" do
      device = %{name: "test_device"}

      assert {:ok, binary} = BTHome.serialize_for_device(@measurements, device)
      assert is_binary(binary)

      # Should be unencrypted (can be deserialized without key)
      assert {:ok, _decoded} = BTHome.deserialize(binary)
    end

    test "falls back to unencrypted when device has partial encryption info" do
      device = %{
        encryption_key: @key
        # Missing mac_address and counter
      }

      assert {:ok, binary} = BTHome.serialize_for_device(@measurements, device)
      assert is_binary(binary)

      # Should be unencrypted (can be deserialized without key)
      assert {:ok, _decoded} = BTHome.deserialize(binary)
    end

    test "produces same result as quick_serialize_encrypted when device has encryption" do
      device = %{
        encryption_key: @key,
        mac_address: @mac,
        counter: @counter
      }

      {:ok, binary1} = BTHome.serialize_for_device(@measurements, device)
      {:ok, binary2} = BTHome.quick_serialize_encrypted(@measurements, @key, @mac, @counter)

      assert binary1 == binary2
    end
  end

  describe "integration with existing API" do
    test "new functions work with existing deserialize functions" do
      # Test with quick_serialize_encrypted
      {:ok, binary} = BTHome.quick_serialize_encrypted(@measurements, @key, @mac, @counter)

      # Should work with deserialize_encrypted
      assert {:ok, decoded} = BTHome.deserialize_encrypted(binary, @key, @mac)
      assert length(decoded.measurements) == 2

      # Should work with deserialize_measurements/2
      {:ok, measurements_map} =
        BTHome.deserialize_measurements(binary, key: @key, mac_address: @mac)

      assert is_map(measurements_map)
      assert Map.has_key?(measurements_map, :temperature)
      assert Map.has_key?(measurements_map, :humidity)
    end

    test "new packet builder works with existing add_measurement" do
      {packet, opts} = BTHome.new_encrypted_packet(@key, @mac, @counter)

      # Add multiple measurements
      packet = BTHome.add_measurement(packet, :temperature, 23.5)
      packet = BTHome.add_measurement(packet, :humidity, 65.0)
      packet = BTHome.add_measurement(packet, :battery, 85)

      assert length(packet.measurements) == 3

      # Serialize and verify
      {:ok, binary} = BTHome.serialize_encrypted(packet, opts)
      {:ok, decoded} = BTHome.deserialize_encrypted(binary, @key, @mac)
      assert length(decoded.measurements) == 3
    end

    test "encryption_opts works with existing serialize_encrypted function" do
      # The existing serialize_encrypted/4 function
      {:ok, binary1} = BTHome.serialize_encrypted(@measurements, @key, @mac, @counter)

      # Using new encryption_opts with serialize/2
      opts = BTHome.encryption_opts(@key, @mac, @counter)
      {:ok, binary2} = BTHome.serialize(@measurements, opts)

      assert binary1 == binary2
    end
  end
end
