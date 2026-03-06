# Example Context File

This is an anonymized example of a high-quality context file for a medium-complexity
Python web service. Every line was included because removing it would cause a wrong
review comment. Inline comments (<!-- ... -->) explain what was EXCLUDED and why.

Use this to calibrate your output quality. The real file is ~180 lines for a project
with 40+ source files, 15+ dependencies, and moderate architectural complexity.

---

## Project Overview

**Purpose:** REST API service that processes insurance claims, validates coverage,
and triggers automated payouts via third-party payment providers.
**Type:** Web service (FastAPI)
**Domain:** Insurance / Claims Processing
**Key Dependencies:** `fastapi` (API framework), `sqlalchemy` (ORM), `celery` (async tasks)

<!-- EXCLUDED: "Built with Python" — obvious from deps -->
<!-- EXCLUDED: "Uses REST architecture" — FastAPI implies this -->
<!-- EXCLUDED: 3-paragraph project history — doesn't help reviewers -->

## Technology Stack

### Versions (current as of 2025-11-15)
- **Python** 3.12
- **fastapi** >=0.115.0 - Uses `Annotated` dependency injection pattern throughout
- **sqlalchemy** >=2.0.36 - 2.0-style queries only (no legacy `session.query()`)
- **celery** >=5.4.0 - Async task processing for claim workflows
- **pydantic** >=2.10.0 - All request/response schemas and internal models
- **httpx** >=0.28.0 - External API calls (payment providers, coverage lookup)
- **alembic** >=1.14.0 - Database migrations (must be backwards-compatible)
- **structlog** >=24.4.0 - All logging (never stdlib `logging` directly)

<!-- EXCLUDED: pytest, ruff, mypy versions — reviewers rarely see these in diffs -->
<!-- EXCLUDED: transitive deps like uvicorn, gunicorn — not in business code -->
<!-- EXCLUDED: "pydantic is a validation library" — everyone knows this -->

### Container Images
- Base: `python:3.12-slim-bookworm`
- Build: `node:22-slim` (for admin dashboard assets only)

### Dev Tools
- **Testing:** pytest >=8.3 (85% coverage enforced) | **Linting:** ruff >=0.8
- **Types:** mypy strict | **CI:** GitHub Actions | **Package:** uv

## Architecture & Code Organization

### Structure
```
src/claims_api/
├── main.py                # FastAPI app factory + middleware setup
├── api/
│   ├── v1/routes/         # Route handlers (thin — delegate to services)
│   └── deps.py            # Dependency injection (DB sessions, auth, config)
├── services/              # Business logic layer (one service per domain)
│   ├── claims.py          # Claim lifecycle (create → validate → process → pay)
│   └── coverage.py        # Coverage verification against policy rules
├── models/                # SQLAlchemy models + Pydantic schemas
│   ├── db/                # ORM models (mapped classes)
│   └── schemas/           # API request/response schemas
├── tasks/                 # Celery task definitions
│   └── claim_tasks.py     # Async claim processing pipeline
├── integrations/          # External service clients
│   ├── payment_gateway.py # PaymentCo API wrapper (retry + idempotency)
│   └── policy_service.py  # Internal policy lookup service
└── core/
    ├── config.py          # Settings via pydantic-settings (env-based)
    └── exceptions.py      # Domain exceptions → HTTP error mapping
```

<!-- EXCLUDED: tests/ structure — standard pytest layout, nothing unusual -->
<!-- EXCLUDED: migrations/ — reviewers understand alembic conventions -->

### Key Patterns
- **Route handlers are thin**: All business logic lives in `services/`. Routes only
  handle request parsing and response formatting. Don't suggest moving logic into routes.
- **Repository pattern**: DB access goes through repository classes in `models/db/`,
  never raw SQLAlchemy in services. Don't suggest `session.execute()` in service code.
- **Idempotency keys**: All payment operations require idempotency keys. The
  `payment_gateway.py` client handles this — don't suggest removing the key parameter.
- **Config via environment**: All config through `pydantic-settings` with env vars.
  No config files, no CLI args. `Settings()` reads from environment.

### Critical Files
- **`services/claims.py`** — Claim state machine with strict transitions. State changes
  must go through `transition_state()` — direct status assignment breaks audit logging.
- **`integrations/payment_gateway.py`** — PaymentCo integration with custom retry logic
  and idempotency. The 3-retry with exponential backoff is required by their API TOS.
- **`core/config.py`** — Environment-based config. All fields have explicit env var names.
  New settings must include `env=` parameter in Field definition.
- **`api/deps.py`** — FastAPI dependency injection. DB session lifecycle managed here.
  Don't suggest alternative session management patterns.

## Review Guidance

### What Reviewers Must Know
- **SQLAlchemy 2.0 style only**: Use `select()`, `session.scalars()`, `session.execute()`.
  Never `session.query()` or legacy patterns — the project fully migrated to 2.0.
- **Claim state transitions**: Must go through `ClaimService.transition_state()`.
  Direct `claim.status = X` bypasses validation, audit logging, and event emission.
- **Migrations must be backwards-compatible**: Zero-downtime deploys mean the old code
  runs alongside new migrations. Add columns as nullable, never drop in the same release.
- **Structured logging only**: Use `structlog.get_logger()`, never `print()` or stdlib
  `logging.getLogger()`. Log context is propagated via context vars.

### Do NOT Flag (Known False Positives)
- `time.sleep()` in `tasks/claim_tasks.py` — Required rate limiting for PaymentCo API
  (max 10 req/sec). Don't suggest async alternatives — Celery workers are sync.
- `# type: ignore[assignment]` on SQLAlchemy relationship attrs — Known mypy limitation
  with mapped columns. Tracked upstream.
- Bare `except Exception` in `payment_gateway.py` retry loop — Intentional catch-all
  for the retry mechanism. PaymentCo can raise non-standard exceptions.
- `Any` type hints in `api/deps.py` — FastAPI's `Depends()` typing is limited.
  Type safety is enforced at the service layer instead.

### Common Pitfalls
- **Forgetting idempotency keys on payment calls**: Every `PaymentGateway.charge()` call
  must include an idempotency key. Without it, retries can cause duplicate charges.
  (Caused production incident — see commit `a3f2e1d`)
- **Adding non-nullable columns in migrations**: Breaks zero-downtime deploys. Always
  add as nullable with a default, then backfill, then add constraint in next release.
- **Using `session.commit()` in service methods**: Services should not commit — the
  route handler's dependency manages transaction boundaries via `deps.get_db()`.

## Internal & Proprietary

- **PaymentCo SDK** (`integrations/payment_gateway.py`): Internal wrapper around PaymentCo's
  REST API. Custom retry logic is contractually required (3 retries, exponential backoff).
  Don't suggest using their official Python SDK — it doesn't support our auth flow.
- **PolicyService** (`integrations/policy_service.py`): Internal gRPC service for policy
  lookups. Called via generated stubs. Don't suggest REST alternatives.
- **`@audit_log` decorator**: Custom decorator that logs all state changes to the audit
  table. Required for compliance. Don't suggest removing it for "simplicity."

<!-- EXCLUDED: Description of what FastAPI, SQLAlchemy, Celery do — the LLM knows -->
<!-- EXCLUDED: How to set up the dev environment — not review-relevant -->
<!-- EXCLUDED: API endpoint documentation — the LLM can read route decorators -->

---
<!-- MANUAL SECTIONS - DO NOT MODIFY THIS LINE -->

## Architecture & Design Decisions

- **Why Celery over FastAPI BackgroundTasks**: Claim processing can take 30+ seconds
  (external API calls + validation). BackgroundTasks would block the worker. Celery
  provides proper retry, dead letter queues, and monitoring via Flower.
- **Why no GraphQL**: Insurance domain has well-defined resources. REST maps cleanly.
  GraphQL would add complexity without solving a real problem for our use case.
- **Service layer pattern**: Adopted after route handlers grew to 200+ lines. Services
  are the only layer allowed to call repositories and external integrations.

## Business Logic

- **Claim state machine**: `DRAFT → SUBMITTED → VALIDATING → APPROVED/DENIED → PAID/CLOSED`.
  Backward transitions are never allowed. Only `SUBMITTED → DRAFT` is permitted (for
  corrections before validation begins).
- **Coverage rules**: A claim is valid only if the policy covers the claim type AND the
  incident date falls within the policy's effective period. Edge case: grace period of
  30 days after policy expiration for claims filed before expiration.
- **Payout thresholds**: Claims under $500 auto-approve. $500-$5000 require one reviewer.
  Over $5000 require two reviewers + manager approval. These thresholds are in config,
  not hardcoded.

## Domain-Specific Context

- **Claim vs Policy**: A claim is a request for payout. A policy is the coverage contract.
  One policy can have many claims. Don't confuse these in review comments.
- **Adjudication**: The process of evaluating a claim against policy rules. Happens in
  `services/claims.py:adjudicate()`. This is the core business logic.
- **Subrogation**: When the insurer recovers costs from a third party. Handled separately
  in `services/subrogation.py` — don't suggest merging with claims service.

## Special Cases

- **Legacy CSV import**: `tasks/import_legacy.py` processes CSV files from the old system.
  Uses pandas despite the project not using it elsewhere. This is intentional — the import
  runs monthly and will be removed after migration completes (target: Q2 2026).
- **Dual payment provider**: During PaymentCo migration from v2 to v3 API, both are active.
  The `PAYMENT_API_VERSION` env var controls which is used. Don't suggest removing v2 code
  until migration is complete.

---
*Generated by [context-generator](https://github.com/juanje/context-generator) v1.0.0 | Cursor 2.6.11 with claude-4.6-opus-high*
