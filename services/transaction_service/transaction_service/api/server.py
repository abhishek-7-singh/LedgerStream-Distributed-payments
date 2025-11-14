from __future__ import annotations

from typing import TYPE_CHECKING

import asyncio

import grpc

from common.config import load_settings
from common.db import async_session_factory, init_engine
from common.logging import setup_logging
from common.metrics import start_metrics_server
from common.telemetry import init_tracer

from ..db.repositories import get_ledger_entry_by_transaction_id
from ..service.processor import TransactionProcessor
from ..worker.outbox import start_scheduler

if TYPE_CHECKING:
    from common.generated import payment_pb2, payment_pb2_grpc

try:
    from common.generated import payment_pb2, payment_pb2_grpc
except ImportError as exc:  # pragma: no cover - run make proto first
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc


class TransactionService(payment_pb2_grpc.TransactionServiceServicer):
    def __init__(self) -> None:
        self.processor = TransactionProcessor()

    async def ProcessTransaction(self, request: payment_pb2.TransactionRequest, context: grpc.aio.ServicerContext) -> payment_pb2.TransactionResponse:  # noqa: N802
        return await self.processor.process(request)

    async def GetStatus(self, request: payment_pb2.TransactionStatus, context: grpc.aio.ServicerContext) -> payment_pb2.TransactionResponse:  # noqa: N802
        async with async_session_factory() as session:
            entry = await get_ledger_entry_by_transaction_id(session, request.transaction_id)

        if entry is None:
            await context.abort(grpc.StatusCode.NOT_FOUND, "Transaction not found")

        status = payment_pb2.TransactionStatus(
            transaction_id=entry.transaction_id,
            status=entry.status,
            reason=entry.reason or "",
        )
        return payment_pb2.TransactionResponse(status=status)


async def serve() -> None:
    settings = load_settings()
    setup_logging(settings.log_level)
    init_tracer("transaction-service")
    init_engine()
    start_metrics_server(settings.metrics.host, settings.metrics.port)
    start_scheduler()

    server = grpc.aio.server()
    payment_pb2_grpc.add_TransactionServiceServicer_to_server(TransactionService(), server)

    listen_addr = f"{settings.grpc.host}:{settings.grpc.port}"
    server.add_insecure_port(listen_addr)

    await server.start()
    await server.wait_for_termination()


def run() -> None:
    asyncio.run(serve())
