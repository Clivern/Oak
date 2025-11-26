# Oak

Elixir Prometheus Exporter

## Installation

The package can be installed by adding `oak` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oak, "~> 0.2"}
  ]
end
```

## Quick Start

### Basic Usage

```elixir
# Start the metrics store
{:ok, store} = Oak.MetricsStore.start_link()

# Create metrics
counter = Oak.Metric.Counter.new("http_requests_total", "Total HTTP requests", %{method: "GET"})
gauge = Oak.Metric.Gauge.new("memory_usage", "Memory usage in bytes", %{instance: "web"})

# Update them in the store (created on first use)
Oak.MetricsStore.inc(store, counter)
Oak.MetricsStore.set(store, gauge, 1024)

# Get all metrics
all_metrics = Oak.Prometheus.get_metrics(store)

# Get a specific metric
metric = Oak.Prometheus.get_metric(store, Oak.Metric.Counter.id(counter))
```

### Using the Prometheus Module

```elixir
# Start metrics store
{:ok, store} = Oak.MetricsStore.start_link()

# Push metrics using the Prometheus module
counter = Oak.Metric.Counter.new("http_requests", "HTTP requests", %{method: "GET"})

Oak.Prometheus.push_metric(store, counter)

# Atomically increment the stored counter (no get/push round-trip needed)
Oak.MetricsStore.inc(store, counter, 1)

# Collect runtime metrics
Oak.Prometheus.collect_runtime_metrics(store)

# Output in Prometheus format
prometheus_output = Oak.Prometheus.output_metrics(store)

IO.puts(prometheus_output)
```

## Metric Types

### Counter

Counters are monotonically increasing metrics, typically used for counting requests, errors, etc.

```elixir
# Create a counter
counter = Oak.Metric.Counter.new("requests_total", "Total requests", %{endpoint: "/api"})

# Increment the counter
counter = Oak.Metric.Counter.inc(counter, 1)

# Set a specific value
counter = Oak.Metric.Counter.set(counter, 100)

# Get current value
value = Oak.Metric.Counter.value(counter)

# Reset to zero
counter = Oak.Metric.Counter.reset(counter)
```

### Gauge

Gauges represent a single numerical value that can arbitrarily go up and down.

```elixir
# Create a gauge
gauge = Oak.Metric.Gauge.new("memory_usage", "Memory usage in bytes", %{instance: "web"})

# Set the gauge value
gauge = Oak.Metric.Gauge.set(gauge, 1024)

# Increment the gauge
gauge = Oak.Metric.Gauge.inc(gauge, 100)

# Decrement the gauge
gauge = Oak.Metric.Gauge.dec(gauge, 50)

# Get current value
value = Oak.Metric.Gauge.value(gauge)
```

### Histogram

Histograms track the size and number of events in buckets, allowing you to measure the distribution of values.

```elixir
# Create a histogram with custom buckets
histogram = Oak.Metric.Histogram.new("request_duration", "Request duration", [0.1, 0.5, 1.0], %{endpoint: "/api"})

# Observe a value
histogram = Oak.Metric.Histogram.observe(histogram, 0.3)

# Get statistics
sum = Oak.Metric.Histogram.sum(histogram)
count = Oak.Metric.Histogram.count(histogram)
bucket_counts = Oak.Metric.Histogram.bucket_counts(histogram)
```

### Summary

Summaries track the size and number of events, providing quantiles over sliding time windows.

```elixir
# Create a summary with custom quantiles
summary = Oak.Metric.Summary.new("response_size", "Response size in bytes", [0.5, 0.9, 0.95], %{service: "auth"})

# Observe a value
summary = Oak.Metric.Summary.observe(summary, 1024)

# Get statistics
sum = Oak.Metric.Summary.sum(summary)
count = Oak.Metric.Summary.count(summary)
observations = Oak.Metric.Summary.observations(summary)

# Calculate quantiles
median = Oak.Metric.Summary.quantile(summary, 0.5)

p90 = Oak.Metric.Summary.quantile(summary, 0.9)
```

## Metrics Store

The `Oak.MetricsStore` provides a centralized GenServer-based storage for all metrics.

```elixir
# Start the store
{:ok, store} = Oak.MetricsStore.start_link()
{:ok, store} = Oak.MetricsStore.start_link(%{initial: "metrics"})

# Update a metric in place (created on first use)
Oak.MetricsStore.inc(store, counter)

# Register a fully built metric
Oak.Prometheus.push_metric(store, metric)

# Get a specific metric
metric = Oak.Prometheus.get_metric(store, metric_id)

# Get all metrics
all_metrics = Oak.Prometheus.get_metrics(store)

# Stop the store (registered under Oak.MetricsStore, so no argument)
Oak.MetricsStore.stop()
```

### Atomic Updates

Use the update functions to change a stored metric in one step. The store applies
the change itself, so concurrent callers never overwrite each other's updates.
If the metric doesn't exist yet, the given metric is used as the starting point.

```elixir
counter = Oak.Metric.Counter.new("http_requests_total", "Total HTTP requests", %{method: "GET"})
Oak.MetricsStore.inc(store, counter)        # increment by 1
Oak.MetricsStore.inc(store, counter, 5)     # increment by 5

gauge = Oak.Metric.Gauge.new("queue_depth", "Jobs waiting")
Oak.MetricsStore.set(store, gauge, 12)      # set to a value
Oak.MetricsStore.inc(store, gauge)          # increment
Oak.MetricsStore.dec(store, gauge, 3)       # decrement

histogram = Oak.Metric.Histogram.new("request_duration", "Request duration", [0.1, 0.5, 1.0])
Oak.MetricsStore.observe(store, histogram, 0.3)   # works for summaries too

# Apply any function to the stored metric
Oak.MetricsStore.update(store, counter, &Oak.Metric.Counter.set(&1, 100))
```

If an update fails (for example, a negative counter increment), the function returns
`{:error, exception}` and the stored metrics are left unchanged.

## Prometheus Integration

The `Oak.Prometheus` module provides high-level functions for working with the metrics store and generating Prometheus-compatible output.

```elixir
# Get all metrics from store
metrics = Oak.Prometheus.get_metrics(store)

# Push a single metric
Oak.Prometheus.push_metric(store, metric)

# Push multiple metrics
Oak.Prometheus.push_metrics(store, [metric1, metric2, metric3])

# Collect runtime metrics (Erlang/OTP stats)
Oak.Prometheus.collect_runtime_metrics(store)

# Output metrics in Prometheus format
prometheus_output = Oak.Prometheus.output_metrics(store)

# Format a list of metrics
formatted = Oak.Prometheus.format_metrics([metric1, metric2])
```

### Prometheus Output Format

The library generates standard Prometheus exposition format:

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET"} 42

# HELP memory_usage Memory usage in bytes
# TYPE memory_usage gauge
memory_usage{instance="web"} 1024
```

### Development Setup

```bash
# Clone the repository
git clone https://github.com/clivern/oak.git
cd oak

# Install dependencies
make deps

# Run tests
make ci

# Run formatting
make fmt
```

## Contributing

We are an open source, community-driven project so please feel free to join us. See the [contributing guidelines](CONTRIBUTING.md) for more details.

## Versioning

For transparency into our release cycle and in striving to maintain backward compatibility, Oak is maintained under the [Semantic Versioning guidelines](https://semver.org/) and release process is predictable and business-friendly.

See the [Releases section of our GitHub project](https://github.com/clivern/oak/releases) for changelogs for each release version of Oak. It contains summaries of the most noteworthy changes made in each release.

## Bug Tracker

If you have any suggestions, bug reports, or annoyances please report them to our issue tracker at https://github.com/clivern/oak/issues

## Security Issues

If you discover a security vulnerability within Oak, please send an email to [hello@clivern.com](mailto:hello@clivern.com)

## License

© 2024, Clivern. Released under [MIT License](https://opensource.org/licenses/mit-license.php).

**Oak** is authored and maintained by [@clivern](http://github.com/clivern).
