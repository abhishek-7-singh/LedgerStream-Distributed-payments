from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from common.config import load_settings
from common.db import init_engine
from common.logging import setup_logging
from common.metrics import start_metrics_server
from common.telemetry import init_tracer

from .api.routes import router

app = FastAPI(title="Distributed Payment Gateway")
app.include_router(router, prefix="/api")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event() -> None:
    settings = load_settings()
    setup_logging(settings.log_level)
    init_engine()
    start_metrics_server(settings.metrics.host, settings.metrics.port)
    init_tracer("gateway-api")


def run() -> None:
    import uvicorn

    uvicorn.run("gateway_api.app:app", host="0.0.0.0", port=8000, reload=False)
