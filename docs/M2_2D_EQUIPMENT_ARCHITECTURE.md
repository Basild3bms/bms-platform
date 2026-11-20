# M2.2D Stage 1 — Equipment Inventory architecture audit

Date: 2026-11-20  
Branch: `feature/m2-2d-equipment-inventory`  
Baseline: `6f0847a`  
Status: Stage 1 proposal with recorded Stage 2 implementation decisions.

## Stage 2 implementation decisions (2026-11-20)

The read-only census of the running local development PostgreSQL `devices` table returned zero rows grouped by protocol and `equipment_type`. There is no device data to map in that database; the migration still performs no device backfill and leaves `devices` and `device_points` untouched. This census does not establish the contents of any other environment.

For the first implementation, a building-local engineering code is the asset tag. Trim and uppercase ASCII input; accept only letters, digits, `_` and `-`, beginning with a letter or digit, up to 64 characters. Enforce canonical storage and `(building_id, code)` uniqueness in both databases. Type codes are a global seeded catalog with immutable code and family; there is no type-management API. Instrumentation and controls hardware are optional inventory entries when maintainable, with no automatic device link.

The six proposed lifecycle statuses are distinct. A holder of `equipment.manage` may make any status change, including retirement, with an audit event; a finer transition policy awaits commissioning workflow design. Location is immutable through the Stage 2 API. An explicit audited relocation workflow is deferred. Central-plant cross-building associations, protocol links, and history policy for linked devices/points remain deferred because this stage creates no such links.

Specifications version 1 is a small allowlist of numeric engineering quantities with explicit units: `design_airflow_m3_h`, `design_flow_m3_h`, `design_capacity_kw`, and `rated_power_kw`. Values must be finite nonnegative numbers, with design values positive; keys must be appropriate to the selected type family. An empty object is allowed, with `spec_schema_version: 1`; an absent specification uses null for both fields. Unknown keys, nested data, credentials, and oversized objects are rejected. Future families need versioned schemas before more keys are accepted. Manufacturer/model/serial are optional and not unique. Code `other` requires a description.

## 1. Current repository findings

The hierarchy is `organizations → buildings → floors → zones`. Buildings have a required organization. Floors have required organization and building; zones have required organization, building and floor. Floors and zones have UUID primary keys and codes unique within their immediate parent. PostgreSQL composite foreign keys and SQLite triggers enforce the same tenant/parent pairing. Reparenting floors and zones is blocked. The existing zone table does not yet have the composite unique key needed to reference `(id, floor_id, building_id, organization_id)` from equipment.

The legacy `devices` table is a logical integration endpoint: organization, building, name, protocol, external ID, nullable `equipment_type`, and status. Its `(building_id, protocol, external_id)` is unique. The `device_points` table belongs to a device and has name, external ID, kind, unit, and a `writable` flag defaulting to false; `(device_id, external_id)` is unique. A later hardening migration enforces device/building tenant alignment. There are no Device or DevicePoint Eloquent models or REST endpoints. `docs/DATABASE.md` calls devices “Equipment identity”; that terminology should be corrected when implementation begins. Existing `devices.equipment_type` must be inventoried before deprecation or migration, never interpreted automatically as a physical asset.

Building, Floor and Zone APIs provide reusable patterns: active membership checks, role permissions, tenant-scoped queries, server-assigned hierarchy IDs, UUID models, paginated `data`/`meta` responses, transactions with audit events, and 403 for insufficient permission versus 404 for inaccessible scopes. Floor/Zone endpoints explicitly reject injected parent IDs and translate uniqueness races to validation errors. The older Building API has somewhat different validation and route behavior; use the stricter Floor/Zone pattern as the starting convention. Audit events are append-only at the database layer.

OpenAPI documents buildings, floors and zones, but no equipment contract. Flutter has matching read-oriented Buildings/Floors/Zones clients, repositories and screens with organization-context protection and stale-response handling; it has no equipment feature. Local Compose uses PostgreSQL for the API, with SQLite used for test coverage. The edge agent remains a shell with physical writes disabled by default. This audit inspects source and migration definitions, not live database rows or production systems.

## 2. Engineering boundary and relationships

An **equipment item** is a physical asset with an engineering identity, location, manufacturer, lifecycle and maintenance history. A **device** is a protocol-facing logical endpoint or controller identity. A physical controller or gateway can have both an equipment record (for procurement/maintenance) and one or more device records (for communications); the records have different purposes and must be linked explicitly. A **point** is an addressable measured, commanded or calculated signal, such as AI, AO, DI, DO, AV, BV or MV. A sensor or actuator may be a maintainable asset when serialized/calibrated, while its readings and commands remain points. The same meter can likewise be an asset and a device endpoint.

One equipment item may be monitored by multiple controllers, and one controller may serve multiple equipment items. Keep those associations out of `equipment` columns. In a later stage add `equipment_device_links` with equipment/device IDs, organization/building scope and a role such as `controls`, `monitors` or `integrates`; unique the pair plus role if multiple roles are meaningful. Add `equipment_point_links` for an equipment item, a device point, its device, scope and engineering use (`supply_air_temperature`, `run_status`, etc.). Point links may be many-to-many where a shared sensor measures a common service. Validate any device/point linkage against the same tenant and building at both application and database levels. That requires additive composite unique identities on `devices` and `device_points` before the junction foreign keys. Do not attach BACnet objects, Modbus registers, MQTT topics, credentials or control settings directly to the asset row.

The initial link rule should be same building. A central plant serving multiple buildings needs a later explicit service-area model and authorization rule, rather than allowing arbitrary cross-building links.

## 3. Recommended data model

Use a controlled, extensible `equipment_types` catalog rather than a database enum. Initially make it global, seeded and administratively versioned with immutable `code`, `family`, display name and active flag. `equipment.type_code` references its code; family is derived from the catalog, not duplicated in each row. Organization-specific custom types can be designed after catalog governance is decided.

| Field | Rule | Reason |
| --- | --- | --- |
| `id` | UUID primary key, server generated | Matches hierarchy and API identity. |
| `organization_id`, `building_id` | Required, server assigned from route | Every asset has a tenant and building. |
| `floor_id`, `zone_id` | Nullable; `zone_id` requires `floor_id` | Plant or roof equipment may be building-wide; floor and zone locations remain available. |
| `code` | Required, at most 64 characters; canonicalized, case-insensitive uniqueness per building | Stable engineering tag; prevent `AHU-01`/`ahu-01` duplicates. |
| `name` | Required | Human-readable identity. |
| `description` | Optional, bounded text | Notes without mandatory filler. |
| `type_code` | Required catalog reference | Validated, extensible classification. |
| `manufacturer`, `model`, `serial_number` | Optional, bounded strings | Unknown for planned and legacy assets. Do not assume serial numbers are globally unique. |
| `lifecycle_status` | Required controlled value; default `planned` | Proposed values: `planned`, `installed`, `commissioned`, `active`, `out_of_service`, `retired`. |
| `installed_on`, `commissioned_on` | Optional dates with valid chronology | Planned or historic assets may lack dates; commissioning cannot precede installation when both known. |
| `specifications`, `spec_schema_version` | Optional JSON object and required version when populated | Type-specific engineering values with validated keys, units, ranges and size. No credentials or live protocol configuration. |
| `created_at`, `updated_at` | Timezone-aware timestamps | Existing Laravel convention. |

Specify tag normalization before implementation (for example trim and uppercase ASCII codes). Use a database expression index or canonical stored column to enforce case-insensitive uniqueness on PostgreSQL; make SQLite tests enforce the equivalent rule. A simple case-sensitive unique index is insufficient. Decide whether a separate asset tag is needed if `code` serves both the engineering tag and UI identifier.

Indexes: unique `(building_id, normalized_code)`; lookup `(organization_id, building_id, type_code, id)` and `(organization_id, building_id, lifecycle_status, id)`; location indexes `(organization_id, building_id, floor_id, id)` and `(organization_id, building_id, zone_id, id)`. Start with indexes justified by query plans and list filters; avoid redundant indexes where the leading columns of an existing index suffice. Bound search text and escape SQL wildcards. Do not index arbitrary JSON initially.

Classification seed, with family and asset interpretation:

| Family | Initial codes | Inventory interpretation |
| --- | --- | --- |
| Air systems | `ahu`, `fcu`, `vav`, `fan` | Physical maintainable equipment. |
| Hydronic/thermal | `chiller`, `boiler`, `heat_pump`, `circulation_pump`, `motorized_valve` | Physical maintainable equipment; small valves may be inventoried by policy. |
| Metering | `electrical_meter`, `water_meter` | Physical asset; link to logical meter device/points when integrated. |
| Instrumentation | `temperature_sensor`, `pressure_transmitter`, `co2_sensor` | Inventory only if separately tagged, calibrated, replaced or maintained; otherwise represent signals as points. |
| Controls hardware | `ddc_controller`, `gateway` | Optional physical hardware asset, linked to logical controller/gateway device identity. |
| General | `other` | Requires an explanatory name/description; review usage before proliferating. |

These codes classify assets; `device_points.kind` and protocol object types classify signals. Neither taxonomy substitutes for the other.

## 4. Tenant, parent and deletion integrity

Add a PostgreSQL composite foreign key `(building_id, organization_id) → buildings(id, organization_id)`, using the existing parent unique key. Add `(floor_id, building_id, organization_id) → floors(id, building_id, organization_id)` using the existing floor unique key. First add a unique `(id, floor_id, building_id, organization_id)` to zones, then reference it from `(zone_id, floor_id, building_id, organization_id)`. Add `CHECK (zone_id IS NULL OR floor_id IS NOT NULL)`. Because PostgreSQL composite foreign keys skip checks when nullable components are null, the check plus required building/org columns and the separate floor foreign key are essential. Use `RESTRICT` on parent deletion, and prohibit ordinary changes to equipment's organization/building/floor/zone columns. Implement equivalent insert/update checks in SQLite test migrations, including parent-scope update guards; SQLite foreign key behavior alone does not reproduce PostgreSQL composite enforcement here.

Do not expose equipment DELETE in the first API. Retirement is an audited status change. Avoid cascade deletion of inventory from building/floor/zone. Existing `devices` and `device_points` have cascading deletes; future link design must explicitly decide whether linked endpoint deletion is restricted, soft-deleted or retains a history snapshot. Existing cascades alone cannot preserve equipment-to-point history.

## 5. Authorization and API contract

Add `equipment.view` to viewer, operator, admin and owner; add `equipment.manage` to admin and owner. Both require an active membership in the route organization. No equipment permission grants live point writes or protocol control. Authorization precedes scoped lookup. Missing/invalid bearer returns 401, an active member lacking permission 403, and nonexistent/foreign tenant or parent resources 404. Validation failures, including duplicate tags at the database race boundary, return 422 without SQL details. Apply existing rate limiting.

All endpoints below are authenticated and start with `/api/v1/organizations/{organization}`. Route IDs use UUID constraints and every lookup includes organization and building scope. Server creates UUIDs and all hierarchy IDs from resolved route parents; reject client-supplied `id`, `organization_id`, `building_id`, `floor_id`, `zone_id`, timestamps, and protocol/point control fields in create/update bodies, including null values.

| Operation | Route | Response / notes |
| --- | --- | --- |
| List | `GET /buildings/{building}/equipment` | 200 `{data:[...],meta:{current_page,per_page,total,last_page}}`; filters `type_code`, `lifecycle_status`, `floor_id`, `zone_id`, bounded `q`; default page 1/per_page 25, max 100; stable `(code,id)` ordering. Validate filter IDs against the scoped hierarchy. |
| Create in building | `POST /buildings/{building}/equipment` | 201; `floor_id` and `zone_id` null. |
| Create on floor | `POST /buildings/{building}/floors/{floor}/equipment` | 201; floor derived from scoped route, zone null. |
| Create in zone | `POST /buildings/{building}/floors/{floor}/zones/{zone}/equipment` | 201; floor and zone derived from scoped route. |
| Detail | `GET /buildings/{building}/equipment/{equipment}` | 200 `{data:{...}}`; location returned as IDs and optionally compact parent labels. |
| Update | `PATCH /buildings/{building}/equipment/{equipment}` | 200; business fields only. No implicit relocation. |

Validate code/name length and normalization, catalog type, lifecycle transition, dates, manufacturer/model/serial bounds, and type-specific specification schema. Use a transaction for create/update and corresponding append-only audit event with tenant, actor, action and equipment subject. Avoid storing secrets or full sensitive payloads in audit metadata. A future explicit relocation operation would validate destination ancestry and audit both old and new locations. List/detail have no audit write requirement.

## 6. Future engineering expansion

- **Protocol mappings:** separate versioned bindings from `device_points` to BACnet object IDs, Modbus unit/register/function/word order, or MQTT topic/payload rules. Keep credentials in a secret store and commands behind server authorization plus gateway enablement.
- **Point and DDC I/O schedules:** render typed equipment-point relationships with engineering use, units, design range, point kind, controller, wiring/terminal details and revision history. Do not infer a schedule from every point on a linked controller.
- **Tender/BOM:** count equipment by type, specification and location; add procurement line items and revision snapshots later so a live inventory edit cannot silently alter an issued tender.
- **Commissioning/maintenance:** attach checklists, work orders, calibration, warranty, service intervals and documents to stable equipment UUIDs. Track events rather than overloading `lifecycle_status` with all workflow states.
- **Lifecycle:** preserve historical link and location intervals when hardware is replaced or moved; retirement retains asset history. Add room/space location only after a room hierarchy exists.

## 7. Implementation sequence and verification gates

1. Read-only census of existing `devices.equipment_type`, protocol and external IDs in the intended development dataset. Decide whether any rows represent physical assets; do not backfill by type alone. Resolve the open decisions below.
2. Write contract and tests first for tenant/parent integrity, code normalization/uniqueness, authorization and audit. Add catalog and equipment migrations, including zone composite unique and PostgreSQL/SQLite constraints. Test on disposable isolated databases, not normal development data.
3. Seed `equipment.view`/`equipment.manage`, add policy and scoped Laravel API following Floor/Zone conventions. Transactionally append audit events. Add OpenAPI schemas/examples and update terminology in database docs.
4. Add read-only Flutter equipment browsing after the backend contract is stable, preserving organization switching and stale-request protection. Keep any editing UI separate from control UI.
5. Design equipment-device and equipment-point links after device/point composite identities and deletion policy are settled. Then introduce protocol mapping and schedules as separate modules. Run PostgreSQL and SQLite contract tests plus the repository's relevant M1 checks before integration.

Critical tests: four role combinations and inactive membership; 401/403/404/422 behavior; every endpoint's tenant and building scoping; floor/zone ancestry including cross-tenant attempts; injected/null hierarchy IDs; building/floor/zone-level assets; case-insensitive code races; filters, pagination and stable ordering; specification shape, unit/range and date validation; audit transaction rollback; parent delete/reparent restrictions in PostgreSQL and SQLite; no equipment DELETE/control route; and, when links arrive, multiple devices/points per asset with cross-tenant/cross-building rejection. Keep edge write-disabled tests before any protocol adapter work.

## 8. Decisions to settle before implementation

1. Is a building-local code sufficient as the permanent engineering tag, and what normalization/allowed character policy should it use?
2. Are `commissioned` and `active` separate lifecycle states, and which status transitions require privileged review?
3. Which specification schemas, canonical units and versioning rules are required for the first equipment families?
4. Are small valves and field sensors always inventoried, or only when tagged/serialized/calibrated? Who owns custom type approval?
5. Will central plants require equipment-to-device or point links across buildings, and if so what service-area authorization model applies?
6. What is the deletion and history policy for linked devices and points, given their current cascading foreign keys?
7. When an asset moves, should the first version offer a separately audited relocation API or defer relocation entirely?
8. Which historic `devices.equipment_type` values, if any, should map to the new catalog after a data census?
