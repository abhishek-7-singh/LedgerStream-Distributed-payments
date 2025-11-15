# LedgerStream Distributed Payment Gateway
## Author: Abhishek Singh | Vellore Institute of Technology Chennai
LedgerStream is a reference implementation of a distributed payment processing platform built with Python microservices, gRPC, PostgreSQL, and a Next.js frontend. It demonstrates how to orchestrate resilient payment flows, fraud analysis, and ledger accounting across independently deployable services.

---
## To Run
### Backend- Docker compose -d --build
### Frontend- cd frontend, npm run dev
---


## 📋 Table of Contents

- [Key Features](#key-features)
- [Architecture Overview](#architecture-overview)
- [Service Catalog](#service-catalog)
- [Tech Stack](#tech-stack)
- [Monorepo Layout](#monorepo-layout)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Frontend Workflow](#frontend-workflow)
- [Environment Configuration](#environment-configuration)
- [Database & Migrations](#database--migrations)
- [Testing & Quality Gates](#testing--quality-gates)
- [Observability](#observability)
- [Troubleshooting](#troubleshooting)
- [Extending the Platform](#extending-the-platform)
- [Deployment Options](#deployment-options)
- [License](#license)

---

## ✨ Key Features

- **End-to-end payment simulation** with card tokenization, authorization, settlement, and ledger postings
- **Service decomposition** into gateway, transaction, fraud, and frontend apps to highlight clear boundaries
- **Fault tolerance** via gRPC retry interceptors, idempotent handlers, and durable ledger persistence
- **Observability hooks** using structured logging, Prometheus metrics, and OpenTelemetry-ready exporters
- **Developer ergonomics** through Docker Compose, Poetry, Alembic, and a responsive Next.js dashboard

---

## 🏗️ Architecture Overview

```
┌───────────────┐      REST      ┌─────────────────────┐
│ Next.js Front │ ─────────────▶ │ Gateway API (FastAPI)│
└───────────────┘                └──────────┬──────────┘
                                             │ gRPC
                                             ▼
                                      ┌───────────────┐
                                      │ Transaction    │
                                      │ Service        │
                                      └──────┬────────┘
                                             │ gRPC
                                             ▼
                                      ┌───────────────┐
                                      │ Fraud Service │
                                      └───────────────┘
                                             │
                                             ▼
                                          PostgreSQL
```

Each component is containerized and orchestrated through `docker-compose.yml`. Postgres stores double-entry ledger entries, transaction metadata, and fraud decision snapshots.

---

## 🔧 Service Catalog

### Gateway API (`services/gateway_api`)
- FastAPI REST ingress that accepts payment requests from the frontend or API clients
- Acts as a gRPC client to the transaction service, queues retryable work, and surfaces aggregated health/status endpoints
- Exposes endpoints for payment submission, transaction queries, and health checks

### Transaction Service (`services/transaction_service`)
- Core domain service responsible for payment state transitions, ledger writes, and fraud lookups
- Uses SQLAlchemy 2.x with async engines, Alembic migrations, and gRPC stubs generated at build time
- Implements double-entry accounting with debit/credit ledger entries
- Coordinates with fraud service for risk evaluation

### Fraud Service (`services/fraud_service`)
- Rule-based risk engine exposed over gRPC
- Streams incremental fraud scores and recommendations back to the transaction service
- Evaluates transactions based on configurable risk thresholds and patterns

### Frontend (`frontend/`)
- Next.js 16 (App Router) portal branded as LedgerStream
- React Query drives data fetching, Zod validates user input, and Sonner renders toast notifications
- Features payment submission form, transaction dashboard, and real-time status updates

---

## 🛠️ Tech Stack

**Backend:**
- Python 3.11
- FastAPI and gRPC (grpcio, grpcio-tools)
- PostgreSQL 15
- SQLAlchemy 2.x with async support
- Alembic for database migrations
- Poetry for dependency management

**Frontend:**
- Next.js 16 with App Router
- React 19
- TypeScript
- Tailwind CSS
- React Query (TanStack Query)
- Zod for schema validation
- React Hook Form
- Sonner for toast notifications

**Infrastructure:**
- Docker & Docker Compose
- Prometheus client for metrics
- OpenTelemetry for distributed tracing
- Loguru/structlog for structured logging

**Testing:**
- pytest & pytest-asyncio
- tox for test automation

---

## 📁 Monorepo Layout

```
├── docker/                 # Container build contexts for services
│   ├── gateway.Dockerfile
│   ├── transaction.Dockerfile
│   └── fraud.Dockerfile
├── docker-compose.yml      # Multi-service orchestration
├── frontend/               # Next.js dashboard (React 19)
│   ├── src/
│   │   ├── app/           # App Router pages
│   │   ├── components/    # React components
│   │   └── lib/           # Utilities and API client
│   └── package.json
├── ops/                    # Infrastructure scripts, Alembic config
├── packages/common/        # Shared config, proto helpers, utils
│   └── config/
├── proto/                  # gRPC protobuf definitions
│   ├── transaction.proto
│   └── fraud.proto
├── services/
│   ├── fraud_service/
│   ├── gateway_api/
│   └── transaction_service/
│       └── db/migrations/  # Alembic migrations
├── tests/                  # Pytest-based contract & unit tests
├── docs/                   # Supplementary diagrams and notes
├── pyproject.toml          # Poetry configuration
├── Makefile                # Build and test shortcuts
└── README.md               # This file
```

---
## Images
<img width="1919" height="1033" alt="image" src="https://github.com/user-attachments/assets/29d348f2-031c-4917-ba6a-182a6d3b15cc" />
The docker engine

<img width="1905" height="1079" alt="image" src="https://github.com/user-attachments/assets/f458bfcb-d5fe-43d4-aec6-40265d7e9cdc" />
Payment frontend 

<img width="548" height="925" alt="image" src="https://github.com/user-attachments/assets/68cd38ec-7e0d-496f-bfb6-2cc9c305d148" />
<img width="549" height="932" alt="image" src="https://github.com/user-attachments/assets/c5db49d8-1eb5-4f6b-8b48-9e443df15ce9" />

Flutter App




##  Prerequisites

- **Docker Desktop** or **Docker Engine 24+**
- **Docker Compose v2**
- **Node.js 20+** and **npm** (for frontend development)
- **Python 3.11+** (if running services locally without Docker)
- **GNU Make** (optional but recommended for workflow shortcuts)

---

##  Quick Start

```bash
# 1. Copy environment template and adjust overrides
cp .env.example .env

# 2. Build and launch all backend services
docker compose up -d --build

# 3. Apply database migrations (required on first run)
docker compose exec transaction-service poetry run alembic upgrade head

# 4. Install frontend dependencies and start dev server
cd frontend
npm install
npm run dev

# 5. Visit the LedgerStream dashboard
# Open http://localhost:3000 in your browser
```

### Service Endpoints

The compose file exposes services on the following defaults:

- **Gateway API:** `http://localhost:8000`
  - API Docs: `http://localhost:8000/docs`
- **Transaction Service gRPC:** `localhost:50051`
- **Fraud Service gRPC:** `localhost:50052`
- **Postgres:** `localhost:5432`
- **Frontend:** `http://localhost:3000`

---

##  Deployment Options

Looking to deploy the backend and web frontend independently? See `docs/deployment-overview.md` for a full walkthrough covering:

- Building and pushing each backend service image (gateway, transaction, fraud)
- Running the stack with Docker Compose or container platforms
- Production build steps for the Next.js frontend, including a sample Dockerfile
- Suggested hosting targets (Vercel, Azure Container Apps/Static Web Apps) and CI/CD tips

Those instructions are designed so you can ship the FastAPI/gRPC services and the Next.js dashboard on separate hosts or managed services.

---

##  Frontend Workflow

### Development

```bash
cd frontend

# Install dependencies
npm install

# Run the Next.js dev server (requires backend already running)
npm run dev

# Lint and format
npm run lint
npm run format
```

### Production Build

```bash
# Generate optimized production build
npm run build

# Start production server
npm start
```

### Features

The LedgerStream dashboard provides:

- **Payment Form:** Submit payments with card details, amount, and currency
- **Transaction Dashboard:** View recent transactions with status indicators
- **Real-time Updates:** Automatic refresh and toast notifications
- **Status Filtering:** Filter transactions by status (pending, completed, failed)
- **Fraud Scores:** Display fraud evaluation results for each transaction

---

## ⚙️ Environment Configuration

Core settings rely on environment variables understood by `packages/common/config/settings.py`. Create a `.env` file based on `.env.example`:

### Key Variables

```bash
# Database
DATABASE__URL=postgresql+asyncpg://postgres:postgres@localhost:5432/payment_gateway

# Gateway API
GATEWAY_API__HOST=0.0.0.0
GATEWAY_API__PORT=8000

# Transaction Service
TRANSACTION_SERVICE__GRPC_HOST=transaction-service
TRANSACTION_SERVICE__GRPC_PORT=50051

# Fraud Service
FRAUD_SERVICE__GRPC_HOST=fraud-service
FRAUD_SERVICE__GRPC_PORT=50052

# Observability
PROMETHEUS__PORT=9090
LOG_LEVEL=INFO

# OpenTelemetry (optional)
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317
```

**Note:** Variable names use double underscores (`__`) to express nested configuration sections.

---

## 🗄️ Database & Migrations

### Migration Management

Alembic migration scripts live under `services/transaction_service/transaction_service/db/migrations`.

#### Apply Migrations

```bash
# Apply all pending migrations
docker compose exec transaction-service poetry run alembic upgrade head
```

#### Generate New Migrations

```bash
# Auto-generate migration from model changes
docker compose exec transaction-service poetry run alembic revision --autogenerate -m "add_new_table"

# Review the generated migration in migrations/versions/
# Then apply it
docker compose exec transaction-service poetry run alembic upgrade head
```

#### Rollback Migrations

```bash
# Rollback one migration
docker compose exec transaction-service poetry run alembic downgrade -1

# Rollback to specific revision
docker compose exec transaction-service poetry run alembic downgrade <revision_id>
```

**Important:** Always run migrations after rebuilding the transaction service image or resetting the Postgres volume.

---

##  Testing & Quality Gates

### Run All Tests

```bash
# Run linting (ruff, mypy, etc.)
make lint

# Execute full pytest suite
make test

# Run tests with coverage
make test-coverage
```

### Service-Specific Tests

```bash
# Test transaction service
poetry run pytest services/transaction_service/tests -v

# Test gateway API
poetry run pytest services/gateway_api/tests -v

# Test fraud service
poetry run pytest services/fraud_service/tests -v
```

### Frontend Tests

```bash
cd frontend

# Run Jest tests
npm test

# Run with coverage
npm run test:coverage
```

### CI/CD Integration

CI/CD pipelines can leverage Make targets:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: |
    make lint
    make test
```

---

##  Observability

### Logging

- **Structured logging** via Loguru/structlog across all services
- Logs include correlation IDs for request tracing
- Configurable log levels via `LOG_LEVEL` environment variable

### Metrics

- **Prometheus metrics** endpoints exposed per service
- Default metrics port: defined by `PROMETHEUS__PORT`
- Custom application metrics for payment flows

### Tracing

- **OpenTelemetry hooks** prepared for distributed tracing
- Configure OTLP endpoint via `OTEL_EXPORTER_OTLP_ENDPOINT`
- Spans capture gRPC calls, database queries, and HTTP requests

### Monitoring Stack (Optional)

Add Grafana and Prometheus to `docker-compose.yml`:

```yaml
prometheus:
  image: prom/prometheus
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml

grafana:
  image: grafana/grafana
  ports:
    - "3001:3000"
```

---

##  Troubleshooting

### Common Issues

#### Missing protobuf modules
```bash
# Rebuild images to regenerate gRPC stubs
docker compose build
docker compose up -d
```

#### Database table not found
```bash
# Run Alembic migrations
docker compose exec transaction-service poetry run alembic upgrade head
```

#### gRPC interceptor errors
- Async interceptors gracefully degrade with warnings
- Verify `grpcio` version compatibility if issues persist
- Check service logs: `docker compose logs transaction-service`

#### Frontend fetch failures
- Confirm Gateway API is running: `curl http://localhost:8000/health`
- Check CORS settings in `services/gateway_api/main.py`
- Verify `NEXT_PUBLIC_API_URL` in frontend `.env.local`

#### Port conflicts
```bash
# Check what's using port 8000
netstat -ano | findstr :8000

# Stop conflicting processes or change ports in docker-compose.yml
```

### View Logs

```bash
# Tail all services
docker compose logs -f

# Specific service
docker compose logs -f transaction-service

# Last 100 lines
docker compose logs --tail=100 gateway-api
```

### Reset Environment

```bash
# Stop and remove all containers, volumes, and networks
docker compose down -v

# Rebuild from scratch
docker compose up -d --build

# Reapply migrations
docker compose exec transaction-service poetry run alembic upgrade head
```

---

##  Extending the Platform

### Add New Fraud Rules

Edit `services/fraud_service/fraud_service/rules.py`:

```python
def evaluate_transaction(amount: Decimal, merchant_id: str) -> FraudScore:
    score = 0.0
    
    # Add custom rules
    if amount > Decimal("10000"):
        score += 0.5
    
    return FraudScore(score=score, reason="Custom rule")
```

### Add New API Endpoints

Create routers in `services/gateway_api/gateway_api/routers/`:

```python
from fastapi import APIRouter

router = APIRouter(prefix="/reports", tags=["reports"])

@router.get("/daily")
async def get_daily_report():
    return {"status": "ok"}
```

### Multi-Currency Support

Extend models in `services/transaction_service/transaction_service/domain/`:

```python
class Payment(Base):
    __tablename__ = "payments"
    
    amount = Column(Numeric(precision=19, scale=4))
    currency = Column(String(3))  # ISO 4217
    exchange_rate = Column(Numeric(precision=10, scale=6))
```

### Implement Settlement Pipelines

- Add scheduled jobs using APScheduler or Celery
- Create settlement domain models and repositories
- Implement batch processing for end-of-day settlement

### CI/CD Pipelines

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          pip install poetry
          poetry install
      - name: Run tests
        run: make test
```

---

##  License

This project is provided for educational and demonstration purposes. Feel free to use, modify, and distribute under your preferred license.

---

##  Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

##  Contact

For questions or support, please open an issue on GitHub.

---

**Built with ❤️ using Python, FastAPI, gRPC, PostgreSQL, and Next.js and Flutter**
