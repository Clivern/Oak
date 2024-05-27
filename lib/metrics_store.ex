# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.MetricsStore do
  @moduledoc """
  A centralized store for managing metrics across a Phoenix application.

  This store acts as a registry where different parts of your app can push metrics,
  and controllers can fetch all metrics in Prometheus format for scraping.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Oak MetricsStore started")
    {:ok, %{counters: %{}, gauges: %{}, histograms: %{}, summaries: %{}}}
  end
end
