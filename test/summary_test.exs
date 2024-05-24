# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.SummaryTest do
  use ExUnit.Case
  alias Oak.Metric.Summary

  describe "new/4" do
    test "creates a new summary with default quantiles and labels" do
      summary = Summary.new("http_request_duration_seconds", "HTTP request duration")
      assert summary.name == "http_request_duration_seconds"
      assert summary.help == "HTTP request duration"
      assert summary.labels == %{}
      assert summary.quantiles == [0.5, 0.9, 0.95, 0.99]
      assert summary.sum == 0
      assert summary.count == 0
      assert summary.observations == []
    end

    test "creates a new summary with custom quantiles" do
      summary = Summary.new("test_summary", "Test summary", [0.1, 0.5, 0.9])
      assert summary.quantiles == [0.1, 0.5, 0.9]
    end

    test "creates a new summary with custom labels" do
      summary =
        Summary.new("http_request_duration_seconds", "HTTP request duration", [0.5, 0.9], %{
          method: "GET"
        })

      assert summary.labels == %{method: "GET"}
    end
  end

  describe "observe/2" do
    test "observes a value and updates sum and count" do
      summary = Summary.new("test_summary", "Test summary")
      updated_summary = Summary.observe(summary, 10.5)

      assert updated_summary.sum == 10.5
      assert updated_summary.count == 1
      assert updated_summary.observations == [10.5]
    end

    test "observes multiple values" do
      summary = Summary.new("test_summary", "Test summary")

      updated_summary =
        summary
        |> Summary.observe(10.0)
        |> Summary.observe(20.0)
        |> Summary.observe(30.0)

      assert updated_summary.sum == 60.0
      assert updated_summary.count == 3
      assert length(updated_summary.observations) == 3
    end
  end

  describe "sum/1" do
    test "returns the current sum of all observed values" do
      summary =
        Summary.new("test_summary", "Test summary")
        |> Summary.observe(5.5)
        |> Summary.observe(10.5)

      assert Summary.sum(summary) == 16.0
    end
  end

  describe "count/1" do
    test "returns the current count of observations" do
      summary =
        Summary.new("test_summary", "Test summary")
        |> Summary.observe(1.0)
        |> Summary.observe(2.0)
        |> Summary.observe(3.0)

      assert Summary.count(summary) == 3
    end
  end

  describe "quantile/2" do
    test "calculates median (0.5 quantile)" do
      summary =
        Summary.new("test_summary", "Test summary")
        |> Summary.observe(1.0)
        |> Summary.observe(2.0)
        |> Summary.observe(3.0)
        |> Summary.observe(4.0)
        |> Summary.observe(5.0)

      assert Summary.quantile(summary, 0.5) == 3.0
    end

    test "calculates 0.9 quantile" do
      summary =
        Summary.new("test_summary", "Test summary")
        |> Summary.observe(1.0)
        |> Summary.observe(2.0)
        |> Summary.observe(3.0)
        |> Summary.observe(4.0)
        |> Summary.observe(5.0)

      assert Summary.quantile(summary, 0.9) == 5.0
    end

    test "returns 0 for empty observations" do
      summary = Summary.new("test_summary", "Test summary")
      assert Summary.quantile(summary, 0.5) == 0
    end

    test "handles single observation" do
      summary =
        Summary.new("test_summary", "Test summary")
        |> Summary.observe(10.0)

      assert Summary.quantile(summary, 0.5) == 10.0
    end
  end

  describe "to_string/1" do
    test "returns string representation without labels" do
      summary =
        Summary.new("test_summary", "Test summary", [0.5, 0.9])
        |> Summary.observe(10.0)
        |> Summary.observe(20.0)

      result = Summary.to_string(summary)

      assert String.contains?(result, "# HELP test_summary Test summary")
      assert String.contains?(result, "# TYPE test_summary summary")
      assert String.contains?(result, "test_summary{quantile=\"0.5\"}")
      assert String.contains?(result, "test_summary{quantile=\"0.9\"}")
      assert String.contains?(result, "test_summary_sum 30.0")
      assert String.contains?(result, "test_summary_count 2")
    end

    test "returns string representation with labels" do
      summary =
        Summary.new("http_request_duration_seconds", "HTTP request duration", [0.5, 0.9], %{
          method: "GET"
        })
        |> Summary.observe(0.1)
        |> Summary.observe(0.2)

      result = Summary.to_string(summary)

      assert String.contains?(
               result,
               "# HELP http_request_duration_seconds HTTP request duration"
             )

      assert String.contains?(result, "# TYPE http_request_duration_seconds summary")

      assert String.contains?(
               result,
               "http_request_duration_seconds{method=\"GET\",quantile=\"0.5\"}"
             )

      assert String.contains?(
               result,
               "http_request_duration_seconds{method=\"GET\",quantile=\"0.9\"}"
             )

      assert String.contains?(result, "http_request_duration_seconds_sum{method=\"GET\"} 0.3")
      assert String.contains?(result, "http_request_duration_seconds_count{method=\"GET\"} 2")
    end
  end
end
