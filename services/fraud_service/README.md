# Fraud Service

Evaluates incoming transactions for potential fraud using a rule-based engine and returns a risk score via gRPC.

## Responsibilities

- Provide gRPC method `Evaluate` for synchronous fraud checks.
- Maintain in-memory rule cache with optional warmup from configuration.
- Publish Prometheus metrics for rule hit counts and risk scores.
- Optionally stream telemetry to OTLP collector.

## Running Locally

```bash
poetry run fraud-service
```

Configuration is environment-driven; see `.env.example` for defaults.
