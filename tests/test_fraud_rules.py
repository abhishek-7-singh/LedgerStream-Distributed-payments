import pytest

try:
    from common.generated import payment_pb2
except ImportError:
    pytest.skip(
        "Generated gRPC stubs missing. Run `make proto` before running tests.",
        allow_module_level=True,
    )

from fraud_service.rules.default_rules import load_default_rules
from fraud_service.rules.engine import RuleEngine


def test_high_amount_flags_transaction():
    engine = RuleEngine(load_default_rules())
    request = payment_pb2.FraudCheckRequest(
        transaction_id="txn-123",
        merchant_id="m-001",
        customer_id="c-001",
        amount=payment_pb2.Money(currency="USD", value_minor=150_000),
        payment_method="card",
    )

    result = engine.evaluate(request)

    assert result.score >= 0.5
