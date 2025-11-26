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

  @impl true
  def handle_call({:update, template, fun}, _from, state) do
    metric_id = get_metric_id(template)
    current = Map.get(state, metric_id, template)

    # Errors (e.g. a negative counter increment) must not crash the store,
    # since that would lose every metric it holds.
    try do
      updated = fun.(current)
      {:reply, :ok, Map.put(state, metric_id, updated)}
    rescue
      error -> {:reply, {:error, error}, state}
    end
  end

  @doc """
  Atomically applies `fun` to the stored metric that has the same id as `template`.

  If no such metric is stored yet, `template` is used as the starting point.
  `fun` receives the current metric and must return the updated metric.

  Because the change runs inside the store process, concurrent callers never
  overwrite each other's updates. Returns `:ok`, or `{:error, exception}` if
  `fun` raises, in which case the stored state is left unchanged.

  ## Parameters

  * `pid` - The pid of the MetricsStore
  * `template` - A metric whose id identifies the stored metric
  * `fun` - A one-argument function that returns the updated metric
  """
  def update(pid, template, fun) when is_function(fun, 1) do
    GenServer.call(pid, {:update, template, fun})
  end

  @doc """
  Atomically increments a counter or gauge in the store by `amount` (defaults to 1).
  """
  def inc(pid, metric, amount \\ 1)

  def inc(pid, %Oak.Metric.Counter{} = counter, amount) do
    update(pid, counter, &Oak.Metric.Counter.inc(&1, amount))
  end

  def inc(pid, %Oak.Metric.Gauge{} = gauge, amount) do
    update(pid, gauge, &Oak.Metric.Gauge.inc(&1, amount))
  end

  @doc """
  Atomically decrements a gauge in the store by `amount` (defaults to 1).
  """
  def dec(pid, %Oak.Metric.Gauge{} = gauge, amount \\ 1) do
    update(pid, gauge, &Oak.Metric.Gauge.dec(&1, amount))
  end

  @doc """
  Atomically sets a gauge in the store to `value`.
  """
  def set(pid, %Oak.Metric.Gauge{} = gauge, value) do
    update(pid, gauge, &Oak.Metric.Gauge.set(&1, value))
  end

  @doc """
  Atomically records `value` in a histogram or summary in the store.
  """
  def observe(pid, %Oak.Metric.Histogram{} = histogram, value) do
    update(pid, histogram, &Oak.Metric.Histogram.observe(&1, value))
  end

  def observe(pid, %Oak.Metric.Summary{} = summary, value) do
    update(pid, summary, &Oak.Metric.Summary.observe(&1, value))
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
