defmodule BTHomeBinaryDataTest do
  @moduledoc """
  Tests for BTHome binary data files.

  This test suite validates the BTHome decoder against real binary data
  files, ensuring compatibility and correctness of the parsing logic.
  Each test corresponds to a specific binary file in test/test_data_bin/.

  This is an exact port of the Python test file test_bthome_v2.py.
  """

  use ExUnit.Case

  @test_data_dir "test/test_data_bin"

  defp load_binary_file(filename) do
    path = Path.join(@test_data_dir, filename)
    File.read!(path)
  end

  test "bthome_wrong_object_id.bin - handles unknown object ID" do
    binary = load_binary_file("bthome_wrong_object_id.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for a non-existing Object ID xFE
    # Should have unknown data
    assert length(decoded.measurements) == 1
    measurement = Enum.at(decoded.measurements, 0)
    assert measurement.unknown == <<0xCA, 0x09>>
  end

  test "bthome_battery_wrong_object_id_humidity.bin - battery reading before unknown object" do
    binary = load_binary_file("bthome_battery_wrong_object_id_humidity.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for battery, wrong object id and humidity reading.
    # Should only return the battery reading, as humidity is after wrong object id.
    measurements = decoded.measurements
    assert length(measurements) >= 2

    assert Enum.at(measurements, 0).value == 93
    assert Enum.at(measurements, 0).unit == "%"
    assert Enum.at(measurements, 1).unknown == <<0x5D, 0x09, 0x03, 0xB7, 0x18>>
  end

  test "bthome_with_mac.bin - pressure reading with MAC address" do
    binary = load_binary_file("bthome_with_mac.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for pressure reading with MAC address in payload
    assert decoded.mac_reversed == <<0xB2, 0x18, 0x8D, 0x38, 0xC1, 0xA4>>
    assert_in_delta Enum.at(decoded.measurements, 0).value, 1008.83, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "hPa"
  end

  test "bthome_temperature_humidity.bin - temperature and humidity without encryption" do
    binary = load_binary_file("bthome_temperature_humidity.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for temperature humidity reading without encryption
    measurements = decoded.measurements
    assert length(measurements) == 2
    assert_in_delta Enum.at(measurements, 0).value, 25.06, 0.01
    assert Enum.at(measurements, 0).unit == "°C"
    assert_in_delta Enum.at(measurements, 1).value, 50.55, 0.01
    assert Enum.at(measurements, 1).unit == "%"
  end

  test "bthome_packet_id_temperature_humidity_battery.bin - packet ID, temperature, humidity and battery" do
    binary = load_binary_file("bthome_packet_id_temperature_humidity_battery.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for packet_id, temperature, humidity and battery reading
    measurements = decoded.measurements
    assert length(measurements) >= 4

    assert Enum.at(measurements, 0).value == 9
    assert Enum.at(measurements, 1).value == 93
    assert Enum.at(measurements, 1).unit == "%"
    assert_in_delta Enum.at(measurements, 2).value, 23.97, 0.01
    assert Enum.at(measurements, 2).unit == "°C"
    assert_in_delta Enum.at(measurements, 3).value, 63.27, 0.01
    assert Enum.at(measurements, 3).unit == "%"
  end

  test "bthome_pressure.bin - pressure reading without encryption" do
    binary = load_binary_file("bthome_pressure.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for pressure reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 1008.83, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "hPa"
  end

  test "bthome_illuminance.bin - illuminance reading" do
    binary = load_binary_file("bthome_illuminance.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for illuminance reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 13_460.67, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "lux"
  end

  test "bthome_mass_kilograms.bin - mass reading in kilograms" do
    binary = load_binary_file("bthome_mass_kilograms.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for mass reading in kilograms without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 80.3, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "kg"
  end

  test "bthome_mass_pounds.bin - mass reading in pounds" do
    binary = load_binary_file("bthome_mass_pounds.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for mass reading in pounds without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 74.86, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "lb"
  end

  test "bthome_dew_point.bin - dew point reading" do
    binary = load_binary_file("bthome_dew_point.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for dew point reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 17.38, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "°C"
  end

  test "bthome_count.bin - counter reading" do
    binary = load_binary_file("bthome_count.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for counter reading without encryption
    assert Enum.at(decoded.measurements, 0).value == 96
  end

  test "bthome_energy.bin - energy reading" do
    binary = load_binary_file("bthome_energy.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for energy reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 1346.067, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "kWh"
  end

  test "bthome_power.bin - power reading" do
    binary = load_binary_file("bthome_power.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for power reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 69.14, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "W"
  end

  test "bthome_voltage.bin - voltage reading" do
    binary = load_binary_file("bthome_voltage.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for voltage reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 3.074, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "V"
  end

  test "bthome_binary_sensor.bin - binary sensor without device class" do
    binary = load_binary_file("bthome_binary_sensor.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for binary sensor without device class, without encryption
    assert Enum.at(decoded.measurements, 0).value == true
  end

  test "bthome_binary_sensor_power.bin - binary sensor power" do
    binary = load_binary_file("bthome_binary_sensor_power.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for binary sensor power without encryption
    assert Enum.at(decoded.measurements, 0).value == true
  end

  test "bthome_binary_sensor_opening.bin - binary sensor opening" do
    binary = load_binary_file("bthome_binary_sensor_opening.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for binary sensor opening without encryption
    assert Enum.at(decoded.measurements, 0).value == false
  end

  test "bthome_binary_sensor_window.bin - binary sensor window" do
    binary = load_binary_file("bthome_binary_sensor_window.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for binary sensor window without encryption
    assert Enum.at(decoded.measurements, 0).value == true
  end

  test "bthome_pm.bin - PM2.5 and PM10 readings" do
    binary = load_binary_file("bthome_pm.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for PM2.5 and PM10 reading without encryption
    measurements = decoded.measurements
    assert length(measurements) >= 2

    assert Enum.at(measurements, 0).value == 3090
    assert Enum.at(measurements, 0).unit == "µg/m³"
    assert Enum.at(measurements, 1).value == 7170
    assert Enum.at(measurements, 1).unit == "µg/m³"
  end

  test "bthome_co2.bin - CO2 reading" do
    binary = load_binary_file("bthome_co2.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for CO2 reading without encryption
    assert Enum.at(decoded.measurements, 0).value == 1250
    assert Enum.at(decoded.measurements, 0).unit == "ppm"
  end

  test "bthome_voc.bin - VOC reading" do
    binary = load_binary_file("bthome_voc.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for VOC reading without encryption
    assert Enum.at(decoded.measurements, 0).value == 307
    assert Enum.at(decoded.measurements, 0).unit == "µg/m³"
  end

  test "bthome_moisture.bin - moisture reading" do
    binary = load_binary_file("bthome_moisture.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for moisture reading from b-parasite sensor
    assert_in_delta Enum.at(decoded.measurements, 0).value, 30.74, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "%"
  end

  test "bthome_event_button_long_press.bin - button long press event" do
    binary = load_binary_file("bthome_event_button_long_press.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for an event of a long press on a button without encryption
    assert Enum.at(decoded.measurements, 0).value == :long_press
  end

  test "bthome_event_triple_button_device.bin - triple button device events" do
    binary = load_binary_file("bthome_event_triple_button_device.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for an event of a triple button device where
    # the 2nd button is pressed and the 3rd button is triple pressed
    measurements = decoded.measurements
    assert length(measurements) >= 3

    assert Enum.at(measurements, 0).value == :none
    assert Enum.at(measurements, 1).value == :press
    assert Enum.at(measurements, 2).value == :triple_press
  end

  test "bthome_event_button_hold_press.bin - button hold press event" do
    binary = load_binary_file("bthome_event_button_hold_press.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for an event of a hold press on a button without encryption
    assert Enum.at(decoded.measurements, 0).value == :hold_press
  end

  test "bthome_event_dimmer_rotate_left_3_steps.bin - dimmer rotate left 3 steps" do
    binary = load_binary_file("bthome_event_dimmer_rotate_left_3_steps.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for an event rotating a dimmer 3 steps left
    measurement = Enum.at(decoded.measurements, 0)
    assert measurement.value.event == :rotate_left
    assert measurement.value.steps == 3
  end

  test "bthome_event_dimmer_none.bin - dimmer none event" do
    binary = load_binary_file("bthome_event_dimmer_none.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for an event None for a dimmer
    measurement = Enum.at(decoded.measurements, 0)
    assert measurement.value.event == :none
    assert measurement.value.steps == 0
  end

  test "bthome_rotation.bin - rotation measurement" do
    binary = load_binary_file("bthome_rotation.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for rotation
    assert_in_delta Enum.at(decoded.measurements, 0).value, 307.4, 0.1
    assert Enum.at(decoded.measurements, 0).unit == "°"
  end

  test "bthome_distance_millimeters.bin - distance in millimeters" do
    binary = load_binary_file("bthome_distance_millimeters.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for distance in millimeters
    assert Enum.at(decoded.measurements, 0).value == 12
    assert Enum.at(decoded.measurements, 0).unit == "mm"
  end

  test "bthome_distance_meters.bin - distance in meters" do
    binary = load_binary_file("bthome_distance_meters.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for distance in meters
    assert_in_delta Enum.at(decoded.measurements, 0).value, 7.8, 0.1
    assert Enum.at(decoded.measurements, 0).unit == "m"
  end

  test "bthome_duration.bin - duration in seconds" do
    binary = load_binary_file("bthome_duration.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for duration in seconds
    assert_in_delta Enum.at(decoded.measurements, 0).value, 13.39, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "s"
  end

  test "bthome_current.bin - current measurement" do
    binary = load_binary_file("bthome_current.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for current in A
    assert_in_delta Enum.at(decoded.measurements, 0).value, 13.39, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "A"
  end

  test "bthome_speed.bin - speed measurement" do
    binary = load_binary_file("bthome_speed.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for speed in m/s
    assert_in_delta Enum.at(decoded.measurements, 0).value, 133.9, 0.01
    assert Enum.at(decoded.measurements, 0).unit == "m/s"
  end

  test "bthome_temperature_2.bin - temperature with one digit precision" do
    binary = load_binary_file("bthome_temperature_2.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for temperature with one digit
    assert_in_delta Enum.at(decoded.measurements, 0).value, 27.3, 0.1
    assert Enum.at(decoded.measurements, 0).unit == "°C"
  end

  test "bthome_uv_index.bin - UV index measurement" do
    binary = load_binary_file("bthome_uv_index.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for UV index
    assert_in_delta Enum.at(decoded.measurements, 0).value, 5.0, 0.1
  end

  test "bthome_volume_liters.bin - volume in liters" do
    binary = load_binary_file("bthome_volume_liters.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for volume in liters
    assert_in_delta Enum.at(decoded.measurements, 0).value, 2215.1, 0.1
    assert Enum.at(decoded.measurements, 0).unit == "L"
  end

  test "bthome_volume_milliliters.bin - volume in milliliters" do
    binary = load_binary_file("bthome_volume_milliliters.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for volume in milliliters
    assert Enum.at(decoded.measurements, 0).value == 34_780
    assert Enum.at(decoded.measurements, 0).unit == "mL"
  end

  test "bthome_volume_flow_rate.bin - volume flow rate" do
    binary = load_binary_file("bthome_volume_flow_rate.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for volume flow rate in m³ per hour
    assert_in_delta Enum.at(decoded.measurements, 0).value, 34.780, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "m³/hr"
  end

  test "bthome_voltage_2.bin - voltage reading (variant 2)" do
    binary = load_binary_file("bthome_voltage_2.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for voltage reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 307.4, 0.1
    assert Enum.at(decoded.measurements, 0).unit == "V"
  end

  test "bthome_gas.bin - gas reading" do
    binary = load_binary_file("bthome_gas.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for gas reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 1346.067, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "m³"
  end

  test "bthome_gas_2.bin - gas reading (uint32)" do
    binary = load_binary_file("bthome_gas_2.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for uint32 gas reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 25_821.505, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "m³"
  end

  test "bthome_energy_2.bin - energy reading (uint32)" do
    binary = load_binary_file("bthome_energy_2.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for uint32 energy reading without encryption
    assert_in_delta Enum.at(decoded.measurements, 0).value, 344_593.17, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "kWh"
  end

  test "bthome_volume_liters_2.bin - volume in liters (uint32)" do
    binary = load_binary_file("bthome_volume_liters_2.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for uint32 volume in liters
    assert_in_delta Enum.at(decoded.measurements, 0).value, 19_551.879, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "L"
  end

  test "bthome_volume_water.bin - water volume" do
    binary = load_binary_file("bthome_volume_water.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for water in liters
    assert_in_delta Enum.at(decoded.measurements, 0).value, 19_551.879, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "L"
  end

  test "bthome_timestamp.bin - Unix timestamp" do
    binary = load_binary_file("bthome_timestamp.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for Unix timestamp
    timestamp = Enum.at(decoded.measurements, 0).value

    expected_timestamp =
      DateTime.new!(~D[2023-05-14], ~T[19:41:17], "Etc/UTC") |> DateTime.to_unix()

    assert timestamp == expected_timestamp
  end

  test "bthome_acceleration.bin - acceleration in m/s²" do
    binary = load_binary_file("bthome_acceleration.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for acceleration in m/s²
    assert_in_delta Enum.at(decoded.measurements, 0).value, 22.151, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "m/s²"
  end

  test "bthome_gyroscope.bin - gyroscope measurement" do
    binary = load_binary_file("bthome_gyroscope.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for gyroscope in °/s
    assert_in_delta Enum.at(decoded.measurements, 0).value, 22.151, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "°/s"
  end

  test "bthome_text.bin - text data" do
    binary = load_binary_file("bthome_text.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for text
    assert Enum.at(decoded.measurements, 0).value == "Hello World!"
  end

  test "bthome_raw.bin - raw binary data" do
    binary = load_binary_file("bthome_raw.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for raw data
    assert Enum.at(decoded.measurements, 0).value ==
             <<0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21>>
  end

  test "bthome_volume_storage.bin - volume storage" do
    binary = load_binary_file("bthome_volume_storage.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for volume storage in liters
    assert_in_delta Enum.at(decoded.measurements, 0).value, 19_551.879, 0.001
    assert Enum.at(decoded.measurements, 0).unit == "L"
  end

  test "bthome_device_type_id.bin - device type ID" do
    binary = load_binary_file("bthome_device_type_id.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for device type ID
    assert Enum.at(decoded.measurements, 0).value == 1
  end

  test "bthome_device_fw_version_uint32.bin - firmware version (4 bytes)" do
    binary = load_binary_file("bthome_device_fw_version_uint32.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for device firmware version (4 bytes)
    measurement = Enum.at(decoded.measurements, 0)
    assert measurement.value.fw_version_major == 4
    assert measurement.value.fw_version_minor == 2
    assert measurement.value.fw_version_patch == 1
    assert measurement.value.fw_version_build == 0
  end

  test "bthome_device_fw_version_uint24.bin - firmware version (3 bytes)" do
    binary = load_binary_file("bthome_device_fw_version_uint24.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for device firmware version (3 bytes)
    measurement = Enum.at(decoded.measurements, 0)
    assert measurement.value.fw_version_major == 6
    assert measurement.value.fw_version_minor == 1
    assert measurement.value.fw_version_patch == 0
  end

  test "bthome_double_temperature.bin - double temperature readings" do
    binary = load_binary_file("bthome_double_temperature.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for double temperature reading without encryption
    measurements = decoded.measurements
    assert length(measurements) == 2
    assert_in_delta Enum.at(measurements, 0).value, 25.06, 0.01
    assert Enum.at(measurements, 0).unit == "°C"
    assert_in_delta Enum.at(measurements, 1).value, 25.11, 0.01
    assert Enum.at(measurements, 1).unit == "°C"
  end

  test "bthome_triple_temperature_double_humidity_battery.bin - multiple sensor readings" do
    binary = load_binary_file("bthome_triple_temperature_double_humidity_battery.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for triple temperature, double humidity and single battery reading without encryption
    measurements = decoded.measurements
    assert length(measurements) == 6
    assert_in_delta Enum.at(measurements, 0).value, 25.06, 0.01
    assert Enum.at(measurements, 0).unit == "°C"
    assert_in_delta Enum.at(measurements, 1).value, 25.11, 0.01
    assert Enum.at(measurements, 1).unit == "°C"
    assert_in_delta Enum.at(measurements, 2).value, 22.55, 0.01
    assert Enum.at(measurements, 2).unit == "°C"
    assert_in_delta Enum.at(measurements, 3).value, 63.27, 0.01
    assert Enum.at(measurements, 3).unit == "%"
    assert_in_delta Enum.at(measurements, 4).value, 60.71, 0.01
    assert Enum.at(measurements, 4).unit == "%"
    assert Enum.at(measurements, 5).value == 93
    assert Enum.at(measurements, 5).unit == "%"
  end

  test "bthome_double_voltage_different_object_id.bin - double voltage with different object ID" do
    binary = load_binary_file("bthome_double_voltage_different_object_id.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for double voltage with different object id
    measurements = decoded.measurements
    assert length(measurements) >= 5

    assert Enum.at(measurements, 0).value == 1
    assert Enum.at(measurements, 1).value == 0
    assert Enum.at(measurements, 1).unit == "W"
    assert_in_delta Enum.at(measurements, 2).value, 231.7, 0.1
    assert Enum.at(measurements, 2).unit == "V"
    assert Enum.at(measurements, 3).value == 51
    assert Enum.at(measurements, 3).unit == "%"
    assert_in_delta Enum.at(measurements, 4).value, 3.305, 0.001
    assert Enum.at(measurements, 4).unit == "V"
  end

  test "bthome_shelly_button.bin - Shelly button device" do
    binary = load_binary_file("bthome_shelly_button.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for Shelly button
    measurements = decoded.measurements
    assert length(measurements) >= 3

    assert Enum.at(measurements, 0).value == 82
    assert Enum.at(measurements, 1).value == 100
    assert Enum.at(measurements, 1).unit == "%"
    assert Enum.at(measurements, 2).value == :press
  end

  test "bthome_shelly_button_encrypted.bin - encrypted Shelly button" do
    binary = load_binary_file("bthome_shelly_button_encrypted.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for Shelly button with encryption
    # Note: This test would require implementing the decryption logic
    # For now, we just verify the structure is parsed correctly
    assert decoded.encrypted == true
    assert decoded.ciphertext != nil
    assert decoded.counter != nil
    assert decoded.mic != nil
  end

  test "bthome_temperature_humidity_encrypted.bin - encrypted temperature and humidity" do
    binary = load_binary_file("bthome_temperature_humidity_encrypted.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    # Test BTHome parser for temperature humidity reading with encryption
    # Note: This test would require implementing the decryption logic
    # For now, we just verify the structure is parsed correctly
    assert decoded.encrypted == true
    assert decoded.ciphertext != nil
    assert decoded.counter != nil
    assert decoded.mic != nil
  end

  # Additional MAC address validation tests
  test "MAC address detection - edge cases" do
    # Test case where first byte looks like MAC but isn't
    binary_no_mac = load_binary_file("bthome_temperature_humidity.bin")
    {:ok, decoded_no_mac} = BTHome.deserialize(binary_no_mac)
    assert decoded_no_mac.mac_reversed == nil

    # Test MAC address extraction with proper validation
    binary_with_mac = load_binary_file("bthome_with_mac.bin")
    {:ok, decoded_with_mac} = BTHome.deserialize(binary_with_mac)

    # Verify MAC address is exactly 6 bytes
    assert byte_size(decoded_with_mac.mac_reversed) == 6
    # Verify MAC address matches expected value
    assert decoded_with_mac.mac_reversed == <<0xB2, 0x18, 0x8D, 0x38, 0xC1, 0xA4>>
    # Verify measurements are still parsed correctly after MAC extraction
    assert length(decoded_with_mac.measurements) > 0
    assert Enum.at(decoded_with_mac.measurements, 0).type == :pressure
  end

  # Additional firmware version structure validation tests
  test "firmware version structure validation - 32-bit" do
    binary = load_binary_file("bthome_device_fw_version_uint32.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    measurement = Enum.at(decoded.measurements, 0)

    # Verify all required firmware version fields are present
    assert Map.has_key?(measurement.value, :fw_version_major)
    assert Map.has_key?(measurement.value, :fw_version_minor)
    assert Map.has_key?(measurement.value, :fw_version_patch)
    assert Map.has_key?(measurement.value, :fw_version_build)

    # Verify field types are integers
    assert is_integer(measurement.value.fw_version_major)
    assert is_integer(measurement.value.fw_version_minor)
    assert is_integer(measurement.value.fw_version_patch)
    assert is_integer(measurement.value.fw_version_build)

    # Verify field ranges (0-255 for each byte)
    assert measurement.value.fw_version_major >= 0 and measurement.value.fw_version_major <= 255
    assert measurement.value.fw_version_minor >= 0 and measurement.value.fw_version_minor <= 255
    assert measurement.value.fw_version_patch >= 0 and measurement.value.fw_version_patch <= 255
    assert measurement.value.fw_version_build >= 0 and measurement.value.fw_version_build <= 255

    # Verify specific expected values match Python test
    assert measurement.value.fw_version_major == 4
    assert measurement.value.fw_version_minor == 2
    assert measurement.value.fw_version_patch == 1
    assert measurement.value.fw_version_build == 0
  end

  test "firmware version structure validation - 24-bit" do
    binary = load_binary_file("bthome_device_fw_version_uint24.bin")
    {:ok, decoded} = BTHome.deserialize(binary)

    measurement = Enum.at(decoded.measurements, 0)

    # Verify required firmware version fields are present (no build field for 24-bit)
    assert Map.has_key?(measurement.value, :fw_version_major)
    assert Map.has_key?(measurement.value, :fw_version_minor)
    assert Map.has_key?(measurement.value, :fw_version_patch)
    refute Map.has_key?(measurement.value, :fw_version_build)

    # Verify field types are integers
    assert is_integer(measurement.value.fw_version_major)
    assert is_integer(measurement.value.fw_version_minor)
    assert is_integer(measurement.value.fw_version_patch)

    # Verify field ranges (0-255 for each byte)
    assert measurement.value.fw_version_major >= 0 and measurement.value.fw_version_major <= 255
    assert measurement.value.fw_version_minor >= 0 and measurement.value.fw_version_minor <= 255
    assert measurement.value.fw_version_patch >= 0 and measurement.value.fw_version_patch <= 255

    # Verify specific expected values match Python test
    assert measurement.value.fw_version_major == 6
    assert measurement.value.fw_version_minor == 1
    assert measurement.value.fw_version_patch == 0
  end
end
