defmodule BTHome.EncryptionIntegrationTest do
  use ExUnit.Case, async: true

  # Test data
  @test_key <<0x23, 0x1D, 0x39, 0xC1, 0xD7, 0xCC, 0x1A, 0xB1, 0xAE, 0xE2, 0x24, 0xCD, 0x09, 0x6D,
              0xB9, 0x32>>
  @test_mac <<0x54, 0x48, 0xE6, 0x8F, 0x80, 0xA5>>
  @test_counter 0x33221100

  # Helper function to create test measurements
  defp create_test_measurements do
    {:ok, temp} = BTHome.measurement(:temperature, 25.6)
    {:ok, hum} = BTHome.measurement(:humidity, 65.5)
    [temp, hum]
  end

  describe "serialize with encryption" do
    test "encrypts measurements successfully" do
      measurements = create_test_measurements()
      opts = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]

      assert {:ok, encrypted_data} = BTHome.serialize(measurements, opts)

      # Check that data is encrypted (should be different from unencrypted)
      {:ok, unencrypted_data} = BTHome.serialize(measurements)
      assert encrypted_data != unencrypted_data

      # Check encryption flag is set
      <<device_info, _rest::binary>> = encrypted_data
      # Encryption bit set
      assert Bitwise.band(device_info, 0x01) == 0x01
    end

    test "serialize! with encryption" do
      measurements = create_test_measurements()
      opts = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]

      encrypted_data = BTHome.serialize!(measurements, opts)

      assert is_binary(encrypted_data)
      assert byte_size(encrypted_data) > 0
    end

    test "serialize_encrypted convenience function" do
      measurements = create_test_measurements()

      {:ok, encrypted_data} =
        BTHome.serialize_encrypted(measurements, @test_key, @test_mac, @test_counter)

      assert is_binary(encrypted_data)

      # Check encryption flag is set
      <<device_info, _rest::binary>> = encrypted_data
      assert Bitwise.band(device_info, 0x01) == 0x01
    end

    test "returns error with invalid encryption options" do
      measurements = create_test_measurements()
      # Too short
      invalid_key = <<1, 2, 3>>
      opts = [encrypt: [key: invalid_key, mac_address: @test_mac, counter: @test_counter]]

      assert {:error, _error} = BTHome.serialize(measurements, opts)
    end
  end

  describe "deserialize with decryption" do
    test "decrypts measurements successfully" do
      measurements = create_test_measurements()
      # First encrypt some data
      encrypt_opts = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]
      {:ok, encrypted_data} = BTHome.serialize(measurements, encrypt_opts)

      # Then decrypt it
      decrypt_opts = [key: @test_key, mac_address: @test_mac]
      assert {:ok, decoded_data} = BTHome.deserialize(encrypted_data, decrypt_opts)

      assert {:ok, measurements_map} =
               BTHome.deserialize_measurements(encrypted_data, decrypt_opts)

      # Check that we got the original measurements back
      expected_measurements = %{
        temperature: 25.6,
        humidity: 65.5
      }

      assert measurements_map == expected_measurements
      assert decoded_data.encrypted == true
      assert decoded_data.counter == @test_counter
    end

    test "deserialize_encrypted convenience function" do
      measurements = create_test_measurements()
      # First encrypt some data
      {:ok, encrypted_data} =
        BTHome.serialize_encrypted(measurements, @test_key, @test_mac, @test_counter)

      # Then decrypt it
      assert {:ok, decoded_data} =
               BTHome.deserialize_encrypted(encrypted_data, @test_key, @test_mac)

      assert {:ok, measurements_map} =
               BTHome.deserialize_measurements(encrypted_data,
                 key: @test_key,
                 mac_address: @test_mac
               )

      expected_measurements = %{
        temperature: 25.6,
        humidity: 65.5
      }

      assert measurements_map == expected_measurements
      assert decoded_data.encrypted == true
    end

    test "returns error with wrong key" do
      measurements = create_test_measurements()
      # Encrypt with one key
      {:ok, encrypted_data} =
        BTHome.serialize_encrypted(measurements, @test_key, @test_mac, @test_counter)

      # Try to decrypt with different key
      wrong_key = BTHome.generate_encryption_key()

      assert {:error, _error} = BTHome.deserialize_encrypted(encrypted_data, wrong_key, @test_mac)
    end

    test "returns error with wrong MAC address" do
      measurements = create_test_measurements()
      # Encrypt with one MAC
      {:ok, encrypted_data} =
        BTHome.serialize_encrypted(measurements, @test_key, @test_mac, @test_counter)

      # Try to decrypt with different MAC
      wrong_mac = <<0x11, 0x22, 0x33, 0x44, 0x55, 0x66>>

      assert {:error, _error} = BTHome.deserialize_encrypted(encrypted_data, @test_key, wrong_mac)
    end

    test "deserializes unencrypted data without decryption options" do
      measurements = create_test_measurements()
      {:ok, unencrypted_data} = BTHome.serialize(measurements)

      assert {:ok, decoded_data} = BTHome.deserialize(unencrypted_data)
      assert {:ok, measurements_map} = BTHome.deserialize_measurements(unencrypted_data)

      expected_measurements = %{
        temperature: 25.6,
        humidity: 65.5
      }

      assert measurements_map == expected_measurements
      assert decoded_data.encrypted == false
    end
  end

  describe "packet API with encryption" do
    test "packet serialize with encryption" do
      opts = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]

      {:ok, encrypted_data} =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 25.6)
        |> BTHome.add_measurement(:humidity, 65.5)
        |> BTHome.serialize(opts)

      assert is_binary(encrypted_data)

      # Check encryption flag is set
      <<device_info, _rest::binary>> = encrypted_data
      assert Bitwise.band(device_info, 0x01) == 0x01
    end

    test "packet serialize! with encryption" do
      opts = [encrypt: [key: @test_key, mac_address: @test_mac, counter: @test_counter]]

      encrypted_data =
        BTHome.new_packet()
        |> BTHome.add_measurement(:temperature, 25.6)
        |> BTHome.add_measurement(:humidity, 65.5)
        |> BTHome.serialize!(opts)

      assert is_binary(encrypted_data)
    end
  end

  describe "key utilities" do
    test "generate_encryption_key creates valid key" do
      key = BTHome.generate_encryption_key()

      assert is_binary(key)
      assert byte_size(key) == 16

      # Test that the key works for encryption
      measurements = create_test_measurements()

      {:ok, encrypted_data} =
        BTHome.serialize_encrypted(measurements, key, @test_mac, @test_counter)

      {:ok, _decoded} = BTHome.deserialize_encrypted(encrypted_data, key, @test_mac)
    end

    test "key_from_hex and key_to_hex" do
      hex_key = "231d39c1d7cc1ab1aee224cd096db932"

      {:ok, key} = BTHome.key_from_hex(hex_key)
      converted_hex = BTHome.key_to_hex(key)

      assert converted_hex == hex_key
      assert key == @test_key
    end
  end

  describe "round trip tests" do
    test "encrypt and decrypt various measurement types" do
      test_cases = [
        # Single measurements
        [elem(BTHome.measurement(:temperature, 23.45), 1)],
        [elem(BTHome.measurement(:humidity, 67.8), 1)],
        [elem(BTHome.measurement(:pressure, 1013.25), 1)],
        [elem(BTHome.measurement(:battery, 85), 1)],

        # Multiple measurements
        [
          elem(BTHome.measurement(:temperature, 23.45), 1),
          elem(BTHome.measurement(:humidity, 60.0), 1),
          elem(BTHome.measurement(:pressure, 1020.0), 1)
        ],

        # Edge cases
        # Minimum temperature
        [elem(BTHome.measurement(:temperature, -40.0), 1)],
        # Maximum temperature
        [elem(BTHome.measurement(:temperature, 85.0), 1)],
        # Minimum humidity
        [elem(BTHome.measurement(:humidity, 0.0), 1)],
        # Maximum humidity
        [elem(BTHome.measurement(:humidity, 100.0), 1)]
      ]

      for measurements <- test_cases do
        # Encrypt
        {:ok, encrypted_data} =
          BTHome.serialize_encrypted(measurements, @test_key, @test_mac, @test_counter)

        # Decrypt
        {:ok, decoded_data} = BTHome.deserialize_encrypted(encrypted_data, @test_key, @test_mac)

        {:ok, measurements_map} =
          BTHome.deserialize_measurements(encrypted_data, key: @test_key, mac_address: @test_mac)

        # Convert measurements to expected format
        expected_measurements =
          measurements
          |> Enum.map(fn %{type: type, value: value} ->
            {type, value}
          end)
          |> Map.new()

        assert measurements_map == expected_measurements
        assert decoded_data.encrypted == true
        assert decoded_data.counter == @test_counter
      end
    end

    test "different counter values" do
      measurements = create_test_measurements()
      counters = [0, 1, 0xFF, 0xFFFF, 0xFFFFFF, 0xFFFFFFFF]

      for counter <- counters do
        {:ok, encrypted_data} =
          BTHome.serialize_encrypted(measurements, @test_key, @test_mac, counter)

        {:ok, decoded_data} = BTHome.deserialize_encrypted(encrypted_data, @test_key, @test_mac)

        assert decoded_data.counter == counter
        assert decoded_data.encrypted == true
      end
    end

    test "different MAC addresses" do
      measurements = create_test_measurements()

      mac_addresses = [
        <<0x11, 0x22, 0x33, 0x44, 0x55, 0x66>>,
        <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>,
        <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>,
        <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>
      ]

      for mac <- mac_addresses do
        {:ok, encrypted_data} =
          BTHome.serialize_encrypted(measurements, @test_key, mac, @test_counter)

        {:ok, decoded_data} = BTHome.deserialize_encrypted(encrypted_data, @test_key, mac)

        {:ok, measurements_map} =
          BTHome.deserialize_measurements(encrypted_data, key: @test_key, mac_address: mac)

        expected_measurements = %{
          temperature: 25.6,
          humidity: 65.5
        }

        assert measurements_map == expected_measurements
        assert decoded_data.encrypted == true
      end
    end
  end
end
