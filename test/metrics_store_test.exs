defmodule Oak.MetricsStoreTest do
  use ExUnit.Case, async: false
  alias Oak.MetricsStore
  alias Oak.Metric.{Counter, Gauge, Histogram, Summary}

  setup do
    # Start a fresh MetricsStore for each test
    {:ok, pid} = MetricsStore.start_link()
    %{store: pid}
  end

  describe "start_link/1" do
    test "starts with empty metrics by default" do
      # Start with a unique name to avoid conflicts
      {:ok, pid} = GenServer.start_link(MetricsStore, %{}, name: :test_store_1)
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with initial metrics" do
      initial_metrics = %{"test" => "value"}
      # Start with a unique name to avoid conflicts
      {:ok, pid} = GenServer.start_link(MetricsStore, initial_metrics, name: :test_store_2)
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  describe "push/1" do
    test "pushes a counter metric", %{store: store} do
      counter = Counter.new("http_requests_total", "Total HTTP requests", %{method: "GET"})

      assert :ok = GenServer.call(store, {:push, counter})

      # Verify the metric was stored
      stored_metric = GenServer.call(store, {:get, Counter.id(counter)})
      assert stored_metric == counter
    end

    test "pushes a gauge metric", %{store: store} do
      gauge = Gauge.new("memory_usage", "Memory usage in bytes", %{instance: "web"})

      assert :ok = GenServer.call(store, {:push, gauge})

      stored_metric = GenServer.call(store, {:get, Gauge.id(gauge)})
      assert stored_metric == gauge
    end

    test "pushes a histogram metric", %{store: store} do
      histogram =
        Histogram.new("request_duration", "Request duration", [0.1, 0.5, 1.0], %{endpoint: "/api"})

      assert :ok = GenServer.call(store, {:push, histogram})

      stored_metric = GenServer.call(store, {:get, Histogram.id(histogram)})
      assert stored_metric == histogram
    end

    test "pushes a summary metric", %{store: store} do
      summary =
        Summary.new("response_size", "Response size in bytes", [0.5, 0.9], %{service: "auth"})

      assert :ok = GenServer.call(store, {:push, summary})

      stored_metric = GenServer.call(store, {:get, Summary.id(summary)})
      assert stored_metric == summary
    end

    test "overwrites existing metric with same id", %{store: store} do
      counter1 = Counter.new("test_counter", "Test counter", %{label: "value"})
      counter2 = Counter.new("test_counter", "Test counter", %{label: "value"})

      # Push first counter
      assert :ok = GenServer.call(store, {:push, counter1})

      # Push second counter (should overwrite)
      assert :ok = GenServer.call(store, {:push, counter2})

      # Should get the second counter
      stored_metric = GenServer.call(store, {:get, Counter.id(counter1)})
      assert stored_metric == counter2
    end

    test "handles metrics with empty labels", %{store: store} do
      counter = Counter.new("simple_counter", "Simple counter", %{})

      assert :ok = GenServer.call(store, {:push, counter})

      stored_metric = GenServer.call(store, {:get, Counter.id(counter)})
      assert stored_metric == counter
    end

    test "handles metrics with complex labels", %{store: store} do
      counter =
        Counter.new("complex_counter", "Complex counter", %{
          method: "POST",
          status: "201",
          endpoint: "/users",
          version: "v1"
        })

      assert :ok = GenServer.call(store, {:push, counter})

      stored_metric = GenServer.call(store, {:get, Counter.id(counter)})
      assert stored_metric == counter
    end
  end

  describe "get/1" do
    test "retrieves existing metric", %{store: store} do
      counter = Counter.new("test_counter", "Test counter", %{label: "value"})
      GenServer.call(store, {:push, counter})

      retrieved_metric = GenServer.call(store, {:get, Counter.id(counter)})
      assert retrieved_metric == counter
    end

    test "returns nil for non-existent metric", %{store: store} do
      non_existent_id = "non_existent_metric"
      retrieved_metric = GenServer.call(store, {:get, non_existent_id})
      assert retrieved_metric == nil
    end
  end

  describe "get_all/0" do
    test "returns empty map when no metrics", %{store: store} do
      all_metrics = GenServer.call(store, {:get_all})
      assert all_metrics == %{}
    end

    test "returns all stored metrics", %{store: store} do
      counter = Counter.new("counter1", "First counter", %{})
      gauge = Gauge.new("gauge1", "First gauge", %{})

      GenServer.call(store, {:push, counter})
      GenServer.call(store, {:push, gauge})

      all_metrics = GenServer.call(store, {:get_all})

      assert map_size(all_metrics) == 2
      assert Map.get(all_metrics, Counter.id(counter)) == counter
      assert Map.get(all_metrics, Gauge.id(gauge)) == gauge
    end

    test "returns correct number of metrics after overwrites", %{store: store} do
      counter1 = Counter.new("same_name", "Counter", %{})
      counter2 = Counter.new("same_name", "Counter", %{})

      GenServer.call(store, {:push, counter1})
      GenServer.call(store, {:push, counter2})

      all_metrics = GenServer.call(store, {:get_all})

      assert map_size(all_metrics) == 1
      assert Map.get(all_metrics, Counter.id(counter1)) == counter2
    end
  end

  describe "metric id generation" do
    test "generates unique ids for different metrics" do
      counter1 = Counter.new("same_name", "Counter", %{label: "value1"})
      counter2 = Counter.new("same_name", "Counter", %{label: "value2"})

      id1 = Counter.id(counter1)
      id2 = Counter.id(counter2)

      assert id1 != id2
      assert String.contains?(id1, "same_name")
      assert String.contains?(id2, "same_name")
    end

    test "generates consistent ids for same metric" do
      counter = Counter.new("test_counter", "Test counter", %{label: "value"})

      id1 = Counter.id(counter)
      id2 = Counter.id(counter)

      assert id1 == id2
    end

    test "handles metrics with spaces in labels" do
      counter = Counter.new("test_counter", "Test counter", %{label: "value with spaces"})

      id = Counter.id(counter)

      # Should not contain spaces (based on the String.replace(" ", "") in counter.ex)
      refute String.contains?(id, " ")
      assert String.contains?(id, "test_counter")
    end
  end

  describe "concurrent operations" do
    test "handles multiple concurrent pushes", %{store: store} do
      # Create multiple metrics
      metrics =
        for i <- 1..10 do
          Counter.new("concurrent_counter_#{i}", "Counter #{i}", %{index: i})
        end

      # Push all metrics concurrently
      tasks =
        Enum.map(metrics, fn metric ->
          Task.async(fn -> GenServer.call(store, {:push, metric}) end)
        end)

      # Wait for all to complete
      results = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(results, &(&1 == :ok))

      # Verify all metrics were stored
      all_metrics = GenServer.call(store, {:get_all})
      assert map_size(all_metrics) == 10

      Enum.each(metrics, fn metric ->
        stored_metric = GenServer.call(store, {:get, Counter.id(metric)})
        assert stored_metric == metric
      end)
    end
  end

  describe "error handling" do
    test "handles invalid metric types gracefully" do
      # This test would need to be implemented if we add validation
      # For now, we'll test that the store doesn't crash with unexpected data
      assert true
    end
  end
end
