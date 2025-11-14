# Architecture Overview

## High-Level Design

The platform is composed of three microservices that communicate over gRPC and HTTP. Each service is packaged as a Docker container and orchestrated locally via Docker Compose.

```
        ┌──────────────┐        gRPC         ┌─────────────┐
Client ─┤ Gateway API  ├────────────────────▶│ Fraud Svc   │
        └──────┬───────┘                     └─────┬───────┘
               │  REST                              │
               ▼                                    │ async risk cache
        ┌──────────────┐        gRPC         ┌──────▼──────┐
        │ Transaction  ├────────────────────▶│ PostgreSQL  │
        │ Service      │◀────────────────────┤ Ledger &    │
        └──────────────┘   gRPC callbacks    │ Outbox      │
                                             └─────────────┘
```

### Data Flow

1. **Gateway API** receives a payment request, validates payloads, and forwards to the transaction service.
2. **Transaction Service** opens a database transaction, inserts ledger entries, and writes an outbox record for asynchronous retries.
3. The service synchronously calls the **Fraud Service** over gRPC. Depending on the response, the transaction is confirmed or rolled back.
4. Failed fraud checks or transient errors enqueue retries via a background worker that drains the outbox table.
5. Metrics and traces are exported by each service for observability.

## Components

- **gRPC Contracts**: Located in `proto/`. Shared Python stubs are generated in `packages/common/generated` and imported by services.
- **Common Library**: Shared configuration, logging, and database utilities in `packages/common`.
- **PostgreSQL**: Primary data store for ledgering and retry queue. Alembic manages migrations.
- **Background Worker**: APScheduler job inside the transaction service polling the outbox table for pending retries.
- **Containerization**: Each service has a Dockerfile under `docker/`. `docker-compose.yml` binds them together with a Postgres instance.

## Fault Tolerance

- gRPC client configured with retries and deadlines using interceptors.
- Circuit breaker pattern via `pybreaker` to prevent overload on downstream services.
- Outbox pattern ensures retries are persisted and processed idempotently.

## Observability

- OpenTelemetry tracing with OTLP exporters (configurable via environment variables).
- Prometheus metrics endpoints exposed on `/metrics` for all services.
- Structured JSON logging with correlation IDs propagated via gRPC metadata.

## Security Considerations

- Mutual TLS between services can be enabled by supplying certificates in `docker/tls/` (see `docs/security.md`).
- Sensitive configuration (DB credentials, API keys) loaded from environment or `.env` files and never hard-coded.
- Input validation enforced via Pydantic schemas and gRPC request validation.
