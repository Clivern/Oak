defmodule Oak.PrometheusTest do
  use ExUnit.Case, async: false
  alias Oak.Prometheus
  alias Oak.MetricsStore
  alias Oak.Metric.{Counter, Gauge, Histogram, Summary}

  setup do
    # Start a fresh MetricsStore for each test with a unique name
    test_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    name = String.to_atom("test_store_#{test_id}")
    {:ok, store_pid} = GenServer.start_link(MetricsStore, %{}, name: name)
    %{store: store_pid}
  end

  describe "get_metrics/1" do
    test "returns empty map when no metrics", %{store: store} do
      metrics = Prometheus.get_metrics(store)
      assert metrics == %{}
    end

    test "returns all stored metrics", %{store: store} do
      counter = Counter.new("test_counter", "Test counter", %{})
      gauge = Gauge.new("test_gauge", "Test gauge", %{})

      GenServer.call(store, {:push, counter})
      GenServer.call(store, {:push, gauge})

      metrics = Prometheus.get_metrics(store)
      assert map_size(metrics) == 2
      assert Map.get(metrics, Counter.id(counter)) == counter
      assert Map.get(metrics, Gauge.id(gauge)) == gauge
    end
  end

  describe "push_metric/2" do
    test "pushes a single metric", %{store: store} do
      counter = Counter.new("http_requests", "HTTP requests", %{method: "GET"})

      assert :ok = Prometheus.push_metric(store, counter)

      # Verify metric was stored
      stored_metric = GenServer.call(store, {:get, Counter.id(counter)})
      assert stored_metric == counter
    end

    test "pushes different metric types", %{store: store} do
      counter = Counter.new("counter", "Counter", %{})
      gauge = Gauge.new("gauge", "Gauge", %{})
      histogram = Histogram.new("histogram", "Histogram", [0.1, 0.5, 1.0], %{})
      summary = Summary.new("summary", "Summary", [0.5, 0.9], %{})

      assert :ok = Prometheus.push_metric(store, counter)
      assert :ok = Prometheus.push_metric(store, gauge)
      assert :ok = Prometheus.push_metric(store, histogram)
      assert :ok = Prometheus.push_metric(store, summary)

      all_metrics = Prometheus.get_metrics(store)
      assert map_size(all_metrics) == 4
    end
  end

  describe "push_metrics/2" do
    test "pushes multiple metrics at once", %{store: store} do
      metrics = [
        Counter.new("counter1", "First counter", %{}),
        Counter.new("counter2", "Second counter", %{}),
        Gauge.new("gauge1", "First gauge", %{})
      ]

      Prometheus.push_metrics(store, metrics)

      all_metrics = Prometheus.get_metrics(store)
      assert map_size(all_metrics) == 3

      Enum.each(metrics, fn metric ->
        metric_id = get_metric_id(metric)
        stored_metric = Map.get(all_metrics, metric_id)
        assert stored_metric == metric
      end)
    end

    test "handles empty list", %{store: store} do
      Prometheus.push_metrics(store, [])

      all_metrics = Prometheus.get_metrics(store)
      assert all_metrics == %{}
    end
  end

  describe "collect_runtime_metrics/1" do
    test "collects and pushes runtime metrics", %{store: store} do
      Prometheus.collect_runtime_metrics(store)

      all_metrics = Prometheus.get_metrics(store)

      # Should have at least the oak_up metric
      assert map_size(all_metrics) >= 1

      # Check for oak_up metric
      oak_up_metric =
        Enum.find(all_metrics, fn {_id, metric} ->
          metric.name == "oak_up"
        end)

      assert oak_up_metric != nil
      {_id, metric} = oak_up_metric
      assert metric.name == "oak_up"
      assert metric.help == "Oak prometheus server status"
      assert metric.value == 1
      assert metric.labels == %{}
    end
  end

  describe "output_metrics/1" do
    test "formats metrics for Prometheus exposition", %{store: store} do
      counter = Counter.new("test_counter", "Test counter", %{label: "value"})
      gauge = Gauge.new("test_gauge", "Test gauge", %{})

      Prometheus.push_metric(store, counter)
      Prometheus.push_metric(store, gauge)

      formatted_output = Prometheus.output_metrics(store)

      # Should contain HELP and TYPE lines for each metric
      assert String.contains?(formatted_output, "# HELP test_counter Test counter")
      assert String.contains?(formatted_output, "# TYPE test_counter counter")
      assert String.contains?(formatted_output, "# HELP test_gauge Test gauge")
      assert String.contains?(formatted_output, "# TYPE test_gauge gauge")

      # Should contain metric values
      assert String.contains?(formatted_output, "test_counter{label=\"value\"} 0")
      assert String.contains?(formatted_output, "test_gauge 0")
    end

    test "handles metrics with complex labels", %{store: store} do
      counter =
        Counter.new("complex_counter", "Complex counter", %{
          method: "POST",
          status: "201",
          endpoint: "/users"
        })

      Prometheus.push_metric(store, counter)

      formatted_output = Prometheus.output_metrics(store)

      # Should contain the complex labels
      assert String.contains?(
               formatted_output,
               "complex_counter{endpoint=\"/users\",method=\"POST\",status=\"201\"} 0"
             )
    end

    test "handles empty metrics store", %{store: store} do
      formatted_output = Prometheus.output_metrics(store)
      assert formatted_output == ""
    end
  end

  describe "format_metrics/1" do
    test "formats list of metrics correctly" do
      counter = Counter.new("format_test", "Format test", %{})
      gauge = Gauge.new("format_test", "Format test", %{})

      metrics = [counter, gauge]

      formatted = Prometheus.format_metrics(metrics)

      assert String.contains?(formatted, "# HELP format_test Format test")
      assert String.contains?(formatted, "# TYPE format_test counter")
      assert String.contains?(formatted, "# TYPE format_test gauge")
    end

    test "handles empty list" do
      formatted = Prometheus.format_metrics([])
      assert formatted == ""
    end
  end

  describe "integration" do
    test "complete workflow from collection to output", %{store: store} do
      # 1. Collect runtime metrics
      Prometheus.collect_runtime_metrics(store)

      # 2. Add custom metrics
      custom_metrics = [
        Counter.new("custom_counter", "Custom counter", %{service: "api"}),
        Gauge.new("custom_gauge", "Custom gauge", %{instance: "web"})
      ]

      Prometheus.push_metrics(store, custom_metrics)

      # 3. Get all metrics
      all_metrics = Prometheus.get_metrics(store)
      # runtime + oak_up + custom metrics
      assert map_size(all_metrics) >= 3

      # 4. Output in Prometheus format
      formatted_output = Prometheus.output_metrics(store)

      # Should contain all metric types
      assert String.contains?(formatted_output, "custom_counter")
      assert String.contains?(formatted_output, "custom_gauge")
      assert String.contains?(formatted_output, "oak_up")

      # Should be valid Prometheus format
      assert String.contains?(formatted_output, "# HELP")
      assert String.contains?(formatted_output, "# TYPE")
    end
  end

  # Helper function to get metric ID based on type
  defp get_metric_id(%Counter{} = metric), do: Counter.id(metric)
  defp get_metric_id(%Gauge{} = metric), do: Gauge.id(metric)
  defp get_metric_id(%Histogram{} = metric), do: Histogram.id(metric)
  defp get_metric_id(%Summary{} = metric), do: Summary.id(metric)
end
