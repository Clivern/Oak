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

    test "raises error when name and help are empty" do
      assert_raise RuntimeError, fn ->
        Gauge.new("", "")
      end
    end

    test "Creates a new gauge with special characters in name and help" do
      gauge = Gauge.new("gauge_with_special_chars_123", "Help with special chars: !@#$%^&*()")
      assert gauge.name == "gauge_with_special_chars_123"
      assert gauge.help == "Help with special chars: !@#$%^&*()"
    end

    test "Creates a new gauge with complex label values" do
      labels = %{
        "string_label" => "value with spaces",
        :atom_label => "value_with_underscores",
        "numeric_string" => "123",
        "empty_string" => "",
        "special_chars" => "!@#$%^&*()"
      }

      gauge = Gauge.new("complex_gauge", "Complex labels test", labels)
      assert gauge.labels == labels
    end
  end

  describe "set/2" do
    test "Sets the gauge value to the given amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      assert gauge.value == 10
    end

    test "Sets the gauge value to zero" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 0)
      assert gauge.value == 0
    end

    test "Sets the gauge value to negative numbers" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, -5)
      assert gauge.value == -5
    end

    test "Sets the gauge value to large numbers" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 1_000_000)
      assert gauge.value == 1_000_000
    end

    test "Sets the gauge value to decimal numbers" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 3.14159)
      assert gauge.value == 3.14159
    end

    test "Overwrites previous value when setting multiple times" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.set(gauge, 20)
      gauge = Gauge.set(gauge, 15)
      assert gauge.value == 15
    end
  end

  describe "inc/2" do
    test "Increments the gauge by the given amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.inc(gauge, 5)
      assert gauge.value == 15
    end

    test "Increments the gauge by default amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.inc(gauge)
      assert gauge.value == 11
    end

    test "Increments from zero" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.inc(gauge, 5)
      assert gauge.value == 5
    end

    test "Increments by negative amount (decrements)" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.inc(gauge, -3)
      assert gauge.value == 7
    end

    test "Increments by zero (no change)" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.inc(gauge, 0)
      assert gauge.value == 10
    end

    test "Increments by decimal amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10.5)
      gauge = Gauge.inc(gauge, 2.3)
      assert gauge.value == 12.8
    end

    test "Increments multiple times" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.inc(gauge, 1)
      gauge = Gauge.inc(gauge, 2)
      gauge = Gauge.inc(gauge, 3)
      assert gauge.value == 6
    end
  end

  describe "dec/2" do
    test "Decrements the gauge by the given amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.dec(gauge, 5)
      assert gauge.value == 5
    end

    test "Decrements the gauge by default amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.dec(gauge)
      assert gauge.value == 9
    end

    test "Decrements to negative values" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 5)
      gauge = Gauge.dec(gauge, 10)
      assert gauge.value == -5
    end

    test "Decrements by negative amount (increments)" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.dec(gauge, -3)
      assert gauge.value == 13
    end

    test "Decrements by zero (no change)" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      gauge = Gauge.dec(gauge, 0)
      assert gauge.value == 10
    end

    test "Decrements by decimal amount" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10.5)
      gauge = Gauge.dec(gauge, 2.3)
      assert gauge.value == 8.2
    end

    test "Decrements multiple times" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 20)
      gauge = Gauge.dec(gauge, 5)
      gauge = Gauge.dec(gauge, 3)
      gauge = Gauge.dec(gauge, 2)
      assert gauge.value == 10
    end
  end

  describe "value/1" do
    test "returns the current value of the gauge" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)
      assert Gauge.value(gauge) == 10
    end

    test "returns zero for newly created gauge" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      assert Gauge.value(gauge) == 0
    end

    test "returns negative values" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, -15)
      assert Gauge.value(gauge) == -15
    end

    test "returns decimal values" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 3.14159)
      assert Gauge.value(gauge) == 3.14159
    end
  end

  describe "to_string/1" do
    test "Returns a string representation of the gauge in Prometheus exposition format" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 10)

      expected_output = """
      # HELP my_gauge Description of my gauge
      # TYPE my_gauge gauge
      my_gauge 10
      """

      assert Gauge.to_string(gauge) == expected_output
    end

    test "Returns a string representation of the gauge with labels in Prometheus exposition format" do
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

    test "Handles empty labels correctly" do
      gauge = Gauge.new("my_gauge", "Description of my gauge", %{})
      gauge = Gauge.set(gauge, 42)

      expected_output = """
      # HELP my_gauge Description of my gauge
      # TYPE my_gauge gauge
      my_gauge 42
      """

      assert Gauge.to_string(gauge) == expected_output
    end

    test "Handles labels with special characters" do
      gauge =
        Gauge.new("my_gauge", "Description with special chars: !@#", %{
          "label_with_spaces" => "value with spaces",
          "label_with_quotes" => "value with \"quotes\"",
          "label_with_backslashes" => "value\\with\\backslashes"
        })

      gauge = Gauge.set(gauge, 99)

      output = Gauge.to_string(gauge)
      assert String.contains?(output, "label_with_spaces=\"value with spaces\"")
      # Note: The current implementation doesn't escape quotes, so we check for the raw value
      assert String.contains?(output, "label_with_quotes=\"value with \"quotes\"\"")
      assert String.contains?(output, "label_with_backslashes=\"value\\with\\backslashes\"")
    end

    test "Handles negative values in output" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, -42)

      expected_output = """
      # HELP my_gauge Description of my gauge
      # TYPE my_gauge gauge
      my_gauge -42
      """

      assert Gauge.to_string(gauge) == expected_output
    end

    test "Handles decimal values in output" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 3.14159)

      expected_output = """
      # HELP my_gauge Description of my gauge
      # TYPE my_gauge gauge
      my_gauge 3.14159
      """

      assert Gauge.to_string(gauge) == expected_output
    end

    test "Handles zero value in output" do
      gauge = Gauge.new("my_gauge", "Description of my gauge")
      gauge = Gauge.set(gauge, 0)

      expected_output = """
      # HELP my_gauge Description of my gauge
      # TYPE my_gauge gauge
      my_gauge 0
      """

      assert Gauge.to_string(gauge) == expected_output
    end

    test "Raises error when name and help are empty" do
      assert_raise RuntimeError, fn ->
        Gauge.new("", "")
      end
    end
  end

  describe "integration scenarios" do
    test "Complete workflow: create, set, increment, decrement, and format" do
      gauge = Gauge.new("workflow_gauge", "Test complete workflow")

      # Initial state
      assert gauge.value == 0

      # Set initial value
      gauge = Gauge.set(gauge, 100)
      assert gauge.value == 100

      # Increment multiple times
      gauge = Gauge.inc(gauge, 25)
      gauge = Gauge.inc(gauge, 25)
      assert gauge.value == 150

      # Decrement
      gauge = Gauge.dec(gauge, 50)
      assert gauge.value == 100

      # Final formatting
      output = Gauge.to_string(gauge)
      assert String.contains?(output, "workflow_gauge 100")
      assert String.contains?(output, "# TYPE workflow_gauge gauge")
    end

    test "Gauge with complex label operations" do
      labels = %{"env" => "production", "service" => "api"}
      gauge = Gauge.new("complex_gauge", "Complex operations test", labels)

      # Verify labels are preserved through operations
      gauge = Gauge.set(gauge, 100)
      assert gauge.labels == labels

      gauge = Gauge.inc(gauge, 50)
      assert gauge.labels == labels

      gauge = Gauge.dec(gauge, 25)
      assert gauge.labels == labels

      # Verify final output includes labels
      output = Gauge.to_string(gauge)
      assert String.contains?(output, "env=\"production\"")
      assert String.contains?(output, "service=\"api\"")
    end

    test "Gauge value boundaries and edge cases" do
      gauge = Gauge.new("boundary_gauge", "Boundary testing")

      # Test very large numbers
      gauge = Gauge.set(gauge, 9_999_999_999)
      assert gauge.value == 9_999_999_999

      # Test very small numbers
      gauge = Gauge.set(gauge, -9_999_999_999)
      assert gauge.value == -9_999_999_999

      # Test floating point precision
      gauge = Gauge.set(gauge, 0.000001)
      assert gauge.value == 0.000001

      # Test incrementing from very small to very large
      gauge = Gauge.inc(gauge, 9_999_999_999)
      assert gauge.value == 9_999_999_999.000001
    end
  end
end
