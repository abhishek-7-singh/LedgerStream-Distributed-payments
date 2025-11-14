# Security Notes

- **Transport Security**: By default, gRPC channels operate without TLS for local development. To enable TLS:
  1. Place certificates under `docker/tls/` (`ca.crt`, `server.crt`, `server.key`).
  2. Set `GRPC_USE_TLS=true` in the `.env` file.
  3. Ensure services mount the certificates using the volumes defined in `docker-compose.yml`.
- **Secrets Management**: Use the `.env` file (not committed) for local secrets. For production deployments, inject secrets via your orchestrator (Kubernetes Secrets, AWS SSM, Azure Key Vault, etc.).
- **Database Credentials**: Ensure PostgreSQL roles are scoped to the minimal privileges required. Rotate credentials regularly.
- **Input Validation**: All REST and gRPC inputs are validated with Pydantic models. Avoid bypassing schema validation when adding new endpoints.
- **Auditing**: Ledger tables include created/updated timestamps and status enums. Extend with user identity metadata if required for compliance.
