FROM python:3.11-slim AS base

WORKDIR /app

COPY pyproject.toml poetry.lock* ./
RUN pip install --no-cache-dir poetry && poetry config virtualenvs.in-project true && poetry install --no-root --only main

COPY packages ./packages
COPY services ./services
COPY proto ./proto
COPY ops ./ops

RUN poetry install --only main --no-root
RUN poetry run python -m grpc_tools.protoc -I proto --python_out=packages/common/generated --grpc_python_out=packages/common/generated proto/payment.proto

ENV PYTHONPATH=/app/packages:/app/packages/common/generated:/app/services/transaction_service

CMD ["poetry", "run", "transaction-service"]
