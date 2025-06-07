defmodule BTHome.DecodedData do
  @moduledoc """
  Struct representing decoded BTHome v2 data with type safety.

  This struct contains the complete result of deserializing a BTHome v2 binary payload.
  It includes protocol metadata and all decoded measurements.

  ## Fields

  - `:version` - BTHome protocol version (should be 2)
  - `:encrypted` - Whether the payload was encrypted
  - `:trigger_based` - Whether this is a trigger-based transmission
  - `:measurements` - List of decoded measurements as `BTHome.Measurement` structs
  - `:ciphertext` - Raw encrypted data (only present for encrypted payloads)
  - `:mac_reversed` - MAC address in reversed byte order (when available)
  - `:counter` - Encryption counter (only present for encrypted payloads)
  - `:mic` - Message integrity check (only present for encrypted payloads)

  ## Examples

      # Typical decoded data
      %BTHome.DecodedData{
        version: 2,
        encrypted: false,
        trigger_based: false,
        measurements: [
          %BTHome.Measurement{type: :temperature, value: 23.45, unit: "°C"},
          %BTHome.Measurement{type: :humidity, value: 67.8, unit: "%"}
        ]
      }
  """

  defstruct [
    :version,
    :encrypted,
    :trigger_based,
    :measurements,
    :ciphertext,
    :mac_reversed,
    :counter,
    :mic
  ]

  @type t :: %__MODULE__{
          version: integer(),
          encrypted: boolean(),
          trigger_based: boolean(),
          measurements: [BTHome.Measurement.t()],
          ciphertext: binary() | nil,
          mac_reversed: binary() | nil,
          counter: binary() | nil,
          mic: binary() | nil
        }
end
