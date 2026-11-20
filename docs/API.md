# API contract

`GET /api/v1/auth/organizations` lists the current bearer-authenticated user's active memberships as `data`. Each entry contains only organization `id`, `name`, server-derived `role`, and current `permissions`. The response can be an empty array; inactive and foreign memberships are omitted. It requires an active account and a valid Sanctum bearer token. M2.1 has no organization status field to filter.

Protected API routes return JSON 401 for unauthenticated requests even when the caller does not send an `Accept: application/json` header.

Base path is `/api/v1`; JSON uses UTF-8. The M1 endpoint `GET /api/v1/status` returns `{"service":"bms-api","version":"0.1.0","status":"ok"}` with HTTP 200. It signals process responsiveness, not PostgreSQL, Redis or gateway readiness. The machine-readable contract is `packages/contracts/openapi.yaml`.

M2.1 adds `POST /api/v1/auth/login`, `GET /api/v1/auth/me`, and `POST /api/v1/auth/logout`. Login issues a 12-hour Sanctum bearer token; logout revokes the current token. Organization-scoped user management is at `GET/POST /api/v1/organizations/{organization}/users`, with role changes and revocation at `PATCH/DELETE /api/v1/organizations/{organization}/memberships/{membership}`. `GET` supports `page` (from 1), `per_page` (1–100, default 25), `search` (name or email), and `role`; its response has `data` and `meta` (`current_page`, `per_page`, `total`, `last_page`). `POST` accepts name, email, and role and returns HTTP 202 with a one-time invitation token for local secure delivery. It has the same response shape for new and existing email addresses and creates no membership until the invitee accepts. `POST /api/v1/invitations/accept` accepts the token, email, and invitee password within 24 hours, then creates or joins the account and consumes the token. The status, login, and invitation acceptance routes are public; every other M2.1 route requires an active user and a bearer token. Web session identities are rejected by these API routes. Foreign or inactive organization memberships return 404; insufficient permission returns 403. There is no unrestricted public registration route. A local operator can initialize an organization and owner with `php artisan bms:bootstrap-organization --name=... --slug=... --email=...`; the command prompts for a password and is unavailable in production.

The Stage 3 Flutter client uses these existing response shapes: login returns `token`, `token_type: Bearer`, `expires_at`, and `user` (`id`, `name`, `email`); `/auth/me` returns the same user fields; organization discovery returns `data` entries containing `id`, `name`, `role`, and `permissions`; logout returns HTTP 200 after revocation. The client treats login 401 as a generic credential/account failure, 422 as invalid input, 429 as rate limiting, and protected 401 as an invalid session. Network and server errors keep protected navigation closed during restoration. The selected organization ID is not a permission claim. Stage 3 adds no backend endpoint or tenant data call.

## M2.2A buildings

The M2.2B Flutter client calls only the two GET routes below using the selected organization ID and existing protected Dio bearer client. It parses list `data` and `meta`, checks each record's `organization_id`, and rejects mismatched detail IDs. A list 401 closes the mobile session; list 403/404 returns to organization selection; detail 403/404 shows an unavailable state. The app has no building write route or equipment control UI.

All four routes require an active Sanctum bearer account and an active membership in `{organization}`:

| Method and path | Permission | Success |
|---|---|---|
| `GET /api/v1/organizations/{organization}/buildings` | `buildings.view` | 200, `{data: [...], meta: {current_page, per_page, total, last_page}}` |
| `POST /api/v1/organizations/{organization}/buildings` | `buildings.manage` | 201, `{data: building}` |
| `GET /api/v1/organizations/{organization}/buildings/{building}` | `buildings.view` | 200, `{data: building}` |
| `PATCH /api/v1/organizations/{organization}/buildings/{building}` | `buildings.manage` | 200, `{data: building}` |

Viewer and operator receive `buildings.view`; admin and owner receive both permissions. Lists are sorted by code and ID and accept `page` from 1 and `per_page` from 1 to 100 (default 25). The building object contains `id`, `organization_id`, `name`, `code`, nullable `address`, `timezone`, `created_at`, and `updated_at`. The server generates the UUID and binds the organization from the URL and active membership. Create requires `name` (1–255 characters), `code` (1–64 letters, digits, `_` or `-`, starting with a letter or digit), and a valid timezone; `address` is optional and nullable up to 255 characters. Patch accepts at least one of those fields. Codes are unique within each organization. `organization_id` in a request body is rejected.

Example body for `POST /api/v1/organizations/{organization}/buildings` (send the bearer token privately in the Authorization header):

```json
{"name":"North Office","code":"N-001","address":"1 Example Street","timezone":"Europe/Paris"}
```

Missing or invalid bearer tokens and inactive accounts return 401. Active members without the needed permission return 403. An inaccessible organization or a building UUID outside that organization returns 404. Validation errors, duplicate codes, and client-supplied `organization_id` return 422. Successful creates and updates append `building.created` or `building.updated` audit events with organization, actor, and building IDs. Building deletion is not exposed because existing device foreign keys cascade on deletion.

## M2.2C Stage 1 floors and zones

The backend adds nested floor and zone routes. All require an active Sanctum bearer account and an active membership in `{organization}`; URL parents must belong to that organization. Floor routes use `floors.view` for GET and `floors.manage` for POST/PATCH. Zone routes use `zones.view` for GET and `zones.manage` for POST/PATCH. Viewer and operator have view permissions; admin and owner have view and manage permissions.

| Resource | List and create | Detail and update |
|---|---|---|
| Floor | `GET/POST /api/v1/organizations/{organization}/buildings/{building}/floors` | `GET/PATCH /api/v1/organizations/{organization}/buildings/{building}/floors/{floor}` |
| Zone | `GET/POST /api/v1/organizations/{organization}/buildings/{building}/floors/{floor}/zones` | `GET/PATCH /api/v1/organizations/{organization}/buildings/{building}/floors/{floor}/zones/{zone}` |

Lists return `{data, meta}` with `current_page`, `per_page`, `total`, and `last_page`, ordered by code then ID. `page` starts at 1; `per_page` is 1–100 (default 25). Detail, create, and update return `{data}`; create uses HTTP 201, reads and updates HTTP 200. The server generates UUIDs and resolves `organization_id`, `building_id`, and `floor_id` from the authorized URL. All parent identifiers are prohibited in POST/PATCH bodies. No DELETE routes are exposed.

Floors have `id`, `organization_id`, `building_id`, `name`, `code`, signed 32-bit `level` (negative for basements), and `created_at`/`updated_at`. Zones additionally have `floor_id` and `zone_type` instead of `level`. Create requires nonempty `name` (up to 255 characters), `code` (up to 64 ASCII letters/digits/underscore/hyphen, beginning with a letter or digit), and `level` or `zone_type`. Accepted zone types are `office`, `plant_room`, `common`, `retail`, `storage`, and `other`. PATCH requires at least one mutable field. Floor codes are unique per building; zone codes are unique per floor. Duplicate codes return 422 even if a concurrent insert wins after application validation. Database unique-violation codes and the matching code constraint are both checked before translating an error to 422. Missing/invalid credentials and inactive accounts return 401; an active member lacking the action permission gets 403; inaccessible organization, mismatched parent/record, or malformed UUID path segment returns 404; invalid input gets 422. Parent and organization keys are rejected whenever supplied, including null and empty values. Successful writes append `floor.created`, `floor.updated`, `zone.created`, or `zone.updated` in the same database transaction. OpenAPI defines the exact response schemas.

The M2.2D equipment list uses bounded numbered pages and scoped filters; the M2.1 user list uses bounded numbered pages. Future mutations will use idempotency keys where retries can cause effects, return stable error codes, and create audit events. Telemetry will include source timestamp, quality and unit; command responses will distinguish accepted, executed and observed outcomes. WebSocket channels and MQTT topics will be tenant scoped and separately authorized. No control endpoint exists in M2.1.

## M2.2D Stage 2 equipment inventory

The backend stores physical equipment independently of logical protocol devices and device points. All equipment routes require an active Sanctum bearer account and active organization membership. Viewer and operator have `equipment.view`; admin and owner have both `equipment.view` and `equipment.manage`. These permissions authorize inventory records only, never live point or gateway commands.

| Method and path under `/api/v1/organizations/{organization}` | Permission | Success |
| --- | --- | --- |
| `GET /buildings/{building}/equipment` | `equipment.view` | 200 `{data, meta}` |
| `POST /buildings/{building}/equipment` | `equipment.manage` | 201 `{data}`; building-level location |
| `POST /buildings/{building}/floors/{floor}/equipment` | `equipment.manage` | 201 `{data}`; floor-level location |
| `POST /buildings/{building}/floors/{floor}/zones/{zone}/equipment` | `equipment.manage` | 201 `{data}`; zone-level location |
| `GET /buildings/{building}/equipment/{equipment}` | `equipment.view` | 200 `{data}` |
| `PATCH /buildings/{building}/equipment/{equipment}` | `equipment.manage` | 200 `{data}` |

List filters are `type_code`, `lifecycle_status`, scoped `floor_id`, scoped `zone_id`, and bounded text `q` (code/name). `page` begins at 1; `per_page` is 1–100, default 25. Results sort by canonical code then UUID. `meta` contains `current_page`, `per_page`, `total`, and `last_page`. Supplying both floor and zone filters requires the zone to belong to that floor.

Create requires `code`, `name`, and an active catalog `type_code`. The server trims and uppercases ASCII codes and enforces uniqueness within the building. Optional fields are `description`, `manufacturer`, `model`, `serial_number`, `installed_on`, `commissioned_on`, `lifecycle_status`, and versioned `specifications`. Status defaults to `planned`; accepted values are `planned`, `installed`, `commissioned`, `active`, `out_of_service`, and `retired`. Dates use `YYYY-MM-DD`, with commissioning on or after installation when both are known. Type `other` requires a description. Version 1 specifications allow only finite, bounded numeric quantities appropriate to the type family: `design_airflow_m3_h`, `design_flow_m3_h`, `design_capacity_kw` and `rated_power_kw`. Supply `spec_schema_version: 1` with the JSON object; the object is limited to 4096 encoded bytes. Protocol configuration, credentials and unknown fields are rejected.

The server generates the UUID and derives organization, building, floor and zone IDs from the authorized route. Supplying any of these IDs, timestamps, device/point IDs or writable/control fields in a mutation body is a 422 error, including null or empty values. PATCH changes business fields only; it cannot relocate an asset. Retirement is a `PATCH` status update. There is no DELETE or live control route. Invalid/expired bearer or inactive account returns 401; active membership without permission returns 403; inaccessible tenant, parent or equipment and malformed path UUID return 404; invalid values and duplicate codes return 422. Successful mutations append `equipment.created` or `equipment.updated` in the same transaction. The machine-readable schemas and full paths are in `packages/contracts/openapi.yaml`.

Equipment routes have a 120-request-per-minute throttle; excess requests return 429.
