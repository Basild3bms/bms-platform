# Software requirements specification

## Scope and users

The BMS serves commercial offices, hotels, shopping centers and other multi-building portfolios. Users include portfolio administrators, building operators, energy managers, maintenance technicians, and read-only viewers. The cloud service holds portfolio data and policy; a local edge gateway interfaces with building networks and buffers data during WAN loss. Web, Android and iOS clients use one versioned API.

## Functional requirements and acceptance criteria

| ID | Requirement | Acceptance criterion |
|---|---|---|
| FR-01 | Organizations and roles | An administrator can invite and revoke users; every read and write is scoped to an organization; cross-tenant access returns 403 or 404. |
| FR-02 | Spatial hierarchy | Users can manage buildings, floors, zones and rooms with stable IDs; deletion cannot silently orphan devices or history. |
| FR-03 | Equipment inventory | Operators can register devices, protocol identities, equipment types and points; duplicate identities within a building are rejected. |
| FR-04 | Protocol connectivity | Edge adapters discover and read BACnet and Modbus endpoints through configured allowlists; KNX and MQTT adapters follow the same contract. Simulators prove mapping and reconnect behavior. |
| FR-05 | Live telemetry | Authorized users see point value, unit, quality and source timestamp; stale and bad-quality values are visibly marked. |
| FR-06 | History | Users can query bounded time windows and aggregate trends; results preserve source timezone information through UTC storage. |
| FR-07 | Alarms | Rules create deduplicated alarm events with severity, acknowledgement, ownership and resolution history. |
| FR-08 | Equipment control | Only authorized operators may request writes to explicitly writable points; server and edge gates validate bounds, freshness, approval and idempotency; every outcome is audited. |
| FR-09 | Automation | Versioned rules and schedules support timezone and daylight-saving behavior, simulation, approval and rollback. |
| FR-10 | Energy | Meter points map to units and buildings; reports show period totals, comparison baseline and missing-data coverage. |
| FR-11 | Maintenance | Work orders link to equipment, assignee, priority, due date and completion evidence. |
| FR-12 | Dashboards | Web and mobile show tenant-scoped portfolio summaries and drill-downs with role-appropriate controls. |
| FR-13 | Notifications | Users configure channels and severity thresholds; delivery attempts and failures are recorded. |
| FR-14 | Security and audit | Authentication, role checks, device identity, encryption, immutable audit events and secret rotation meet the controls in `SECURITY.md`. |
| FR-15 | Operations | Health, queue lag, gateway connectivity, backups, restore drills and deployment status are visible to operators. |

## Nonfunctional requirements

- Availability: define per-site SLA before production; edge data collection must continue during cloud disconnection and replay idempotently.
- Performance targets for design and load testing: 10,000 points per organization; live updates normally within 5 seconds of acquisition on a healthy network; 95th percentile indexed history query under 2 seconds for one point and 30 days at hourly resolution.
- Data: UTC timestamps, explicit units, source quality, retention policy per tenant, and a documented deletion/export process.
- Security: least privilege, TLS on every network boundary, signed gateway identity, no hardcoded credentials, audit events for sensitive actions, and default-deny control.
- Accessibility: web workflows target WCAG 2.2 AA; mobile uses semantic controls and platform accessibility settings.
- Internationalization: locale-aware labels, units and dates; building timezone governs schedules.

## M1 acceptance gate

Git and the monorepo exist; Laravel boots and exposes `/api/v1/status`; migrations create organizations, buildings, devices and device points with key constraints and nonwritable default; a Vue TypeScript build succeeds; a Flutter source shell and test exist; a Python edge shell rejects writes by default; Compose defines PostgreSQL, Redis, API, web and edge services; CI runs available component tests. M1 does not claim production readiness or live protocol support.
