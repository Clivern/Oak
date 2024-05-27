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

    test "handles empty buckets list" do
      histogram = Histogram.new("test", "Test histogram", [])
      assert histogram.buckets == ["+Inf"]
      assert histogram.bucket_counts == %{"+Inf" => 0}
    end

    test "handles single bucket" do
      histogram = Histogram.new("test", "Test histogram", [1.0])
      assert histogram.buckets == [1.0, "+Inf"]
      assert histogram.bucket_counts == %{1.0 => 0, "+Inf" => 0}
    end

    test "handles duplicate buckets" do
      assert_raise RuntimeError, "buckets must be unique", fn ->
        Histogram.new("test", "Test histogram", [0.1, 0.1, 0.3])
      end
    end

    test "handles negative bucket values" do
      histogram = Histogram.new("test", "Test histogram", [-1.0, 0.0, 1.0])
      assert histogram.buckets == [-1.0, 0.0, 1.0, "+Inf"]
    end

    test "raises error for empty name" do
      assert_raise RuntimeError, "name and help cannot be empty", fn ->
        Histogram.new("", "Test histogram", [0.1, 0.3, 0.5])
      end
    end

    test "raises error for empty help" do
      assert_raise RuntimeError, "name and help cannot be empty", fn ->
        Histogram.new("test", "", [0.1, 0.3, 0.5])
      end
    end

    test "handles complex labels" do
      labels = %{method: "POST", status: "200", endpoint: "/api/users"}
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5], labels)
      assert histogram.labels == labels
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

    test "handles zero value", %{histogram: histogram} do
      updated = Histogram.observe(histogram, 0.0)
      assert updated.sum == 0.0
      assert updated.count == 1
      assert updated.bucket_counts == %{0.1 => 1, 0.3 => 1, 0.5 => 1, "+Inf" => 1}
    end

    test "handles negative values", %{histogram: histogram} do
      updated = Histogram.observe(histogram, -0.1)
      assert updated.sum == -0.1
      assert updated.count == 1
      assert updated.bucket_counts == %{0.1 => 1, 0.3 => 1, 0.5 => 1, "+Inf" => 1}
    end

    test "handles exact bucket boundary values", %{histogram: histogram} do
      updated = Histogram.observe(histogram, 0.1)
      assert updated.bucket_counts == %{0.1 => 1, 0.3 => 1, 0.5 => 1, "+Inf" => 1}
    end

    test "handles very large values", %{histogram: histogram} do
      updated = Histogram.observe(histogram, 1_000_000.0)
      assert updated.sum == 1_000_000.0
      assert updated.count == 1
      assert updated.bucket_counts == %{0.1 => 0, 0.3 => 0, 0.5 => 0, "+Inf" => 1}
    end

    test "handles very small values", %{histogram: histogram} do
      updated = Histogram.observe(histogram, 0.000001)
      assert updated.sum == 0.000001
      assert updated.count == 1
      assert updated.bucket_counts == %{0.1 => 1, 0.3 => 1, 0.5 => 1, "+Inf" => 1}
    end

    test "handles integer values", %{histogram: histogram} do
      updated = Histogram.observe(histogram, 1)
      assert updated.sum == 1.0
      assert updated.count == 1
      assert updated.bucket_counts == %{0.1 => 0, 0.3 => 0, 0.5 => 0, "+Inf" => 1}
    end

    test "handles many observations efficiently", %{histogram: histogram} do
      updated =
        Enum.reduce(1..1000, histogram, fn i, acc ->
          Histogram.observe(acc, i * 0.001)
        end)

      assert updated.count == 1000
      assert updated.sum > 0
      assert updated.bucket_counts["+Inf"] == 1000
    end
  end

  describe "sum/1" do
    test "returns the current sum" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      updated = Histogram.observe(histogram, 0.2)
      assert Histogram.sum(updated) == 0.2
    end

    test "returns zero for new histogram" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      assert Histogram.sum(histogram) == 0
    end

    test "returns cumulative sum after multiple observations" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])

      updated =
        histogram |> Histogram.observe(0.2) |> Histogram.observe(0.4) |> Histogram.observe(0.6)

      assert Histogram.sum(updated) == 1.2000000000000002
    end
  end

  describe "count/1" do
    test "returns the current count" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      updated = Histogram.observe(histogram, 0.2)
      assert Histogram.count(updated) == 1
    end

    test "returns zero for new histogram" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      assert Histogram.count(histogram) == 0
    end

    test "returns cumulative count after multiple observations" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])

      updated =
        histogram |> Histogram.observe(0.2) |> Histogram.observe(0.4) |> Histogram.observe(0.6)

      assert Histogram.count(updated) == 3
    end
  end

  describe "bucket_counts/1" do
    test "returns the current bucket counts" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      updated = Histogram.observe(histogram, 0.2)
      assert Histogram.bucket_counts(updated) == %{0.1 => 0, 0.3 => 1, 0.5 => 1, "+Inf" => 1}
    end

    test "returns empty bucket counts for new histogram" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      assert Histogram.bucket_counts(histogram) == %{0.1 => 0, 0.3 => 0, 0.5 => 0, "+Inf" => 0}
    end

    test "returns updated bucket counts after multiple observations" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])

      updated =
        histogram |> Histogram.observe(0.2) |> Histogram.observe(0.4) |> Histogram.observe(0.6)

      bucket_counts = Histogram.bucket_counts(updated)
      assert bucket_counts[0.1] == 0
      assert bucket_counts[0.3] == 1
      assert bucket_counts[0.5] == 2
      assert bucket_counts["+Inf"] == 3
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

    test "formats histogram with multiple labels" do
      histogram =
        Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5], %{method: "POST", status: "200"})
        |> Histogram.observe(0.2)

      result = Histogram.to_string(histogram)
      assert String.contains?(result, "method=\"POST\"")
      assert String.contains?(result, "status=\"200\"")
      assert String.contains?(result, "le=\"0.1\"")
    end

    test "formats histogram with no observations" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5])
      result = Histogram.to_string(histogram)

      assert String.contains?(result, "# HELP test Test histogram")
      assert String.contains?(result, "# TYPE test histogram")
      assert String.contains?(result, "test_bucket{le=\"0.1\"} 0")
      assert String.contains?(result, "test_sum 0")
      assert String.contains?(result, "test_count 0")
    end

    test "formats histogram with empty buckets" do
      histogram = Histogram.new("test", "Test histogram", [])
      result = Histogram.to_string(histogram)

      assert String.contains?(result, "test_bucket{le=\"+Inf\"} 0")
      assert String.contains?(result, "test_sum 0")
      assert String.contains?(result, "test_count 0")
    end

    test "formats histogram with special characters in name" do
      histogram =
        Histogram.new("http_request_duration_seconds", "HTTP request duration", [0.1, 0.3, 0.5])

      result = Histogram.to_string(histogram)

      assert String.contains?(result, "http_request_duration_seconds_bucket")
      assert String.contains?(result, "http_request_duration_seconds_sum")
      assert String.contains?(result, "http_request_duration_seconds_count")
    end

    test "formats histogram with numeric labels" do
      histogram =
        Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5], %{status_code: 404, port: 8080})
        |> Histogram.observe(0.2)

      result = Histogram.to_string(histogram)
      assert String.contains?(result, "status_code=\"404\"")
      assert String.contains?(result, "port=\"8080\"")
    end

    test "formats histogram with boolean labels" do
      histogram =
        Histogram.new("test", "Test histogram", [0.1, 0.3, 0.5], %{success: true, debug: false})
        |> Histogram.observe(0.2)

      result = Histogram.to_string(histogram)
      assert String.contains?(result, "success=\"true\"")
      assert String.contains?(result, "debug=\"false\"")
    end
  end

  describe "edge cases and error handling" do
    test "handles very small bucket values" do
      histogram = Histogram.new("test", "Test histogram", [0.000001, 0.00001, 0.0001])
      updated = Histogram.observe(histogram, 0.000005)
      assert updated.bucket_counts[0.00001] == 1
    end

    test "handles very large bucket values" do
      histogram = Histogram.new("test", "Test histogram", [1_000_000, 10_000_000, 100_000_000])
      updated = Histogram.observe(histogram, 5_000_000)
      assert updated.bucket_counts[10_000_000] == 1
    end

    test "handles mixed positive and negative buckets" do
      histogram = Histogram.new("test", "Test histogram", [-1.0, 0.0, 1.0])
      updated = Histogram.observe(histogram, -0.5)
      assert updated.bucket_counts[-1.0] == 0
      assert updated.bucket_counts[0.0] == 1
    end

    test "handles zero bucket values" do
      histogram = Histogram.new("test", "Test histogram", [-1.0, 0.0, 1.0])
      updated = Histogram.observe(histogram, 0.0)
      assert updated.bucket_counts[0.0] == 1
      assert updated.bucket_counts[1.0] == 1
      assert updated.bucket_counts["+Inf"] == 1
    end

    test "handles floating point precision issues" do
      histogram = Histogram.new("test", "Test histogram", [0.1, 0.2, 0.3])
      updated = Histogram.observe(histogram, 0.1 + 0.2)
      # 0.1 + 0.2 = 0.30000000000000004 in floating point
      assert updated.bucket_counts[0.3] == 0
      assert updated.bucket_counts["+Inf"] == 1
    end
  end
end
