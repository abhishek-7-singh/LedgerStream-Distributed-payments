from datetime import datetime, timedelta
from typing import Optional, Sequence

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from .models import LedgerEntry, RetryOutbox


async def create_ledger_entry(session: AsyncSession, entry: LedgerEntry) -> LedgerEntry:
    session.add(entry)
    await session.flush()
    return entry


async def update_ledger_status(
    session: AsyncSession,
    transaction_id: str,
    status: str,
    reason: Optional[str] = None,
) -> None:
    await session.execute(
        update(LedgerEntry)
        .where(LedgerEntry.transaction_id == transaction_id)
        .values(status=status, reason=reason, updated_at=datetime.utcnow())
    )


async def get_ledger_entry_by_transaction_id(
    session: AsyncSession, transaction_id: str
) -> Optional[LedgerEntry]:
    stmt = (
        select(LedgerEntry)
        .where(LedgerEntry.transaction_id == transaction_id)
        .order_by(LedgerEntry.created_at.desc())
        .limit(1)
    )
    result = await session.scalars(stmt)
    return result.first()


async def list_ledger_entries(
    session: AsyncSession,
    *,
    status: Optional[str] = None,
    limit: int = 50,
) -> Sequence[LedgerEntry]:
    stmt = select(LedgerEntry).order_by(LedgerEntry.created_at.desc()).limit(limit)
    if status:
        stmt = stmt.where(LedgerEntry.status == status)
    result = await session.scalars(stmt)
    return result.all()


async def insert_outbox(
    session: AsyncSession, transaction_id: str, payload: dict, max_attempts: int
) -> RetryOutbox:
    record = RetryOutbox(transaction_id=transaction_id, payload=payload, max_attempts=max_attempts)
    session.add(record)
    await session.flush()
    return record


async def get_due_outbox(session: AsyncSession, limit: int = 20) -> Sequence[RetryOutbox]:
    stmt = (
        select(RetryOutbox)
        .where(
            RetryOutbox.next_attempt_at <= datetime.utcnow(),
            RetryOutbox.attempts < RetryOutbox.max_attempts,
        )
        .order_by(RetryOutbox.next_attempt_at)
        .limit(limit)
    )
    result = await session.scalars(stmt)
    return result.all()


async def mark_outbox_attempt(session: AsyncSession, record: RetryOutbox, success: bool) -> None:
    record.attempts += 1
    if success:
        await session.delete(record)
        return

    backoff_seconds = min(60, 2**record.attempts)
    record.next_attempt_at = datetime.utcnow() + timedelta(seconds=backoff_seconds)
    if record.attempts >= record.max_attempts:
        await session.delete(record)
