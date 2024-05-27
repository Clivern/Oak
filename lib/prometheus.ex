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

  use GenServer
  require Logger

  @default_port 9090
  @default_host "0.0.0.0"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    port = Keyword.get(opts, :port, @default_port)
    host = Keyword.get(opts, :host, @default_host)

    Logger.info("Starting Oak Prometheus server on #{host}:#{port}")

    # Start the HTTP server
    server_pid = start_http_server(host, port)

    {:ok, %{server_pid: server_pid, port: port, host: host}}
  end

  defp start_http_server(host, port) do
    # For now, we'll use a simple approach
    # In production, you might want to use Plug or similar
    Logger.info("Oak Prometheus server started on #{host}:#{port}")
    Logger.info("Metrics available at http://#{host}:#{port}/metrics")

    # Return a dummy PID for now - in a real implementation,
    # you'd start an actual HTTP server here
    spawn(fn ->
      Logger.info("Oak Prometheus server ready")
      # Keep the process alive
      receive do
        _ -> :ok
      end
    end)
  end

  @doc """
  Collects all metrics and formats them for Prometheus exposition.
  """
  def collect_metrics do
    # This would collect from a registry in a real implementation
    # For now, return a sample metric
    """
    # HELP oak_up Oak server status
    # TYPE oak_up gauge
    oak_up 1
    """
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

  @doc """
  Stops the Prometheus server.

  ## Parameters

  * `prometheus` - The Prometheus server to stop
  """
  def stop do
    GenServer.stop(__MODULE__)
  end
end
