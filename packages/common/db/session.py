from typing import Optional

from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from common.config import load_settings


class Base(DeclarativeBase):
    pass


_engine: Optional[AsyncEngine] = None
async_session_factory = async_sessionmaker(expire_on_commit=False)


def init_engine() -> AsyncEngine:
    """Lazily initialize the async engine and session factory."""

    global _engine
    if _engine is None:
        settings = load_settings()
        _engine = create_async_engine(
            settings.database.url,
            echo=settings.database.echo,
            pool_size=settings.database.pool_size,
            max_overflow=settings.database.max_overflow,
        )
        async_session_factory.configure(bind=_engine)
    return _engine
