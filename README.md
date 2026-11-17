# BMS platform

Development scaffold for a hybrid cloud and local gateway building management system. M1 is closed; M2.1 adds local identity and organization-scoped user management. Protocol discovery, telemetry ingestion, equipment commands, and deployment are later milestones.

## Local development

With Docker installed, copy `.env.example` to `.env`, then run `docker compose up --build`. API: `http://localhost:8000/api/v1/status`; web: `http://localhost:5173`. The edge agent starts in simulation mode with writes disabled. No live equipment endpoint is configured.

Without Docker, install PHP 8.3+, Composer, Node 22+, Python 3.12+, Flutter, PostgreSQL and Redis as needed. API tests use SQLite in memory. See `docs/PROGRESS.md` for verified local commands and missing tools.
