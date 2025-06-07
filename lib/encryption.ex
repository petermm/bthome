defmodule BTHome.Encryption do
  @moduledoc """
  AES-CCM encryption/decryption for BTHome v2 protocol.

  Implements the BTHome v2 encryption specification using AES-CCM mode
  with 16-byte keys and 4-byte MIC (Message Integrity Check).

  ## Key Requirements

  - Encryption key must be exactly 16 bytes (128-bit)
  - MAC address must be exactly 6 bytes
  - Counter is a 4-byte unsigned integer (little-endian)
  - MIC (Message Integrity Check) is always 4 bytes

  ## Nonce Construction

  The nonce is constructed by concatenating:
  1. MAC address (6 bytes)
  2. BTHome UUID (2 bytes, always 0xD2FC)
  3. Device info byte (1 byte)
  4. Counter (4 bytes, little-endian)

  Total nonce length: 13 bytes

  ## Examples

      # Encrypt sensor data
      key = <<0x23, 0x1d, 0x39, 0xc1, 0xd7, 0xcc, 0x1a, 0xb1,
              0xae, 0xe2, 0x24, 0xcd, 0x09, 0x6d, 0xb9, 0x32>>
      mac = <<0x54, 0x48, 0xe6, 0x8f, 0x80, 0xa5>>
      data = <<0x02, 0xca, 0x09, 0x03, 0xbf, 0x13>>  # temp + humidity
      counter = 0x33221100

      {:ok, {ciphertext, mic}} = BTHome.Encryption.encrypt(data, key, mac, counter)

      # Decrypt sensor data
      {:ok, decrypted} = BTHome.Encryption.decrypt(ciphertext, mic, key, mac, counter)
  """

  alias BTHome.Config

  @bthome_uuid <<0xD2, 0xFC>>
  @mic_length 4
  @key_length 16
  @mac_length 6
  @counter_length 4

  @doc """
  Encrypts BTHome sensor data using AES-CCM.

  ## Parameters

  - `data` - Binary sensor data to encrypt
  - `key` - 16-byte encryption key
  - `mac_address` - 6-byte MAC address of the device
  - `counter` - 4-byte counter value (unsigned integer)
  - `device_info` - Device information byte (optional, defaults to encrypted v2)

  ## Returns

  - `{:ok, {ciphertext, mic}}` - Success with encrypted data and MIC
  - `{:error, reason}` - Encryption failed

  ## Examples

      key = :crypto.strong_rand_bytes(16)
      mac = <<0x54, 0x48, 0xe6, 0x8f, 0x80, 0xa5>>
      data = <<0x02, 0xca, 0x09>>  # temperature measurement

      {:ok, {ciphertext, mic}} = encrypt(data, key, mac, 1)
  """
  def encrypt(data, key, mac_address, counter)
      when is_binary(data) and is_binary(key) and byte_size(key) == @key_length and
             is_binary(mac_address) and byte_size(mac_address) == @mac_length and
             is_integer(counter) and counter >= 0 and counter <= 0xFFFFFFFF do
    nonce = build_nonce(mac_address, counter)
    perform_encryption(data, key, nonce)
  end

  def encrypt(data, key, mac_address, counter) do
    case validate_encrypt_params(data, key, mac_address, counter) do
      :ok -> {:error, "Invalid parameters"}
      error -> error
    end
  end

  defp build_nonce(mac_address, counter) do
    device_info = build_encrypted_device_info()

    <<mac_address::binary-size(@mac_length), @bthome_uuid::binary, device_info,
      counter::little-size(@counter_length * 8)>>
  end

  defp perform_encryption(data, key, nonce) do
    case :crypto.crypto_one_time_aead(:aes_128_ccm, key, nonce, data, <<>>, @mic_length, true) do
      {ciphertext, mic} ->
        {:ok, {ciphertext, mic}}

      error ->
        {:error, "AES-CCM encryption failed: #{inspect(error)}"}
    end
  end

  defp validate_encrypt_params(data, key, mac_address, counter) do
    with :ok <- validate_data(data),
         :ok <- validate_key(key),
         :ok <- validate_mac_address(mac_address),
         :ok <- validate_counter(counter) do
      :ok
    else
      error -> error
    end
  end

  defp validate_data(data) when is_binary(data), do: :ok
  defp validate_data(_), do: {:error, "Data must be binary"}

  defp validate_key(key) when is_binary(key) and byte_size(key) == @key_length, do: :ok

  defp validate_key(key) do
    {:error, "Invalid key length: expected #{@key_length} bytes, got #{byte_size(key || <<>>)}"}
  end

  defp validate_mac_address(mac_address)
       when is_binary(mac_address) and byte_size(mac_address) == @mac_length,
       do: :ok

  defp validate_mac_address(mac_address) do
    {:error,
     "Invalid MAC address length: expected #{@mac_length} bytes, got #{byte_size(mac_address || <<>>)}"}
  end

  defp validate_counter(counter)
       when is_integer(counter) and counter >= 0 and counter <= 0xFFFFFFFF,
       do: :ok

  defp validate_counter(counter) do
    {:error, "Invalid counter: must be 32-bit unsigned integer (0-4294967295), got #{counter}"}
  end

  @doc """
  Decrypts BTHome sensor data using AES-CCM.

  ## Parameters

  - `ciphertext` - Encrypted sensor data
  - `mic` - 4-byte Message Integrity Check
  - `key` - 16-byte encryption key (same as used for encryption)
  - `mac_address` - 6-byte MAC address of the device
  - `counter` - 4-byte counter value used during encryption
  - `device_info` - Device information byte (optional, defaults to encrypted v2)

  ## Returns

  - `{:ok, data}` - Successfully decrypted sensor data
  - `{:error, reason}` - Decryption failed (wrong key, tampered data, etc.)

  ## Examples

      {:ok, data} = decrypt(ciphertext, mic, key, mac, 1)
  """
  def decrypt(ciphertext, mic, key, mac_address, counter) do
    if valid_decrypt_params?(ciphertext, mic, key, mac_address, counter) do
      nonce = build_nonce(mac_address, counter)
      perform_decryption(ciphertext, mic, key, nonce)
    else
      case validate_decrypt_params(ciphertext, mic, key, mac_address, counter) do
        :ok -> {:error, "Invalid parameters"}
        error -> error
      end
    end
  end

  defp valid_decrypt_params?(ciphertext, mic, key, mac_address, counter) do
    valid_ciphertext?(ciphertext) and valid_mic?(mic) and
      valid_key?(key) and valid_mac_address?(mac_address) and
      valid_counter?(counter)
  end

  defp valid_ciphertext?(ciphertext), do: is_binary(ciphertext)
  defp valid_mic?(mic), do: is_binary(mic) and byte_size(mic) == @mic_length
  defp valid_key?(key), do: is_binary(key) and byte_size(key) == @key_length

  defp valid_mac_address?(mac_address),
    do: is_binary(mac_address) and byte_size(mac_address) == @mac_length

  defp valid_counter?(counter), do: is_integer(counter) and counter >= 0 and counter <= 0xFFFFFFFF

  defp perform_decryption(ciphertext, mic, key, nonce) do
    case :crypto.crypto_one_time_aead(:aes_128_ccm, key, nonce, ciphertext, <<>>, mic, false) do
      data when is_binary(data) ->
        {:ok, data}

      error ->
        {:error, "AES-CCM decryption failed: #{inspect(error)}"}
    end
  end

  defp validate_decrypt_params(ciphertext, mic, key, mac_address, counter) do
    with :ok <- validate_ciphertext(ciphertext),
         :ok <- validate_mic(mic),
         :ok <- validate_key(key),
         :ok <- validate_mac_address(mac_address),
         :ok <- validate_counter(counter) do
      :ok
    else
      error -> error
    end
  end

  defp validate_ciphertext(ciphertext) when is_binary(ciphertext), do: :ok
  defp validate_ciphertext(_), do: {:error, "Ciphertext must be binary"}

  defp validate_mic(mic) when is_binary(mic) and byte_size(mic) == @mic_length, do: :ok

  defp validate_mic(mic) do
    {:error, "Invalid MIC length: expected #{@mic_length} bytes, got #{byte_size(mic || <<>>)}"}
  end

  @doc """
  Generates a random encryption key.

  ## Returns

  16-byte random encryption key
  """
  def generate_key do
    :crypto.strong_rand_bytes(@key_length)
  end

  @doc """
  Converts a hex string to binary key.

  ## Parameters

  - `hex_string` - Hex string representation of key (32 characters)

  ## Returns

  - `{:ok, key}` - Successfully converted key
  - `{:error, reason}` - Invalid hex string

  ## Examples

      {:ok, key} = key_from_hex("231d39c1d7cc1ab1aee224cd096db932")
  """
  def key_from_hex(hex_string) when is_binary(hex_string) do
    # 2 hex chars per byte
    expected_length = @key_length * 2

    case String.length(hex_string) do
      ^expected_length ->
        try do
          key = Base.decode16!(hex_string, case: :mixed)
          {:ok, key}
        rescue
          ArgumentError -> {:error, "Invalid hex string: #{hex_string}"}
        end

      length ->
        {:error, "Invalid hex key length: expected #{expected_length} characters, got #{length}"}
    end
  end

  @doc """
  Converts a binary key to hex string.

  ## Parameters

  - `key` - Binary encryption key

  ## Returns

  Hex string representation of the key

  ## Examples

      hex = key_to_hex(key)  # => "231d39c1d7cc1ab1aee224cd096db932"
  """
  def key_to_hex(key) when is_binary(key) do
    Base.encode16(key, case: :lower)
  end

  # Private functions

  defp build_encrypted_device_info do
    # BTHome v2 with encryption flag set
    Config.device_info_base() |> Bitwise.bor(Config.encryption_mask())
  end
end
