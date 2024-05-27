# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.Collector.Runtime do
  @moduledoc """
  Collects runtime metrics from the Elixir/BEAM VM.

  This collector provides metrics for:
  - Process and port counts
  - Memory usage (total, allocated, system)
  - Garbage collection statistics
  - System information
  - Load averages
  """

  @doc """
  Collects all runtime metrics and returns them as a list of metric structs.
  """
  def collect do
    [
      collect_process_metrics(),
      collect_memory_metrics(),
      collect_gc_metrics(),
      collect_system_metrics(),
      collect_load_metrics()
    ]
    |> List.flatten()
  end

  @doc """
  Collects process-related metrics.
  """
  def collect_process_metrics do
    process_count = Process.list() |> length()
    port_count = :erlang.ports() |> length()

    [
      %Oak.Metric.Gauge{
        name: "erlang_processes_total",
        help: "Total number of processes",
        labels: %{},
        value: process_count
      },
      %Oak.Metric.Gauge{
        name: "erlang_ports_total",
        help: "Total number of ports",
        labels: %{},
        value: port_count
      }
    ]
  end

  @doc """
  Collects memory usage metrics.
  """
  def collect_memory_metrics do
    memory = :erlang.memory()

    [
      %Oak.Metric.Gauge{
        name: "erlang_memory_bytes",
        help: "Memory usage in bytes",
        labels: %{type: "total"},
        value: memory[:total]
      },
      %Oak.Metric.Gauge{
        name: "erlang_memory_bytes",
        help: "Memory usage in bytes",
        labels: %{type: "processes"},
        value: memory[:processes]
      },
      %Oak.Metric.Gauge{
        name: "erlang_memory_bytes",
        help: "Memory usage in bytes",
        labels: %{type: "system"},
        value: memory[:system]
      },
      %Oak.Metric.Gauge{
        name: "erlang_memory_bytes",
        help: "Memory usage in bytes",
        labels: %{type: "atom"},
        value: memory[:atom]
      },
      %Oak.Metric.Gauge{
        name: "erlang_memory_bytes",
        help: "Memory usage in bytes",
        labels: %{type: "binary"},
        value: memory[:binary]
      },
      %Oak.Metric.Gauge{
        name: "erlang_memory_bytes",
        help: "Memory usage in bytes",
        labels: %{type: "ets"},
        value: memory[:ets]
      }
    ]
  end

  @doc """
  Collects garbage collection metrics.
  """
  def collect_gc_metrics do
    # Get GC info for all processes
    gc_info =
      Process.list()
      |> Enum.map(fn pid ->
        case Process.info(pid, [:garbage_collection]) do
          [{:garbage_collection, gc}] -> gc
          _ -> []
        end
      end)
      |> List.flatten()

    # Count GC runs
    gc_runs =
      gc_info
      |> Enum.count(fn {key, _} -> key == :number_of_gcs end)

    # Sum GC words
    gc_words =
      gc_info
      |> Enum.filter(fn {key, _} -> key == :words_reclaimed end)
      |> Enum.map(fn {_, value} -> value end)
      |> Enum.sum()

    [
      %Oak.Metric.Counter{
        name: "erlang_gc_runs_total",
        help: "Total number of garbage collections",
        labels: %{},
        value: gc_runs
      },
      %Oak.Metric.Counter{
        name: "erlang_gc_words_reclaimed_total",
        help: "Total words reclaimed by garbage collection",
        labels: %{},
        value: gc_words
      }
    ]
  end

  @doc """
  Collects system information metrics.
  """
  def collect_system_metrics do
    [
      %Oak.Metric.Gauge{
        name: "erlang_system_info",
        help: "System information value",
        labels: %{type: "process_count"},
        value: :erlang.system_info(:process_count)
      },
      %Oak.Metric.Gauge{
        name: "erlang_system_info",
        help: "System information value",
        labels: %{type: "port_count"},
        value: :erlang.system_info(:port_count)
      },
      %Oak.Metric.Gauge{
        name: "erlang_system_info",
        help: "System information value",
        labels: %{type: "schedulers"},
        value: :erlang.system_info(:schedulers)
      },
      %Oak.Metric.Gauge{
        name: "erlang_system_info",
        help: "System information value",
        labels: %{type: "schedulers_online"},
        value: :erlang.system_info(:schedulers_online)
      }
    ]
  end

  @doc """
  Collects system load metrics (Unix-specific).
  """
  def collect_load_metrics do
    case :os.type() do
      {:unix, _} ->
        try do
          # Get load average from /proc/loadavg on Linux
          case File.read("/proc/loadavg") do
            {:ok, content} ->
              [load1, load5, load15 | _] = String.split(content, " ")

              [
                %Oak.Metric.Gauge{
                  name: "system_load_average",
                  help: "System load average",
                  labels: %{period: "1m"},
                  value: String.to_float(load1)
                },
                %Oak.Metric.Gauge{
                  name: "system_load_average",
                  help: "System load average",
                  labels: %{period: "5m"},
                  value: String.to_float(load5)
                },
                %Oak.Metric.Gauge{
                  name: "system_load_average",
                  help: "System load average",
                  labels: %{period: "15m"},
                  value: String.to_float(load15)
                }
              ]

            _ ->
              []
          end
        rescue
          _ -> []
        end

      _ ->
        []
    end
  end
end
