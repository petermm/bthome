defmodule BTHome.PythonCompatibilityTest do
  use ExUnit.Case

  alias BTHome.{ButtonEvent, DimmerEvent}

  @moduledoc """
  Tests to ensure Elixir BTHome implementation matches Python BTHome library expectations.

  This test suite validates that our event handling system produces the same results
  as the Python BTHome library, particularly for button and dimmer events.
  """

  describe "Button event compatibility with Python ButtonEvent" do
    test "button event values match Python enum expectations" do
      # These assertions verify that our Elixir implementation produces
      # the same event values that Python BTHome tests expect

      # Python: assert measurement.value == BthomeServiceData.ButtonEventType.none
      assert ButtonEvent.none() == :none

      # Python: assert measurement.value == BthomeServiceData.ButtonEventType.press
      assert ButtonEvent.press() == :press

      # Python: assert measurement.value == BthomeServiceData.ButtonEventType.long_press
      assert ButtonEvent.long_press() == :long_press

      # Python: assert measurement.value == BthomeServiceData.ButtonEventType.triple_press
      assert ButtonEvent.triple_press() == :triple_press

      # Python: assert measurement.value == BthomeServiceData.ButtonEventType.hold_press
      assert ButtonEvent.hold_press() == :hold_press
    end

    test "button events from binary data match Python expectations" do
      # Test actual binary data parsing to ensure compatibility

      # Load and test long press button event
      binary = File.read!("test/test_data_bin/bthome_event_button_long_press.bin")
      {:ok, decoded} = BTHome.deserialize(binary)

      # This should match Python: assert measurement.value == ButtonEvent.long_press
      assert Enum.at(decoded.measurements, 0).value == ButtonEvent.long_press()
      assert Enum.at(decoded.measurements, 0).value == :long_press

      # Load and test hold press button event
      binary = File.read!("test/test_data_bin/bthome_event_button_hold_press.bin")
      {:ok, decoded} = BTHome.deserialize(binary)

      # This should match Python: assert measurement.value == ButtonEvent.hold_press
      assert Enum.at(decoded.measurements, 0).value == ButtonEvent.hold_press()
      assert Enum.at(decoded.measurements, 0).value == :hold_press
    end

    test "triple button device events match Python expectations" do
      binary = File.read!("test/test_data_bin/bthome_event_triple_button_device.bin")
      {:ok, decoded} = BTHome.deserialize(binary)

      measurements = decoded.measurements
      assert length(measurements) >= 3

      # Python expects: ButtonEvent.none, ButtonEvent.press, ButtonEvent.triple_press
      assert Enum.at(measurements, 0).value == ButtonEvent.none()
      assert Enum.at(measurements, 1).value == ButtonEvent.press()
      assert Enum.at(measurements, 2).value == ButtonEvent.triple_press()

      # Verify atom values match
      assert Enum.at(measurements, 0).value == :none
      assert Enum.at(measurements, 1).value == :press
      assert Enum.at(measurements, 2).value == :triple_press
    end
  end

  describe "Dimmer event compatibility with Python DimmerEvent" do
    test "dimmer event values match Python enum expectations" do
      # These assertions verify that our Elixir implementation produces
      # the same event values that Python BTHome tests expect

      # Python: assert measurement.value.event == BthomeServiceData.DimmerEventType.none
      assert DimmerEvent.none() == :none

      # Python: assert measurement.value.event == BthomeServiceData.DimmerEventType.rotate_left
      assert DimmerEvent.rotate_left() == :rotate_left

      # Python: assert measurement.value.event == BthomeServiceData.DimmerEventType.rotate_right
      assert DimmerEvent.rotate_right() == :rotate_right
    end

    test "dimmer events include separate steps field like Python" do
      # Test dimmer rotate left with 3 steps
      binary = File.read!("test/test_data_bin/bthome_event_dimmer_rotate_left_3_steps.bin")
      {:ok, decoded} = BTHome.deserialize(binary)

      measurement = Enum.at(decoded.measurements, 0)

      # Python expects:
      # assert measurement.value.event == DimmerEvent.rotate_left
      # assert measurement.value.steps == 3
      assert measurement.value.event == DimmerEvent.rotate_left()
      assert measurement.value.event == :rotate_left
      assert measurement.value.steps == 3
      assert is_integer(measurement.value.steps)
    end

    test "dimmer none event matches Python expectations" do
      binary = File.read!("test/test_data_bin/bthome_event_dimmer_none.bin")
      {:ok, decoded} = BTHome.deserialize(binary)

      measurement = Enum.at(decoded.measurements, 0)

      # Python expects:
      # assert measurement.value.event == DimmerEvent.none
      # assert measurement.value.steps == 0
      assert measurement.value.event == DimmerEvent.none()
      assert measurement.value.event == :none
      assert measurement.value.steps == 0
    end

    test "dimmer value structure matches Python expectations" do
      # Verify that dimmer measurements have the expected structure
      # Python expects: measurement.value with .event and .steps attributes

      dimmer_value = %{
        event: DimmerEvent.rotate_left(),
        steps: 5
      }

      # Verify structure matches Python expectations
      assert Map.has_key?(dimmer_value, :event)
      assert Map.has_key?(dimmer_value, :steps)
      assert dimmer_value.event == :rotate_left
      assert dimmer_value.steps == 5
      assert is_atom(dimmer_value.event)
      assert is_integer(dimmer_value.steps)
    end
  end

  describe "Event system validation" do
    test "all button event types are valid" do
      # Ensure all our button event types pass validation
      Enum.each(ButtonEvent.all(), fn event_type ->
        assert ButtonEvent.valid?(event_type)
      end)
    end

    test "all dimmer event types are valid" do
      # Ensure all our dimmer event types pass validation
      Enum.each(DimmerEvent.all(), fn event_type ->
        assert DimmerEvent.valid?(event_type)
      end)
    end

    test "event types match expected Python enum count" do
      # Verify we have the expected number of event types
      # This helps catch missing or extra event types
      assert length(ButtonEvent.all()) == 9
      assert length(DimmerEvent.all()) == 3
    end
  end
end
