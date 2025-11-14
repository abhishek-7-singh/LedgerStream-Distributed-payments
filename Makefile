SHELL := powershell.exe
PYTHON := poetry run python
POETRY := poetry
PROTO_SRC := proto/payment.proto
PROTO_OUT := packages/common/generated

.PHONY: install proto lint test format up down logs migrate seed

install:
	$(POETRY) install

proto:
	$(POETRY) run python -m grpc_tools.protoc -I proto --python_out=$(PROTO_OUT) --grpc_python_out=$(PROTO_OUT) $(PROTO_SRC)

lint:
	$(POETRY) run ruff check .
	$(POETRY) run black --check .
	$(POETRY) run mypy services packages

format:
	$(POETRY) run black .
	$(POETRY) run isort .

migrate:
	$(POETRY) run alembic -c ops/alembic.ini upgrade head

seed:
	$(POETRY) run python ops/seed_data.py

up:
	docker compose up -d --build

logs:
	docker compose logs -f

down:
	docker compose down -v

test:
	$(POETRY) run pytest
