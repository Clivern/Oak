# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Metric.GaugeTest do
  use ExUnit.Case
  alias Oak.Metric.Gauge

  describe "new/3" do
    test "creates a new gauge with default labels" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      assert gauge.name == "my_gauge"
      assert gauge.help == "Description of my gauge"
      assert gauge.labels == %{}
      assert gauge.value == 0
    end

    test "creates a new gauge with custom labels" do
      gauge =
        Gauge.new("my_gauge", "Description of my gauge", %{label1: "value1", label2: "value2"})

      assert gauge.labels == %{label1: "value1", label2: "value2"}
    end
  end

  describe "set/2" do
    test "sets the gauge value to the given amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      assert gauge.value == 10
    end

    test "sets the gauge value to zero" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 0)
      assert gauge.value == 0
    end
  end

  describe "inc/2" do
    test "increments the gauge by the given amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.inc(gauge, 5)
      assert gauge.value == 15
    end

    test "increments the gauge by default amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.inc(gauge)
      assert gauge.value == 11
    end
  end

  describe "dec/2" do
    test "decrements the gauge by the given amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.dec(gauge, 5)
      assert gauge.value == 5
    end

    test "decrements the gauge by default amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.dec(gauge)
      assert gauge.value == 9
    end
  end

  describe "value/1" do
    test "returns the current value of the gauge" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      assert Gauge.value(gauge) == 10
    end
  end

  describe "to_string/1" do
    test "returns a string representation of the gauge in Prometheus exposition format" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)

      expected_output = """
      # HELP my_gauge Description of my gauge
      # TYPE my_gauge gauge
      my_gauge 10
      """

      assert Gauge.to_string(gauge) == expected_output
    end

    test "returns a string representation of the gauge with labels in Prometheus exposition format" do
      gauge =
        Gauge.new("my_gauge", "Description of my gauge", %{label1: "value1", label2: "value2"})

      gauge = Gauge.set(gauge, 10)

      expected_output = """
      # HELP my_gauge Description of my gauge
      # TYPE my_gauge gauge
      my_gauge{label1="value1",label2="value2"} 10
      """

      assert Gauge.to_string(gauge) == expected_output
    end
  end
end
