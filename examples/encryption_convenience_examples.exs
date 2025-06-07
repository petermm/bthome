# BTHome Encryption Convenience API Examples
#
# This file demonstrates the new encryption convenience functions that simplify
# working with encrypted BTHome v2 data.

defmodule BTHome.EncryptionConvenienceExamples do

  # Sample data for examples
  @key BTHome.generate_encryption_key()
  @mac <<0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC>>
  @counter 1

  @measurements [
    %{type: :temperature, value: 23.5},
    %{type: :humidity, value: 65.0},
    %{type: :battery, value: 85}
  ]

  def run_examples do
    IO.puts("\n=== BTHome Encryption Convenience API Examples ===")

    example_1_basic_encryption_opts()
    example_2_device_context()
    example_3_packet_builder()
    example_4_quick_serialization()
    example_5_device_integration()
    example_6_comparison_with_old_api()
  end

  # Example 1: Basic encryption options creation
  defp example_1_basic_encryption_opts do
    IO.puts("\n--- Example 1: Basic Encryption Options ---")

    # Before: Manual option creation
    old_opts = [encrypt: [key: @key, mac_address: @mac, counter: @counter]]

    # After: Using convenience function
    new_opts = BTHome.encryption_opts(@key, @mac, @counter)

    IO.puts("Old way: #{inspect(old_opts)}")
    IO.puts("New way: #{inspect(new_opts)}")
    IO.puts("Same result: #{old_opts == new_opts}")

    # Use with serialize/2
    {:ok, binary} = BTHome.serialize(@measurements, new_opts)
    IO.puts("Encrypted binary size: #{byte_size(binary)} bytes")
  end

  # Example 2: Device context extraction
  defp example_2_device_context do
    IO.puts("\n--- Example 2: Device Context Extraction ---")

    # Device context with standard keys
    device1 = %{
      key: @key,
      mac_address: @mac,
      counter: @counter
    }

    # Device context with alternative keys
    device2 = %{
      encryption_key: @key,
      mac: @mac,
      counter: @counter
    }

    {:ok, opts1} = BTHome.encryption_opts(device1)
    {:ok, opts2} = BTHome.encryption_opts(device2)

    IO.puts("Device 1 options: #{inspect(opts1)}")
    IO.puts("Device 2 options: #{inspect(opts2)}")
    IO.puts("Same result: #{opts1 == opts2}")

    # Error handling for incomplete device context
    incomplete_device = %{key: @key}  # Missing mac and counter
    case BTHome.encryption_opts(incomplete_device) do
      {:ok, _opts} -> IO.puts("Unexpected success")
      {:error, error} -> IO.puts("Expected error: #{error.message}")
    end
  end

  # Example 3: Encrypted packet builder
  defp example_3_packet_builder do
    IO.puts("\n--- Example 3: Encrypted Packet Builder ---")

    # Create encrypted packet builder
    {packet, opts} = BTHome.new_encrypted_packet(@key, @mac, @counter)

    # Add measurements using the builder pattern
    packet = packet
    |> BTHome.add_measurement(:temperature, 23.5)
    |> BTHome.add_measurement(:humidity, 65.0)
    |> BTHome.add_measurement(:motion, true)

    IO.puts("Packet has #{length(packet.measurements)} measurements")

    # Serialize with convenience function
    {:ok, binary1} = BTHome.serialize_encrypted(packet, opts)

    # Compare with regular serialize
    {:ok, binary2} = BTHome.serialize(packet, opts)

    IO.puts("serialize_encrypted result: #{byte_size(binary1)} bytes")
    IO.puts("serialize result: #{byte_size(binary2)} bytes")
    IO.puts("Same result: #{binary1 == binary2}")

    # Verify decryption works
    {:ok, decoded} = BTHome.deserialize_encrypted(binary1, @key, @mac)
    IO.puts("Decrypted #{length(decoded.measurements)} measurements")
  end

  # Example 4: Quick serialization
  defp example_4_quick_serialization do
    IO.puts("\n--- Example 4: Quick Serialization ---")

    # Before: Multiple steps
    opts = [encrypt: [key: @key, mac_address: @mac, counter: @counter]]
    {:ok, binary1} = BTHome.serialize(@measurements, opts)

    # After: One-liner
    {:ok, binary2} = BTHome.quick_serialize_encrypted(@measurements, @key, @mac, @counter)

    IO.puts("Multi-step result: #{byte_size(binary1)} bytes")
    IO.puts("One-liner result: #{byte_size(binary2)} bytes")
    IO.puts("Same result: #{binary1 == binary2}")

    # Verify both can be decrypted
    {:ok, decoded1} = BTHome.deserialize_encrypted(binary1, @key, @mac)
    {:ok, decoded2} = BTHome.deserialize_encrypted(binary2, @key, @mac)

    IO.puts("Both decrypt to #{length(decoded1.measurements)} measurements")
  end

  # Example 5: Device integration
  defp example_5_device_integration do
    IO.puts("\n--- Example 5: Device Integration ---")

    # Device with encryption
    encrypted_device = %{
      name: "Temperature Sensor 1",
      encryption_key: @key,
      mac_address: @mac,
      counter: @counter
    }

    # Device without encryption
    unencrypted_device = %{
      name: "Temperature Sensor 2"
    }

    # Serialize for both devices
    {:ok, encrypted_binary} = BTHome.serialize_for_device(@measurements, encrypted_device)
    {:ok, unencrypted_binary} = BTHome.serialize_for_device(@measurements, unencrypted_device)

    IO.puts("Encrypted device binary: #{byte_size(encrypted_binary)} bytes")
    IO.puts("Unencrypted device binary: #{byte_size(unencrypted_binary)} bytes")

    # Verify encryption status
    case BTHome.deserialize(encrypted_binary) do
      {:ok, _decoded} -> IO.puts("ERROR: Encrypted binary should not decrypt without key!")
      {:error, _error} -> IO.puts("✓ Encrypted binary requires decryption key")
    end

    case BTHome.deserialize(unencrypted_binary) do
      {:ok, decoded} -> IO.puts("✓ Unencrypted binary decrypts normally (#{length(decoded.measurements)} measurements)")
      {:error, error} -> IO.puts("ERROR: #{error.message}")
    end

    # Decrypt the encrypted one
    {:ok, decrypted} = BTHome.deserialize_encrypted(encrypted_binary, @key, @mac)
    IO.puts("✓ Encrypted binary decrypts with key (#{length(decrypted.measurements)} measurements)")
  end

  # Example 6: Comparison with old API
  defp example_6_comparison_with_old_api do
    IO.puts("\n--- Example 6: Before vs After Comparison ---")

    IO.puts("\n** BEFORE (verbose encryption setup): **")
    IO.puts("""
    # Manual encryption options
    encrypt_opts = [encrypt: [key: key, mac_address: mac, counter: counter]]
    {:ok, binary} = BTHome.serialize(measurements, encrypt_opts)

    # Or using existing serialize_encrypted/4
    {:ok, binary} = BTHome.serialize_encrypted(measurements, key, mac, counter)
    """)

    IO.puts("\n** AFTER (convenient encryption): **")
    IO.puts("""
    # Option 1: Create reusable encryption options
    opts = BTHome.encryption_opts(key, mac, counter)
    {:ok, binary} = BTHome.serialize(measurements, opts)

    # Option 2: One-liner for quick use
    {:ok, binary} = BTHome.quick_serialize_encrypted(measurements, key, mac, counter)

    # Option 3: Device context integration
    {:ok, binary} = BTHome.serialize_for_device(measurements, device_context)

    # Option 4: Builder pattern with encryption
    {packet, opts} = BTHome.new_encrypted_packet(key, mac, counter)
    packet = BTHome.add_measurement(packet, :temperature, 23.5)
    {:ok, binary} = BTHome.serialize_encrypted(packet, opts)
    """)

    # Demonstrate all approaches produce the same result
    opts = BTHome.encryption_opts(@key, @mac, @counter)
    {:ok, binary1} = BTHome.serialize(@measurements, opts)
    {:ok, binary2} = BTHome.quick_serialize_encrypted(@measurements, @key, @mac, @counter)
    {:ok, binary3} = BTHome.serialize_for_device(@measurements, %{
      encryption_key: @key, mac_address: @mac, counter: @counter
    })

    {packet, packet_opts} = BTHome.new_encrypted_packet(@key, @mac, @counter)
    packet = Enum.reduce(@measurements, packet, fn %{type: type, value: value}, acc ->
      BTHome.add_measurement(acc, type, value)
    end)
    {:ok, binary4} = BTHome.serialize_encrypted(packet, packet_opts)

    IO.puts("\nAll approaches produce identical results:")
    IO.puts("  encryption_opts + serialize: #{byte_size(binary1)} bytes")
    IO.puts("  quick_serialize_encrypted: #{byte_size(binary2)} bytes")
    IO.puts("  serialize_for_device: #{byte_size(binary3)} bytes")
    IO.puts("  packet builder: #{byte_size(binary4)} bytes")
    IO.puts("  All identical: #{binary1 == binary2 and binary2 == binary3 and binary3 == binary4}")
  end
end

# Run the examples if this file is executed directly
if __ENV__.file == Path.absname(__ENV__.file) do
  BTHome.EncryptionConvenienceExamples.run_examples()
end
