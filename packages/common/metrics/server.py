import threading
from prometheus_client import start_http_server


def start_metrics_server(host: str, port: int) -> None:
    """Launch Prometheus metrics server on a background thread."""

    def _run() -> None:
        start_http_server(port, host)

    thread = threading.Thread(target=_run, daemon=True)
    thread.start()
