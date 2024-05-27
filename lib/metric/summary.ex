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

  ## Parameters

  * `name` - The name of the summary
  * `help` - The help text of the summary
  * `quantiles` - The quantiles to calculate (defaults to [0.5, 0.9, 0.95, 0.99])
  * `labels` - The labels of the summary
  """
  def new(name, help, quantiles \\ [0.5, 0.9, 0.95, 0.99], labels \\ %{}) do
    if name == "" or help == "" do
      raise "name and help cannot be empty"
    end

    if quantiles == [] do
      raise "quantiles cannot be empty"
    end

    if Enum.uniq(quantiles) != quantiles do
      raise "quantiles must be unique"
    end

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

  ## Parameters

  * `summary` - The summary to observe
  * `value` - The value to observe
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

  ## Parameters

  * `summary` - The summary to get the sum from
  """
  def sum(summary), do: summary.sum

  @doc """
  Returns the current count of observations.

  ## Parameters

  * `summary` - The summary to get the count from
  """
  def count(summary), do: summary.count

  @doc """
  Returns the current observations.

  ## Parameters

  * `summary` - The summary to get the observations from
  """
  def observations(summary), do: summary.observations

  @doc """
  Calculates the specified quantile from observations.

  Uses a simple quantile calculation method:
  - Maps quantile q (0-1) directly to array index
  - For quantile q, returns the value at index floor(q * n) where n is the number of observations
  - Handles edge cases for 0.0 and 1.0 quantiles
  """
  def quantile(summary, q) when q >= 0 and q <= 1 do
    case summary.observations do
      [] ->
        0

      obs ->
        sorted = Enum.sort(obs)
        n = length(sorted)

        if n == 1 do
          # Single observation
          List.first(sorted)
        else
          cond do
            q == 0.0 ->
              # 0th quantile returns the minimum value
              List.first(sorted)
            q == 1.0 ->
              # 100th quantile returns the maximum value
              List.last(sorted)
            true ->
              # Calculate index: floor(q * n)
              # For q=0.5, n=4: index = floor(0.5 * 4) = floor(2) = 2
              # For q=0.9, n=5: index = floor(0.9 * 5) = floor(4.5) = 4
              index = trunc(q * n)
              # Ensure index is within bounds
              clamped_index = max(0, min(index, n - 1))
              Enum.at(sorted, clamped_index)
          end
        end
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
