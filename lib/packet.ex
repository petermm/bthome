defmodule BTHome.Packet do
  @moduledoc """
  Builder pattern for creating BTHome v2 packets with a pipeable API.

  This module provides a fluent interface for building BTHome v2 packets by
  accumulating measurements and then serializing them. It supports the builder
  pattern with method chaining using the pipe operator.

  ## Examples

      # Basic usage with builder pattern
      {:ok, binary} = BTHome.new_packet()
      |> BTHome.add_measurement(:temperature, 23.45)
      |> BTHome.add_measurement(:motion, true)
      |> BTHome.serialize()

      # With encryption
      {:ok, binary} = BTHome.new_packet()
      |> BTHome.add_measurement(:temperature, 23.45)
      |> BTHome.add_measurement(:humidity, 67.8)
      |> BTHome.serialize(true)

      # Error handling in the chain
      result = BTHome.new_packet()
      |> BTHome.add_measurement(:temperature, 23.45)
      |> BTHome.add_measurement(:invalid_type, 42)  # This will return an error
      |> BTHome.serialize()

      case result do
        {:ok, binary} -> handle_success(binary)
        {:error, error} -> handle_error(error)
      end
  """

  alias BTHome.Measurement

  @type t :: %__MODULE__{
          measurements: [Measurement.t()],
          error: String.t() | nil
        }

  @enforce_keys []
  defstruct measurements: [], error: nil

  @doc """
  Creates a new empty packet builder.

  Returns a new `BTHome.Packet` struct that can be used to accumulate
  measurements using the builder pattern.

  ## Returns
  A new packet builder struct.

  ## Examples
      iex> BTHome.new_packet()
      %BTHome.Packet{measurements: [], error: nil}
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Adds a measurement to the packet builder.

  If the packet already contains an error from a previous operation, this
  function will return the packet unchanged. Otherwise, it validates the
  measurement and adds it to the packet if valid.

  ## Parameters
  - `packet` - The packet builder struct
  - `type` - The measurement type atom
  - `value` - The measurement value
  - `opts` - Optional keyword list (same as `BTHome.Measurement.new/3`)

  ## Returns
  The updated packet builder struct, potentially with an error if validation fails.

  ## Examples
      iex> packet = BTHome.new_packet()
      iex> result = BTHome.add_measurement(packet, :temperature, 23.45)
      iex> length(result.measurements)
      1
      iex> is_nil(result.error)
      true

      iex> packet = BTHome.new_packet()
      iex> result = BTHome.add_measurement(packet, :invalid_type, 42)
      iex> match?(%BTHome.Packet{measurements: [], error: "Unsupported measurement type: :invalid_type"}, result)
      true
  """
  @spec add_measurement(t(), atom(), number() | boolean(), keyword()) :: t()
  def add_measurement(packet, type, value, opts \\ [])

  def add_measurement(%__MODULE__{error: error} = packet, _type, _value, _opts)
      when not is_nil(error) do
    # If there's already an error, don't process further measurements
    packet
  end

  def add_measurement(%__MODULE__{measurements: measurements} = packet, type, value, opts) do
    case Measurement.new(type, value, opts) do
      {:ok, measurement} ->
        %{packet | measurements: measurements ++ [measurement]}

      {:error, error} ->
        %{packet | error: error}
    end
  end

  @doc """
  Serializes the accumulated measurements in the packet.

  ## Parameters
  - `packet` - The packet builder struct
  - `opts` - Serialization options (keyword list)
    - `:encrypt` - Encryption options (keyword list or map)
      - `:key` - 16-byte encryption key (required)
      - `:mac_address` - 6-byte MAC address (required)
      - `:counter` - 4-byte counter value (required)

  ## Returns
  `{:ok, binary}` on success, `{:error, reason}` on failure.

  ## Examples
      # Basic usage
      iex> {:ok, binary} = BTHome.new_packet()
      iex> |> BTHome.add_measurement(:temperature, 23.45)
      iex> |> BTHome.serialize()
      iex> is_binary(binary)
      true

      # With encryption
      iex> key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      iex> mac = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      iex> opts = [encrypt: [key: key, mac_address: mac, counter: 1]]
      iex> {:ok, binary} = BTHome.new_packet()
      iex> |> BTHome.add_measurement(:temperature, 23.45)
      iex> |> BTHome.serialize(opts)
      iex> is_binary(binary)
      true
  """
  @spec serialize(t(), boolean() | keyword()) :: {:ok, binary()} | {:error, String.t()}
  def serialize(packet, opts \\ [])

  def serialize(%__MODULE__{error: error}, _opts) when not is_nil(error) do
    {:error, error}
  end

  def serialize(%__MODULE__{measurements: measurements}, opts) do
    BTHome.serialize(measurements, opts)
  end

  @doc """
  Serializes the accumulated measurements in the packet, raising on error.

  Similar to `serialize/2` but raises an exception instead of returning an error tuple.
  This is useful for pipeline operations where you want to fail fast on errors.

  ## Parameters
  - `packet` - The packet builder struct
  - `opts` - Serialization options (same as `serialize/2`)

  ## Returns
  Binary BTHome v2 data on success, raises on error.

  ## Examples
      # Basic usage
      iex> binary = BTHome.new_packet()
      iex> |> BTHome.add_measurement(:temperature, 23.45)
      iex> |> BTHome.serialize!()
      iex> is_binary(binary)
      true

      # With encryption
      iex> key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      iex> mac = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      iex> opts = [encrypt: [key: key, mac_address: mac, counter: 1]]
      iex> binary = BTHome.new_packet()
      iex> |> BTHome.add_measurement(:temperature, 23.45)
      iex> |> BTHome.serialize!(opts)
      iex> is_binary(binary)
      true

  ## Raises
  `ArgumentError` if serialization fails or packet contains an error.
  """
  @spec serialize!(t(), boolean() | keyword()) :: binary()
  def serialize!(packet, opts \\ []) do
    case serialize(packet, opts) do
      {:ok, binary} -> binary
      {:error, error} -> raise error
    end
  end
end
