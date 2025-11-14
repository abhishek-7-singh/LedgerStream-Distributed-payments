from __future__ import annotations

from typing import TYPE_CHECKING

import logging

import grpc

from common.config import load_settings
from common.grpc import RetryInterceptor, build_ssl_channel_credentials, metadata_request_id

if TYPE_CHECKING:
    from common.generated import payment_pb2, payment_pb2_grpc

try:
    from common.generated import payment_pb2, payment_pb2_grpc
except ImportError as exc:  # pragma: no cover
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc


logger = logging.getLogger(__name__)


class TransactionClient:
    def __init__(
        self, channel: grpc.aio.Channel, stub: payment_pb2_grpc.TransactionServiceStub
    ) -> None:
        self._channel = channel
        self._stub = stub

    @classmethod
    async def create(cls) -> "TransactionClient":
        settings = load_settings()
        target = f"{settings.transaction_service_host}:{settings.transaction_service_port}"
        interceptors = [RetryInterceptor(3)]
        creds = None
        if settings.grpc.use_tls:
            creds = build_ssl_channel_credentials(
                settings.grpc.root_cert_path,
                settings.grpc.private_key_path,
                settings.grpc.cert_chain_path,
            )
        if creds:
            channel = grpc.aio.secure_channel(target, creds)
        else:
            channel = grpc.aio.insecure_channel(target)
        if interceptors:
            intercept_fn = getattr(grpc.aio, "intercept_channel", None)
            if intercept_fn is not None:
                channel = intercept_fn(channel, *interceptors)
            else:
                logger.warning(
                    "grpc.aio.intercept_channel unavailable; continuing without interceptors"
                )
        return cls(channel=channel, stub=payment_pb2_grpc.TransactionServiceStub(channel))

    async def process(
        self, request: payment_pb2.TransactionRequest
    ) -> payment_pb2.TransactionResponse:
        metadata = metadata_request_id()
        return await self._stub.ProcessTransaction(request, metadata=metadata)

    async def get_status(self, transaction_id: str) -> payment_pb2.TransactionResponse:
        metadata = metadata_request_id()
        request = payment_pb2.TransactionStatus(transaction_id=transaction_id, status="", reason="")
        return await self._stub.GetStatus(request, metadata=metadata)

    async def close(self) -> None:
        await self._channel.close()
