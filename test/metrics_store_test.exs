# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.MetricsStoreTest do
  use ExUnit.Case, async: false
  alias Oak.MetricsStore

  setup do
    # Start a fresh metrics store for each test
    {:ok, pid} = MetricsStore.start_link()
    {:ok, %{store: pid}}
  end

  describe "counter metrics" do
    test "can push and increment counters", %{store: _store} do
      # Push a counter
      assert :ok = MetricsStore.push_counter("test_counter", "Test counter", %{label: "value"})

      # Increment it
      assert :ok = MetricsStore.inc_counter("test_counter", %{label: "value"})
      assert :ok = MetricsStore.inc_counter("test_counter", %{label: "value"})

      # Get the metric
      metric = MetricsStore.get_metric("test_counter", %{label: "value"})
      assert metric.value == 3
    end

    test "creates counter automatically when incrementing", %{store: _store} do
      # Increment non-existent counter
      assert :ok = MetricsStore.inc_counter("auto_counter", %{auto: "created"})

      # Should be created with value 1
      metric = MetricsStore.get_metric("auto_counter", %{auto: "created"})
      assert metric.value == 1
    end
  end

  describe "gauge metrics" do
    test "can push and set gauges", %{store: _store} do
      # Push a gauge
      assert :ok = MetricsStore.push_gauge("test_gauge", "Test gauge", %{label: "value"})

      # Set its value
      assert :ok = MetricsStore.set_gauge("test_gauge", 42, %{label: "value"})

      # Get the metric
      metric = MetricsStore.get_metric("test_gauge", %{label: "value"})
      assert metric.value == 42
    end

    test "creates gauge automatically when setting", %{store: _store} do
      # Set non-existent gauge
      assert :ok = MetricsStore.set_gauge("auto_gauge", 100, %{auto: "created"})

      # Should be created with the set value
      metric = MetricsStore.get_metric("auto_gauge", %{auto: "created"})
      assert metric.value == 100
    end
  end

  describe "histogram metrics" do
    test "can push and observe histograms", %{store: _store} do
      # Push a histogram
      assert :ok = MetricsStore.push_histogram("test_histogram", "Test histogram", [0.1, 0.5, 1.0], %{label: "value"})

      # Observe values
      assert :ok = MetricsStore.observe_histogram("test_histogram", 0.3, %{label: "value"})
      assert :ok = MetricsStore.observe_histogram("test_histogram", 0.7, %{label: "value"})

      # Get the metric
      metric = MetricsStore.get_metric("test_histogram", %{label: "value"})
      assert metric.count == 2
      assert metric.sum == 1.0
    end

    test "creates histogram automatically when observing", %{store: _store} do
      # Observe non-existent histogram
      assert :ok = MetricsStore.observe_histogram("auto_histogram", 0.5, %{auto: "created"})

      # Should be created with default buckets (including +Inf)
      metric = MetricsStore.get_metric("auto_histogram", %{auto: "created"})
      assert metric.buckets == [0.1, 0.5, 1.0, 2.0, 5.0, "+Inf"]
    end
  end

  describe "summary metrics" do
    test "can push and observe summaries", %{store: _store} do
      # Push a summary
      assert :ok = MetricsStore.push_summary("test_summary", "Test summary", [0.5, 0.9, 0.99], %{label: "value"})

      # Observe values
      assert :ok = MetricsStore.observe_summary("test_summary", 10, %{label: "value"})
      assert :ok = MetricsStore.observe_summary("test_summary", 20, %{label: "value"})

      # Get the metric
      metric = MetricsStore.get_metric("test_summary", %{label: "value"})
      assert metric.count == 2
      assert metric.sum == 30
    end

    test "creates summary automatically when observing", %{store: _store} do
      # Observe non-existent summary
      assert :ok = MetricsStore.observe_summary("auto_summary", 15, %{auto: "created"})

      # Should be created with default quantiles
      metric = MetricsStore.get_metric("auto_summary", %{auto: "created"})
      assert metric.quantiles == [0.5, 0.9, 0.95, 0.99]
    end
  end

  describe "fetching metrics" do
    test "returns metrics in Prometheus format", %{store: _store} do
      # Add some metrics
      MetricsStore.inc_counter("test_counter", %{label: "value"})
      MetricsStore.set_gauge("test_gauge", 42, %{label: "value"})

      # Fetch all metrics
      metrics_string = MetricsStore.fetch_metrics()

      # Should contain the up metric
      assert metrics_string =~ "# HELP oak_up Oak server status"
      assert metrics_string =~ "# TYPE oak_up gauge"
      assert metrics_string =~ "oak_up 1"

      # Should contain our metrics
      assert metrics_string =~ "test_counter"
      assert metrics_string =~ "test_gauge"
    end

    test "returns only up metric when no custom metrics exist", %{store: _store} do
      metrics_string = MetricsStore.fetch_metrics()

      # Should only contain the up metric
      assert metrics_string =~ "# HELP oak_up Oak server status"
      assert metrics_string =~ "# TYPE oak_up gauge"
      assert metrics_string =~ "oak_up 1"

      # Should not contain any other metrics
      refute metrics_string =~ "test_counter"
    end
  end

  describe "metric labels" do
    test "handles different label combinations correctly", %{store: _store} do
      # Same metric name, different labels
      MetricsStore.inc_counter("labeled_counter", %{service: "web", endpoint: "/users"})
      MetricsStore.inc_counter("labeled_counter", %{service: "api", endpoint: "/users"})

      # Should be treated as separate metrics
      web_metric = MetricsStore.get_metric("labeled_counter", %{service: "web", endpoint: "/users"})
      api_metric = MetricsStore.get_metric("labeled_counter", %{service: "api", endpoint: "/users"})

      assert web_metric.value == 1
      assert api_metric.value == 1
      assert web_metric != api_metric
    end

    test "handles empty labels", %{store: _store} do
      MetricsStore.inc_counter("no_labels_counter", %{})

      metric = MetricsStore.get_metric("no_labels_counter", %{})
      assert metric.value == 1
    end
  end
end
