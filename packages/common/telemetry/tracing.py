import logging

from common.config import load_settings


def init_tracer(service_name: str) -> None:
    settings = load_settings()
    if not settings.enable_traces or not settings.otel_exporter_endpoint:
        return

    try:
        from opentelemetry import trace
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
        from opentelemetry.sdk.resources import SERVICE_NAME, Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
    except ImportError:
        logging.getLogger(__name__).warning(
            "OpenTelemetry packages not installed; tracing disabled."
        )
        return

    resource = Resource(attributes={SERVICE_NAME: service_name})
    provider = TracerProvider(resource=resource)
    span_processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=settings.otel_exporter_endpoint))
    provider.add_span_processor(span_processor)
    trace.set_tracer_provider(provider)
