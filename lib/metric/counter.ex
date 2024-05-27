# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.Counter do
  @moduledoc """
  Represents a Counter metric.

  A Counter is a cumulative metric that represents a single monotonically
  increasing counter whose value can only increase or be reset to zero.
  """

  defstruct [:name, :help, :labels, :value]

  @doc """
  Creates a new Counter metric.

  ## Parameters

  * `name` - The name of the counter
  * `help` - The help text of the counter
  * `labels` - The labels of the counter
  """
  def new(name, help, labels \\ %{}) do
    if name == "" or help == "" do
      raise "name and help cannot be empty"
    end

    %__MODULE__{
      name: name,
      help: help,
      labels: labels,
      value: 0
    }
  end

  @doc """
  Increments the counter by the given amount.

  ## Parameters

  * `counter` - The counter to increment
  * `amount` - The amount to increment by (defaults to 1)
  """
  def inc(counter, amount \\ 1) when is_integer(amount) and amount >= 0 do
    %{counter | value: counter.value + amount}
  end

  @doc """
  Set the counter value

  ## Parameters

  * `counter` - The counter to set
  * `value` - The value to set (defaults to 1)
  """
  def set(counter, value \\ 1) when is_integer(value) and value >= 0 do
    %{counter | value: value}
  end

  @doc """
  Returns the current value of the counter

  ## Parameters

  * `counter` - The counter to get the value from
  """
  def value(counter), do: counter.value

  @doc """
  Resets the counter to zero

  ## Parameters

  * `counter` - The counter to reset
  """
  def reset(counter) do
    %{counter | value: 0}
  end

  @doc """
  Returns a string representation of the counter in Prometheus exposition format

  ## Parameters

  * `counter` - The counter to convert to a string
  """
  def to_string(counter) do
    labels_str =
      counter.labels
      |> Enum.map(fn {key, value} -> "#{key}=\"#{value}\"" end)
      |> Enum.join(",")

    labels_formatted = if labels_str == "", do: "", else: "{#{labels_str}}"

    """
    # HELP #{counter.name} #{counter.help}
    # TYPE #{counter.name} counter
    #{counter.name}#{labels_formatted} #{counter.value}
    """
  end
end
