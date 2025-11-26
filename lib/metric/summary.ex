# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.Summary do
  @moduledoc """
  Represents a Summary metric.

  A Summary samples observations (usually things like request durations and response sizes) and provides
  a total count of observations and sum of all observed values, while calculating configurable quantiles over a sliding time window.
  """

  alias Oak.Metric.Labels

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

      observations ->
        # A tuple gives constant-time indexed access to the sorted values.
        sorted = observations |> Enum.sort() |> List.to_tuple()
        n = tuple_size(sorted)

        cond do
          # A single observation is every quantile.
          n == 1 -> elem(sorted, 0)
          # 0th percentile is the minimum value.
          q == 0.0 -> elem(sorted, 0)
          # 100th percentile is the maximum value.
          q == 1.0 -> elem(sorted, n - 1)
          true -> interpolate(sorted, n, q)
        end
    end
  end

  @doc """
  Returns the id of the summary

  ## Parameters

  * `summary` - The summary to get the id from
  """
  def id(summary), do: Labels.id(summary.name, summary.labels)

  @doc """
  Returns a string representation of the summary in Prometheus exposition format.
  """
  def to_string(summary) do
    rendered = Labels.render(summary.labels)
    labels = Labels.braced(rendered)

    quantile_strings =
      summary.quantiles
      |> Enum.map(fn q ->
        value = quantile(summary, q)
        quantile_labels = Labels.braced(Labels.append(rendered, ~s(quantile="#{q}")))
        "#{summary.name}#{quantile_labels} #{value}"
      end)
      |> Enum.join("\n")

    """
    # HELP #{summary.name} #{summary.help}
    # TYPE #{summary.name} summary
    #{quantile_strings}
    #{summary.name}_sum#{labels} #{summary.sum}
    #{summary.name}_count#{labels} #{summary.count}
    """
  end

  # Interpolates the quantile `q` between the two sorted values that bracket
  # position q * (n - 1). Exact integer positions return the value directly.
  defp interpolate(sorted, n, q) do
    position = q * (n - 1)
    lower_index = trunc(position)
    upper_index = min(lower_index + 1, n - 1)

    lower_value = elem(sorted, lower_index)
    upper_value = elem(sorted, upper_index)

    if position == lower_index do
      lower_value
    else
      weight = position - lower_index
      lower_value * (1 - weight) + upper_value * weight
    end
  end
end
