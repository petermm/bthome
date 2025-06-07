defmodule BTHome.Validator do
  @moduledoc """
  Input validation for BTHome v2 measurements and data.
  Provides comprehensive validation with detailed error messages and struct support.
  """

  alias BTHome.{Config, Measurement, Objects}

  @doc "Validate a list of measurements"
  def validate_measurements(measurements) when is_list(measurements) do
    measurements
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {measurement, index}, :ok ->
      case validate_measurement(measurement) do
        :ok ->
          {:cont, :ok}

        {:error, message} ->
          {:halt, {:error, "Measurement #{index}: #{message}"}}
      end
    end)
  end

  def validate_measurements(_),
    do: {:error, "Measurements must be a list"}

  @doc "Validate a single measurement (struct-only)"
  def validate_measurement(%Measurement{type: type, value: value}) do
    with :ok <- validate_type_supported(type),
         :ok <- validate_value_type(type, value) do
      validate_value_range(type, value)
    end
  end

  def validate_measurement(_),
    do: {:error, "Invalid measurement format - must be a Measurement struct"}

  defp validate_type_supported(type) do
    case Objects.find_by_type(type) do
      nil ->
        {:error, "Unsupported measurement type: #{inspect(type)}"}

      _ ->
        :ok
    end
  end

  defp validate_value_type(_type, value) when is_number(value), do: :ok

  defp validate_value_type(type, value) when is_boolean(value) do
    # Only allow booleans for binary sensors
    if Objects.binary_sensor?(type) do
      :ok
    else
      {:error, "Boolean values only allowed for binary sensors, got boolean for #{type}"}
    end
  end

  defp validate_value_type(_type, value),
    do: {:error, "Value must be a number or boolean, got: #{inspect(value)}"}

  defp validate_value_range(type, value) when is_boolean(value) do
    validate_value_range(type, if(value, do: 1, else: 0))
  end

  defp validate_value_range(type, value) when is_number(value) do
    case Objects.find_by_type(type) do
      {_id, definition} -> validate_value_with_definition(value, type, definition)
      nil -> {:error, "Unknown type: #{type}"}
    end
  end

  defp validate_value_with_definition(value, type, %{signed: signed, size: size, factor: factor}) do
    int_value = round(value / factor)

    case get_value_limits(signed, size) do
      {min_val, max_val} ->
        validate_int_value_range(int_value, min_val, max_val, factor, type, value)

      :error ->
        {:error, "Cannot determine value limits for type #{type}"}
    end
  rescue
    ArithmeticError ->
      {:error, "Arithmetic error in value conversion for type #{type}"}
  end

  defp validate_int_value_range(int_value, min_val, max_val, factor, type, value) do
    if int_value >= min_val and int_value <= max_val do
      :ok
    else
      build_range_error(value, type, min_val, max_val, factor)
    end
  end

  defp build_range_error(value, type, min_val, max_val, factor) do
    actual_min = min_val * factor
    actual_max = max_val * factor

    {:error, "Value #{value} out of range [#{actual_min}, #{actual_max}] for type #{type}"}
  end

  defp get_value_limits(false, 1), do: {0, 255}
  defp get_value_limits(true, 1), do: {-128, 127}
  defp get_value_limits(false, 2), do: {0, 65_535}
  defp get_value_limits(true, 2), do: {-32_768, 32_767}
  defp get_value_limits(false, 3), do: {0, 16_777_215}
  defp get_value_limits(true, 3), do: {-8_388_608, 8_388_607}
  defp get_value_limits(false, 4), do: {0, 4_294_967_295}
  defp get_value_limits(true, 4), do: {-2_147_483_648, 2_147_483_647}
  defp get_value_limits(_signed, _size), do: :error

  @doc "Validate BTHome device information byte"
  def validate_device_info(device_info) when is_integer(device_info) do
    version =
      Bitwise.bsr(Bitwise.band(device_info, Config.version_mask()), Config.version_shift())

    if version == Config.version() do
      :ok
    else
      {:error, "Unsupported BTHome version: #{version}"}
    end
  end

  def validate_device_info(_),
    do: {:error, "Device info must be an integer"}
end
