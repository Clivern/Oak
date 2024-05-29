# Integrating Oak with Phoenix Applications

This guide explains how to integrate [Oak](https://github.com/Clivern/Oak) with your Phoenix application. Oak is a high-performance metrics collection and aggregation library written in Elixir.

## Installation

### 1. Add Oak Dependencies

Add the following to your `mix.exs`:

```elixir
def deps do
  [
    # ... other deps
    {:oak, "~> 0.2"}
  ]
end
```

### 2. Install Dependencies

```bash
mix deps.get
```

## Basic Configuration

### 1. Start Oak in Your Application

Update your `lib/your_app/application.ex`:

```elixir
defmodule YourApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ... other children
      {Oak.MetricsStore, %{}}
    ]

    opts = [strategy: :one_for_one, name: YourApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Metrics Collection

### 1. Create a Metrics Plug

Create a plug to collect HTTP request metrics. This should be placed **after** your router to capture actual response statuses:

```elixir
# lib/your_app_web/plugs/route_metrics.ex
defmodule YourAppWeb.Plugs.RouteMetrics do
  @moduledoc """
  Plug that tracks route metrics and pushes them to Oak metrics store.
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)

    conn
    |> register_before_send(&track_metrics(&1, start_time))
  end

  defp track_metrics(conn, start_time) do
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Get route information
    route = conn.request_path
    method = conn.method
    status = conn.status || 500

    # Push metrics to Oak
    try do
      # HTTP request counter
      http_requests_total = Oak.Metric.Counter.new("http_requests_total", "HTTP requests total", %{
        method: method,
        route: route,
        status: status
      })

      case Oak.Prometheus.get_metric(Oak.MetricsStore, Oak.Prometheus.get_counter_id(http_requests_total)) do
        nil ->
          Oak.Prometheus.push_metric(Oak.MetricsStore, http_requests_total |> Oak.Metric.Counter.inc(1))
        metric ->
          Oak.Prometheus.push_metric(Oak.MetricsStore, metric |> Oak.Metric.Counter.inc(1))
      end

      # Request duration histogram
      request_duration = Oak.Metric.Histogram.new("request_duration", "Request duration", [10, 50, 100, 250, 500, 1000, 2500, 5000], %{
        method: method,
        route: route
      })

      case Oak.Prometheus.get_metric(Oak.MetricsStore, Oak.Prometheus.get_histogram_id(request_duration)) do
        nil ->
          Oak.Prometheus.push_metric(Oak.MetricsStore, request_duration |> Oak.Metric.Histogram.observe(duration))
        metric ->
          Oak.Prometheus.push_metric(Oak.MetricsStore, metric |> Oak.Metric.Histogram.observe(duration))
      end
    rescue
      e ->
        Logger.warning("Failed to push route metrics: #{inspect(e)}")
    end

    conn
  end
end
```

### 2. Add the Plug to Your Endpoint

**Important**: Place the metrics plug **before** your router to ensure it captures actual response statuses

```elixir
# lib/your_app_web/endpoint.ex
defmodule YourAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :your_app

  # ... other plugs

  # Route metrics tracking
  plug YourAppWeb.Plugs.RouteMetrics

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug YourAppWeb.Router
end
```

### 3. Create a Metrics Controller

Create a controller to expose metrics for Prometheus scraping:

```elixir
# lib/your_app_web/controllers/metrics_controller.ex
defmodule YourAppWeb.MetricsController do
  use YourAppWeb, :controller

  def metrics(conn, _params) do
    Oak.Prometheus.collect_runtime_metrics(Oak.MetricsStore)
    metrics_text = Oak.Prometheus.output_metrics(Oak.MetricsStore)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics_text)
  end
end
```

### 4. Add Metrics Route

Add the metrics endpoint to your router:

```elixir
# lib/your_app_web/router.ex
defmodule YourAppWeb.Router do
  use YourAppWeb, :router

  # ... other routes

  scope "/", YourAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/_metrics", MetricsController, :metrics  # Metrics endpoint
  end
end
```

## Custom Metrics

### 1. Business Logic Metrics

You can add custom metrics throughout your application:

```elixir
# Example: Tracking user registrations
def register_user(user_params) do
  case create_user(user_params) do
    {:ok, user} ->
      # Increment user registration counter
      counter = Oak.Metric.Counter.new("user_registrations_total", "Total user registrations", %{})

      case Oak.Prometheus.get_metric(Oak.MetricsStore, Oak.Prometheus.get_counter_id(counter)) do
        nil ->
          Oak.Prometheus.push_metric(Oak.MetricsStore, counter |> Oak.Metric.Counter.inc(1))
        metric ->
          Oak.Prometheus.push_metric(Oak.MetricsStore, metric |> Oak.Metric.Counter.inc(1))
      end

      {:ok, user}

    {:error, changeset} ->
      {:error, changeset}
  end
end
```

## Testing Your Integration

### 1. Start Your Application

```bash
mix phx.server
```

### 2. Check Metrics Endpoint

Visit `http://localhost:4000/_metrics` to see your metrics in Prometheus format.
