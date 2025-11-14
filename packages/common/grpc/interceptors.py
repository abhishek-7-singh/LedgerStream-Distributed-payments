import asyncio
import random
import uuid
from typing import Any, Callable, Optional, Tuple

import grpc


ClientInterceptorCallable = Callable[[grpc.ClientCallDetails, Any], Any]


class RetryInterceptor(grpc.aio.UnaryUnaryClientInterceptor):
    """Unary gRPC client interceptor adding retry with exponential backoff."""

    def __init__(self, max_attempts: int, backoff_base: float = 0.2, backoff_multiplier: float = 2.0) -> None:
        self._max_attempts = max(max_attempts, 1)
        self._backoff_base = backoff_base
        self._backoff_multiplier = backoff_multiplier

    async def intercept_unary_unary(
        self,
        continuation: ClientInterceptorCallable,
        client_call_details: grpc.ClientCallDetails,
        request: Any,
    ) -> Any:
        attempt = 0
        delay = self._backoff_base

        while True:
            try:
                return await continuation(client_call_details, request)
            except grpc.aio.AioRpcError as exc:
                if not _retryable(exc.code()) or attempt >= self._max_attempts - 1:
                    raise
                await asyncio.sleep(delay + random.uniform(0, delay / 2))
                delay *= self._backoff_multiplier
                attempt += 1


def _retryable(status_code: grpc.StatusCode) -> bool:
    return status_code in {
        grpc.StatusCode.UNAVAILABLE,
        grpc.StatusCode.DEADLINE_EXCEEDED,
        grpc.StatusCode.INTERNAL,
        grpc.StatusCode.RESOURCE_EXHAUSTED,
    }


def metadata_request_id(metadata: Optional[Tuple[Tuple[str, str], ...]] = None) -> Tuple[Tuple[str, str], ...]:
    request_id = str(uuid.uuid4())
    base_metadata = tuple(metadata or ())
    return base_metadata + (("x-request-id", request_id),)
