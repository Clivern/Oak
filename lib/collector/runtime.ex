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

  @memory_types [:total, :processes, :system, :atom, :binary, :ets]
  @system_info_keys [:process_count, :port_count, :schedulers, :schedulers_online]
  @load_periods [{"1m", 0}, {"5m", 1}, {"15m", 2}]

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
    [
      gauge("erlang_processes_total", "Total number of processes", %{}, length(Process.list())),
      gauge("erlang_ports_total", "Total number of ports", %{}, length(:erlang.ports()))
    ]
  end

  @doc """
  Collects memory usage metrics.
  """
  def collect_memory_metrics do
    memory = :erlang.memory()

    for type <- @memory_types do
      gauge(
        "erlang_memory_bytes",
        "Memory usage in bytes",
        %{type: Atom.to_string(type)},
        memory[type]
      )
    end
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
    for key <- @system_info_keys do
      gauge(
        "erlang_system_info",
        "System information value",
        %{type: Atom.to_string(key)},
        :erlang.system_info(key)
      )
    end
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
              loads = String.split(content, " ")

              for {period, index} <- @load_periods do
                gauge(
                  "system_load_average",
                  "System load average",
                  %{period: period},
                  String.to_float(Enum.at(loads, index))
                )
              end

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

  defp gauge(name, help, labels, value) do
    %Oak.Metric.Gauge{name: name, help: help, labels: labels, value: value}
  end
end
