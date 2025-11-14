from functools import lru_cache
from typing import Optional

from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseSettings(BaseModel):
    url: str = Field(..., description="Async SQLAlchemy connection URL")
    echo: bool = Field(default=False)
    pool_size: int = Field(default=10, ge=1)
    max_overflow: int = Field(default=5, ge=0)


class GrpcSettings(BaseModel):
    host: str = Field(default="0.0.0.0")
    port: int = Field(default=50052, ge=1, le=65535)
    use_tls: bool = Field(default=False)
    root_cert_path: Optional[str] = Field(default=None)
    private_key_path: Optional[str] = Field(default=None)
    cert_chain_path: Optional[str] = Field(default=None)


class MetricsSettings(BaseModel):
    host: str = Field(default="0.0.0.0")
    port: int = Field(default=9464, ge=1, le=65535)


class AppSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore", env_nested_delimiter="__")

    app_name: str = Field(default="distributed-payment-gateway")
    environment: str = Field(default="development")
    log_level: str = Field(default="INFO")

    database: DatabaseSettings
    grpc: GrpcSettings
    metrics: MetricsSettings = Field(default_factory=MetricsSettings)

    fraud_service_host: str = Field(default="fraud-service")
    fraud_service_port: int = Field(default=50053, ge=1, le=65535)
    fraud_service_timeout_seconds: float = Field(default=3.0, gt=0.0)
    fraud_service_retry_attempts: int = Field(default=3, ge=0)

    transaction_service_host: str = Field(default="transaction-service")
    transaction_service_port: int = Field(default=50052, ge=1, le=65535)

    otel_exporter_endpoint: Optional[str] = Field(default=None)
    enable_traces: bool = Field(default=False)


@lru_cache()
def load_settings() -> AppSettings:
    return AppSettings()  # type: ignore[arg-type]
