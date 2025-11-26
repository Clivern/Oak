# Integrating Oak with Phoenix

## Installation

Add Oak to `mix.exs`:

```elixir
def deps do
  [
    {:oak, "~> 0.2"}
  ]
end
```

```bash
mix deps.get
```

## Start the Metrics Store

In `lib/your_app/application.ex`:

```elixir
children = [
  {Oak.MetricsStore, %{}}
]
```

## Collect Request Metrics

Create `lib/your_app_web/plugs/route_metrics.ex`:

```elixir
defmodule YourAppWeb.Plugs.RouteMetrics do
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)
    register_before_send(conn, &track_metrics(&1, start_time))
  end

  defp track_metrics(conn, start_time) do
    duration = System.monotonic_time(:millisecond) - start_time

    counter = Oak.Metric.Counter.new("http_requests_total", "HTTP requests total", %{
      method: conn.method,
      route: conn.request_path,
      status: conn.status || 500
    })

    histogram = Oak.Metric.Histogram.new("request_duration", "Request duration",
      [10, 50, 100, 250, 500, 1000, 2500, 5000],
      %{method: conn.method, route: conn.request_path})

    record(Oak.MetricsStore.inc(Oak.MetricsStore, counter))
    record(Oak.MetricsStore.observe(Oak.MetricsStore, histogram, duration))

    conn
  end

  defp record(:ok), do: :ok

  defp record({:error, reason}) do
    Logger.warning("Failed to record route metric: #{inspect(reason)}")
  end
end
```

Add it to `lib/your_app_web/endpoint.ex`, **before** the router so it sees the final status:

```elixir
plug YourAppWeb.Plugs.RouteMetrics
plug YourAppWeb.Router
```

## Expose a Metrics Endpoint

Create `lib/your_app_web/controllers/metrics_controller.ex`:

```elixir
defmodule YourAppWeb.MetricsController do
  use YourAppWeb, :controller

  def metrics(conn, _params) do
    Oak.Prometheus.collect_runtime_metrics(Oak.MetricsStore)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, Oak.Prometheus.output_metrics(Oak.MetricsStore))
  end
end
```

Add the route in `lib/your_app_web/router.ex`:

```elixir
get "/_metrics", MetricsController, :metrics
```

## Custom Metrics

Increment a counter from anywhere in your code:

```elixir
def register_user(user_params) do
  case create_user(user_params) do
    {:ok, user} ->
      counter = Oak.Metric.Counter.new("user_registrations_total", "Total user registrations", %{})
      Oak.MetricsStore.inc(Oak.MetricsStore, counter)
      {:ok, user}

    {:error, changeset} ->
      {:error, changeset}
  end
end
```

## Verify

```bash
mix phx.server
```

Open http://localhost:4000/_metrics.
