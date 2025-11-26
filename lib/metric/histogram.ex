# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.Histogram do
  @moduledoc """
  Represents a Histogram metric.

  A Histogram samples observations (usually things like request durations or response sizes) and counts them in configurable buckets.
  """

  alias Oak.Metric.Labels

  defstruct [:name, :help, :labels, :buckets, :sum, :count, :bucket_counts]

  @doc """
  Creates a new Histogram metric.

  ## Parameters

  * `name` - The name of the histogram
  * `help` - The help text of the histogram
  * `buckets` - The buckets of the histogram
  * `labels` - The labels of the histogram
  """
  def new(name, help, buckets, labels \\ %{}) do
    if name == "" or help == "" do
      raise "name and help cannot be empty"
    end

    buckets = buckets ++ ["+Inf"]

    if Enum.uniq(buckets) != buckets do
      raise "buckets must be unique"
    end

    %__MODULE__{
      name: name,
      help: help,
      labels: labels,
      buckets: Enum.sort(buckets),
      sum: 0,
      count: 0,
      bucket_counts: Map.new(buckets, fn bucket -> {bucket, 0} end)
    }
  end

  @doc """
  Observes a value in the histogram.

  ## Parameters

  * `histogram` - The histogram to observe
  * `value` - The value to observe
  """
  def observe(histogram, value) when is_number(value) do
    updated_bucket_counts =
      histogram.bucket_counts
      |> Enum.map(fn {bucket, count} ->
        if value <= bucket or bucket == "+Inf", do: {bucket, count + 1}, else: {bucket, count}
      end)
      |> Map.new()

    %{
      histogram
      | sum: histogram.sum + value,
        count: histogram.count + 1,
        bucket_counts: updated_bucket_counts
    }
  end

  @doc """
  Returns the current sum of all observed values.

  ## Parameters

  * `histogram` - The histogram to get the sum from
  """
  def sum(histogram), do: histogram.sum

  @doc """
  Returns the current count of observations.

  ## Parameters

  * `histogram` - The histogram to get the count from
  """
  def count(histogram), do: histogram.count

  @doc """
  Returns the current bucket counts.

  ## Parameters

  * `histogram` - The histogram to get the bucket counts from
  """
  def bucket_counts(histogram), do: histogram.bucket_counts

  @doc """
  Returns the id of the histogram

  ## Parameters

  * `histogram` - The histogram to get the id from
  """
  def id(histogram), do: Labels.id(histogram.name, histogram.labels)

  @doc """
  Returns a string representation of the histogram in Prometheus exposition format.

  ## Parameters

  * `histogram` - The histogram to convert to a string
  """
  def to_string(histogram) do
    rendered = Labels.render(histogram.labels)
    labels = Labels.braced(rendered)

    bucket_strings =
      histogram.bucket_counts
      |> Enum.map(fn {bucket, count} ->
        bucket_labels = Labels.braced(Labels.append(rendered, ~s(le="#{bucket}")))
        "#{histogram.name}_bucket#{bucket_labels} #{count}"
      end)
      |> Enum.join("\n")

    """
    # HELP #{histogram.name} #{histogram.help}
    # TYPE #{histogram.name} histogram
    #{bucket_strings}
    #{histogram.name}_sum#{labels} #{histogram.sum}
    #{histogram.name}_count#{labels} #{histogram.count}
    """
  end
end
