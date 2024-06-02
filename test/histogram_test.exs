# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.HistogramTest do
  use ExUnit.Case
  alias Oak.Metric.Histogram

  describe "new/4" do
    test "creates a new histogram with default labels" do
      histogram =
        Histogram.new("http_request_duration_seconds", "HTTP request duration in seconds", [
          0.1,
          0.3,
          0.5
        ])

      assert histogram.name == "http_request_duration_seconds"
      assert histogram.help == "HTTP request duration in seconds"
      assert histogram.labels == %{}
      assert histogram.buckets == [0.1, 0.3, 0.5, "+Inf"]
      assert histogram.sum == 0
      assert histogram.count == 0
      assert histogram.bucket_counts == %{0.1 => 0, 0.3 => 0, 0.5 => 0, "+Inf" => 0}
    end

    test "creates a new histogram with custom labels" do
      histogram =
        Histogram.new(
          "http_request_duration_seconds",
          "HTTP request duration in seconds",
          [0.1, 0.3, 0.5],
          %{method: "GET"}
        )

      assert histogram.labels == %{method: "GET"}
    end

    test "sorts buckets and adds +Inf" do
      histogram = Histogram.new("test", "Test histogram", [0.5, 0.1, 0.3])
      assert histogram.buckets == [0.1, 0.3, 0.5, "+Inf"]
    end
  end

  describe "observe/2" do
    setup do
      {:ok, histogram: Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])}
    end

    test "updates sum and count", %{histogram: histogram} do
      updated = Histogram.observe(histogram, 0.2)
      assert updated.sum == 0.2
      assert updated.count == 1
    end

    test "updates correct buckets", %{histogram: histogram} do
      updated = Histogram.observe(histogram, 0.2)
      assert updated.bucket_counts == %{0.1 => 0, 0.3 => 1, 0.5 => 1, "+Inf" => 1}
    end

    test "handles values above all buckets", %{histogram: histogram} do
      updated = Histogram.observe(histogram, 1.0)
      assert updated.bucket_counts == %{0.1 => 0, 0.3 => 0, 0.5 => 0, "+Inf" => 1}
    end

    test "handles multiple observations", %{histogram: histogram} do
      updated = histogram |> Histogram.observe(0.2) |> Histogram.observe(0.4)
      assert updated.sum == 0.6000000000000001
      assert updated.count == 2
      assert updated.bucket_counts == %{0.1 => 0, 0.3 => 1, 0.5 => 2, "+Inf" => 2}
    end
  end

  describe "sum/1" do
    test "returns the current sum" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      updated = Histogram.observe(histogram, 0.2)
      assert Histogram.sum(updated) == 0.2
    end
  end

  describe "count/1" do
    test "returns the current count" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      updated = Histogram.observe(histogram, 0.2)
      assert Histogram.count(updated) == 1
    end
  end

  describe "to_string/1" do
    test "formats histogram without labels" do
      histogram =
        Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
        |> Histogram.observe(0.2)
        |> Histogram.observe(0.4)

      expected = """
      # HELP test Test histogram
      # TYPE test histogram
      test_bucket{le="0.1"} 0
      test_bucket{le="0.3"} 1
      test_bucket{le="0.5"} 2
      test_bucket{le="+Inf"} 2
      test_sum 0.6000000000000001
      test_count 2
      """

      assert String.trim(Histogram.to_string(histogram)) == String.trim(expected)
    end

    test "formats histogram with labels" do
      histogram =
        Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5], %{method: "GET"})
        |> Histogram.observe(0.2)

      expected = """
      # HELP test Test histogram
      # TYPE test histogram
      test_bucket{method="GET",le="0.1"} 0
      test_bucket{method="GET",le="0.3"} 1
      test_bucket{method="GET",le="0.5"} 1
      test_bucket{method="GET",le="+Inf"} 1
      test_sum{method="GET"} 0.2
      test_count{method="GET"} 1
      """

      assert String.trim(Histogram.to_string(histogram)) == String.trim(expected)
    end
  end
end
