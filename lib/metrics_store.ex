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

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Oak MetricsStore started")
    {:ok, %{metrics: %{}, counters: %{}, gauges: %{}, histograms: %{}, summaries: %{}}}
  end

  @doc """
  Pushes a metric to the store.

  ## Examples

      iex> counter = Oak.Metric.Counter.new("http_requests_total", "Total HTTP requests")
      iex> Oak.MetricsStore.push_metric(counter)
      :ok
  """
  @spec push_metric(metric()) :: :ok
  def push_metric(metric) do
    GenServer.cast(__MODULE__, {:push_metric, metric})
  end

  @doc """
  Pushes a counter metric to the store.

  ## Examples

      iex> Oak.MetricsStore.push_counter("http_requests_total", "Total HTTP requests", %{endpoint: "/api/users"})
      :ok
  """
  @spec push_counter(String.t(), String.t(), map()) :: :ok
  def push_counter(name, help, labels \\ %{}) do
    counter = Oak.Metric.Counter.new(name, help, labels)
    push_metric(counter)
  end

  @doc """
  Pushes a gauge metric to the store.

  ## Examples

      iex> Oak.MetricsStore.push_gauge("active_connections", "Number of active connections", %{service: "database"})
      :ok
  """
  @spec push_gauge(String.t(), String.t(), map()) :: :ok
  def push_gauge(name, help, labels \\ %{}) do
    gauge = Oak.Metric.Gauge.new(name, help, labels)
    push_metric(gauge)
  end

  @doc """
  Pushes a histogram metric to the store.

  ## Examples

      iex> Oak.MetricsStore.push_histogram("http_request_duration_seconds", "HTTP request duration", [0.1, 0.5, 1.0, 2.0, 5.0])
      :ok
  """
  @spec push_histogram(String.t(), String.t(), list(), map()) :: :ok
  def push_histogram(name, help, buckets, labels \\ %{}) do
    histogram = Oak.Metric.Histogram.new(name, help, buckets, labels)
    push_metric(histogram)
  end

  @doc """
  Pushes a summary metric to the store.

  ## Examples

      iex> Oak.MetricsStore.push_summary("http_request_duration_seconds", "HTTP request duration", [0.5, 0.9, 0.99], labels: %{endpoint: "/api"})
      :ok
  """
  @spec push_summary(String.t(), String.t(), list(), map()) :: :ok
  def push_summary(name, help, quantiles, labels \\ %{}) do
    summary = Oak.Metric.Summary.new(name, help, quantiles, labels)
    push_metric(summary)
  end

  @doc """
  Increments a counter by name and labels.

  ## Examples

      iex> Oak.MetricsStore.inc_counter("http_requests_total", %{endpoint: "/api/users"})
      :ok
  """
  @spec inc_counter(String.t(), map()) :: :ok
  def inc_counter(name, labels \\ %{}) do
    GenServer.cast(__MODULE__, {:inc_counter, name, labels})
  end

  @doc """
  Sets a gauge value by name and labels.

  ## Examples

      iex> Oak.MetricsStore.set_gauge("active_connections", 42, %{service: "database"})
      :ok
  """
  @spec set_gauge(String.t(), number(), map()) :: :ok
  def set_gauge(name, value, labels \\ %{}) do
    GenServer.cast(__MODULE__, {:set_gauge, name, value, labels})
  end

  @doc """
  Observes a histogram value by name and labels.

  ## Examples

      iex> Oak.MetricsStore.observe_histogram("http_request_duration_seconds", 0.5, %{endpoint: "/api/users"})
      :ok
  """
  @spec observe_histogram(String.t(), number(), map()) :: :ok
  def observe_histogram(name, value, labels \\ %{}) do
    GenServer.cast(__MODULE__, {:observe_histogram, name, value, labels})
  end

  @doc """
  Observes a summary value by name and labels.

  ## Examples

      iex> Oak.MetricsStore.observe_summary("http_request_duration_seconds", 0.5, %{endpoint: "/api/users"})
      :ok
  """
  @spec observe_summary(String.t(), number(), map()) :: :ok
  def observe_summary(name, value, labels \\ %{}) do
    GenServer.cast(__MODULE__, {:observe_summary, name, value, labels})
  end

  @doc """
  Fetches all metrics in Prometheus exposition format.

  This is the main function you'll call from your Phoenix controller
  to expose metrics for Prometheus scraping.

  ## Examples

      iex> Oak.MetricsStore.fetch_metrics()
      "# HELP oak_up Oak server status\\n# TYPE oak_up gauge\\noak_up 1\\n..."
  """
  @spec fetch_metrics() :: String.t()
  def fetch_metrics do
    GenServer.call(__MODULE__, :fetch_metrics)
  end

  @doc """
  Gets a specific metric by name and labels.
  """
  @spec get_metric(String.t(), map()) :: metric() | nil
  def get_metric(name, labels \\ %{}) do
    GenServer.call(__MODULE__, {:get_metric, name, labels})
  end

  @doc """
  Gets all stored metrics as a map.
  """
  @spec get_all_metrics() :: map()
  def get_all_metrics do
    GenServer.call(__MODULE__, :get_all_metrics)
  end

  # GenServer callbacks

  def handle_cast({:push_metric, metric}, state) do
    key = metric_key(metric)
    new_state = update_metric_in_state(state, metric, key)
    {:noreply, new_state}
  end

    def handle_cast({:inc_counter, name, labels}, state) do
    case get_metric_from_state(state, name, labels) do
      nil ->
        # Create new counter if it doesn't exist
        counter = Oak.Metric.Counter.new(name, "Counter for #{name}", labels)
        key = metric_key(counter)
        new_state = update_metric_in_state(state, counter, key)
        Logger.debug("Created new counter #{name} with key #{key}")
        {:noreply, new_state}

      counter ->
        # Increment existing counter
        updated_counter = Oak.Metric.Counter.inc(counter)
        key = metric_key(updated_counter)
        new_state = update_metric_in_state(state, updated_counter, key)
        Logger.debug("Incremented counter #{name} from #{counter.value} to #{updated_counter.value}")
        {:noreply, new_state}
    end
  end

  def handle_cast({:set_gauge, name, value, labels}, state) do
    case get_metric_from_state(state, name, labels) do
      nil ->
        # Create new gauge if it doesn't exist
        gauge = Oak.Metric.Gauge.new(name, "Gauge for #{name}", labels)
        updated_gauge = Oak.Metric.Gauge.set(gauge, value)
        key = metric_key(updated_gauge)
        new_state = update_metric_in_state(state, updated_gauge, key)
        {:noreply, new_state}

      gauge ->
        # Set existing gauge value
        updated_gauge = Oak.Metric.Gauge.set(gauge, value)
        key = metric_key(updated_gauge)
        new_state = update_metric_in_state(state, updated_gauge, key)
        {:noreply, new_state}
    end
  end

  def handle_cast({:observe_histogram, name, value, labels}, state) do
    case get_metric_from_state(state, name, labels) do
      nil ->
        # Create new histogram if it doesn't exist
        histogram = Oak.Metric.Histogram.new(name, "Histogram for #{name}", [0.1, 0.5, 1.0, 2.0, 5.0], labels)
        updated_histogram = Oak.Metric.Histogram.observe(histogram, value)
        key = metric_key(updated_histogram)
        new_state = update_metric_in_state(state, updated_histogram, key)
        {:noreply, new_state}

      histogram ->
        # Observe existing histogram
        updated_histogram = Oak.Metric.Histogram.observe(histogram, value)
        key = metric_key(updated_histogram)
        new_state = update_metric_in_state(state, updated_histogram, key)
        {:noreply, new_state}
    end
  end

  def handle_cast({:observe_summary, name, value, labels}, state) do
    case get_metric_from_state(state, name, labels) do
      nil ->
        # Create new summary if it doesn't exist
        summary = Oak.Metric.Summary.new(name, "Summary for #{name}", [0.5, 0.9, 0.95, 0.99], labels)
        updated_summary = Oak.Metric.Summary.observe(summary, value)
        key = metric_key(updated_summary)
        new_state = update_metric_in_state(state, updated_summary, key)
        {:noreply, new_state}

      summary ->
        # Observe existing summary
        updated_summary = Oak.Metric.Summary.observe(summary, value)
        key = metric_key(updated_summary)
        new_state = update_metric_in_state(state, updated_summary, key)
        {:noreply, new_state}
    end
  end

  def handle_call(:fetch_metrics, _from, state) do
    metrics_string = format_all_metrics_for_prometheus(state)
    {:reply, metrics_string, state}
  end

  def handle_call({:get_metric, name, labels}, _from, state) do
    metric = get_metric_from_state(state, name, labels)
    {:reply, metric, state}
  end

  def handle_call(:get_all_metrics, _from, state) do
    {:reply, state, state}
  end

  # Private functions

  defp metric_key(metric) do
    labels_str =
      metric.labels
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}:#{v}" end)
      |> Enum.join("|")

    "#{metric.name}|#{labels_str}"
  end

  defp get_metric_from_state(state, name, labels) do
    # Create a temporary struct with the same structure as actual metrics
    temp_metric = %{name: name, labels: labels}
    key = metric_key(temp_metric)
    Map.get(state.metrics, key)
  end

  defp update_metric_in_state(state, metric, key) do
    %{state | metrics: Map.put(state.metrics, key, metric)}
  end

  defp format_all_metrics_for_prometheus(state) do
    # Add a default up metric
    up_metric = """
    # HELP oak_up Oak server status
    # TYPE oak_up gauge
    oak_up 1
    """

    # Format all stored metrics
    metrics_strings =
      state.metrics
      |> Map.values()
      |> Enum.map(&format_metric_for_prometheus/1)
      |> Enum.join("\n")

    if metrics_strings == "" do
      up_metric
    else
      up_metric <> "\n" <> metrics_strings
    end
  end

  defp format_metric_for_prometheus(metric) do
    case metric do
      %Oak.Metric.Counter{} -> Oak.Metric.Counter.to_string(metric)
      %Oak.Metric.Gauge{} -> Oak.Metric.Gauge.to_string(metric)
      %Oak.Metric.Histogram{} -> Oak.Metric.Histogram.to_string(metric)
      %Oak.Metric.Summary{} -> Oak.Metric.Summary.to_string(metric)
      _ -> ""
    end
  end
end
