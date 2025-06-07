defmodule BTHome.DimmerEvent do
  @moduledoc """
  Defines dimmer events for BTHome v2 format.

  This module provides constants for dimmer events that match the Python
  BTHome library's DimmerEvent enum values.
  """

  @doc """
  No dimmer event occurred.
  """
  def none, do: :none

  @doc """
  Dimmer rotated left.
  """
  def rotate_left, do: :rotate_left

  @doc """
  Dimmer rotated right.
  """
  def rotate_right, do: :rotate_right

  @doc """
  Returns all valid dimmer event types.
  """
  def all do
    [
      none(),
      rotate_left(),
      rotate_right()
    ]
  end

  @doc """
  Checks if the given value is a valid dimmer event type.
  """
  def valid?(event_type) do
    event_type in all()
  end
end
