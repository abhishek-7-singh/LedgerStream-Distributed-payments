from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Callable, Iterable, List, Optional

if TYPE_CHECKING:
    from common.generated import payment_pb2

try:
    from common.generated import payment_pb2
except ImportError as exc:  # pragma: no cover
    raise RuntimeError("Generated gRPC modules missing. Run `make proto`.") from exc


@dataclass
class RuleResult:
    name: str
    score: float
    reason: Optional[str] = None


class Rule:
    def __init__(
        self, name: str, func: Callable[[payment_pb2.FraudCheckRequest], RuleResult]
    ) -> None:
        self.name = name
        self.func = func

    def evaluate(self, request: payment_pb2.FraudCheckRequest) -> RuleResult:
        return self.func(request)


class RuleEngine:
    def __init__(self, rules: Iterable[Rule]) -> None:
        self.rules: List[Rule] = list(rules)

    def evaluate(self, request: payment_pb2.FraudCheckRequest) -> RuleResult:
        score = 0.0
        reasons: List[str] = []

        for rule in self.rules:
            result = rule.evaluate(request)
            score += result.score
            if result.reason:
                reasons.append(f"{rule.name}: {result.reason}")

        flagged = score >= 0.7
        reason = "; ".join(reasons) if reasons else None
        return RuleResult(
            name="aggregate", score=min(score, 1.0), reason=reason if flagged else None
        )
