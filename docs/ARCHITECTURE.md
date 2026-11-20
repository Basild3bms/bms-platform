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

M2.2C Stage 1 adds the `organization → building → floor → zone` backend hierarchy. Floor and zone rows carry explicit organization and parent IDs; PostgreSQL composite foreign keys and SQLite triggers enforce agreement with their parents. Parent changes are blocked at the database boundary, and new hierarchy foreign keys restrict deletion. The API resolves every nested resource within the authorized URL hierarchy, uses active membership role permissions, and commits each write with its audit event. This stage adds no client screens or device commands.

## Data and command paths

Telemetry path: adapter reads point, normalizes value/unit/quality/timestamp, assigns monotonic source sequence, persists to local buffer, publishes securely, API validates tenant/device mapping and deduplicates, stores history, then fans out updates. Commands require an authenticated user, tenant and role check, point allowlist, value bounds, optional approval, expiry and idempotency key. The edge rechecks all restrictions before any protocol write, then reports acknowledgement and observed state. Physical writes remain disabled by default.

## Deployment

Local Compose is development only. Production topology separates the public API from database and Redis; uses TLS, secret management, database backups and restore drills, broker authentication, edge certificate provisioning, observability, and phased rollout. Edge gateways have outbound-only cloud connectivity where practical. Offline buffering has bounded disk usage and explicit overflow alerts.

## Repository boundaries

`apps/api` contains API and relational migrations; `apps/web` and `apps/mobile` consume versioned contracts; `services/edge-agent` contains protocol boundary; `packages/contracts` holds public schemas; `infra` holds development images and future deployment assets; `tests` holds cross-component fixtures and scenarios.

## Mobile foundation

The authenticated organization discovery route joins active memberships to organizations and current role permissions in one tenant-bound query. It supplies only the caller's organization IDs, names, roles, and permission codes for future mobile selection. Server authorization remains authoritative for every scoped request.

The Flutter app has Android and iOS runners and a modular shell. Riverpod manages session state and in-process locale/theme preferences; GoRouter guards startup, login, organization selection, and dashboard routes. A public Dio client calls status and login, while a protected client attaches the Sanctum bearer token only to authenticated routes. Secure storage holds the token, expiry, and selected organization ID. Startup validates a stored token with `/auth/me` before opening protected navigation, then refreshes organization discovery. Session generations and request cancellation discard late responses after logout or organization changes. The selected organization is UI context, never proof of authorization; Laravel authorizes every tenant-scoped query. M2.2B fetches read-only building data and M2.2C.3 adds read-only floor/zone screens; no mobile equipment feature or command is active. See `FLUTTER_ARCHITECTURE.md`.

## M2.2D Stage 2 inventory boundary

The Laravel API now owns tenant-scoped physical equipment records under buildings, with optional floor and zone location. A physical asset is distinct from a logical `devices` communication endpoint and a `device_points` signal. The new type catalog classifies assets, including maintainable controllers, gateways and field instruments when appropriate; it does not assign protocol identities. There are no equipment-device or equipment-point associations yet. Future many-to-many links and BACnet/Modbus/MQTT mappings require separate same-building authorization, history and deletion policy.

Organization policy grants inventory reads to active viewer, operator, admin and owner memberships, and inventory mutations to admin and owner. Route parents are resolved under the authorized tenant; IDs are generated or derived on the server. Composite PostgreSQL keys, equivalent SQLite triggers, restrictive foreign keys and immutable-location guards provide a second integrity boundary. Each mutation and its append-only audit event commit together. The API offers no equipment deletion, device command, protocol connection or physical write path. Edge write enablement remains a separate disabled gate.
