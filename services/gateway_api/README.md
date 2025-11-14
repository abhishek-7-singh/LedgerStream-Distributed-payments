# Gateway API

REST ingress for the distributed payment gateway. Accepts payment requests and forwards them to the Transaction Service using gRPC while exposing user-friendly HTTP endpoints.

## Responsibilities

- Receive REST requests for transaction submission and status queries.
- Translate payloads to gRPC requests for backend services.
- Propagate correlation IDs and handle error translation.
- Serve Prometheus metrics and health endpoints.

## Running Locally

```bash
poetry run gateway-api
```

Environment variables configure target gRPC hosts; see `.env.example` for reference.
