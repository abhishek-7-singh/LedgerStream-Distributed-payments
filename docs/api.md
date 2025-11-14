# API Reference

## REST Endpoints

### POST /api/payments

Creates a payment transaction and returns an immediate status response.

**Request Body**

```json
{
  "transaction_id": "string",
  "merchant_id": "string",
  "customer_id": "string",
  "amount": {
    "currency": "USD",
    "value_minor": 1050
  },
  "payment_method": "card",
  "reference": "optional text"
}
```

**Response**

```json
{
  "transaction_id": "string",
  "status": "confirmed | declined | retry",
  "reason": "optional"
}
```

Possible status codes:

- `202 Accepted` for successful submission.
- `400 Bad Request` on validation errors.
- `502 Bad Gateway` when downstream services are unavailable.

### GET /metrics

Prometheus metrics endpoint exposed by each service.

## gRPC Services

### TransactionService

- `ProcessTransaction(TransactionRequest) -> TransactionResponse`
- `GetStatus(TransactionStatus) -> TransactionResponse`

### FraudService

- `Evaluate(FraudCheckRequest) -> FraudCheckResponse`

Consult `proto/payment.proto` for message definitions. Generate Python stubs via `make proto`.
