# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.MetricsStore do
  use GenServer

  def start_link(initial_map \\ %{}) do
    GenServer.start_link(__MODULE__, initial_map)
  end

  def init(initial_map) do
    {:ok, initial_map}
  end

  def handle_call({:get, key}, _from, map) do
    {:reply, Map.get(map, key), map}
  end

  def handle_call({:put, key, value}, _from, map) do
    new_map = Map.put(map, key, value)
    {:reply, :ok, new_map}
  end

  def handle_call(:get_all, _from, map) do
    {:reply, map, map}
  end
end
