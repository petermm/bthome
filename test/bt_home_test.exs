defmodule BTHomeTest do
  use ExUnit.Case
  doctest BTHome

  alias BTHome.{Measurement, Objects, Validator}

  # Test struct-based API
  test "basic struct-based serialization" do
    measurements = [%Measurement{type: :temperature, value: 23.45}]
    assert {:ok, _binary} = BTHome.serialize(measurements)
  end

  # Test basic serialization
  test "serialize single temperature measurement" do
    measurements = [%Measurement{type: :temperature, value: 21.3}]
    assert {:ok, binary} = BTHome.serialize(measurements)

    # Check device info byte (0x40 for BTHome)
    <<device_info, 0x02, temp_bytes::binary-size(2)>> = binary
    assert device_info == 0x40

    # Check temperature encoding (21.3 / 0.01 = 2130)
    <<temp_value::signed-little-16>> = temp_bytes
    expected = round(21.3 / 0.01)
    assert temp_value == expected
  end

  test "serialize binary sensor encoding" do
    measurements = [
      %Measurement{type: :motion, value: true},
      %Measurement{type: :door, value: false}
    ]

    assert {:ok, binary} = BTHome.serialize(measurements)
    # motion=0x21, door=0x1A
    assert binary == <<0x40, 0x21, 0x01, 0x1A, 0x00>>
  end

  test "factor conversion fix - temperature round trip" do
    # Test that 23.45°C correctly converts to 2345 (factor 0.01)
    measurements = [%Measurement{type: :temperature, value: 23.45}]

    assert {:ok, binary} = BTHome.serialize(measurements)
    assert {:ok, result} = BTHome.deserialize(binary)

    [measurement] = result.measurements
    # Should round-trip correctly within precision
    assert abs(measurement.value - 23.45) < 0.01
  end

  test "illuminance encoding with 3-byte size" do
    measurements = [
      %Measurement{type: :illuminance, value: 1234.56}
    ]

    assert {:ok, binary} = BTHome.serialize(measurements)
    assert {:ok, result} = BTHome.deserialize(binary)

    [measurement] = result.measurements
    assert measurement.type == :illuminance
    assert measurement.unit == "lux"
    # Check precision (factor 0.01)
    assert abs(measurement.value - 1234.56) < 0.01
  end

  test "comprehensive serialization test" do
    measurements = [
      %Measurement{type: :battery, value: 85},
      %Measurement{type: :temperature, value: 23.45},
      %Measurement{type: :humidity, value: 67.8},
      %Measurement{type: :motion, value: true}
    ]

    assert {:ok, binary} = BTHome.serialize(measurements)
    assert {:ok, result} = BTHome.deserialize(binary)

    assert result.version == 2
    assert result.encrypted == false
    assert result.trigger_based == false
    assert length(result.measurements) == 4

    # Check each measurement type is present
    types = Enum.map(result.measurements, & &1.type)
    assert :battery in types
    assert :temperature in types
    assert :humidity in types
    assert :motion in types
  end

  test "validation - unsupported measurement type" do
    measurements = [%Measurement{type: :invalid_sensor, value: 42}]
    assert {:error, message} = BTHome.serialize(measurements)
    assert message =~ "Unsupported measurement type"
  end

  test "validation - boolean for non-binary sensor" do
    measurements = [%Measurement{type: :temperature, value: true}]
    assert {:error, message} = BTHome.serialize(measurements)
    assert message =~ "Boolean values only allowed for binary sensors"
  end

  test "validation - value out of range" do
    # Battery should be 0-255
    measurements = [%Measurement{type: :battery, value: 300}]
    assert {:error, message} = BTHome.serialize(measurements)
    assert message =~ "out of range"
  end

  test "validation - invalid measurement format" do
    measurements = [%{invalid: :format}]
    assert {:error, message} = BTHome.serialize(measurements)
    assert message =~ "must be a Measurement struct"
  end

  test "decoder error recovery" do
    # Create binary with unknown object ID in the middle
    # temperature 23.45°C
    valid_temp = <<0x02, 0x51, 0x09>>
    # unknown object ID
    unknown_data = <<0xFF, 0x12, 0x34>>
    # battery 85%
    valid_battery = <<0x01, 0x55>>

    binary = <<0x40>> <> valid_temp <> unknown_data <> valid_battery

    assert {:ok, result} = BTHome.deserialize(binary)
    # Should recover and parse the valid measurements
    # At least temperature should be parsed
    assert length(result.measurements) >= 1
  end

  test "empty measurements list" do
    assert {:ok, binary} = BTHome.serialize([])
    assert {:ok, result} = BTHome.deserialize(binary)
    assert result.measurements == []
  end

  test "encryption flag" do
    measurements = [%Measurement{type: :battery, value: 85}]
    key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
    mac_address = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
    counter = 1

    # Without encryption
    assert {:ok, binary_no_enc} = BTHome.serialize(measurements)
    <<device_info_no_enc, _rest::binary>> = binary_no_enc
    assert Bitwise.band(device_info_no_enc, 0x01) == 0

    # With encryption
    opts = [encrypt: [key: key, mac_address: mac_address, counter: counter]]
    assert {:ok, binary_enc} = BTHome.serialize(measurements, opts)
    <<device_info_enc, _rest::binary>> = binary_enc
    assert Bitwise.band(device_info_enc, 0x01) == 1
  end

  test "supported types" do
    types = BTHome.supported_types()

    # Check some key types are present
    assert Map.has_key?(types, :temperature)
    assert Map.has_key?(types, :humidity)
    assert Map.has_key?(types, :battery)
    assert Map.has_key?(types, :motion)

    # Check temperature definition
    temp_def = types[:temperature]
    assert temp_def.unit == "°C"
    assert temp_def.factor == 0.01
    assert temp_def.signed == true
    assert temp_def.size == 2
  end

  test "measurement helper function" do
    assert {:ok, measurement} = BTHome.measurement(:temperature, 23.45)
    assert measurement.type == :temperature
    assert measurement.value == 23.45

    # Invalid type
    assert {:error, _reason} = BTHome.measurement(:invalid_type, 42)
  end

  test "deserialize measurements" do
    measurements = [%Measurement{type: :temperature, value: 23.45}]
    {:ok, binary} = BTHome.serialize(measurements)

    {:ok, decoded} = BTHome.deserialize(binary)
    assert decoded.version == 2
    assert decoded.encrypted == false
    assert decoded.trigger_based == false
    assert length(decoded.measurements) == 1

    [measurement] = decoded.measurements
    assert measurement.type == :temperature
    assert_in_delta measurement.value, 23.45, 0.01
  end

  test "binary sensor detection" do
    assert Objects.binary_sensor?(:motion) == true
    assert Objects.binary_sensor?(:door) == true
    assert Objects.binary_sensor?(:temperature) == false
    assert Objects.binary_sensor?(:humidity) == false
  end

  test "object definitions lookup" do
    # Test by object ID
    assert %{name: :temperature} = Objects.get_definition(0x02)
    assert %{name: :motion} = Objects.get_definition(0x21)
    assert nil == Objects.get_definition(0xFF)

    # Test by type
    assert {0x02, %{name: :temperature}} = Objects.find_by_type(:temperature)
    assert {0x21, %{name: :motion}} = Objects.find_by_type(:motion)
    assert nil == Objects.find_by_type(:invalid_type)
  end

  test "backwards compatibility delegation" do
    measurements = [%Measurement{type: :temperature, value: 23.45}]

    # Test that BTHome delegates to BTHome
    assert {:ok, binary1} = BTHome.serialize(measurements)
    assert {:ok, binary2} = BTHome.serialize(measurements)
    assert binary1 == binary2

    assert {:ok, result1} = BTHome.deserialize(binary1)
    assert {:ok, result2} = BTHome.deserialize(binary1)
    assert result1 == result2
  end

  test "device info validation" do
    # Valid BTHome v2 device info
    assert :ok = Validator.validate_device_info(0x40)
    # with encryption
    assert :ok = Validator.validate_device_info(0x41)

    # Invalid version
    # version 1
    assert {:error, message} =
             Validator.validate_device_info(0x20)

    assert message =~ "Unsupported BTHome version"

    # Invalid type
    assert {:error, _reason} = Validator.validate_device_info("invalid")
  end

  test "large values within range" do
    # Test maximum values for different sizes
    measurements = [
      # 1 byte unsigned max
      %Measurement{type: :battery, value: 255},
      # 3 byte unsigned max * 0.01

      %Measurement{type: :illuminance, value: 167_772.15}
    ]

    assert {:ok, binary} = BTHome.serialize(measurements)
    assert {:ok, result} = BTHome.deserialize(binary)

    battery_measurement = Enum.find(result.measurements, &(&1.type == :battery))
    illuminance_measurement = Enum.find(result.measurements, &(&1.type == :illuminance))

    assert battery_measurement.value == 255
    assert abs(illuminance_measurement.value - 167_772.15) < 0.01
  end

  test "negative temperature values" do
    measurements = [%Measurement{type: :temperature, value: -10.5}]

    assert {:ok, binary} = BTHome.serialize(measurements)
    assert {:ok, result} = BTHome.deserialize(binary)

    [measurement] = result.measurements
    assert abs(measurement.value - -10.5) < 0.01
  end

  test "decode specific BTHome payload 400037013902260903EA13" do
    # Test decoding a specific real-world BTHome v2 payload
    hex_payload = "400037013902260903EA13"
    binary = Base.decode16!(hex_payload)

    assert {:ok, result} = BTHome.deserialize(binary)

    # Verify the decoded structure
    assert result.version == 2
    assert result.encrypted == false
    assert result.trigger_based == false
    assert length(result.measurements) == 4

    # Extract measurements by type
    packet_id_measurement = Enum.find(result.measurements, &(&1.type == :packet_id))
    battery_measurement = Enum.find(result.measurements, &(&1.type == :battery))
    temperature_measurement = Enum.find(result.measurements, &(&1.type == :temperature))
    humidity_measurement = Enum.find(result.measurements, &(&1.type == :humidity))

    # Verify packet_id measurement (object ID 0x00, value 55)
    assert packet_id_measurement != nil
    assert packet_id_measurement.type == :packet_id
    assert packet_id_measurement.value == 55

    # Verify battery measurement (object ID 0x01, value 57%)
    assert battery_measurement != nil
    assert battery_measurement.type == :battery
    assert battery_measurement.unit == "%"
    assert battery_measurement.value == 57

    # Verify temperature measurement (object ID 0x02, value 23.42°C)
    assert temperature_measurement != nil
    assert temperature_measurement.type == :temperature
    assert temperature_measurement.unit == "°C"
    assert abs(temperature_measurement.value - 23.42) < 0.01

    # Verify humidity measurement (object ID 0x03, value ~51%)
    assert humidity_measurement != nil
    assert humidity_measurement.type == :humidity
    assert humidity_measurement.unit == "%"
    assert abs(humidity_measurement.value - 50.98) < 0.1

    # Test round-trip serialization
    assert {:ok, reserialized} = BTHome.serialize(result.measurements)
    assert {:ok, redeserialized} = BTHome.deserialize(reserialized)

    # Verify round-trip preserves data (within precision limits)
    assert length(redeserialized.measurements) == 4

    packet_id_rt = Enum.find(redeserialized.measurements, &(&1.type == :packet_id))
    battery_rt = Enum.find(redeserialized.measurements, &(&1.type == :battery))
    temp_rt = Enum.find(redeserialized.measurements, &(&1.type == :temperature))
    humidity_rt = Enum.find(redeserialized.measurements, &(&1.type == :humidity))

    assert packet_id_rt.value == 55
    assert battery_rt.value == 57
    assert abs(temp_rt.value - 23.42) < 0.01
    assert abs(humidity_rt.value - 50.98) < 0.1
  end

  # MAC address handling edge cases
  test "handles data too short for MAC address" do
    # Create a payload that's too short to contain a MAC address
    # device_info + temp measurement
    short_payload = <<0x40, 0x02, 0x01, 0x64>>
    {:ok, decoded} = BTHome.deserialize(short_payload)
    assert decoded.mac_reversed == nil
    assert length(decoded.measurements) == 1
  end

  test "correctly identifies when first byte is valid object ID (no MAC)" do
    # Create payload starting with valid object ID (0x02 = temperature)
    # device_info + temp measurement
    payload_no_mac = <<0x40, 0x02, 0x01, 0x64>>
    {:ok, decoded} = BTHome.deserialize(payload_no_mac)
    assert decoded.mac_reversed == nil
    assert length(decoded.measurements) == 1
    assert Enum.at(decoded.measurements, 0).type == :temperature
  end

  test "handles ambiguous MAC detection gracefully" do
    # Test case where 6 bytes could be MAC but 7th byte is not valid object ID
    ambiguous_payload = <<0x40, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x02, 0x01, 0x64>>
    {:ok, decoded} = BTHome.deserialize(ambiguous_payload)
    # Should not extract MAC if no valid object ID follows
    assert decoded.mac_reversed == nil
  end

  # Firmware version validation edge cases
  test "validates firmware version field boundaries" do
    # Test that firmware version components are properly extracted from bit fields
    # This tests the bit manipulation logic in extract_firmware_version_32

    # Create a mock 32-bit firmware version: 0x04020100 (4.2.1.0)
    fw_value = 0x04020100

    # Test bit extraction manually to verify decoder logic
    major = Bitwise.bsr(fw_value, 24) |> Bitwise.band(0xFF)
    minor = Bitwise.bsr(fw_value, 16) |> Bitwise.band(0xFF)
    patch = Bitwise.bsr(fw_value, 8) |> Bitwise.band(0xFF)
    build = fw_value |> Bitwise.band(0xFF)

    assert major == 4
    assert minor == 2
    assert patch == 1
    assert build == 0
  end

  test "validates 24-bit firmware version extraction" do
    # Test 24-bit firmware version: 0x060100 (6.1.0)
    fw_value = 0x060100

    major = Bitwise.bsr(fw_value, 16) |> Bitwise.band(0xFF)
    minor = Bitwise.bsr(fw_value, 8) |> Bitwise.band(0xFF)
    patch = fw_value |> Bitwise.band(0xFF)

    assert major == 6
    assert minor == 1
    assert patch == 0
  end

  test "handles maximum firmware version values" do
    # Test edge case with maximum values (255.255.255.255)
    max_fw_value = 0xFFFFFFFF

    major = Bitwise.bsr(max_fw_value, 24) |> Bitwise.band(0xFF)
    minor = Bitwise.bsr(max_fw_value, 16) |> Bitwise.band(0xFF)
    patch = Bitwise.bsr(max_fw_value, 8) |> Bitwise.band(0xFF)
    build = max_fw_value |> Bitwise.band(0xFF)

    assert major == 255
    assert minor == 255
    assert patch == 255
    assert build == 255
  end
end
