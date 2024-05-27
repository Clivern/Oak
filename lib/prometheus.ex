# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Prometheus do
  @moduledoc """
  Main Prometheus module for Oak metrics collection and HTTP server.

  This module provides functionality to:
  - Start an HTTP server for metrics exposition
  - Collect and format all registered metrics
  - Export metrics in Prometheus exposition format
  """

  @doc """
  Get all metrics from the MetricsStore

  ## Parameters

  * `pid` - The pid of the MetricsStore
  """
  def get_metrics(pid) do
    GenServer.call(pid, {:get_all})
  end

  @doc """
  Push a metric to the MetricsStore

  ## Parameters

  * `pid` - The pid of the MetricsStore
  * `metric` - The metric to push
  """
  def push_metric(pid, metric) do
    GenServer.call(pid, {:push, metric})
  end

  @doc """
  Push a list of metrics to the MetricsStore

  ## Parameters

  * `pid` - The pid of the MetricsStore
  * `metrics` - The list of metrics to push
  """
  def push_metrics(pid, metrics) do
    Enum.each(metrics, fn metric -> push_metric(pid, metric) end)
  end

  @doc """
  Collects all metrics and formats them for Prometheus exposition.

  ## Parameters

  * `pid` - The pid of the MetricsStore
  """
  def collect_runtime_metrics(pid) do
    # Collect runtime metrics
    runtime_metrics = Oak.Collector.Runtime.collect()

    # Add server status metric
    status_metric = %Oak.Metric.Gauge{
      name: "oak_up",
      help: "Oak prometheus server status",
      labels: %{},
      value: 1
    }

    push_metrics(pid, [status_metric | runtime_metrics])
  end

  @doc """
  Outputs the metrics in Prometheus exposition format.

  ## Parameters

  * `pid` - The pid of the MetricsStore
  """
  def output_metrics(pid) do
    get_metrics(pid)
    |> Map.values()
    |> format_metrics
  end

  @doc """
  Formats a list of metrics for Prometheus exposition.

  ## Parameters

  * `metrics` - The list of metrics to format
  """
  def format_metrics(metrics) when is_list(metrics) do
    metrics
    |> Enum.map(&format_metric/1)
    |> Enum.join("\n")
  end

  defp format_metric(metric) do
    case metric do
      %Oak.Metric.Counter{} -> Oak.Metric.Counter.to_string(metric)
      %Oak.Metric.Gauge{} -> Oak.Metric.Gauge.to_string(metric)
      %Oak.Metric.Histogram{} -> Oak.Metric.Histogram.to_string(metric)
      %Oak.Metric.Summary{} -> Oak.Metric.Summary.to_string(metric)
      _ -> ""
    end
  end
end
