# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.Gauge do
  @moduledoc """
  Represents a Gauge metric.

  A Gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
  """

  defstruct [:name, :help, :labels, :value]

  @doc """
  Creates a new Gauge metric.

  ## Parameters

  * `name` - The name of the gauge
  * `help` - The help text of the gauge
  * `labels` - The labels of the gauge
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
  Sets the gauge value to the given amount.

  ## Parameters

  * `gauge` - The gauge to set
  * `value` - The value to set
  """
  def set(gauge, value) when is_number(value) do
    %{gauge | value: value}
  end

  @doc """
  Increments the gauge by the given amount.

  ## Parameters

  * `gauge` - The gauge to increment
  * `amount` - The amount to increment by (defaults to 1)
  """
  def inc(gauge, amount \\ 1) when is_number(amount) do
    %{gauge | value: gauge.value + amount}
  end

  @doc """
  Decrements the gauge by the given amount.

  ## Parameters

  * `gauge` - The gauge to decrement
  * `amount` - The amount to decrement by (defaults to 1)
  """
  def dec(gauge, amount \\ 1) when is_number(amount) do
    %{gauge | value: gauge.value - amount}
  end

  @doc """
  Returns the current value of the gauge.

  ## Parameters

  * `gauge` - The gauge to get the value from
  """
  def value(gauge), do: gauge.value

  @doc """
  Returns the id of the counter

  ## Parameters

  * `counter` - The counter to get the id from
  """
  def id(counter),
    do:
      "#{counter.name}|#{format_labels(counter.labels)}"
      |> String.replace(" ", "")
      |> String.downcase()

  defp format_labels(labels) when is_map(labels) and map_size(labels) == 0, do: ""

  defp format_labels(labels) when is_map(labels) do
    labels
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map(fn {key, value} -> "#{key}_#{value}" end)
    |> Enum.join(",")
  end

  @doc """
  Returns a string representation of the gauge in Prometheus exposition format.

  ## Parameters

  * `gauge` - The gauge to convert to a string
  """
  def to_string(gauge) do
    labels_str =
      gauge.labels
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map(fn {key, value} -> "#{key}=\"#{value}\"" end)
      |> Enum.join(",")

    labels_formatted = if labels_str == "", do: "", else: "{#{labels_str}}"

    """
    # HELP #{gauge.name} #{gauge.help}
    # TYPE #{gauge.name} gauge
    #{gauge.name}#{labels_formatted} #{gauge.value}
    """
  end
end
