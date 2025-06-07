defmodule BTHome.ConfigTest do
  use ExUnit.Case, async: true
  doctest BTHome.Config
  import Bitwise

  alias BTHome.Config

  describe "version constants" do
    test "returns correct BTHome version" do
      assert Config.version() == 2
    end

    test "returns correct version mask" do
      assert Config.version_mask() == 0xE0
      assert Config.version_mask() == 224
    end

    test "returns correct version shift" do
      assert Config.version_shift() == 5
    end
  end

  describe "flag masks" do
    test "returns correct trigger mask" do
      assert Config.trigger_mask() == 0x10
      assert Config.trigger_mask() == 16
    end

    test "returns correct encryption mask" do
      assert Config.encryption_mask() == 0x01
      assert Config.encryption_mask() == 1
    end
  end

  describe "protocol constants" do
    test "returns correct max skip bytes" do
      assert Config.max_skip_bytes() == 10
    end

    test "returns correct device info base" do
      assert Config.device_info_base() == 0x40
      assert Config.device_info_base() == 64
    end
  end

  describe "constant consistency" do
    test "version mask and shift work together correctly" do
      # Test that version extraction works with the mask and shift
      # Version 2 (010) in bits 7-5
      device_info = 0x40
      version = (device_info &&& Config.version_mask()) >>> Config.version_shift()
      assert version == Config.version()
    end

    test "all masks are non-overlapping for device info byte" do
      # Ensure version, trigger, and encryption masks don't overlap
      version_mask = Config.version_mask()
      trigger_mask = Config.trigger_mask()
      encryption_mask = Config.encryption_mask()

      # No overlap between version and trigger
      assert (version_mask &&& trigger_mask) == 0
      # No overlap between version and encryption
      assert (version_mask &&& encryption_mask) == 0
      # No overlap between trigger and encryption
      assert (trigger_mask &&& encryption_mask) == 0
    end

    test "device info base has correct version bits" do
      # Device info base should have version 2 encoded
      base = Config.device_info_base()
      version = (base &&& Config.version_mask()) >>> Config.version_shift()
      assert version == Config.version()
    end

    test "device info base has no flags set" do
      # Base should not have trigger or encryption flags set
      base = Config.device_info_base()
      assert (base &&& Config.trigger_mask()) == 0
      assert (base &&& Config.encryption_mask()) == 0
    end
  end

  describe "bit manipulation validation" do
    test "version mask covers exactly 3 bits" do
      # Version should use exactly bits 7, 6, 5
      mask = Config.version_mask()
      assert mask == 0b11100000

      # Count set bits
      bit_count = mask |> Integer.to_string(2) |> String.graphemes() |> Enum.count(&(&1 == "1"))
      assert bit_count == 3
    end

    test "trigger mask covers exactly 1 bit" do
      # Trigger should use exactly bit 4
      mask = Config.trigger_mask()
      assert mask == 0b00010000

      # Count set bits
      bit_count = mask |> Integer.to_string(2) |> String.graphemes() |> Enum.count(&(&1 == "1"))
      assert bit_count == 1
    end

    test "encryption mask covers exactly 1 bit" do
      # Encryption should use exactly bit 0
      mask = Config.encryption_mask()
      assert mask == 0b00000001

      # Count set bits
      bit_count = mask |> Integer.to_string(2) |> String.graphemes() |> Enum.count(&(&1 == "1"))
      assert bit_count == 1
    end

    test "version shift matches version mask position" do
      # The shift should position the version bits correctly
      shift = Config.version_shift()
      mask = Config.version_mask()

      # The mask should start at the shift position
      expected_mask = 0b111 <<< shift
      assert mask == expected_mask
    end
  end

  describe "protocol limits" do
    test "max skip bytes is reasonable" do
      # Should be a reasonable limit for error recovery
      max_skip = Config.max_skip_bytes()
      assert max_skip > 0
      # Should fit in a byte
      assert max_skip <= 255
      # Should be at least a few bytes
      assert max_skip >= 5
    end

    test "version is within valid range" do
      # BTHome version should be reasonable
      version = Config.version()
      assert version > 0
      # 3 bits can represent 0-7
      assert version <= 7
    end
  end

  describe "function return types" do
    test "all functions return integers" do
      assert is_integer(Config.version())
      assert is_integer(Config.version_mask())
      assert is_integer(Config.version_shift())
      assert is_integer(Config.trigger_mask())
      assert is_integer(Config.encryption_mask())
      assert is_integer(Config.max_skip_bytes())
      assert is_integer(Config.device_info_base())
    end

    test "all functions return non-negative integers" do
      assert Config.version() >= 0
      assert Config.version_mask() >= 0
      assert Config.version_shift() >= 0
      assert Config.trigger_mask() >= 0
      assert Config.encryption_mask() >= 0
      assert Config.max_skip_bytes() >= 0
      assert Config.device_info_base() >= 0
    end

    test "all mask values fit in a byte" do
      assert Config.version_mask() <= 255
      assert Config.trigger_mask() <= 255
      assert Config.encryption_mask() <= 255
      assert Config.device_info_base() <= 255
    end
  end

  describe "real-world usage scenarios" do
    test "can build device info byte with all flags" do
      # Test building a complete device info byte
      base = Config.device_info_base()
      with_trigger = Bitwise.bor(base, Config.trigger_mask())
      with_encryption = Bitwise.bor(base, Config.encryption_mask())

      with_both =
        base |> Bitwise.bor(Config.trigger_mask()) |> Bitwise.bor(Config.encryption_mask())

      # All should be valid bytes
      assert with_trigger <= 255
      assert with_encryption <= 255
      assert with_both <= 255

      # Version should be preserved
      for device_info <- [base, with_trigger, with_encryption, with_both] do
        version = (device_info &&& Config.version_mask()) >>> Config.version_shift()
        assert version == Config.version()
      end
    end

    test "can extract flags from device info byte" do
      # Test flag extraction
      device_info =
        Config.device_info_base()
        |> Bitwise.bor(Config.trigger_mask())
        |> Bitwise.bor(Config.encryption_mask())

      trigger_set = (device_info &&& Config.trigger_mask()) != 0
      encryption_set = (device_info &&& Config.encryption_mask()) != 0

      assert trigger_set
      assert encryption_set
    end
  end
end
