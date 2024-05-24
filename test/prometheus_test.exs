# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.PrometheusTest do
  use ExUnit.Case
  alias Oak.Prometheus
  alias Oak.Metric.{Counter, Gauge, Histogram, Summary}

  # Helper function to start a Prometheus server for specific tests
  defp start_test_server(opts \\ []) do
    test_name = "test_#{:rand.uniform(10000)}"
    # Always use a unique port, even if one is specified in opts
    port = 9000 + :rand.uniform(1000)
    opts = Keyword.merge([port: port, name: String.to_atom(test_name)], opts)
    # Override any port that was passed in to ensure uniqueness
    opts = Keyword.put(opts, :port, port)
    Prometheus.start_link(opts)
  end

  describe "start_link/1" do
    test "starts with default options" do
      {:ok, pid} = start_test_server()
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "starts with custom port" do
      {:ok, pid} = start_test_server(port: 9092)
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  describe "collect_metrics/0" do
    test "returns basic metrics" do
      metrics = Prometheus.collect_metrics()
      assert String.contains?(metrics, "# HELP oak_up")
      assert String.contains?(metrics, "# TYPE oak_up gauge")
      assert String.contains?(metrics, "oak_up 1")
    end
  end

  describe "format_metrics/1" do
    test "formats counter metrics" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(5)

      metrics = Prometheus.format_metrics([counter])
      assert String.contains?(metrics, "# HELP test_counter Test counter")
      assert String.contains?(metrics, "# TYPE test_counter counter")
      assert String.contains?(metrics, "test_counter 5")
    end

    test "formats gauge metrics" do
      gauge =
        Gauge.new("test_gauge", "Test gauge")
        |> Gauge.set(42.5)

      metrics = Prometheus.format_metrics([gauge])
      assert String.contains?(metrics, "# HELP test_gauge Test gauge")
      assert String.contains?(metrics, "test_gauge 42.5")
    end

    test "formats histogram metrics" do
      histogram =
        Histogram.new("test_histogram", "Test histogram", [1, 5, 10])
        |> Histogram.observe(3.0)
        |> Histogram.observe(7.0)

      metrics = Prometheus.format_metrics([histogram])
      assert String.contains?(metrics, "# HELP test_histogram Test histogram")
      assert String.contains?(metrics, "# TYPE test_histogram histogram")
      assert String.contains?(metrics, "test_histogram_bucket{le=\"1\"} 0")
      assert String.contains?(metrics, "test_histogram_bucket{le=\"5\"} 1")
      assert String.contains?(metrics, "test_histogram_bucket{le=\"10\"} 2")
      assert String.contains?(metrics, "test_histogram_bucket{le=\"+Inf\"} 2")
      assert String.contains?(metrics, "test_histogram_sum 10.0")
      assert String.contains?(metrics, "test_histogram_count 2")
    end

    test "formats summary metrics" do
      summary =
        Summary.new("test_summary", "Test summary", [0.5, 0.9])
        |> Summary.observe(10.0)
        |> Summary.observe(20.0)

      metrics = Prometheus.format_metrics([summary])
      assert String.contains?(metrics, "# HELP test_summary Test summary")
      assert String.contains?(metrics, "# TYPE test_summary summary")
      assert String.contains?(metrics, "test_summary{quantile=\"0.5\"}")
      assert String.contains?(metrics, "test_summary{quantile=\"0.9\"}")
      assert String.contains?(metrics, "test_summary_sum 30.0")
      assert String.contains?(metrics, "test_summary_count 2")
    end

    test "formats multiple metrics" do
      counter = Counter.new("test_counter", "Test counter") |> Counter.inc(5)
      gauge = Gauge.new("test_gauge", "Test gauge") |> Gauge.set(42.5)

      metrics = Prometheus.format_metrics([counter, gauge])
      assert String.contains?(metrics, "test_counter 5")
      assert String.contains?(metrics, "test_gauge 42.5")
    end

    test "handles empty metrics list" do
      metrics = Prometheus.format_metrics([])
      assert metrics == ""
    end

    test "ignores unknown metric types" do
      metrics = Prometheus.format_metrics([%{unknown: "metric"}])
      assert metrics == ""
    end
  end
end
