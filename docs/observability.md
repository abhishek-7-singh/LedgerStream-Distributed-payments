# Observability

## Logging

- All services use Loguru for structured logging.
- Logs are emitted in JSON-friendly format including `request_id` to correlate traces across boundaries.
- The Gateway injects `x-request-id` metadata for downstream gRPC calls.

## Metrics

- Prometheus metrics server exposed on `/metrics` port per service.
- Default metrics include process stats and request counters. Extend by registering custom metrics via `prometheus_client`.

## Tracing

- OpenTelemetry SDK configured via environment variables.
- Set `ENABLE_TRACES=true` and `OTEL_EXPORTER_ENDPOINT` to your collector URL to enable tracing.
- Trace context flows through gRPC metadata.

## Dashboards

Sample Grafana dashboards can be imported using the JSON files under `docs/dashboards/` (add custom dashboards as needed).
