# BMS platform

M1 foundation for a hybrid cloud and local gateway building management system. It is a development scaffold; protocol discovery, telemetry ingestion, authentication, equipment commands, and deployment are later milestones.

## Local development

With Docker installed, copy `.env.example` to `.env`, then run `docker compose up --build`. API: `http://localhost:8000/api/v1/status`; web: `http://localhost:5173`. The edge agent starts in simulation mode with writes disabled. No live equipment endpoint is configured.

Without Docker, install PHP 8.3+, Composer, Node 22+, Python 3.12+, Flutter, PostgreSQL and Redis as needed. API tests use SQLite in memory. See `docs/PROGRESS.md` for verified local commands and missing tools.
