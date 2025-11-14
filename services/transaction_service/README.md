# Transaction Service

Handles payment lifecycle orchestration, ledger persistence, and fraud evaluation calls.

## Responsibilities

- Accept gRPC requests for transaction processing.
- Persist double-entry ledger data in PostgreSQL.
- Call the Fraud Service to evaluate risk.
- Manage retry queue via outbox table and background worker.
- Expose Prometheus metrics and OpenTelemetry traces.

## Running Locally

```bash
poetry run transaction-service
```

Configuration is sourced from environment variables; see `.env.example` at repo root.
