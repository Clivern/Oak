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
  Returns a string representation of the histogram in Prometheus exposition format.

  ## Parameters

  * `histogram` - The histogram to convert to a string
  """
  def to_string(histogram) do
    labels_str =
      histogram.labels
      |> Enum.sort_by(fn {key, _value} -> key end)
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
