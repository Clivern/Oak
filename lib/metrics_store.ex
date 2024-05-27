# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.MetricsStore do
  @moduledoc """
  A centralized store for managing metrics across a Phoenix application.

  This store acts as a registry where different parts of your app can push metrics,
  and controllers can fetch all metrics in Prometheus format for scraping.
  """

  use GenServer
  require Logger

  def start_link(metrics \\ %{}) do
    GenServer.start_link(__MODULE__, metrics, name: __MODULE__)
  end

  @impl true
  def init(metrics) do
    Logger.debug("MetricsStore initialized with metrics: #{inspect(metrics)}")
    {:ok, metrics}
  end

  @impl true
  def handle_call({:push, metric}, _from, state) do
    metric_id = get_metric_id(metric)
    Logger.debug("Pushing metric: #{inspect(metric)} with id: #{metric_id}")
    state = Map.put(state, metric_id, metric)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, metric_id}, _from, state) do
    metric = Map.get(state, metric_id)
    Logger.debug("Getting metric: #{inspect(metric)} with id: #{metric_id}")
    {:reply, metric, state}
  end

  @impl true
  def handle_call({:get_all}, _from, state) do
    {:reply, state, state}
  end

  defp get_metric_id(%Oak.Metric.Counter{} = metric), do: Oak.Metric.Counter.id(metric)
  defp get_metric_id(%Oak.Metric.Gauge{} = metric), do: Oak.Metric.Gauge.id(metric)
  defp get_metric_id(%Oak.Metric.Histogram{} = metric), do: Oak.Metric.Histogram.id(metric)
  defp get_metric_id(%Oak.Metric.Summary{} = metric), do: Oak.Metric.Summary.id(metric)

  @doc """
  Stops the MetricsStore.
  """
  def stop do
    GenServer.stop(__MODULE__)
  end
end
