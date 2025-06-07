defmodule BTHome.Encoder do
  @moduledoc """
  BTHome v2 serialization logic.
  Handles encoding measurements into binary format with struct support.
  """

  alias BTHome.{Config, Encryption, Measurement, Objects, Validator}

  @doc "Encode measurements to BTHome v2 binary format"
  def encode_measurements(measurements, opts \\ []) do
    with :ok <- Validator.validate_measurements(measurements) do
      encode_with_options(measurements, opts)
    end
  end

  @doc "Encode pre-validated measurements (skips validation)"
  def encode_validated(measurements, opts \\ []) do
    encode_with_options(measurements, opts)
  end

  # Optimized encoding using iodata to avoid intermediate binary allocations
  defp encode_to_iodata(measurements) do
    encode_measurements_acc(measurements, [])
  end

  defp encode_measurements_acc([], acc), do: {:ok, Enum.reverse(acc)}

  defp encode_measurements_acc([measurement | rest], acc) do
    case encode_measurement(measurement) do
      {:ok, encoded} -> encode_measurements_acc(rest, [encoded | acc])
      {:error, reason} -> {:error, reason}
    end
  end

  # Main encoding logic with options support
  defp encode_with_options(measurements, opts) do
    case Keyword.get(opts, :encrypt) do
      encrypt_opts when is_list(encrypt_opts) -> encode_encrypted(measurements, encrypt_opts)
      nil -> encode_unencrypted(measurements)
      _ -> {:error, "Invalid encrypt option"}
    end
  end

  # Encode without encryption
  defp encode_unencrypted(measurements) do
    device_info = build_device_info(false)

    case encode_to_iodata(measurements) do
      {:ok, iodata} -> {:ok, IO.iodata_to_binary([device_info | iodata])}
      {:error, reason} -> {:error, reason}
    end
  end

  # Encode with encryption
  defp encode_encrypted(measurements, encrypt_opts) do
    with {:ok, key} <- get_required_option(encrypt_opts, :key, "encryption key"),
         {:ok, mac_address} <- get_required_option(encrypt_opts, :mac_address, "MAC address"),
         {:ok, counter} <- get_required_option(encrypt_opts, :counter, "counter"),
         {:ok, iodata} <- encode_to_iodata(measurements),
         device_info = build_device_info(true),
         plaintext = IO.iodata_to_binary(iodata),
         {:ok, {ciphertext, mic}} <- Encryption.encrypt(plaintext, key, mac_address, counter) do
      # Build final packet: device_info + ciphertext + counter + mic
      packet = [device_info, ciphertext, <<counter::little-32>>, mic]
      {:ok, IO.iodata_to_binary(packet)}
    end
  end

  defp get_required_option(opts, key, description) do
    case Keyword.get(opts, key) do
      nil -> {:error, "Missing required #{description} for encryption"}
      value -> {:ok, value}
    end
  end

  defp build_device_info(encryption) do
    # BTHome device information byte: version 2, no trigger, encryption flag
    base = Config.device_info_base()
    if encryption, do: Bitwise.bor(base, Config.encryption_mask()), else: base
  end

  # Encode a single measurement (struct-only)
  defp encode_measurement(%Measurement{
         type: type,
         value: value,
         object_id: object_id
       }) do
    {id, definition} = find_object_definition(type, object_id)
    encode_value(id, value, definition)
  end

  # Find object definition for pre-validated data
  defp find_object_definition(type, nil) do
    Objects.find_by_type(type)
  end

  defp find_object_definition(_type, object_id) when is_integer(object_id) do
    {object_id, Objects.get_definition(object_id)}
  end

  defp encode_value(object_id, value, %{factor: factor, signed: signed, size: size}) do
    numeric_value = convert_boolean_to_numeric(value)

    with {:ok, int_value} <- convert_to_integer(numeric_value, factor),
         {:ok, binary_value} <- encode_integer(int_value, signed, size) do
      {:ok, <<object_id, binary_value::binary>>}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp convert_boolean_to_numeric(value) when is_boolean(value) do
    if value, do: 1, else: 0
  end

  defp convert_boolean_to_numeric(value), do: value

  defp convert_to_integer(value, factor)
       when is_number(value) and is_number(factor) and factor != 0 do
    int_value = round(value / factor)
    {:ok, int_value}
  rescue
    _e ->
      {:error, "Failed to convert value #{value} with factor #{factor}"}
  end

  defp convert_to_integer(value, factor) do
    {:error, "Invalid value #{inspect(value)} or factor #{inspect(factor)}"}
  end

  defp encode_integer(int_value, signed, size) do
    case encode_integer_safe(int_value, signed, size) do
      {:ok, binary_value} -> {:ok, binary_value}
      {:error, reason} -> {:error, reason}
    end
  end

  # Safe integer encoding with range validation
  defp encode_integer_safe(int_value, false, 1) when int_value >= 0 and int_value <= 255 do
    {:ok, <<int_value::unsigned-8>>}
  end

  defp encode_integer_safe(int_value, true, 1) when int_value >= -128 and int_value <= 127 do
    {:ok, <<int_value::signed-8>>}
  end

  defp encode_integer_safe(int_value, false, 2) when int_value >= 0 and int_value <= 65_535 do
    {:ok, <<int_value::unsigned-little-16>>}
  end

  defp encode_integer_safe(int_value, true, 2)
       when int_value >= -32_768 and int_value <= 32_767 do
    {:ok, <<int_value::signed-little-16>>}
  end

  defp encode_integer_safe(int_value, false, 3) when int_value >= 0 and int_value <= 16_777_215 do
    {:ok, <<int_value::unsigned-little-24>>}
  end

  defp encode_integer_safe(int_value, true, 3)
       when int_value >= -8_388_608 and int_value <= 8_388_607 do
    {:ok, <<int_value::signed-little-24>>}
  end

  defp encode_integer_safe(int_value, false, 4)
       when int_value >= 0 and int_value <= 4_294_967_295 do
    {:ok, <<int_value::unsigned-little-32>>}
  end

  defp encode_integer_safe(int_value, true, 4)
       when int_value >= -2_147_483_648 and int_value <= 2_147_483_647 do
    {:ok, <<int_value::signed-little-32>>}
  end

  defp encode_integer_safe(int_value, signed, size) do
    {:error,
     "Value #{int_value} out of range for #{if signed, do: "signed", else: "unsigned"} #{size}-byte integer"}
  end
end
