from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, List

if TYPE_CHECKING:
    from common.generated import payment_pb2

try:
    from common.generated import payment_pb2
except ImportError as exc:  # pragma: no cover
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc

from .engine import Rule, RuleResult


HIGH_RISK_PAYMENT_METHODS = {"gift_card", "crypto"}


def amount_threshold_rule(request: payment_pb2.FraudCheckRequest) -> RuleResult:
    if request.amount.value_minor > 100_000:  # > 1000.00
        return RuleResult(name="amount_threshold", score=0.5, reason="High value transaction")
    return RuleResult(name="amount_threshold", score=0.0)


def risky_payment_method_rule(request: payment_pb2.FraudCheckRequest) -> RuleResult:
    if request.payment_method.lower() in HIGH_RISK_PAYMENT_METHODS:
        return RuleResult(name="risky_payment_method", score=0.5, reason="Risky payment method")
    return RuleResult(name="risky_payment_method", score=0.0)


def night_time_rule(request: payment_pb2.FraudCheckRequest) -> RuleResult:
    now = datetime.utcnow()
    if 2 <= now.hour <= 5:
        return RuleResult(name="night_time", score=0.3, reason="Transaction during risk window")
    return RuleResult(name="night_time", score=0.0)


def load_default_rules() -> List[Rule]:
    return [
        Rule("amount_threshold", amount_threshold_rule),
        Rule("risky_payment_method", risky_payment_method_rule),
        Rule("night_time", night_time_rule),
    ]
