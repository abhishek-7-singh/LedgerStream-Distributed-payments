from __future__ import annotations

from typing import TYPE_CHECKING

from loguru import logger

from common.logging import setup_logging

from ..rules.default_rules import load_default_rules
from ..rules.engine import RuleEngine

if TYPE_CHECKING:
    from common.generated import payment_pb2

try:
    from common.generated import payment_pb2
except ImportError as exc:  # pragma: no cover
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc


class FraudEvaluator:
    def __init__(self) -> None:
        setup_logging()
        self.engine = RuleEngine(load_default_rules())

    def evaluate(self, request: payment_pb2.FraudCheckRequest) -> payment_pb2.FraudCheckResponse:
        result = self.engine.evaluate(request)
        flagged = result.score >= 0.7
        logger.bind(request_id=request.transaction_id).info(
            "Fraud evaluation completed", score=result.score, flagged=flagged, reason=result.reason
        )
        return payment_pb2.FraudCheckResponse(
            transaction_id=request.transaction_id,
            flagged=flagged,
            score=result.score,
            reason=result.reason or "",
        )
