import logging
import sys
from typing import Any, Dict

from loguru import logger

_LEVEL_MAP: Dict[str, int] = {
    "TRACE": logging.NOTSET,
    "DEBUG": logging.DEBUG,
    "INFO": logging.INFO,
    "WARNING": logging.WARNING,
    "ERROR": logging.ERROR,
    "CRITICAL": logging.CRITICAL,
}


def setup_logging(level: str = "INFO") -> None:
    """Configure loguru to play nicely with standard logging."""

    logger.remove()
    logger.add(
        sys.stdout,
        level=level,
        format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level} | {extra[request_id]} | {message}",
        enqueue=True,
        colorize=False,
        filter=_inject_request_id,
    )

    # Bridge standard logging so libraries respect our handler
    class InterceptHandler(logging.Handler):
        def emit(self, record: logging.LogRecord) -> None:  # pragma: no cover - simple bridge
            logger_opt = logger.opt(depth=6, exception=record.exc_info)
            logger_opt.log(record.levelno, record.getMessage())

    logging.basicConfig(handlers=[InterceptHandler()], level=_LEVEL_MAP.get(level.upper(), logging.INFO))


def _inject_request_id(record: Any) -> bool:
    context: Dict[str, Any]
    if isinstance(record, dict):
        context = record
    else:  # pragma: no cover - defensive branch for Loguru stubs
        context = getattr(record, "__dict__", {})

    context.setdefault("extra", {})
    context["extra"].setdefault("request_id", "-")
    return True
