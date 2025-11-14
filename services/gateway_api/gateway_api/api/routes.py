from __future__ import annotations

from typing import TYPE_CHECKING, Optional

from fastapi import APIRouter, HTTPException, Query, status

from ..clients.transaction import TransactionClient
from ..schemas.payment import (
    Money,
    PaymentCollection,
    PaymentRecord,
    PaymentRequest,
    PaymentResponse,
)

from common.db import async_session_factory
from transaction_service.db.models import LedgerEntry
from transaction_service.db.repositories import (
    get_ledger_entry_by_transaction_id,
    list_ledger_entries,
)

if TYPE_CHECKING:
    from common.generated import payment_pb2

try:
    from common.generated import payment_pb2
except ImportError as exc:  # pragma: no cover
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc

router = APIRouter()


def _map_entry(entry: LedgerEntry) -> PaymentRecord:
    return PaymentRecord(
        transaction_id=entry.transaction_id,
        merchant_id=entry.merchant_id,
        customer_id=entry.customer_id,
        amount=Money(currency=entry.currency, value_minor=entry.amount_minor),
        payment_method=entry.payment_method,
        status=entry.status,
        reason=entry.reason,
        created_at=entry.created_at,
        updated_at=entry.updated_at,
    )


@router.post("/payments", response_model=PaymentResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_payment(payload: PaymentRequest) -> PaymentResponse:
    client = await TransactionClient.create()
    try:
        request = payment_pb2.TransactionRequest(
            transaction_id=payload.transaction_id,
            merchant_id=payload.merchant_id,
            customer_id=payload.customer_id,
            amount=payment_pb2.Money(
                currency=payload.amount.currency, value_minor=payload.amount.value_minor
            ),
            payment_method=payload.payment_method,
            reference=payload.reference or "",
        )
        response = await client.process(request)
        status_payload = response.status
        return PaymentResponse(
            transaction_id=status_payload.transaction_id,
            status=status_payload.status,
            reason=status_payload.reason or None,
        )
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
    finally:
        await client.close()


@router.get("/payments/{transaction_id}", response_model=PaymentRecord)
async def retrieve_payment(transaction_id: str) -> PaymentRecord:
    async with async_session_factory() as session:
        entry = await get_ledger_entry_by_transaction_id(session, transaction_id)

    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    return _map_entry(entry)


@router.get("/payments", response_model=PaymentCollection)
async def list_payments(
    status_filter: Optional[str] = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
) -> PaymentCollection:
    async with async_session_factory() as session:
        entries = await list_ledger_entries(session, status=status_filter, limit=limit)

    mapped = [_map_entry(entry) for entry in entries]
    return PaymentCollection(items=mapped, total=len(mapped))
