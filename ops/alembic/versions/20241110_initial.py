"""Initial tables for ledger and retry outbox

Revision ID: 20241110_initial
Revises: 
Create Date: 2025-11-10
"""

from collections.abc import Sequence
from typing import Optional

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20241110_initial"
down_revision: Optional[str] = None
branch_labels: Optional[Sequence[str]] = None
depends_on: Optional[Sequence[str]] = None


def upgrade() -> None:
    op.create_table(
        "ledger_entries",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("transaction_id", sa.String(length=64), nullable=False),
        sa.Column("merchant_id", sa.String(length=64), nullable=False),
        sa.Column("customer_id", sa.String(length=64), nullable=False),
        sa.Column("amount_minor", sa.BigInteger(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("payment_method", sa.String(length=32), nullable=False),
        sa.Column("status", sa.Enum("pending", "confirmed", "declined", "retry", name="ledgerstatus"), nullable=False),
        sa.Column("reason", sa.String(length=255), nullable=True),
    sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now(), server_onupdate=sa.func.now()),
    )
    op.create_index("idx_ledger_transaction_status", "ledger_entries", ["transaction_id", "status"])

    op.create_table(
        "retry_outbox",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("transaction_id", sa.String(length=64), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("max_attempts", sa.Integer(), nullable=False, server_default="5"),
        sa.Column("next_attempt_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now(), server_onupdate=sa.func.now()),
    )
    op.create_index("idx_retry_transaction", "retry_outbox", ["transaction_id"])


def downgrade() -> None:
    op.drop_index("idx_retry_transaction", table_name="retry_outbox")
    op.drop_table("retry_outbox")
    op.drop_index("idx_ledger_transaction_status", table_name="ledger_entries")
    op.drop_table("ledger_entries")
    op.execute("DROP TYPE IF EXISTS ledgerstatus")
