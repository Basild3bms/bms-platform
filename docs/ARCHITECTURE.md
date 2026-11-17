# Architecture

## System context

```mermaid
flowchart LR
  W[Vue web] --> API[Laravel API]
  M[Flutter mobile] --> API
  API --> PG[(PostgreSQL)]
  API --> R[(Redis)]
  API <--> G[Python edge gateway]
  G --> B[Building networks]
```

Cloud API owns tenant identity, authorization, inventory, telemetry storage, alarms and command policy. Edge gateway owns protocol connections, local buffering and final safety checks. Clients never access building networks directly. A future broker carries mutually authenticated MQTT messages; WebSockets deliver live updates to clients. M1 has only a status API and inert edge process.

## Data and command paths

Telemetry path: adapter reads point, normalizes value/unit/quality/timestamp, assigns monotonic source sequence, persists to local buffer, publishes securely, API validates tenant/device mapping and deduplicates, stores history, then fans out updates. Commands require an authenticated user, tenant and role check, point allowlist, value bounds, optional approval, expiry and idempotency key. The edge rechecks all restrictions before any protocol write, then reports acknowledgement and observed state. Physical writes remain disabled by default.

## Deployment

Local Compose is development only. Production topology separates the public API from database and Redis; uses TLS, secret management, database backups and restore drills, broker authentication, edge certificate provisioning, observability, and phased rollout. Edge gateways have outbound-only cloud connectivity where practical. Offline buffering has bounded disk usage and explicit overflow alerts.

## Repository boundaries

`apps/api` contains API and relational migrations; `apps/web` and `apps/mobile` consume versioned contracts; `services/edge-agent` contains protocol boundary; `packages/contracts` holds public schemas; `infra` holds development images and future deployment assets; `tests` holds cross-component fixtures and scenarios.

## Mobile foundation

The Flutter app has Android and iOS runners and a modular shell. Riverpod holds in-process locale and theme preferences, GoRouter selects sections, and Material UI renders English/French navigation and explicit unavailable states. Dio is configured for the public versioned status route; secure storage is wrapped for a later Sanctum bearer flow. No authenticated request or building data fetch is active. See `FLUTTER_ARCHITECTURE.md` for module boundaries and the contract gap for organization selection.
