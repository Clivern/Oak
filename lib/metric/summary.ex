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

  Uses the standard percentile calculation method:
  - Index = (n-1) × p where n is the number of observations and p is the percentile (0-1)
  - Interpolates between values when the index is not an integer
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
              # 0th percentile returns the minimum value
              List.first(sorted)
            q == 1.0 ->
              # 100th percentile returns the maximum value
              List.last(sorted)
            true ->
              # Calculate the position using standard percentile formula
              # For quantile q, position = q * (n - 1)
              position = q * (n - 1)

              # Get the integer part and fractional part
              lower_index = trunc(position)
              upper_index = min(lower_index + 1, n - 1)

              # Get the values at these indices
              lower_value = Enum.at(sorted, lower_index)
              upper_value = Enum.at(sorted, upper_index)

              # If we're at an exact integer position, return that value
              if position == lower_index do
                lower_value
              else
                # Interpolate between the two values
                weight = position - lower_index
                lower_value * (1 - weight) + upper_value * weight
              end
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
