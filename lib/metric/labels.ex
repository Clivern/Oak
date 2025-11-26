# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.Labels do
  @moduledoc false

  # Shared label handling used by every metric type. This is an internal
  # module and is not part of Oak's public API.

  @doc """
  Builds the identifier a metric is stored under in the MetricsStore.

  The identifier is the metric name and its labels, lowercased and without
  spaces, e.g. `"http_requests_total|method_get"`.
  """
  def id(name, labels) do
    "#{name}|#{id_labels(labels)}"
    |> String.replace(" ", "")
    |> String.downcase()
  end

  @doc """
  Renders labels as Prometheus `key="value"` pairs, sorted by key and joined
  with commas. Returns an empty string when there are no labels.
  """
  def render(labels) do
    labels
    |> sorted()
    |> Enum.map_join(",", fn {key, value} -> "#{key}=\"#{value}\"" end)
  end

  @doc """
  Wraps rendered labels in braces for use in a sample line. Returns an empty
  string when there are no labels.
  """
  def braced(""), do: ""
  def braced(rendered), do: "{#{rendered}}"

  @doc """
  Appends one more pair to already-rendered labels, e.g. `le="0.5"` for
  histogram buckets or `quantile="0.9"` for summaries.
  """
  def append("", extra), do: extra
  def append(rendered, extra), do: "#{rendered},#{extra}"

  defp id_labels(labels) do
    labels
    |> sorted()
    |> Enum.map_join(",", fn {key, value} -> "#{key}_#{value}" end)
  end

  defp sorted(labels), do: Enum.sort_by(labels, fn {key, _value} -> key end)
end
