# Distributed Payment Gateway – Detailed Explanation

## 1. Project Overview

The **Distributed Payment Gateway** is a reference architecture for a payment-processing platform composed of Python microservices. It demonstrates how to coordinate card-like transactions across multiple bounded contexts—request ingress, ledger management, and fraud evaluation—while keeping the codebase modular and observable. Everything runs under Python 3.9.9 with infrastructure packaged for Docker Compose and local development via Poetry.

Key design goals:

- **Service isolation:** Each bounded context (Gateway API, Transaction Service, Fraud Service) runs as an independent service with its own runtime dependencies.
- **Async-first communication:** gRPC (asyncio) provides efficient RPC between services. FastAPI exposes a REST gateway for external clients.
- **Reliability patterns:** The transaction service persists ledger entries in PostgreSQL and uses an outbox table plus APScheduler for retries when downstream calls fail.
- **Observability:** Prometheus metrics endpoints and optional OpenTelemetry hooks provide visibility into system health.
- **Developer ergonomics:** A shared `common` package centralizes configuration, logging, database utilities, and generated protobuf code. Tooling (Makefile, Poetry, pytest, Ruff, mypy, Docker Compose) keeps workflows consistent.

## 2. Repository Structure

```
├── docker/                    # Service-specific Dockerfiles
│   ├── fraud.Dockerfile
│   ├── gateway.Dockerfile
│   └── transaction.Dockerfile
├── docs/                      # Architectural notes (see doc set for diagrams and ADRs)
├── packages/
│   └── common/                # Shared library used by all microservices
│       ├── config/            # Pydantic settings, environment loading
│       ├── db/                # SQLAlchemy async engine/session helpers
│       ├── generated/         # Protobuf & gRPC stubs (build artifact)
│       ├── grpc/              # Interceptors, TLS helpers, channel utilities
│       ├── logging/           # Loguru-based logging pipeline
│       ├── metrics/           # Prometheus server bootstrap
│       └── telemetry/         # Optional OpenTelemetry tracing bootstrap
├── proto/payment.proto        # Service contract shared by gRPC services
├── services/
│   ├── fraud_service/         # Fraud scoring microservice (gRPC)
│   ├── gateway_api/           # FastAPI REST ingress + gRPC client
│   └── transaction_service/   # Ledger + workflow orchestration microservice
├── ops/                       # Alembic configuration, migrations, seed data
├── tests/                     # pytest suite with gRPC stub dependency guard
├── docker-compose.yml         # Composes services & Postgres for local runs
├── Makefile                   # Helper commands (install, proto, lint, test, up)
├── pyproject.toml             # Poetry project definition & tooling config
└── explanation.md             # (This document)
```

## 3. Service Responsibilities & Interactions

### 3.1 Gateway API (`services/gateway_api`)
- **Purpose:** Exposes external REST endpoints (FastAPI) for clients to create payments and query status.
- **Flow:** Accepts `POST /payments` with payload validated by Pydantic models in `gateway_api/schemas/payment.py`. Uses the generated gRPC stub (`TransactionClient`) to forward the request to the transaction service. Returns the resulting status to the client.
- **Metrics & logging:** Inherits shared logging setup and exposes a Prometheus endpoint. Request IDs are propagated via gRPC metadata using helpers in `common/grpc/interceptors.py`.

### 3.2 Transaction Service (`services/transaction_service`)
- **Purpose:** Orchestrates the payment lifecycle—persists ledger entries, calls the fraud service, and reconciles outcomes.
- **Key modules:**
  - `service/processor.py`: Core workflow; writes `LedgerEntry`, invokes the fraud client, updates status, and populates an outbox on failure.
  - `worker/outbox.py`: APScheduler job that periodically drains the outbox, retrying fraud evaluations and updating ledger state.
  - `db/models.py` & `db/repositories.py`: SQLAlchemy models and CRUD helpers for the ledger and retry tables.
- **Database:** Async SQLAlchemy engine defined in `common/db/engine.py`, connecting to PostgreSQL via configuration from `common/config/settings.py`.

### 3.3 Fraud Service (`services/fraud_service`)
- **Purpose:** Provides a gRPC endpoint that evaluates transactions against a rule engine.
- **Flow:** `api/server.py` registers `FraudServiceServicer`, delegating to `service/evaluator.py`. The evaluator runs the request through `rules/engine.py` with default rules defined in `rules/default_rules.py` (high amount, risky payment methods, night-time transactions).
- **Extensibility:** Rules are composable `Rule` objects returning scores; future heuristics or ML models can integrate here.

### 3.4 Shared Modules (`packages/common`)
- `config/settings.py`: Pydantic-based settings with nested structures (`DatabaseSettings`, `GrpcSettings`, etc.), reading from environment variables (including Docker Compose overrides).
- `db/__init__.py`: Builds async SQLAlchemy engine/session factories and includes Alembic integration.
- `grpc/`: Retry interceptors, TLS channel builder, metadata helper for request IDs.
- `metrics/server.py`: Launches a Prometheus HTTP server for each service.
- `telemetry/tracing.py`: Optional OpenTelemetry OTLP exporter configuration with graceful fallback if libraries are missing.
- `generated/`: Contains `payment_pb2.py` and `payment_pb2_grpc.py` generated via `make proto` or Docker builds; these files are ignored by mypy/ruff through config tweaks and `# ruff: noqa` markers.

## 4. Data Flow & Sequence

1. **Client payment request:** REST POST reaches the Gateway API.
2. **gRPC handoff:** Gateway packages request into `payment_pb2.TransactionRequest` and sends it to the transaction service.
3. **Ledger persistence:** Transaction service records a ledger entry (`status="pending"`).
4. **Fraud evaluation:** Calls fraud service via async gRPC client. If unavailable, the request enters the retry outbox.
5. **Decision:**
   - If flagged: ledger status becomes `declined`, reason recorded.
   - If clean: status becomes `confirmed`.
6. **Response:** Transaction service returns a `TransactionResponse`, propagated back to the REST caller.
7. **Retries:** APScheduler-driven job replays outbox items, ensuring eventual consistency when the fraud service or dependencies recover.

## 5. Environment & Toolchain

- **Python runtime:** Locked to Python 3.9 (`pyproject.toml`), satisfying the user’s requirement. Poetry manages virtual environments (`poetry install`).
- **Linters & formatters:** Ruff, Black, isort, and mypy (configured in `pyproject.toml`). `make lint` runs the suite.
- **Testing:** `pytest` with async support. Tests guard against missing gRPC stubs, instructing developers to run `make proto`.
- **Database migrations:** Alembic configured in `ops/alembic.ini`, with migration scripts in `ops/alembic/versions`. `make migrate` applies migrations; `make seed` populates starter data.
- **Containers:** Each service has a Dockerfile installing dependencies via Poetry (`--only main --no-root`), generating protobuf stubs, and setting `PYTHONPATH`. Docker Compose orchestrates Postgres plus the three services; `make up` builds and starts, `make down` tears everything down.
- **CI/CD (optional):** GitHub Actions workflow (not shown here) runs lint/test on push—see `.github/workflows/` if present in repository.

## 6. Observability & Operations

- **Logging:** Loguru-based logger with request ID injection ensures consistent log format across services.
- **Metrics:** Each service exposes Prometheus-compatible metrics on `METRICS__PORT` (e.g., 9464 for transaction service).
- **Tracing:** `common/telemetry/tracing.py` enables OTLP export when OpenTelemetry packages are installed and `ENABLE_TRACES` is true.
- **Health checks:** PostgreSQL container uses `pg_isready`; gRPC services rely on Docker Compose restart policies and logs for readiness.

## 7. Development Workflow

Typical local workflow:

```bash
poetry install                       # Install dependencies
poetry run make proto                # Or directly: make proto
poetry run ruff check && poetry run black --check .
poetry run pytest
make up                              # Build & start containers
make logs                            # Tail service logs
make down                            # Stop and remove containers
```

While containers run, the FastAPI gateway listens on `localhost:8000`. You can submit a payment request using curl or a REST client:

```bash
curl -X POST http://localhost:8000/payments \
  -H "Content-Type: application/json" \
  -d '{
        "transaction_id": "txn-001",
        "merchant_id": "m-001",
        "customer_id": "c-001",
        "amount": {"currency": "USD", "value_minor": 2500},
        "payment_method": "card",
        "reference": "order-123"
      }'
```

## 8. Testing & Quality Gates

- **Unit tests:** Ensure rule engine thresholds behave (see `tests/test_fraud_rules.py`). Additional tests would typically cover repository CRUD, API contracts, and integration flows.
- **Type checking:** `poetry run mypy services packages` enforces typing (with generated modules excluded via mypy config).
- **Formatting & linting:** `ruff`, `black`, and `isort` maintain code style; `pyproject.toml` registers configuration.

## 9. Deployment Considerations

- **Containerized environment:** Suitable for Kubernetes or other orchestrators by translating compose services into deployments/services.
- **Secrets management:** In production, replace plain env vars with secret stores (Azure Key Vault, AWS Secrets Manager, etc.).
- **Scaling:** Gateway API and transaction service are stateless and horizontally scalable. Fraud service can scale as long as rule evaluation remains stateless or uses shared caches.
- **Database migrations:** Run Alembic migrations as part of deployment pipelines to keep schema in sync.

## 10. Future Enhancements

- **Additional payment states:** Support capture/refund flows or multi-leg settlement.
- **Event streaming:** Integrate Kafka (or similar) for transaction events instead of direct gRPC coupling.
- **Advanced fraud models:** Swap rule engine for ML-based scoring with feature stores.
- **API expansion:** Add status polling endpoints, synthetic transactions for monitoring, or merchant dashboards.
- **Security hardening:** mTLS on gRPC channels, JWT auth on REST endpoints, WAF integration.

---

This document should serve as a deep-dive companion to the repository, guiding contributors through architecture, code layout, and operational workflows.
