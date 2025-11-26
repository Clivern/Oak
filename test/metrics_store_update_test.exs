# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.MetricsStoreUpdateTest do
  use ExUnit.Case, async: false
  alias Oak.MetricsStore
  alias Oak.Metric.{Counter, Gauge, Histogram, Summary}

  setup do
    test_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    name = String.to_atom("test_store_update_#{test_id}")
    {:ok, pid} = GenServer.start_link(MetricsStore, %{}, name: name)
    %{store: pid}
  end

  defp stored(store, metric), do: GenServer.call(store, {:get, Counter.id(metric)})

  describe "inc/3 for counters" do
    test "creates the counter from the template when absent", %{store: store} do
      counter = Counter.new("hits_total", "Hits", %{route: "/"})

      assert :ok = MetricsStore.inc(store, counter, 3)
      assert Counter.value(stored(store, counter)) == 3
    end

    test "defaults the amount to 1", %{store: store} do
      counter = Counter.new("hits_total", "Hits")

      assert :ok = MetricsStore.inc(store, counter)
      assert :ok = MetricsStore.inc(store, counter)
      assert Counter.value(stored(store, counter)) == 2
    end

    test "concurrent increments are not lost", %{store: store} do
      counter = Counter.new("concurrent_total", "Concurrent increments")

      1..20
      |> Task.async_stream(
        fn _ -> Enum.each(1..50, fn _ -> MetricsStore.inc(store, counter) end) end,
        max_concurrency: 20,
        timeout: 10_000
      )
      |> Stream.run()

      assert Counter.value(stored(store, counter)) == 1000
    end

    test "returns an error and keeps state when the amount is invalid", %{store: store} do
      counter = Counter.new("hits_total", "Hits")
      assert :ok = MetricsStore.inc(store, counter, 5)

      assert {:error, _} = MetricsStore.inc(store, counter, -1)

      # The store process survives and the value is unchanged.
      assert Process.alive?(store)
      assert Counter.value(stored(store, counter)) == 5
    end
  end

  describe "gauges" do
    test "set/3 stores the value", %{store: store} do
      gauge = Gauge.new("temp", "Temperature")

      assert :ok = MetricsStore.set(store, gauge, 21.5)
      assert Gauge.value(stored(store, gauge)) == 21.5
    end

    test "inc/3 and dec/3 adjust the stored value", %{store: store} do
      gauge = Gauge.new("queue_depth", "Queue depth")

      assert :ok = MetricsStore.inc(store, gauge, 10)
      assert :ok = MetricsStore.dec(store, gauge, 4)
      assert Gauge.value(stored(store, gauge)) == 6
    end
  end

  describe "histograms and summaries" do
    test "observe/3 updates a histogram", %{store: store} do
      histogram = Histogram.new("duration", "Duration", [0.1, 1.0])

      assert :ok = MetricsStore.observe(store, histogram, 0.5)
      assert :ok = MetricsStore.observe(store, histogram, 2.0)

      stored = GenServer.call(store, {:get, Histogram.id(histogram)})
      assert Histogram.count(stored) == 2
      assert Histogram.sum(stored) == 2.5
    end

    test "observe/3 updates a summary", %{store: store} do
      summary = Summary.new("size", "Size")

      assert :ok = MetricsStore.observe(store, summary, 4)
      assert :ok = MetricsStore.observe(store, summary, 6)

      stored = GenServer.call(store, {:get, Summary.id(summary)})
      assert Summary.count(stored) == 2
      assert Summary.sum(stored) == 10
    end
  end

  describe "update/3" do
    test "applies an arbitrary function to the stored metric", %{store: store} do
      counter = Counter.new("custom_total", "Custom")
      assert :ok = MetricsStore.inc(store, counter, 2)

      assert :ok = MetricsStore.update(store, counter, &Counter.set(&1, 42))
      assert Counter.value(stored(store, counter)) == 42
    end

    test "does not change the store when the function raises", %{store: store} do
      counter = Counter.new("custom_total", "Custom")
      assert :ok = MetricsStore.inc(store, counter, 2)

      assert {:error, %RuntimeError{}} =
               MetricsStore.update(store, counter, fn _ -> raise "boom" end)

      assert Counter.value(stored(store, counter)) == 2
    end
  end
end
