from __future__ import annotations

from typing import TYPE_CHECKING

import asyncio

import grpc

from common.config import load_settings
from common.logging import setup_logging
from common.metrics import start_metrics_server
from common.telemetry import init_tracer

from ..service.evaluator import FraudEvaluator

if TYPE_CHECKING:
    from common.generated import payment_pb2, payment_pb2_grpc

try:
    from common.generated import payment_pb2, payment_pb2_grpc
except ImportError as exc:  # pragma: no cover
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc


def _get_server() -> grpc.aio.Server:
    server = grpc.aio.server()
    payment_pb2_grpc.add_FraudServiceServicer_to_server(FraudServicer(), server)
    return server


class FraudServicer(payment_pb2_grpc.FraudServiceServicer):
    def __init__(self) -> None:
        self.evaluator = FraudEvaluator()

    async def Evaluate(self, request: payment_pb2.FraudCheckRequest, context: grpc.aio.ServicerContext) -> payment_pb2.FraudCheckResponse:  # noqa: N802
        return self.evaluator.evaluate(request)


async def serve() -> None:
    settings = load_settings()
    setup_logging(settings.log_level)
    init_tracer("fraud-service")
    start_metrics_server(settings.metrics.host, settings.metrics.port)

    server = _get_server()
    listen_addr = f"{settings.grpc.host}:{settings.grpc.port}"
    server.add_insecure_port(listen_addr)

    await server.start()
    await server.wait_for_termination()


def run() -> None:
    asyncio.run(serve())
