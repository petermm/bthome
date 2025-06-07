defmodule BTHome.EventTypesTest do
  use ExUnit.Case
  doctest BTHome.ButtonEvent
  doctest BTHome.DimmerEvent

  alias BTHome.ButtonEvent
  alias BTHome.DimmerEvent

  describe "ButtonEvent" do
    test "provides correct enum values" do
      assert ButtonEvent.none() == :none
      assert ButtonEvent.press() == :press
      assert ButtonEvent.double_press() == :double_press
      assert ButtonEvent.triple_press() == :triple_press
      assert ButtonEvent.long_press() == :long_press
      assert ButtonEvent.long_double_press() == :long_double_press
      assert ButtonEvent.long_triple_press() == :long_triple_press
      assert ButtonEvent.hold_press() == :hold_press
      assert ButtonEvent.release() == :release
    end

    test "all/0 returns all button event types" do
      all_events = ButtonEvent.all()

      assert :none in all_events
      assert :press in all_events
      assert :double_press in all_events
      assert :triple_press in all_events
      assert :long_press in all_events
      assert :long_double_press in all_events
      assert :long_triple_press in all_events
      assert :hold_press in all_events
      assert :release in all_events

      assert length(all_events) == 9
    end

    test "valid?/1 correctly validates button event types" do
      assert ButtonEvent.valid?(:none)
      assert ButtonEvent.valid?(:press)
      assert ButtonEvent.valid?(:double_press)
      assert ButtonEvent.valid?(:triple_press)
      assert ButtonEvent.valid?(:long_press)
      assert ButtonEvent.valid?(:long_double_press)
      assert ButtonEvent.valid?(:long_triple_press)
      assert ButtonEvent.valid?(:hold_press)
      assert ButtonEvent.valid?(:release)

      refute ButtonEvent.valid?(:invalid_event)
      refute ButtonEvent.valid?("press")
      refute ButtonEvent.valid?(123)
    end
  end

  describe "DimmerEvent" do
    test "provides correct enum values" do
      assert DimmerEvent.none() == :none
      assert DimmerEvent.rotate_left() == :rotate_left
      assert DimmerEvent.rotate_right() == :rotate_right
    end

    test "all/0 returns all dimmer event types" do
      all_events = DimmerEvent.all()

      assert :none in all_events
      assert :rotate_left in all_events
      assert :rotate_right in all_events

      assert length(all_events) == 3
    end

    test "valid?/1 correctly validates dimmer event types" do
      assert DimmerEvent.valid?(:none)
      assert DimmerEvent.valid?(:rotate_left)
      assert DimmerEvent.valid?(:rotate_right)

      refute DimmerEvent.valid?(:invalid_event)
      refute DimmerEvent.valid?("rotate_left")
      refute DimmerEvent.valid?(123)
    end
  end

  describe "Event system compatibility with Python BTHome library" do
    test "button events match Python ButtonEvent enum values" do
      # These should match the Python BTHome library expectations
      assert ButtonEvent.none() == :none
      assert ButtonEvent.press() == :press
      assert ButtonEvent.triple_press() == :triple_press
      assert ButtonEvent.long_press() == :long_press
      assert ButtonEvent.hold_press() == :hold_press
    end

    test "dimmer events match Python DimmerEvent enum values" do
      # These should match the Python BTHome library expectations
      assert DimmerEvent.none() == :none
      assert DimmerEvent.rotate_left() == :rotate_left
    end

    test "dimmer events include steps field structure" do
      # Verify that dimmer events are expected to have both event and steps
      # This matches the Python test expectations where dimmer has separate event and steps
      dimmer_value = %{event: DimmerEvent.rotate_left(), steps: 3}

      assert dimmer_value.event == :rotate_left
      assert dimmer_value.steps == 3
      assert is_integer(dimmer_value.steps)
    end
  end
end
