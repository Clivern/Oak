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
        Counter.new("http_requests_total", "Total number of HTTP requests", %{method: "GET"})

      assert counter.labels == %{method: "GET"}
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
  end

  describe "value/1" do
    test "returns the current value of the counter" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(3)

      assert Counter.value(counter) == 3
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
  end

  describe "to_string/1" do
    test "returns string representation without labels" do
      counter =
        Counter.new("test_counter", "Test counter")
        |> Counter.inc(5)

      assert Counter.to_string(counter) == "test_counter 5"
    end

    test "returns string representation with labels" do
      counter =
        Counter.new("http_requests_total", "Total number of HTTP requests", %{
          method: "GET",
          status: "200"
        })
        |> Counter.inc(15)

      assert Counter.to_string(counter) == "http_requests_total{status=\"200\",method=\"GET\"} 15"
    end
  end
end
