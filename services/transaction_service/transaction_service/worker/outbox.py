from typing import Optional

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from loguru import logger

from common.db import async_session_factory

from ..db.repositories import get_due_outbox, mark_outbox_attempt, update_ledger_status
from ..service.fraud_client import FraudClient
_scheduler: Optional[AsyncIOScheduler] = None


async def _drain_outbox() -> None:
    async with async_session_factory() as session:
        async with session.begin():
            rows = await get_due_outbox(session)
            for record in rows:
                payload = record.payload
                fraud_client: Optional[FraudClient] = None
                try:
                    fraud_client = await FraudClient.create()
                    response = await fraud_client.evaluate(
                        transaction_id=payload["transaction_id"],
                        merchant_id=payload["merchant_id"],
                        customer_id=payload["customer_id"],
                        amount_minor=payload["amount_minor"],
                        currency=payload["currency"],
                        payment_method=payload["payment_method"],
                    )
                    if response.flagged:
                        await update_ledger_status(
                            session,
                            payload["transaction_id"],
                            "declined",
                            response.reason,
                        )
                    else:
                        await update_ledger_status(session, payload["transaction_id"], "confirmed")

                    await mark_outbox_attempt(session, record, success=True)
                except Exception as exc:  # pragma: no cover
                    logger.exception("Retry attempt failed: %s", exc)
                    await mark_outbox_attempt(session, record, success=False)
                finally:
                    if fraud_client is not None:
                        await fraud_client.close()


def start_scheduler() -> None:
    global _scheduler
    if _scheduler is not None:
        return
    _scheduler = AsyncIOScheduler()
    _scheduler.add_job(_drain_outbox, "interval", seconds=15, id="drain_outbox", replace_existing=True)
    _scheduler.start()


async def shutdown_scheduler() -> None:
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
