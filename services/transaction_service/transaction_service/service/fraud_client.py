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
except ImportError as exc:  # pragma: no cover - fails until proto compiled
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc


logger = logging.getLogger(__name__)


class FraudClient:
    def __init__(self, channel: grpc.aio.Channel, stub: payment_pb2_grpc.FraudServiceStub) -> None:
        self._channel = channel
        self._stub = stub

    @classmethod
    async def create(cls) -> "FraudClient":
        settings = load_settings()
        target = f"{settings.fraud_service_host}:{settings.fraud_service_port}"
        interceptors = [RetryInterceptor(settings.fraud_service_retry_attempts)]
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

        stub = payment_pb2_grpc.FraudServiceStub(channel)
        return cls(channel=channel, stub=stub)

    async def evaluate(
        self,
        transaction_id: str,
        merchant_id: str,
        customer_id: str,
        amount_minor: int,
        currency: str,
        payment_method: str,
    ) -> payment_pb2.FraudCheckResponse:
        request = payment_pb2.FraudCheckRequest(
            transaction_id=transaction_id,
            merchant_id=merchant_id,
            customer_id=customer_id,
            amount=payment_pb2.Money(currency=currency, value_minor=amount_minor),
            payment_method=payment_method,
        )
        metadata = metadata_request_id()
        return await self._stub.Evaluate(
            request, timeout=load_settings().fraud_service_timeout_seconds, metadata=metadata
        )

    async def close(self) -> None:
        await self._channel.close()
