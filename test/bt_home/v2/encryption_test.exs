defmodule BTHome.EncryptionTest do
  use ExUnit.Case, async: true

  alias BTHome.Encryption

  # Test vectors from BTHome v2 specification
  @test_key <<0x23, 0x1D, 0x39, 0xC1, 0xD7, 0xCC, 0x1A, 0xB1, 0xAE, 0xE2, 0x24, 0xCD, 0x09, 0x6D,
              0xB9, 0x32>>
  @test_mac <<0x54, 0x48, 0xE6, 0x8F, 0x80, 0xA5>>
  @test_counter 0x33221100
  # temp + humidity
  @test_data <<0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13>>

  describe "encrypt/4" do
    test "encrypts data successfully with valid parameters" do
      assert {:ok, {ciphertext, mic}} =
               Encryption.encrypt(@test_data, @test_key, @test_mac, @test_counter)

      assert is_binary(ciphertext)
      assert is_binary(mic)
      assert byte_size(mic) == 4
      assert byte_size(ciphertext) == byte_size(@test_data)
    end

    test "returns error with invalid key length" do
      # Too short
      invalid_key = <<1, 2, 3>>

      assert {:error, _reason} =
               Encryption.encrypt(@test_data, invalid_key, @test_mac, @test_counter)
    end

    test "returns error with invalid MAC address length" do
      # Too short
      invalid_mac = <<1, 2, 3>>

      assert {:error, _reason} =
               Encryption.encrypt(@test_data, @test_key, invalid_mac, @test_counter)
    end

    test "returns error with invalid counter" do
      invalid_counter = -1

      assert {:error, _reason} =
               Encryption.encrypt(@test_data, @test_key, @test_mac, invalid_counter)
    end

    test "encrypts empty data" do
      assert {:ok, {ciphertext, mic}} =
               Encryption.encrypt(<<>>, @test_key, @test_mac, @test_counter)

      assert byte_size(ciphertext) == 0
      assert byte_size(mic) == 4
    end

    test "produces different ciphertext for different counters" do
      {:ok, {ciphertext1, _}} = Encryption.encrypt(@test_data, @test_key, @test_mac, 1)
      {:ok, {ciphertext2, _}} = Encryption.encrypt(@test_data, @test_key, @test_mac, 2)

      assert ciphertext1 != ciphertext2
    end
  end

  describe "decrypt/5" do
    test "decrypts data successfully" do
      {:ok, {ciphertext, mic}} =
        Encryption.encrypt(@test_data, @test_key, @test_mac, @test_counter)

      assert {:ok, decrypted} =
               Encryption.decrypt(ciphertext, mic, @test_key, @test_mac, @test_counter)

      assert decrypted == @test_data
    end

    test "returns error with wrong key" do
      {:ok, {ciphertext, mic}} =
        Encryption.encrypt(@test_data, @test_key, @test_mac, @test_counter)

      wrong_key = :crypto.strong_rand_bytes(16)

      assert {:error, _reason} =
               Encryption.decrypt(ciphertext, mic, wrong_key, @test_mac, @test_counter)
    end

    test "returns error with wrong MAC address" do
      {:ok, {ciphertext, mic}} =
        Encryption.encrypt(@test_data, @test_key, @test_mac, @test_counter)

      wrong_mac = <<0x11, 0x22, 0x33, 0x44, 0x55, 0x66>>

      assert {:error, _reason} =
               Encryption.decrypt(ciphertext, mic, @test_key, wrong_mac, @test_counter)
    end

    test "returns error with wrong counter" do
      {:ok, {ciphertext, mic}} =
        Encryption.encrypt(@test_data, @test_key, @test_mac, @test_counter)

      wrong_counter = @test_counter + 1

      assert {:error, _reason} =
               Encryption.decrypt(ciphertext, mic, @test_key, @test_mac, wrong_counter)
    end

    test "returns error with tampered ciphertext" do
      {:ok, {ciphertext, mic}} =
        Encryption.encrypt(@test_data, @test_key, @test_mac, @test_counter)

      tampered_ciphertext = <<0xFF>> <> binary_part(ciphertext, 1, byte_size(ciphertext) - 1)

      assert {:error, _reason} =
               Encryption.decrypt(tampered_ciphertext, mic, @test_key, @test_mac, @test_counter)
    end

    test "returns error with tampered MIC" do
      {:ok, {ciphertext, _mic}} =
        Encryption.encrypt(@test_data, @test_key, @test_mac, @test_counter)

      tampered_mic = <<0xFF, 0xFF, 0xFF, 0xFF>>

      assert {:error, _reason} =
               Encryption.decrypt(ciphertext, tampered_mic, @test_key, @test_mac, @test_counter)
    end

    test "decrypts empty data" do
      {:ok, {ciphertext, mic}} = Encryption.encrypt(<<>>, @test_key, @test_mac, @test_counter)

      assert {:ok, decrypted} =
               Encryption.decrypt(ciphertext, mic, @test_key, @test_mac, @test_counter)

      assert decrypted == <<>>
    end
  end

  describe "key utilities" do
    test "generate_key/0 creates valid key" do
      key = Encryption.generate_key()

      assert is_binary(key)
      assert byte_size(key) == 16
    end

    test "key_from_hex/1 converts valid hex string" do
      hex = "231d39c1d7cc1ab1aee224cd096db932"

      assert {:ok, key} = Encryption.key_from_hex(hex)
      assert key == @test_key
    end

    test "key_from_hex/1 handles mixed case" do
      hex = "231D39C1d7cc1ab1AEE224CD096db932"

      assert {:ok, key} = Encryption.key_from_hex(hex)
      assert key == @test_key
    end

    test "key_from_hex/1 rejects invalid hex string" do
      assert {:error, _reason} = Encryption.key_from_hex("invalid")
      # Too short
      assert {:error, _reason} =
               Encryption.key_from_hex("231d39c1d7cc1ab1aee224cd096db93")

      # Too long
      assert {:error, _reason} =
               Encryption.key_from_hex("231d39c1d7cc1ab1aee224cd096db932x")
    end

    test "key_to_hex/1 converts key to hex" do
      hex = Encryption.key_to_hex(@test_key)

      assert hex == "231d39c1d7cc1ab1aee224cd096db932"
      assert String.length(hex) == 32
    end

    test "key conversion round trip" do
      original_hex = "231d39c1d7cc1ab1aee224cd096db932"

      {:ok, key} = Encryption.key_from_hex(original_hex)
      converted_hex = Encryption.key_to_hex(key)

      assert converted_hex == original_hex
    end
  end

  describe "encrypt/decrypt round trip" do
    test "various data sizes" do
      test_cases = [
        # Empty
        <<>>,
        # Single byte
        <<0x01>>,
        # Temperature
        <<0x02, 0xCA, 0x09>>,
        # Temperature + humidity
        <<0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13>>,
        # Large data
        :crypto.strong_rand_bytes(50)
      ]

      for data <- test_cases do
        {:ok, {ciphertext, mic}} = Encryption.encrypt(data, @test_key, @test_mac, @test_counter)

        {:ok, decrypted} =
          Encryption.decrypt(ciphertext, mic, @test_key, @test_mac, @test_counter)

        assert decrypted == data, "Round trip failed for data: #{inspect(data)}"
      end
    end

    test "various counter values" do
      counters = [0, 1, 0xFF, 0xFFFF, 0xFFFFFF, 0xFFFFFFFF]

      for counter <- counters do
        {:ok, {ciphertext, mic}} = Encryption.encrypt(@test_data, @test_key, @test_mac, counter)
        {:ok, decrypted} = Encryption.decrypt(ciphertext, mic, @test_key, @test_mac, counter)

        assert decrypted == @test_data, "Round trip failed for counter: #{counter}"
      end
    end
  end
end
