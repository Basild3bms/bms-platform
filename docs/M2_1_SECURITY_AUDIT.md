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
| Medium | User creation disclosed whether an email existed in another organization, and administrators set initial passwords. | Fixed for the local API with a uniform 202 invitation response. No user or membership is created until the invitee accepts with a one-time token and their own password. Invitation tokens are stored only as hashes and expire after 24 hours. Secure recipient delivery and email ownership verification remain release blockers. |
| Medium | The M1 `devices.organization_id` and `devices.building_id` foreign keys did not jointly enforce tenant consistency. | Fixed at the database layer. PostgreSQL has a composite foreign key; SQLite has equivalent insert/update triggers. Existing mismatches stop the migration. No M2.1 device write API exists; application authorization must be added with M2.3 CRUD. |
| Low | Audit rows had no database-level immutability protection. | Fixed with PostgreSQL update/delete/truncate triggers and SQLite update/delete triggers. Database owners can still alter schema; production runtime privileges must be restricted. |
| Low | User listing was capped at 100 without pagination. | Fixed with bounded page size, total metadata, literal name/email search, role filtering, and tenant-bound queries. |
| Medium | The rank policy forbids changing or removing any owner, including when two owners exist. | Safe for concurrent last-owner operations because no M2.1 route can demote or revoke an owner. A reviewed ownership transfer workflow remains a release blocker. |

## Controls reviewed

- **Authentication:** Passwords use Laravel's hashed cast. Login returns a generic 401 for invalid credentials or inactive users. Tokens expire after 12 hours; expiry and logout revocation are tested. Bearer-only routes reject sessions and inactive users. Login returns a token only on success, and user responses contain only ID, name, and email. Failed, limited, successful, and logout events contain no password or token value. Invitation acceptance is limited to five requests per minute per client IP.
- **Tenant authorization:** Membership queries bind both user and organization IDs and require `active=true`. A foreign tenant or foreign membership returns 404. Viewers and operators cannot manage users; admins cannot grant owner; the owner cannot demote or remove the owner role. A role, email, and user-state mass-assignment check is covered by tests. Revoked membership access is denied on subsequent requests even while the bearer token remains valid.
- **Schema:** Roles and permissions have primary keys and a constrained pivot. Memberships have organization/user foreign keys, a unique pair, and listing indexes. Invitations have tenant, inviter, role, hashed-token, and expiry fields. Audit events have organization/time and actor/time indexes, restricted parent deletion, and immutability triggers. Sanctum tokens have unique token hashes and expiry index. Device/building tenant consistency is enforced in both databases. M1 device/point deletion remains a later inventory design issue.
- **Upgrade:** A separate PostgreSQL database received four M1 migrations and legacy user, organization, building, and device rows, then four M2.1 migrations. All rows remained, the legacy user received `is_active=true`, and the composite tenant constraint was present. The hardening migration rolled back and reapplied successfully. The normal development database was not reset or migrated for this audit.
- **API and contracts:** Invalid roles return 422; unauthenticated requests return 401; insufficient roles return 403; foreign resources return 404; invitation requests return 202 and acceptance returns 201. OpenAPI describes bearer-only authentication, invitation acceptance, pagination, rate limits, and response shapes. The status route remains public.
- **Global review:** No committed `.env`, private key, or credential file was found. Composer and npm advisory audits reported zero known vulnerabilities. Laravel Boost generated guidance and development-only configuration were reviewed; no production credential was found. Membership and audit query construction is repeated across controllers, and paginated listing still performs a count query; monitor these as tenant sizes grow.

## Verification

| Check | Result |
|---|---|
| SQLite full Laravel suite | 35 passed, 1 skipped, 148 assertions |
| Isolated PostgreSQL full Laravel suite with driver assertion and array cache | 36 passed, 149 assertions |
| Disposable M1-to-M2.1 PostgreSQL upgrade | 4 M1 and 4 M2.1 migrations; legacy rows preserved; hardening rollback/reapply passed |
| Vue production build in web container | Passed, 11 modules; host build remains affected by mixed Alpine/WSL optional Rollup binary |
| Python edge tests | 2 passed |
| `docker compose config --quiet` | Passed |
| Redocly OpenAPI semantic validation, `git diff --check`, Composer and npm advisory audits | Passed; OpenAPI has 2 nonblocking style warnings; zero dependency advisories |
| Remote CI execution for revised matrix | Not yet run |

The local development API remains bound to localhost by Compose, and the edge process remains in simulation mode with writes disabled. Flutter runtime tests are still deferred because its SDK and platform runners are unavailable.
