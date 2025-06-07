defmodule BTHome.Measurement do
  @moduledoc """
  Struct representing a BTHome v2 measurement with type safety.

  This struct provides a type-safe representation of sensor measurements in the BTHome v2
  protocol. It enforces required fields and provides validation during creation.

  ## Fields

  - `:type` (required) - The sensor type as an atom (e.g., `:temperature`, `:humidity`)
  - `:value` (required) - The measured value (number for sensors, boolean for binary sensors)
  - `:unit` (optional) - The unit of measurement as a string (e.g., "°C", "%")
  - `:object_id` (optional) - The BTHome object ID for this measurement type

  ## Examples

      # Create a temperature measurement
      iex> BTHome.Measurement.new(:temperature, 23.45)
      {:ok, %BTHome.Measurement{type: :temperature, value: 23.45, unit: "°C"}}

      # Create a binary sensor measurement
      iex> BTHome.Measurement.new(:motion, true)
      {:ok, %BTHome.Measurement{type: :motion, value: true, unit: nil}}

      # Invalid measurement type
      iex> BTHome.Measurement.new(:invalid_type, 42)
      {:error, "Unsupported measurement type: invalid_type"}
  """

  alias BTHome.{Objects, Validator}

  @enforce_keys [:type, :value]
  defstruct [:type, :value, :unit, :object_id, :unknown]

  @type t :: %__MODULE__{
          type: atom(),
          value: number() | boolean() | map(),
          unit: String.t() | nil,
          object_id: integer() | nil,
          unknown: binary() | nil
        }

  @doc """
  Creates a new measurement with validation.

  This function creates a new `BTHome.Measurement` struct and validates it according
  to BTHome v2 protocol requirements. It automatically looks up the unit for known
  measurement types.

  ## Parameters

  - `type` - The measurement type as an atom (must be supported by BTHome v2)
  - `value` - The measurement value (number for sensors, boolean for binary sensors)
  - `opts` - Optional keyword list with:
    - `:unit` - Override the default unit for this measurement type
    - `:object_id` - Override the default object ID for this measurement type

  ## Returns

  - `{:ok, measurement}` - Successfully created and validated measurement
  - `{:error, error}` - Validation failed with error details

  ## Examples

      # Temperature measurement (unit automatically set to "°C")
      iex> BTHome.Measurement.new(:temperature, 23.45)
      {:ok, %BTHome.Measurement{type: :temperature, value: 23.45, unit: "°C"}}

      # Binary sensor
      iex> BTHome.Measurement.new(:motion, true)
      {:ok, %BTHome.Measurement{type: :motion, value: true, unit: nil}}

      # With custom unit
      iex> BTHome.Measurement.new(:temperature, 74.21, unit: "°F")
      {:ok, %BTHome.Measurement{type: :temperature, value: 74.21, unit: "°F"}}

      # Invalid type
      iex> BTHome.Measurement.new(:invalid, 42)
      {:error, "Unsupported measurement type: :invalid_type"}
  """
  @spec new(atom(), number() | boolean(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def new(type, value, opts \\ []) do
    # Get unit from object definitions if not provided
    unit =
      case Keyword.get(opts, :unit) do
        nil ->
          case Objects.find_by_type(type) do
            # Convert empty string to nil for binary sensors
            {_id, %{unit: ""}} -> nil
            {_id, %{unit: unit}} -> unit
            _ -> nil
          end

        custom_unit ->
          custom_unit
      end

    measurement = %__MODULE__{
      type: type,
      value: value,
      unit: unit,
      object_id: Keyword.get(opts, :object_id)
    }

    case Validator.validate_measurement(measurement) do
      :ok -> {:ok, measurement}
      error -> error
    end
  end
end
