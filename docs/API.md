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

Future inventory collections will use cursor pagination and bounded filters; the M2.1 user list uses bounded numbered pages. Future mutations will use idempotency keys where retries can cause effects, return stable error codes, and create audit events. Telemetry will include source timestamp, quality and unit; command responses will distinguish accepted, executed and observed outcomes. WebSocket channels and MQTT topics will be tenant scoped and separately authorized. No control endpoint exists in M2.1.
