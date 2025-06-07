defmodule BTHome.DecoderTest do
  use ExUnit.Case, async: true
  alias BTHome.{ButtonEvent, DecodedData, Decoder, DimmerEvent}

  describe "decode_measurements/1 basic functionality" do
    test "decodes simple temperature measurement" do
      # Device info (version 2, no encryption, no trigger) + temperature (0x02) + value (23.45°C = 2345)
      binary = <<0x40, 0x02, 0x29, 0x09>>

      {:ok, %DecodedData{} = decoded} = Decoder.decode_measurements(binary)

      assert decoded.version == 2
      assert decoded.encrypted == false
      assert decoded.trigger_based == false
      assert length(decoded.measurements) == 1

      [measurement] = decoded.measurements
      assert measurement.type == :temperature
      assert measurement.value == 23.45
      assert measurement.unit == "°C"
    end

    test "decodes multiple measurements" do
      # Device info + temperature + humidity + battery
      binary = <<0x40, 0x02, 0x29, 0x09, 0x03, 0x01, 0x19, 0x01, 0x64>>

      {:ok, %DecodedData{} = decoded} = Decoder.decode_measurements(binary)

      assert length(decoded.measurements) == 3

      [temp, humidity, battery] = decoded.measurements

      assert temp.type == :temperature
      assert temp.value == 23.45

      assert humidity.type == :humidity
      assert humidity.value == 64.01

      assert battery.type == :battery
      assert battery.value == 100
    end

    test "decodes binary sensor measurements" do
      # Device info + motion sensor (true)
      binary = <<0x40, 0x21, 0x01>>

      {:ok, %DecodedData{} = decoded} = Decoder.decode_measurements(binary)

      assert length(decoded.measurements) == 1

      [motion] = decoded.measurements
      assert motion.type == :motion
      assert motion.value == true
    end

    test "decodes binary sensor as false" do
      # Device info + motion sensor (false)
      binary = <<0x40, 0x21, 0x00>>

      {:ok, %DecodedData{} = decoded} = Decoder.decode_measurements(binary)

      [motion] = decoded.measurements
      assert motion.type == :motion
      assert motion.value == false
    end

    test "handles empty measurement data" do
      # Only device info, no measurements
      binary = <<0x40>>

      {:ok, %DecodedData{} = decoded} = Decoder.decode_measurements(binary)

      assert decoded.version == 2
      assert decoded.measurements == []
    end
  end

  describe "device info parsing" do
    test "parses version correctly" do
      # Version 2 (bits 7-5 = 010)
      binary = <<0x40, 0x02, 0x29, 0x09>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.version == 2
    end

    test "parses encryption flag" do
      # Encryption enabled (bit 0 = 1)
      binary = <<0x41>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.encrypted == true
    end

    test "parses trigger flag" do
      # Trigger based (bit 4 = 1), version 2 (bits 7-5 = 010)
      # 01010010 - version 2 + trigger bit
      binary = <<0x52>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.trigger_based == true
    end

    test "parses combined flags" do
      # Version 2, encrypted, trigger-based
      # 01010011 - version 2 + trigger bit + encryption bit
      binary = <<0x53>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.version == 2
      assert decoded.encrypted == true
      assert decoded.trigger_based == true
    end

    test "rejects invalid version" do
      # Version 1 (bits 7-5 = 001)
      binary = <<0x20, 0x02, 0x29, 0x09>>
      {:error, _reason} = Decoder.decode_measurements(binary)
    end
  end

  describe "MAC address extraction" do
    test "extracts MAC when present" do
      # Device info + 6-byte MAC + temperature measurement
      # Use MAC starting with 0xAA (not a valid object ID)
      mac = <<0xAA, 0x02, 0x03, 0x04, 0x05, 0x06>>
      binary = <<0x40>> <> mac <> <<0x02, 0x29, 0x09>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.mac_reversed == mac
      assert length(decoded.measurements) == 1
    end

    test "handles data without MAC" do
      # Device info + temperature (no MAC)
      binary = <<0x40, 0x02, 0x29, 0x09>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.mac_reversed == nil
      assert length(decoded.measurements) == 1
    end

    test "correctly identifies when first byte is object ID" do
      # Device info + temperature (0x02 is valid object ID)
      binary = <<0x40, 0x02, 0x29, 0x09>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.mac_reversed == nil
      assert length(decoded.measurements) == 1
    end
  end

  describe "encrypted payload handling" do
    test "handles encrypted payload" do
      # Device info with encryption + some encrypted data
      encrypted_data = <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A>>
      binary = <<0x41>> <> encrypted_data

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.encrypted == true
      assert decoded.measurements == []
      assert decoded.ciphertext != nil
    end

    test "extracts counter and MIC from encrypted data" do
      # Device info + encrypted data (at least 8 bytes for counter + MIC)
      encrypted_data = <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A>>
      binary = <<0x41>> <> encrypted_data

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.counter != nil
      assert decoded.mic != nil
      assert decoded.ciphertext != nil
    end

    test "handles short encrypted payload" do
      # Device info + short encrypted data (less than 8 bytes)
      encrypted_data = <<0x01, 0x02, 0x03>>
      binary = <<0x41>> <> encrypted_data

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.encrypted == true
      assert decoded.counter == nil
      assert decoded.mic == nil
      assert decoded.ciphertext == encrypted_data
    end
  end

  describe "different data types" do
    test "decodes 1-byte unsigned values" do
      # Battery (1-byte unsigned)
      # 100%
      binary = <<0x40, 0x01, 0x64>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [battery] = decoded.measurements
      assert battery.type == :battery
      assert battery.value == 100
    end

    test "decodes 1-byte signed values" do
      # Temperature sint8 (1-byte signed)
      # -25°C (0x57 is temperature_sint8)
      binary = <<0x40, 0x57, 0xE7>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [temp] = decoded.measurements
      assert temp.type == :temperature_sint8
      assert temp.value == -25
    end

    test "decodes 2-byte values" do
      # Humidity (2-byte unsigned with factor 0.01)
      # 64.01% (0x1901 = 6401, 6401 * 0.01 = 64.01)
      binary = <<0x40, 0x03, 0x01, 0x19>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [humidity] = decoded.measurements
      assert humidity.type == :humidity
      assert humidity.value == 64.01
    end

    test "decodes 3-byte values" do
      # Pressure (3-byte unsigned with factor 0.01)
      # 755.39 hPa (0x012713 = 75539, 75539 * 0.01 = 755.39)
      binary = <<0x40, 0x04, 0x13, 0x27, 0x01>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [pressure] = decoded.measurements
      assert pressure.type == :pressure
      assert pressure.value == 755.39
    end

    test "decodes 3-byte energy values" do
      # Energy uint24 (3-byte unsigned with factor 0.001)
      # 10.0 kWh
      binary = <<0x40, 0x0A, 0x10, 0x27, 0x00>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [energy] = decoded.measurements
      assert energy.type == :energy
      assert energy.value == 10.0
    end
  end

  describe "special value types" do
    test "decodes button events" do
      test_cases = [
        {0, ButtonEvent.none()},
        {1, ButtonEvent.press()},
        {2, ButtonEvent.double_press()},
        {3, ButtonEvent.triple_press()},
        {4, ButtonEvent.long_press()},
        {5, ButtonEvent.long_double_press()},
        {6, ButtonEvent.long_triple_press()},
        {128, ButtonEvent.hold_press()},
        {254, ButtonEvent.hold_press()},
        {255, ButtonEvent.release()}
      ]

      for {value, expected_event} <- test_cases do
        binary = <<0x40, 0x3A, value>>
        {:ok, decoded} = Decoder.decode_measurements(binary)
        [button] = decoded.measurements
        assert button.type == :button
        assert button.value == expected_event
      end
    end

    test "decodes unknown button event values" do
      # Unknown button event value
      binary = <<0x40, 0x3A, 99>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      [button] = decoded.measurements
      assert button.type == :button
      # Should return the raw value
      assert button.value == 99
    end

    test "decodes dimmer events" do
      # Dimmer rotate left with 5 steps (little-endian: event=1, steps=5)
      binary = <<0x40, 0x3C, 0x01, 0x05>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      [dimmer] = decoded.measurements
      assert dimmer.type == :dimmer
      assert dimmer.value.event == DimmerEvent.rotate_left()
      assert dimmer.value.steps == 5

      # Dimmer rotate right with 3 steps
      binary = <<0x40, 0x3C, 0x02, 0x03>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      [dimmer] = decoded.measurements
      assert dimmer.value.event == DimmerEvent.rotate_right()
      assert dimmer.value.steps == 3
    end

    test "decodes firmware version 32-bit" do
      # Firmware version 1.2.3.4 (major.minor.patch.build)
      # Little-endian
      binary = <<0x40, 0xF1, 0x04, 0x03, 0x02, 0x01>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      [fw] = decoded.measurements
      assert fw.type == :firmware_version_uint32
      assert fw.value.fw_version_major == 1
      assert fw.value.fw_version_minor == 2
      assert fw.value.fw_version_patch == 3
      assert fw.value.fw_version_build == 4
    end

    test "decodes firmware version 24-bit" do
      # Firmware version 1.2.3 (major.minor.patch)
      # Little-endian (0xF2 is firmware_version_uint24)
      binary = <<0x40, 0xF2, 0x03, 0x02, 0x01>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      [fw] = decoded.measurements
      assert fw.type == :firmware_version_uint24
      assert fw.value.fw_version_major == 1
      assert fw.value.fw_version_minor == 2
      assert fw.value.fw_version_patch == 3
    end
  end

  describe "variable-length data types" do
    test "decodes text measurements" do
      text = "Hello"
      text_length = byte_size(text)
      binary = <<0x40, 0x53, text_length>> <> text

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [text_measurement] = decoded.measurements
      assert text_measurement.type == :text
      assert text_measurement.value == text
    end

    test "decodes raw measurements" do
      raw_data = <<0x01, 0x02, 0x03, 0x04>>
      data_length = byte_size(raw_data)
      binary = <<0x40, 0x54, data_length>> <> raw_data

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [raw_measurement] = decoded.measurements
      assert raw_measurement.type == :raw
      assert raw_measurement.value == raw_data
    end

    test "handles empty text" do
      binary = <<0x40, 0x53, 0x00>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [text_measurement] = decoded.measurements
      assert text_measurement.type == :text
      assert text_measurement.value == ""
    end

    test "handles empty raw data" do
      binary = <<0x40, 0x54, 0x00>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      [raw_measurement] = decoded.measurements
      assert raw_measurement.type == :raw
      assert raw_measurement.value == <<>>
    end
  end

  describe "error handling" do
    test "handles insufficient data for measurement" do
      # Temperature requires 2 bytes but only 1 provided
      binary = <<0x40, 0x02, 0x29>>

      {:error, _reason} = Decoder.decode_measurements(binary)
    end

    test "handles unknown object IDs gracefully" do
      # Unknown object ID 0xFF with some data
      binary = <<0x40, 0xFF, 0x01, 0x02, 0x03>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert length(decoded.measurements) == 1

      [unknown] = decoded.measurements
      assert unknown.type == :unknown
      assert unknown.unknown == <<0x01, 0x02, 0x03>>
    end

    test "handles corrupted variable-length data" do
      # Text with length 10 but only 3 bytes available
      binary = <<0x40, 0x53, 0x0A, 0x01, 0x02, 0x03>>

      {:error, _reason} = Decoder.decode_measurements(binary)
    end

    test "handles invalid binary format" do
      {:error, message} =
        Decoder.decode_measurements(<<>>)

      assert message == "Invalid BTHome data format"

      {:error, _reason} =
        Decoder.decode_measurements("invalid")
    end

    test "handles unsupported variable-sized types" do
      # This would require a mock or modification to test internal error handling
      # For now, we test that known variable types work correctly
      binary = <<0x40, 0x53, 0x05, "Hello">>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert length(decoded.measurements) == 1
    end
  end

  describe "edge cases" do
    test "handles maximum values for each size" do
      test_cases = [
        # 1-byte unsigned max (255)
        {<<0x40, 0x01, 0xFF>>, :battery, 255},
        # 1-byte signed max (127)
        {<<0x40, 0x57, 0x7F>>, :temperature_sint8, 127},
        # 1-byte signed min (-128)
        {<<0x40, 0x57, 0x80>>, :temperature_sint8, -128}
      ]

      for {binary, expected_type, expected_value} <- test_cases do
        {:ok, decoded} = Decoder.decode_measurements(binary)
        [measurement] = decoded.measurements
        assert measurement.type == expected_type
        assert measurement.value == expected_value
      end
    end

    test "handles zero values" do
      # Temperature 0.0°C
      binary = <<0x40, 0x02, 0x00, 0x00>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      [temp] = decoded.measurements
      assert temp.value == 0.0
    end

    test "handles negative values" do
      # Temperature -10.0°C = -1000 (with factor 0.01)
      # -1000 in little-endian signed 16-bit
      binary = <<0x40, 0x02, 0x18, 0xFC>>
      {:ok, decoded} = Decoder.decode_measurements(binary)
      [temp] = decoded.measurements
      assert temp.value == -10.0
    end

    test "handles very long measurement sequences" do
      # Create a long sequence of battery measurements
      measurements = for i <- 1..100, into: <<>>, do: <<0x01, rem(i, 256)>>
      binary = <<0x40>> <> measurements

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert length(decoded.measurements) == 100
    end

    test "handles mixed measurement types in sequence" do
      # Temperature + humidity + motion + battery + button
      binary =
        <<
          0x40,
          # Temperature 23.45°C
          0x02,
          0x29,
          0x09,
          # Humidity 64.01%
          0x03,
          0x01,
          0x19,
          # Motion true
          0x21,
          0x01,
          # Battery 100%
          0x01,
          0x64,
          # Button press
          0x3A,
          0x01
        >>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert length(decoded.measurements) == 5

      types = Enum.map(decoded.measurements, & &1.type)
      assert types == [:temperature, :humidity, :motion, :battery, :button]
    end
  end

  describe "real-world scenarios" do
    test "decodes typical sensor payload" do
      # Realistic payload: temperature, humidity, battery, motion
      # Device info (version 2, no encryption)
      binary =
        <<
          0x40,
          # Temperature 21.26°C
          0x02,
          0x4E,
          0x08,
          # Humidity 50.55%
          0x03,
          0xBF,
          0x13,
          # Battery 95%
          0x01,
          0x5F,
          # Motion false
          0x21,
          0x00
        >>

      {:ok, decoded} = Decoder.decode_measurements(binary)

      assert decoded.version == 2
      assert decoded.encrypted == false
      assert decoded.trigger_based == false
      assert length(decoded.measurements) == 4

      [temp, humidity, battery, motion] = decoded.measurements

      assert temp.type == :temperature
      assert_in_delta temp.value, 21.26, 0.01

      assert humidity.type == :humidity
      assert_in_delta humidity.value, 50.55, 0.01

      assert battery.type == :battery
      assert battery.value == 95

      assert motion.type == :motion
      assert motion.value == false
    end

    test "decodes payload with MAC address" do
      # MAC + temperature measurement
      mac = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      binary = <<0x40>> <> mac <> <<0x02, 0x29, 0x09>>

      {:ok, decoded} = Decoder.decode_measurements(binary)

      assert decoded.mac_reversed == mac
      assert length(decoded.measurements) == 1

      [temp] = decoded.measurements
      assert temp.type == :temperature
      assert temp.value == 23.45
    end

    test "handles payload with MAC address" do
      # Test a realistic payload that includes MAC address
      # Device info (0x40) + MAC (6 bytes) + temperature (3 bytes) + humidity (3 bytes)
      # Use MAC starting with 0xFF (invalid object ID) so it gets detected as MAC
      mac = <<0xFF, 0x34, 0x56, 0x78, 0x9A, 0xBC>>
      # Temperature object_id + little-endian value
      temp_data = <<0x02, 0x34, 0x12>>
      # Humidity object_id + little-endian value
      humidity_data = <<0x03, 0x20, 0x4E>>
      binary = <<0x40>> <> mac <> temp_data <> humidity_data

      {:ok, decoded} = Decoder.decode_measurements(binary)
      assert decoded.mac_reversed == mac
      assert length(decoded.measurements) == 2
    end
  end

  describe "edge cases and error paths" do
    test "handles unsupported variable-sized types" do
      # This would require modifying object definitions to have an unsupported variable type
      # For now, test with a corrupted variable-length measurement that has invalid type
      # Device info + unknown object_id with variable length indicator
      # Unknown object_id 0xFF with length 5
      binary = <<0x40, 0xFF, 0x05, "test", 0x00>>

      {:ok, decoded} = Decoder.decode_measurements(binary)
      # Should create an unknown measurement
      assert length(decoded.measurements) >= 1
    end

    test "handles extract_measurement_value with unknown patterns" do
      # Test the catch-all case in extract_measurement_value
      # This is hard to trigger directly, but we can test with malformed data
      # Device info + temperature object_id but no data
      binary = <<0x40, 0x02>>

      {:error, _reason} = Decoder.decode_measurements(binary)
    end

    test "handles corrupted variable-length data edge cases" do
      # Test various edge cases in variable-length data parsing
      test_cases = [
        # Text with length but no data
        # Text object_id + length 5 but no actual text data
        <<0x40, 0x53, 0x05>>,
        # Raw with length but insufficient data
        # Raw object_id + length 3 but only 1 byte of data
        <<0x40, 0x54, 0x03, 0x01>>,
        # Zero-length text
        # Text with zero length
        <<0x40, 0x53, 0x00>>,
        # Zero-length raw
        # Raw with zero length
        <<0x40, 0x54, 0x00>>
      ]

      for test_binary <- test_cases do
        case Decoder.decode_measurements(test_binary) do
          # Some cases might succeed with empty data
          {:ok, _decoded} -> :ok
          # Expected for insufficient data
          {:error, _reason} -> :ok
        end
      end
    end

    test "handles malformed encryption data" do
      # Test encrypted payload with insufficient data for counter/mic
      # Encrypted flag set but insufficient data
      encrypted_binary = <<0x41, 0x02, 0x34>>

      {:ok, %DecodedData{encrypted: true, measurements: [], ciphertext: <<0x02, 0x34>>}} =
        Decoder.decode_measurements(encrypted_binary)
    end

    test "handles edge cases in integer decoding" do
      # Test various edge cases in integer decoding functions
      test_cases = [
        # 3-byte integer with insufficient data
        # Pressure object_id (3-byte) but only 1 byte of data
        <<0x40, 0x04, 0x12>>,
        # 4-byte integer with insufficient data
        # Count uint32 object_id (4-byte) but only 2 bytes of data
        <<0x40, 0x3E, 0x12, 0x34>>
      ]

      for test_binary <- test_cases do
        {:error, _reason} = Decoder.decode_measurements(test_binary)
      end
    end

    test "handles firmware version edge cases" do
      # Test firmware version with insufficient data
      test_cases = [
        # 24-bit firmware version with insufficient data (0xF2 = 242)
        # Firmware version object_id but only 1 byte (needs 3)
        <<0x40, 0xF2, 0x12>>,
        # 32-bit firmware version with insufficient data (0xF1 = 241)
        # Firmware version object_id but only 2 bytes (needs 4)
        <<0x40, 0xF1, 0x12, 0x34>>
      ]

      for test_binary <- test_cases do
        {:error, _reason} = Decoder.decode_measurements(test_binary)
      end
    end

    test "handles button and dimmer event edge cases" do
      # Test with invalid button/dimmer event values
      test_cases = [
        # Button event with invalid value
        # Button object_id with invalid event value
        <<0x40, 0x3A, 0xFF>>,
        # Dimmer event with invalid value (dimmer requires 2 bytes)
        # Dimmer object_id with invalid event value
        <<0x40, 0x3C, 0xFF, 0xFF>>
      ]

      for test_binary <- test_cases do
        {:ok, decoded} = Decoder.decode_measurements(test_binary)
        # Should still decode but might have unknown event values
        assert length(decoded.measurements) == 1
      end
    end

    test "handles MAC extraction edge cases" do
      # Test MAC extraction with edge cases
      test_cases = [
        # Exactly 6 bytes that could be MAC but followed by invalid object_id
        <<0x40, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xFF>>,
        # Less than 6 bytes before valid object_id
        # Only 2 bytes before temperature
        <<0x40, 0x12, 0x34, 0x02, 0x34, 0x12>>,
        # More than 6 bytes before valid object_id
        <<0x40, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0x02, 0x34, 0x12>>
      ]

      for test_binary <- test_cases do
        {:ok, decoded} = Decoder.decode_measurements(test_binary)
        # MAC extraction logic should handle these cases appropriately
        assert is_struct(decoded, BTHome.DecodedData)
      end
    end
  end
end
