defmodule BTHome.ButtonEvent do
  @moduledoc """
  Defines button events for BTHome v2 format.

  This module provides constants for button events that match the Python
  BTHome library's ButtonEvent enum values.
  """

  @doc """
  No button event occurred.
  """
  def none, do: :none

  @doc """
  Single button press event.
  """
  def press, do: :press

  @doc """
  Double button press event.
  """
  def double_press, do: :double_press

  @doc """
  Triple button press event.
  """
  def triple_press, do: :triple_press

  @doc """
  Long button press event.
  """
  def long_press, do: :long_press

  @doc """
  Long double button press event.
  """
  def long_double_press, do: :long_double_press

  @doc """
  Long triple button press event.
  """
  def long_triple_press, do: :long_triple_press

  @doc """
  Button hold press event.
  """
  def hold_press, do: :hold_press

  @doc """
  Button release event.
  """
  def release, do: :release

  @doc """
  Returns all valid button event types.
  """
  def all do
    [
      none(),
      press(),
      double_press(),
      triple_press(),
      long_press(),
      long_double_press(),
      long_triple_press(),
      hold_press(),
      release()
    ]
  end

  @doc """
  Checks if the given value is a valid button event type.
  """
  def valid?(event_type) do
    event_type in all()
  end
end
