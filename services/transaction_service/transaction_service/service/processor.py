from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from common.db import async_session_factory
from ..db.models import LedgerEntry
from ..db.repositories import create_ledger_entry, insert_outbox, update_ledger_status
from .fraud_client import FraudClient

try:
    from common.generated import payment_pb2
except ImportError as exc:  # pragma: no cover - run make proto first
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc


@dataclass
class TransactionProcessor:
    async def process(
        self, request: payment_pb2.TransactionRequest
    ) -> payment_pb2.TransactionResponse:
        async with async_session_factory() as session:
            async with session.begin():
                entry = LedgerEntry(
                    transaction_id=request.transaction_id,
                    merchant_id=request.merchant_id,
                    customer_id=request.customer_id,
                    amount_minor=request.amount.value_minor,
                    currency=request.amount.currency,
                    payment_method=request.payment_method,
                    status="pending",
                    reason=None,
                )
                await create_ledger_entry(session, entry)

                fraud_client: Optional[FraudClient] = None
                try:
                    fraud_client = await FraudClient.create()
                    fraud_result = await fraud_client.evaluate(
                        transaction_id=request.transaction_id,
                        merchant_id=request.merchant_id,
                        customer_id=request.customer_id,
                        amount_minor=request.amount.value_minor,
                        currency=request.amount.currency,
                        payment_method=request.payment_method,
                    )
                except Exception as exc:  # pragma: no cover - rethrow after logging
                    await insert_outbox(
                        session,
                        transaction_id=request.transaction_id,
                        payload={
                            "transaction_id": request.transaction_id,
                            "merchant_id": request.merchant_id,
                            "customer_id": request.customer_id,
                            "amount_minor": request.amount.value_minor,
                            "currency": request.amount.currency,
                            "payment_method": request.payment_method,
                        },
                        max_attempts=5,
                    )
                    await update_ledger_status(session, request.transaction_id, "retry", str(exc))
                    raise
                finally:
                    if fraud_client is not None:
                        await fraud_client.close()

                if fraud_result.flagged:
                    await update_ledger_status(
                        session, request.transaction_id, "declined", fraud_result.reason
                    )
                    status = payment_pb2.TransactionStatus(
                        transaction_id=request.transaction_id,
                        status="declined",
                        reason=fraud_result.reason,
                    )
                else:
                    await update_ledger_status(session, request.transaction_id, "confirmed")
                    status = payment_pb2.TransactionStatus(
                        transaction_id=request.transaction_id,
                        status="confirmed",
                        reason="",
                    )

        return payment_pb2.TransactionResponse(status=status)
