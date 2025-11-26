# Oak

Elixir Prometheus Exporter

## Installation

```elixir
def deps do
  [
    {:oak, "~> 0.2"}
  ]
end
```

## Quick Start

```elixir
{:ok, store} = Oak.MetricsStore.start_link()

counter = Oak.Metric.Counter.new("http_requests_total", "Total HTTP requests", %{method: "GET"})
gauge = Oak.Metric.Gauge.new("memory_usage", "Memory usage in bytes", %{instance: "web"})

Oak.MetricsStore.inc(store, counter)
Oak.MetricsStore.set(store, gauge, 1024)

IO.puts(Oak.Prometheus.output_metrics(store))
```

## Metric Types

```elixir
# Counter: only goes up
counter = Oak.Metric.Counter.new("requests_total", "Total requests", %{endpoint: "/api"})
counter = Oak.Metric.Counter.inc(counter, 1)

# Gauge: goes up and down
gauge = Oak.Metric.Gauge.new("memory_usage", "Memory usage in bytes", %{instance: "web"})
gauge = Oak.Metric.Gauge.set(gauge, 1024)
gauge = Oak.Metric.Gauge.dec(gauge, 50)

# Histogram: counts observations in buckets
histogram = Oak.Metric.Histogram.new("request_duration", "Request duration", [0.1, 0.5, 1.0])
histogram = Oak.Metric.Histogram.observe(histogram, 0.3)

# Summary: observations with quantiles
summary = Oak.Metric.Summary.new("response_size", "Response size in bytes", [0.5, 0.9])
summary = Oak.Metric.Summary.observe(summary, 1024)
median = Oak.Metric.Summary.quantile(summary, 0.5)
```

## Metrics Store

`Oak.MetricsStore` is a GenServer that holds all metrics.

```elixir
{:ok, store} = Oak.MetricsStore.start_link()

Oak.Prometheus.push_metric(store, metric)
metric = Oak.Prometheus.get_metric(store, metric_id)
all_metrics = Oak.Prometheus.get_metrics(store)

Oak.MetricsStore.stop()  # registered name, no argument
```

### Atomic Updates

Update a stored metric in one step. The store applies the change, so concurrent callers never overwrite each other. A missing metric is created from the given one.

```elixir
Oak.MetricsStore.inc(store, counter, 5)
Oak.MetricsStore.set(store, gauge, 12)
Oak.MetricsStore.dec(store, gauge, 3)
Oak.MetricsStore.observe(store, histogram, 0.3)  # also works for summaries

Oak.MetricsStore.update(store, counter, &Oak.Metric.Counter.set(&1, 100))
```

On failure (e.g. a negative counter increment) the function returns `{:error, exception}` and stored metrics are unchanged.

## Prometheus Integration

```elixir
Oak.Prometheus.push_metrics(store, [metric1, metric2])
Oak.Prometheus.collect_runtime_metrics(store)  # Erlang/OTP stats
Oak.Prometheus.output_metrics(store)           # exposition format
```

Output looks like:

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET"} 42
```

## Development

```bash
make deps   # install dependencies
make ci     # run tests
make fmt    # format code
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

**Oak** is maintained by [@clivern](http://github.com/clivern).
