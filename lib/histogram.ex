# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.Histogram do
  @moduledoc """
  Represents a Histogram metric.

  A Histogram samples observations (usually things like request durations or response sizes) and counts them in configurable buckets.
  """

  defstruct [:name, :help, :labels, :buckets, :sum, :count, :bucket_counts]

  @doc """
  Creates a new Histogram metric.
  """
  def new(name, help, buckets, labels \\ %{}) do
    buckets = buckets ++ ["+Inf"]

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
  """
  def sum(histogram), do: histogram.sum

  @doc """
  Returns the current count of observations.
  """
  def count(histogram), do: histogram.count

  @doc """
  Returns a string representation of the histogram in Prometheus exposition format.
  """
  def to_string(histogram) do
    labels_str =
      histogram.labels
      |> Enum.map(fn {key, value} -> "#{key}=\"#{value}\"" end)
      |> Enum.join(",")

    labels_formatted = if labels_str == "", do: "", else: "{#{labels_str}}"

    bucket_strings =
      histogram.bucket_counts
      |> Enum.map(fn {bucket, count} ->
        if labels_str == "",
          do: "#{histogram.name}_bucket{le=\"#{bucket}\"} #{count}",
          else: "#{histogram.name}_bucket{#{labels_str},le=\"#{bucket}\"} #{count}"
      end)
      |> Enum.join("\n")

    """
    # HELP #{histogram.name} #{histogram.help}
    # TYPE #{histogram.name} histogram
    #{bucket_strings}
    #{histogram.name}_sum#{labels_formatted} #{histogram.sum}
    #{histogram.name}_count#{labels_formatted} #{histogram.count}
    """
  end
end
