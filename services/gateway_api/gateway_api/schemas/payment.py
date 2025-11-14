from datetime import datetime
from typing import Annotated, Optional

from pydantic import BaseModel, Field, StringConstraints


CurrencyStr = Annotated[str, StringConstraints(min_length=3, max_length=3)]
TransactionIdStr = Annotated[str, StringConstraints(min_length=8, max_length=64)]
PartyIdStr = Annotated[str, StringConstraints(min_length=4, max_length=64)]
PaymentMethodStr = Annotated[str, StringConstraints(min_length=2, max_length=32)]


class Money(BaseModel):
    currency: CurrencyStr = Field(..., description="ISO 4217 currency code")
    value_minor: int = Field(..., gt=0)


class PaymentRequest(BaseModel):
    transaction_id: TransactionIdStr
    merchant_id: PartyIdStr
    customer_id: PartyIdStr
    amount: Money
    payment_method: PaymentMethodStr
    reference: Optional[str] = Field(default=None, max_length=128)


class PaymentResponse(BaseModel):
    transaction_id: str
    status: str
    reason: Optional[str] = None


class PaymentRecord(BaseModel):
    transaction_id: str
    merchant_id: str
    customer_id: str
    amount: Money
    payment_method: str
    status: str
    reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class PaymentCollection(BaseModel):
    items: list[PaymentRecord]
    total: int
