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
  """
  def new(name, help, labels \\ %{}) do
    %__MODULE__{
      name: name,
      help: help,
      labels: labels,
      value: 0
    }
  end

  @doc """
  Sets the gauge value to the given amount.
  """
  def set(gauge, value) when is_number(value) do
    %{gauge | value: value}
  end

  @doc """
  Increments the gauge by the given amount.
  """
  def inc(gauge, amount \\ 1) when is_number(amount) do
    %{gauge | value: gauge.value + amount}
  end

  @doc """
  Decrements the gauge by the given amount.
  """
  def dec(gauge, amount \\ 1) when is_number(amount) do
    %{gauge | value: gauge.value - amount}
  end

  @doc """
  Returns the current value of the gauge.
  """
  def value(gauge), do: gauge.value

  @doc """
  Returns a string representation of the gauge in Prometheus exposition format.
  """
  def to_string(gauge) do
    labels_str =
      gauge.labels
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
