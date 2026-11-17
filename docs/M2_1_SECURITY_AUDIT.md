# M2.1 security and acceptance audit

Date: 2026-11-17. Branch: `feature/m2-implementation`. Scope: M2.1 API, identity schema, contracts, local Docker stack, and CI configuration. M2.2 and physical equipment writes remain outside scope.

## Findings by severity

| Severity | Finding | Status and evidence |
|---|---|---|
| Critical | No confirmed critical issue in the exposed M2.1 routes. | No M2.1 route writes equipment or exposes tenant inventory. The remaining risks below block shared deployment until resolved. |
| High | Sanctum accepted a web session identity on bearer routes; logout called `delete()` on a transient token and returned HTTP 500. | Fixed with `RequireActiveBearerToken`. Session identities now return 401. Regression test first reproduced the 500 and now passes on both databases. |
| High | There was no global disabled-user control, so a disabled account could keep using a previously issued token. | Fixed with additive `users.is_active` defaulting to true, login rejection, and a bearer-request check. Tests cover both new login and existing-token access. No public or tenant-admin account-disable endpoint is exposed; the flag is managed administratively until a reviewed workflow exists. |
| Medium | Failed-login limiting was keyed only by email and IP, allowing one IP to spread guesses over many emails. | Fixed with a second 20-failure-per-IP, one-minute limit. A regression test first reproduced the bypass. Lockouts are audited without credentials. |
| Medium | Audit foreign keys previously nulled actor or organization references on deletion, losing context. | Fixed by restricting parent deletion when audit events reference them. Tests verify the restriction and the unaudited membership cascade on SQLite and PostgreSQL. |
| Medium | CI ran the API suite only with SQLite. A Docker test run also inherited the development Redis limiter state. | Fixed CI configuration with SQLite/PostgreSQL matrix, `pdo_pgsql`, explicit isolated cache/session/queue settings, and a driver assertion. Both paths passed locally; the revised remote jobs have not run yet. |
| Medium | Creating an account with an email already used in another organization can disclose that the global account exists through a validation error. Admins also set initial passwords. | Open. A consent-based invitation and password-set flow is required before shared deployment. M2.1 remains local development only. |
| Medium | The M1 `devices.organization_id` and `devices.building_id` foreign keys do not jointly enforce tenant consistency. | Open for the equipment schema gate before M2.3 CRUD routes. No M2.1 API exposes devices or points. |
| Low | Audit rows are append-only through the M2.1 API but have no database-level immutability trigger. | Open for production hardening. The API has no audit update or delete route. |
| Low | User listing is capped at 100 without pagination. | Open for the user-management UI contract before M2.4; the cap prevents unbounded responses. |

## Controls reviewed

- **Authentication:** Passwords use Laravel's hashed cast. Login returns a generic 401 for invalid credentials or inactive users. Tokens expire after 12 hours; expiry and logout revocation are tested. Bearer-only routes reject sessions and inactive users. Login returns a token only on success, and user responses contain only ID, name, and email. Failed, limited, successful, and logout events contain no password or token value.
- **Tenant authorization:** Membership queries bind both user and organization IDs and require `active=true`. A foreign tenant or foreign membership returns 404. Viewers and operators cannot manage users; admins cannot grant owner; the owner cannot demote or remove the owner role. A role, email, and user-state mass-assignment check is covered by tests. Revoked membership access is denied on subsequent requests even while the bearer token remains valid.
- **Schema:** Roles and permissions have primary keys and a constrained pivot. Memberships have organization/user foreign keys, a unique pair, and a user/active index. Audit events have organization/time and actor/time indexes plus restricted parent deletion. Sanctum tokens have unique token hashes and expiry index. M1 device/point deletion remains a later inventory design issue. Both SQLite and PostgreSQL exercised the new constraints.
- **Upgrade:** A disposable PostgreSQL database received the four M1 migrations and legacy user/organization rows, then the three M2.1 migrations. The rows remained, and the legacy user received `is_active=true`. The normal development database was not reset or migrated for this audit.
- **API and contracts:** Invalid roles return 422; unauthenticated requests return 401; insufficient roles return 403; foreign resources return 404; successful creation returns 201. OpenAPI now describes bearer-only authentication, active-user failures, rate limits, and response shapes. The status route remains public.

## Verification

| Check | Result |
|---|---|
| SQLite full Laravel suite with driver assertion | 30 passed, 120 assertions |
| Isolated PostgreSQL full Laravel suite with driver assertion and array cache | 30 passed, 120 assertions |
| Disposable M1-to-M2.1 PostgreSQL upgrade | 4 M1 and 3 M2.1 migrations; legacy rows preserved |
| Vue production build in web container | Passed, 11 modules |
| Python edge tests | 2 passed |
| `docker compose config --quiet` | Passed |
| OpenAPI and CI YAML parse; database matrix inspection | Passed |
| Remote CI execution for revised matrix | Not yet run |

The local development API remains bound to localhost by Compose, and the edge process remains in simulation mode with writes disabled. Flutter runtime tests are still deferred because its SDK and platform runners are unavailable.
