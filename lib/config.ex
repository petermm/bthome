defmodule BTHome.Config do
  @moduledoc """
  Configuration constants for BTHome v2 protocol.

  This module centralizes all magic numbers, protocol-specific values, and configuration
  constants used throughout the BTHome v2 implementation. By keeping these values in one
  place, we ensure consistency and make the codebase easier to maintain.

  ## Constants

  - `version/0` - BTHome protocol version (2)
  - `version_mask/0` - Bitmask for extracting version from device info (0xE0)
  - `version_shift/0` - Bit shift for version extraction (5)
  - `trigger_mask/0` - Bitmask for trigger-based flag (0x10)
  - `encryption_mask/0` - Bitmask for encryption flag (0x01)
  - `max_skip_bytes/0` - Maximum bytes to skip when recovering from unknown data (10)
  - `device_info_base/0` - Base value for device info byte (0x40)

  ## Examples

      iex> BTHome.Config.version()
      2

      iex> BTHome.Config.version_mask()
      224  # 0xE0
  """

  @bthome_version 2
  @version_mask 0xE0
  @version_shift 5
  @trigger_mask 0x10
  @encryption_mask 0x01
  @max_skip_bytes 10
  @device_info_base 0x40

  def version, do: @bthome_version
  def version_mask, do: @version_mask
  def version_shift, do: @version_shift
  def trigger_mask, do: @trigger_mask
  def encryption_mask, do: @encryption_mask
  def max_skip_bytes, do: @max_skip_bytes
  def device_info_base, do: @device_info_base
end
