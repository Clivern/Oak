# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.Summary do
  @moduledoc """
  Represents a Summary metric.

  A Summary samples observations (usually things like request durations and response sizes) and provides
  a total count of observations and sum of all observed values, while calculating configurable quantiles over a sliding time window.
  """

  defstruct [:name, :help, :labels, :quantiles, :sum, :count, :observations]

  @doc """
  Creates a new Summary metric.
  """
  def new(name, help, quantiles \\ [0.5, 0.9, 0.95, 0.99], labels \\ %{}) do
    %__MODULE__{
      name: name,
      help: help,
      labels: labels,
      quantiles: quantiles,
      sum: 0,
      count: 0,
      observations: []
    }
  end

  @doc """
  Observes a value in the summary.
  """
  def observe(summary, value) when is_number(value) do
    %{
      summary
      | sum: summary.sum + value,
        count: summary.count + 1,
        observations: [value | summary.observations]
    }
  end

  @doc """
  Returns the current sum of all observed values.
  """
  def sum(summary), do: summary.sum

  @doc """
  Returns the current count of observations.
  """
  def count(summary), do: summary.count

  @doc """
  Calculates the specified quantile from observations.
  """
  def quantile(summary, q) when q >= 0 and q <= 1 do
    case summary.observations do
      [] ->
        0

      obs ->
        sorted = Enum.sort(obs)
        # For 0.9 quantile with 5 observations: index = trunc(4 * 0.9) = 3
        # This gives us the 4th element (index 3) which is 4, but we want 5 for 90th percentile
        # We need to round up to get the correct quantile
        index = ceil((length(sorted) - 1) * q)
        # Ensure index is within bounds
        index = max(0, min(index, length(sorted) - 1))
        Enum.at(sorted, index, 0)
    end
  end

  @doc """
  Returns a string representation of the summary in Prometheus exposition format.
  """
  def to_string(summary) do
    labels_str =
      summary.labels
      |> Enum.map(fn {key, value} -> "#{key}=\"#{value}\"" end)
      |> Enum.join(",")

    labels_formatted = if labels_str == "", do: "", else: "{#{labels_str}}"

    quantile_strings =
      summary.quantiles
      |> Enum.map(fn q ->
        value = quantile(summary, q)

        if labels_str == "",
          do: "#{summary.name}{quantile=\"#{q}\"} #{value}",
          else: "#{summary.name}{#{labels_str},quantile=\"#{q}\"} #{value}"
      end)
      |> Enum.join("\n")

    """
    # HELP #{summary.name} #{summary.help}
    # TYPE #{summary.name} summary
    #{quantile_strings}
    #{summary.name}_sum#{labels_formatted} #{summary.sum}
    #{summary.name}_count#{labels_formatted} #{summary.count}
    """
  end
end
