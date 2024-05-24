# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.CounterTest do
  use ExUnit.Case
  alias Oak.Metric.Counter

  describe "new/3" do
    test "creates a new counter with default labels" do
      counter = Counter.new("http_requests_total", "Total number of HTTP requests")

      assert counter.name == "http_requests_total"
      assert counter.help == "Total number of HTTP requests"
      assert counter.labels == %{}
      assert counter.value == 0
    end

    test "creates a new counter with custom labels" do
      counter =
        Counter.new(
          "http_requests_total",
          "Total number of HTTP requests",
          %{method: "GET"}
        )

      assert counter.labels == %{method: "GET"}
    end

    test "creates a new counter with empty string name and help" do
      counter = Counter.new("", "")
      assert counter.name == ""
      assert counter.help == ""
      assert counter.value == 0
    end

    test "creates a new counter with complex labels" do
      labels = %{
        method: "POST",
        status: "500",
        endpoint: "/api/users",
        version: "v1.0"
      }

      counter = Counter.new("api_errors_total", "Total API errors", labels)
      assert counter.labels == labels
      assert map_size(counter.labels) == 4
    end

    test "creates a new counter with numeric labels" do
      labels = %{status_code: 404, port: 8080}
      counter = Counter.new("http_errors", "HTTP errors", labels)
      assert counter.labels == labels
    end
  end

  describe "inc/2" do
    test "increments the counter by 1 by default" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc()

      assert Counter.value(counter) == 1
    end

    test "increments the counter by a specified amount" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(5)

      assert Counter.value(counter) == 5
    end

    test "does not change when incrementing by 0" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(0)

      assert Counter.value(counter) == 0
    end

    test "raises error when incrementing by negative value" do
      counter = Counter.new("test_counter", "Test counter")

      assert_raise FunctionClauseError, fn ->
        Counter.inc(counter, -1)
      end
    end

    test "increments multiple times correctly" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(1)
        |> Counter.inc(2)
        |> Counter.inc(3)

      assert Counter.value(counter) == 6
    end

    test "increments by large values" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(1_000_000)

      assert Counter.value(counter) == 1_000_000
    end

    test "increments by maximum integer value" do
      max_int = 9_223_372_036_854_775_807

      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(max_int)

      assert Counter.value(counter) == max_int
    end

    test "raises error when incrementing by non-integer" do
      counter = Counter.new("test_counter", "Test counter")

      assert_raise FunctionClauseError, fn ->
        Counter.inc(counter, 1.5)
      end

      assert_raise FunctionClauseError, fn ->
        Counter.inc(counter, "invalid")
      end

      assert_raise FunctionClauseError, fn ->
        Counter.inc(counter, :atom)
      end
    end
  end

  describe "value/1" do
    test "returns the current value of the counter" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(3)

      assert Counter.value(counter) == 3
    end

    test "returns zero for new counter" do
      counter = Counter.new("test_counter", "Test counter")
      assert Counter.value(counter) == 0
    end

    test "returns value after multiple operations" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(10)
        |> Counter.set(25)
        |> Counter.inc(5)
        |> Counter.reset()
        |> Counter.inc(7)

      assert Counter.value(counter) == 7
    end
  end

  describe "set/1" do
    test "set the counter to 20" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(10)
        |> Counter.set(20)

      assert Counter.value(counter) == 20
    end

    test "set the counter to zero" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(100)
        |> Counter.set(0)

      assert Counter.value(counter) == 0
    end

    test "set the counter to large value" do
      large_value = 1_000_000_000

      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.set(large_value)

      assert Counter.value(counter) == large_value
    end

    test "raises error when setting negative value" do
      counter = Counter.new("test_counter", "Test counter")

      assert_raise FunctionClauseError, fn ->
        Counter.set(counter, -5)
      end
    end

    test "raises error when setting non-integer value" do
      counter = Counter.new("test_counter", "Test counter")

      assert_raise FunctionClauseError, fn ->
        Counter.set(counter, 1.5)
      end

      assert_raise FunctionClauseError, fn ->
        Counter.set(counter, "invalid")
      end
    end

    test "set with default value of 1" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(50)
        |> Counter.set()

      assert Counter.value(counter) == 1
    end
  end

  describe "reset/1" do
    test "resets the counter to zero" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(10)
        |> Counter.reset()

      assert Counter.value(counter) == 0
    end

    test "reset already zero counter" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.reset()

      assert Counter.value(counter) == 0
    end

    test "reset after set operation" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.set(999)
        |> Counter.reset()

      assert Counter.value(counter) == 0
    end

    test "reset multiple times" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(100)
        |> Counter.reset()
        |> Counter.inc(50)
        |> Counter.reset()

      assert Counter.value(counter) == 0
    end
  end

  describe "to_string/1" do
    test "returns string representation without labels" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(5)

      assert Counter.to_string(counter) ==
               "# HELP test_counter Test counter\n# TYPE test_counter counter\ntest_counter 5\n"
    end

    test "returns string representation with labels" do
      counter =
        Counter.new("http_requests_total", "Total number of HTTP requests", %{
          method: "GET",
          status: "200"
        })
        |> Counter.inc(15)

      assert Counter.to_string(counter) ==
               "# HELP http_requests_total Total number of HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{status=\"200\",method=\"GET\"} 15\n" ||
               Counter.to_string(counter) ==
                 "# HELP http_requests_total Total number of HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{method=\"GET\",status=\"200\"} 15\n"
    end

    test "returns string representation with empty name and help" do
      counter =
        Counter.new("", "")
        |> Counter.inc(42)

      assert Counter.to_string(counter) ==
               "# HELP  \n# TYPE  counter\n 42\n"
    end

    test "returns string representation with complex labels" do
      counter =
        Counter.new("database_queries", "Database query count", %{
          database: "postgres",
          table: "users",
          operation: "SELECT",
          shard: "shard_01"
        })
        |> Counter.inc(1234)

      result = Counter.to_string(counter)
      assert String.contains?(result, "# HELP database_queries Database query count")
      assert String.contains?(result, "# TYPE database_queries counter")
      assert String.contains?(result, "database_queries{")
      assert String.contains?(result, "database=\"postgres\"")
      assert String.contains?(result, "table=\"users\"")
      assert String.contains?(result, "operation=\"SELECT\"")
      assert String.contains?(result, "shard=\"shard_01\"")
      assert String.contains?(result, "} 1234")
    end

    test "returns string representation with numeric labels" do
      counter =
        Counter.new("http_errors", "HTTP error count", %{
          status_code: 500,
          port: 8080
        })
        |> Counter.inc(99)

      result = Counter.to_string(counter)
      assert String.contains?(result, "status_code=\"500\"")
      assert String.contains?(result, "port=\"8080\"")
      assert String.contains?(result, "} 99")
    end

    test "returns string representation with zero value" do
      counter = Counter.new("empty_counter", "Empty counter")

      assert Counter.to_string(counter) ==
               "# HELP empty_counter Empty counter\n# TYPE empty_counter counter\nempty_counter 0\n"
    end

    test "returns string representation with large value" do
      large_value = 9_999_999_999

      counter =
        Counter.new("large_counter", "Large counter")
        |> Counter.set(large_value)

      result = Counter.to_string(counter)
      assert String.contains?(result, "large_counter #{large_value}")
    end
  end

  describe "immutability" do
    test "operations return new counter instances" do
      original = Counter.new("test_counter", "Test counter")

      incremented = Counter.inc(original, 5)
      assert original.value == 0
      assert incremented.value == 5
      assert original !== incremented

      set_counter = Counter.set(original, 10)
      assert original.value == 0
      assert set_counter.value == 10
      assert original !== set_counter

      reset_counter = Counter.reset(original)
      assert original.value == 0
      assert reset_counter.value == 0
      assert original === reset_counter
    end

    test "labels remain unchanged after operations" do
      labels = %{method: "POST", endpoint: "/api"}
      counter = Counter.new("api_calls", "API calls", labels)

      incremented = Counter.inc(counter, 1)
      assert incremented.labels == labels

      set_counter = Counter.set(counter, 100)
      assert set_counter.labels == labels

      reset_counter = Counter.reset(counter)
      assert reset_counter.labels == labels
    end
  end

  describe "edge cases" do
    test "handles very long names and help text" do
      long_name = String.duplicate("a", 1000)
      long_help = String.duplicate("This is a very long help text. ", 50)

      counter = Counter.new(long_name, long_help)
      assert counter.name == long_name
      assert counter.help == long_help

      result = Counter.to_string(counter)
      assert String.contains?(result, long_name)
      assert String.contains?(result, long_help)
    end

    test "handles special characters in names and labels" do
      special_name = "metric-with_underscores.and.dots"

      special_labels = %{
        "label-with-dash" => "value_with_underscore",
        "label.with.dots" => "value-with-dash"
      }

      counter = Counter.new(special_name, "Special metric", special_labels)
      assert counter.name == special_name
      assert counter.labels == special_labels

      result = Counter.to_string(counter)
      assert String.contains?(result, special_name)
      assert String.contains?(result, "label-with-dash=\"value_with_underscore\"")
      assert String.contains?(result, "label.with.dots=\"value-with-dash\"")
    end

    test "handles empty labels map" do
      counter = Counter.new("test", "test", %{})
      assert counter.labels == %{}

      result = Counter.to_string(counter)
      assert String.contains?(result, "test 0")
      refute String.contains?(result, "{}")
    end
  end
end
