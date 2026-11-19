# Progress log

## M2.2C.3 final Flutter source audit — 2026-11-19

- Reproduced three defects with focused tests: a pending response accessed a disposed Riverpod provider; canceling a page-two request left `loadingMore` true; and returning from a newer building's floor list to an older list left the older route on a loading spinner. Fixed these with provider mount checks, cancellation state recovery, and visible-route reloading. The same route handling covers Floor and Zone Details; a stacked Zone Details test confirms the older requested ID reloads on return.
- Floor and Zone API boundaries now require canonical UUID-shaped organization and hierarchy identifiers before a request, validate response IDs, and reject inconsistent pagination or duplicate IDs. Controllers reject overlaps between pages while preserving the existing list and allowing a retry. Added English/French navigation, direct-link, dark-theme, scope-switch, disposal, cancellation, and duplicate-page regression assertions.
- Final checks: `flutter analyze --no-pub` found no issues; all 105 Flutter tests passed; `git diff --check` passed. Backend, migrations, database records, dependencies, production systems, and physical equipment were not changed. The existing secure-storage combined-failure commercial-release blocker remains open. Android and iOS runtime validation remains pending.

## M2.2C.3 Flutter Floors and Zones — 2026-11-19

- Added read-only typed Floor and Zone GET clients and repositories using protected Dio; list/detail controllers and screens; Building Details and Floor Details browse actions; and guarded hierarchy routes. Lists support numbered pages, pull-to-refresh, empty/error/retry states, and English/French labels. Signed floor levels and translated zone types display correctly.
- The client validates organization, building, floor, and detail IDs and rejects malformed responses. Session changes and logout clear hierarchy state and cancel requests; leaving a screen cancels its pending request, and request counters discard late replies. HTTP 401 closes the session; 403/404 show safe unavailable states. No create/update/delete or equipment write path was added.
- Automated contract, controller, and widget tests cover parsing, protected GET paths, paging, refresh, errors, organization switching, route changes, cancellation, logout, guarded deep links, and English/French navigation. Android and iOS runtime checks remain pending. The secure-storage combined-failure commercial-release blocker remains open. No backend source, migration, database record, production system, or physical equipment was changed.
- Final checks: `flutter analyze --no-pub` found no issues and all 97 Flutter tests passed; `composer test` reported 85 passed, 1 skipped, 525 assertions; both edge tests passed; Docker web `npm run build` passed. The web build used the existing local container. No Android or iOS runner was available in WSL for this implementation pass.

## M2.2C local HTTP validation and final backend hardening — 2026-11-19

- The supplied local HTTP report records owner authentication 200; three floor and six zone creates 201; updates, lists, details, and pagination 200; duplicate floor/zone codes and invalid zone type 422; cross-floor zone access 404; unauthenticated requests 401; logout 200; and replay of the revoked bearer token 401. The credential and token were not disclosed in this review. The token replay is independent server-side revocation evidence, while the Flutter secure-storage combined-failure commercial-release blocker remains unresolved.
- Read-only PostgreSQL verification independently confirmed 11 applied migrations, 12 new role-permission assignments, one organization, one demonstration building, three floors, and six zones. Basement `B1` is `Basement - Technical Level` at level -1; the technical plant room is `Main Technical Plant Room`. Audit counts are `floor.created=3`, `floor.updated=1`, `zone.created=6`, and `zone.updated=1`; all 11 rows refer to an existing resource in the same organization. No demonstration record was changed during this hardening pass.
- Added UUID constraints only to the eight floor/zone routes, so malformed path segments return 404 before PostgreSQL UUID lookup. Mutation validation now requires organization and parent keys to be absent, rejecting null and empty values. Duplicate-code translation now requires the database unique-violation code and the matching floor/zone code constraint. Tests cover malformed paths, null/empty identifiers, genuine uniqueness races, and unrelated errors that mention a constraint name.
- Final focused tests: 28 passed, 228 assertions on SQLite and on a new isolated PostgreSQL database. Full SQLite API suite: 85 passed, 1 skipped, 525 assertions. Full PostgreSQL API suite: 86 passed, 526 assertions on a separate new isolated database. Flutter analysis found no issues and all 82 tests passed; PHP Pint, Docker web build, both edge tests, and `git diff --check` passed. Redocly OpenAPI validation passed with the two existing style warnings about `info.license` and the public status response.
- Existing development and test databases were not reset; the new hardening tests used fresh isolated databases. No previously applied migration, production system, account credential, equipment, Flutter/Vue screen, commit, or remote branch was changed. Manual Android pull-to-refresh and switching between two distinct organizations remain pending. Related Buildings API hardening gaps are recorded separately in `SECURITY.md` and were not changed here.

## M2.2C Stage 1 floors and zones backend — 2026-11-19

- Added two additive migrations for `floors`, `zones`, and four permissions. Floors have UUID identity, explicit organization/building parents, signed integer level, and unique code per building. Zones add a floor parent, validated type, and unique code per floor. PostgreSQL composite foreign keys and SQLite triggers enforce parent/tenant agreement; both drivers block reparenting, and restrictive foreign keys protect the hierarchy from parent deletion. Migration rollback/reapply was tested on both drivers.
- Added eight bearer-protected nested REST operations for floor/zone list, create, detail, and update, using active membership policy checks and parent-scoped queries. Viewer/operator can read; admin/owner can read and manage. Requests cannot supply parent IDs. Lists are bounded, paginated, and stably ordered. Successful writes and append-only audit events share a transaction; a failed audit rolls back the write. Unique indexes handle concurrent code conflicts, returned as 422. No DELETE, client screen, equipment command, or physical write was added.
- Test-first focused coverage initially failed on missing routes and tables, then passed. Final focused suites: 22 tests and 171 assertions on SQLite and isolated PostgreSQL. Full SQLite API suite: 79 passed, 1 skipped, 468 assertions. Full isolated PostgreSQL API suite: 80 passed, 469 assertions. Flutter analysis found no issues and all 82 Flutter tests passed; Docker web build and both edge tests passed. PHP Pint passed. Redocly semantic validation passed with two pre-existing style warnings (missing `info.license` and no 4XX response on public status). Earlier comma-containing flow descriptions in the OpenAPI contract were quoted after lint found that YAML had parsed them as extra keys.
- PostgreSQL checks used only the new `bms_m2_2c_isolated_check` database with CI-style array cache/session settings. The normal development database was not migrated or reset; the two new migrations still require a reviewed deployment decision there. The isolated test database remains available for review. Existing commercial-release security blockers remain open. No production access, account change, commit, or push occurred during this implementation.

## M2.2B Android runtime validation — 2026-11-19

- Windows 11 validation report for commit `66fcbbe` on `feature/m2-2b-flutter-buildings`: Flutter analysis found no issues, all 82 Flutter tests passed, and a debug APK compiled, installed, and launched on `emulator-5554`.
- The authenticated Buildings list displayed real local PostgreSQL data. Detail showed the expected name, code, address, and time zone. Disconnecting the network showed a safe error and Retry button; restoring the network and retrying recovered detail. Organization reselection restored building access.
- Logout returned to Sign in; Android Back did not reveal protected building information, and reopening the app preserved the logged-out state. This evidence comes from the supplied Windows runtime report; the emulator was not rerun from WSL during this documentation update.
- Still pending: independent pull-to-refresh confirmation, manual switching between two distinct organizations, independent server-side logout-token revocation verification, and the secure-storage failure-handling commercial-release blocker. The WSL host Rollup binary mismatch remains unresolved. No application source, production system, database record, or physical equipment was changed in this documentation update.

## M2.2B Flutter Buildings integration — 2026-11-19

- Implemented read-only, organization-scoped Buildings list and detail using the existing Laravel GET API, protected Dio bearer client, and selected session context. Added typed response validation, numbered pagination, pull-to-refresh, safe loading/empty/error/retry states, English/French labels, and an overview entry. No building IDs are hardcoded in the app.
- Building state is cleared and in-flight requests are cancelled or disregarded on organization switch and logout. A list 401 closes the session; list 403/404 returns to organization selection; detail 403/404 shows unavailable. No API, database, migration, equipment command, or physical-write change was made.
- Flutter analysis passed with no issues. The full Flutter suite passed 82 tests after adding API contract, controller, and widget tests; it uses fake HTTP and does not touch the development database. SQLite `composer test` passed 57 tests, 1 skipped, 296 assertions; edge unit tests passed 2. Web build passed in the existing Docker container. The WSL host web build remains blocked by the known missing GNU Rollup optional binary in shared `node_modules`.
- Android M2.2B building runtime validation was pending at implementation review; the subsequent Windows report is recorded above. Secure-storage failure handling remains a commercial-release blocker. Implementation is recorded at commit `66fcbbe`; this documentation update is uncommitted and unpushed pending review.

## M2.2A secure buildings API — 2026-11-19

- On local `feature/m2-2-building-management`, added a reversible migration for `buildings.view` (viewer, operator, admin, owner) and `buildings.manage` (admin, owner) without changing previously executed migrations. Existing user and role permissions remain intact.
- Added a UUID Building model and authenticated, organization-scoped list, create, detail, and update routes. Active membership and server role mapping control 404/403 outcomes. Building UUIDs are resolved under the requested organization, and request bodies cannot set `organization_id`. Creates and updates append actor-, organization-, and building-scoped audit events in the same transaction. No DELETE or equipment command route was added.
- Test-first building coverage initially failed on missing routes and permissions, then passed. Final SQLite suite: 57 passed, 1 skipped, 296 assertions. Isolated PostgreSQL suite: 58 passed, 297 assertions. Existing organization discovery tests were updated to expect the two new server-derived permissions. The Vue container build, both edge tests, all 64 Flutter tests, Flutter analysis, PHP Pint, OpenAPI structure, and `git diff --check` passed.
- The new migration was applied only inside isolated test databases. A final read-only status check found that the four earlier M2.1 migrations are now applied in the normal development PostgreSQL database; the new M2.2A building-permission migration alone is pending. No normal development database migration, account change, reset, production connection, physical write, commit, or push was performed during M2.2A work. Local API runtime for M2.2A awaits an approved development database migration.

## Local development account check — 2026-11-19

- Read-only inspection of the running local Docker API's PostgreSQL `bms` database found zero users, zero organizations, and no `organization_memberships` table. Four M2.1 identity and hardening migrations are pending. There is no active development account with an organization membership for authenticated Android testing.
- The local-only `bms:bootstrap-organization` command creates an organization and active owner membership and prompts privately for a password of 12–128 characters. Applying the pending migrations and creating credentials require a separate user action; neither was performed in this check. Normal development data was not reset or modified.

## M2.1F Stage 3 mobile authentication implementation — 2026-11-19

- Implemented the existing Laravel/OpenAPI authentication contract in Flutter on local `feature/m2-1f-mobile-authentication`, starting from `6e564423a64ec31850cf603320853a8466ceaa2c`. Tests were added before the corresponding infrastructure and UI. No backend endpoint, dependency upgrade, or tenant data feature was added.
- Added typed login/current-user/organization responses; public and bearer-authenticated Dio boundaries; secure token, expiry, and selected organization storage; server-validated restoration; expiry and 401 invalidation; retry states; request cancellation and generation checks; English/French login; protected GoRouter navigation; organization selection, refresh, switching, and access-loss handling; and logout that reports uncertain server revocation or local deletion. The dashboard keeps unavailable states for unimplemented modules, including energy management and reports.
- Automated checks after the security review: Flutter analysis found no issues, all 64 Flutter tests passed, and Dart formatting is clean. Backend SQLite passed 44 tests, 1 skipped, 180 assertions; isolated PostgreSQL `bms_m2_1f_isolated_check` passed 45 tests, 181 assertions. The prior Stage 3 edge tests and web container build passed; neither component changed during this review. OpenAPI YAML parsed with all four auth operations present; Android XML parsed with backup disabled and release cleartext denied; `git diff --check` passed. The WSL host web build still cannot load its GNU Rollup optional binary from the container-owned `node_modules`.
- Security review: no credentials or bearer values are logged by the new mobile source; public status and login are bearer-free; restored sessions cannot enter the shell before server validation; selected organization and displayed permissions are UI context only. No tenant data or equipment command is requested. A regression test reproduced token recovery after failed secure deletion. The client now invalidates the token in secure storage before deleting it; restart and repeated-logout tests cover the deletion-only failure and preserve an unconfirmed revocation warning. If secure overwrite and deletion both fail while server revocation is unavailable, the old token can still be restored after restart. This combined failure requires an architectural decision before distribution.
- The combined secure-storage overwrite/delete failure with unavailable server revocation remains an unresolved **commercial-release blocker**. The architecture decision accepts this risk for development and testing only, preserves automatic server-validated restoration, and authorizes feature-branch commit and remote CI. Authenticated Windows Android runtime, iOS build, release signing, MFA/onboarding, and commercial hardening remain pending. The 2026-11-18 emulator evidence covers only public status. Windows PowerShell commands and manual acceptance steps are in `FLUTTER_SETUP.md`. No deployment, database reset, production connection, or physical write was made.

## M2.1F Android runtime validation and mobile authentication planning — 2026-11-18

- Windows validation report for commit `54413b0`: the updated debug APK compiled, installed, and launched on `emulator-5554` (Android 17/API 37); the overview displayed correctly, and **Check API connection** returned **API process reachable**. This establishes direct emulator access to the public `/api/v1/status` route. It does not validate mobile login, bearer requests, organization access, release transport, or building data.
- `feature/m2-1f-organization-discovery` was pushed with upstream tracking at `54413b05a721485656b6f924cbbd7f83e3233e17`; GitHub Actions CI passed its web, edge, mobile debug APK, SQLite API, and PostgreSQL API jobs. PR #3 remains open at Flutter foundation commit `04735e7` with passing checks. The discovery branch has no PR yet.
- Reviewed the Laravel routes, Sanctum middleware, OpenAPI response shapes, Flutter router, Dio client, and secure storage wrapper for the next mobile authentication phase. The proposed sequence and failure handling are in `M2_1F_IMPLEMENTATION_PLAN.md`. No mobile authentication code, commit, push, or merge was made during this planning update.

## M2.1F organization discovery and API connectivity preparation — 2026-11-18

Final review corrected the Windows workflow to use `C:\projects\bms-platform` with `C:\dev\flutter\bin\flutter.bat` after an approved branch push. It also added an explicit release network security policy to deny Android 17's implicit localhost cleartext allowance. The Windows app-to-API runtime check was pending at this review and was subsequently completed as recorded above.

- Created local branch `feature/m2-1f-organization-discovery` at validated Flutter foundation commit `04735e7`; PR #3 remains open and untouched.
- Added `GET /api/v1/auth/organizations` behind existing Sanctum bearer and active-user middleware. A single tenant-filtered query returns only active memberships with minimal organization identity and current server-derived role permissions. M2.1 has no organization status flag.
- Test-first evidence: eight discovery tests initially failed because the route was absent, then passed. A ninth test reproduced an unauthenticated no-`Accept` request returning 500 due to Laravel's missing login redirect route. The API redirect was corrected; direct local HTTP now returns JSON 401. Final full SQLite `composer test` passed 44 tests, one skipped, 180 assertions. Full PostgreSQL tests passed 45 tests and 181 assertions against the newly created `bms_m2_1f_isolated_check` database; the normal development database was untouched. Remote CI subsequently passed as recorded above.
- Added environment-specific Flutter API origin validation, a debug-only Android local cleartext exception, release cleartext denial, and an on-demand public status check in the overview. Automated configuration and widget tests use mocks; direct Windows emulator-to-API connectivity was subsequently verified for the public status route only.
- Final checks: Flutter analysis found no issues and all 12 mobile tests passed; the web build passed in its Docker container, and both edge tests passed. The new PHP files pass Pint, but repository-wide Pint flags untouched `CoreSchemaTest.php`. The WSL host web build remains blocked by its existing missing Rollup optional binary; an offline dependency reinstall could not replace container-owned `node_modules` files. OpenAPI structure, Android manifest/network XML, and `git diff --check` passed. Android debug runtime and remote CI subsequently passed; authenticated runtime remains pending.
- No development database was reset, and no production access, equipment write, mobile login, commit, push, merge, or deployment occurred.

## M2.1F Flutter foundation — 2026-11-17

- Generated Android and iOS runners with Flutter 3.50.0 without replacing the M1 overview behavior. Set both application identifiers to `com.bms.mobile`, Android minimum API 24, iOS minimum 15, and ignored local build and signing artifacts. Identifier ownership and release signing remain distribution tasks.
- Added Riverpod, Dio, GoRouter, secure storage boundary, reusable unavailable UI, English/French labels, and light/dark themes. The overview explicitly says there is no live building data. Authentication, tenant selection, and data features remain pending review; the API contract lacks a current-user organization list.
- Added Flutter CI, setup and architecture documentation, a mobile test plan, and `M2_1F_IMPLEMENTATION_PLAN.md`.
- Flutter 3.50.0/Dart 3.14.0 and Material UI 1.11.1 were verified locally. Dependency resolution selected Riverpod 3.5.0, Dio 5.11.1, GoRouter 18.1.4, and secure storage 11.2.0. `flutter pub get` passed, `flutter analyze` reported no issues, all five mobile tests passed, and the existing `composer test` backend regression suite passed 35 tests with one skipped and 148 assertions. Flutter CI and its Android debug build have not run remotely yet.
- Flutter Doctor found no Android SDK in WSL, so an Android build cannot run here. iOS builds require macOS/Xcode. No development database reset, production access, deployment, or equipment write occurred.

## M1 closure — 2026-11-17

M1 passed local acceptance, remote GitHub CI, and pull request #1. Merge commit: `dbeee99`. The local evidence below remains the validation record. Flutter runtime analysis and widget tests remain deferred because the Flutter SDK and platform runners are unavailable; the M1 gate required the source shell and test to exist. Physical equipment writes remain disabled.

## M2.1 identity and security — 2026-11-17

- Completed on `feature/m2-implementation`: Sanctum token login/logout, current-user endpoint, login throttling, local-only bootstrap command, organization membership roles and permissions, policy-backed organization-scoped user creation/listing, role changes, revocation, and audit events. The full M2 sequence is in `M2_IMPLEMENTATION_PLAN.md`; M2.2 has not started.
- M2.1 routes and security behavior are documented in `API.md`, `SECURITY.md`, `DATABASE.md`, and `packages/contracts/openapi.yaml`. No default user, public registration, equipment command route, or physical write enablement was added.
- SQLite `composer test`: 18 passed, 70 assertions, including M1 regressions, authentication, bearer-token integration, cross-tenant denial, role policy, bootstrap, and audit behavior. The same 18 tests and 70 assertions passed inside Docker against the separate `bms_m2_1_check` PostgreSQL database; six migrations applied there. The normal development PostgreSQL database was not reset or migrated for M2.1.
- `docker compose config --quiet`, web container `npm run build`, and Python edge unit tests (2 passed) succeeded. OpenAPI YAML parsed. Local Docker services were running with PostgreSQL healthy and edge simulation mode. No remote CI run or pull request for M2.1 has been checked yet.
- Deferred: Flutter runtime tests (SDK/platform runners absent), M2.2–M2.4 implementation, invitation delivery and password reset, MFA and production hardening. The M2.1 user creation route requires an administrator to supply an initial password; a secure onboarding and reset flow is needed before shared deployment. Physical writes remain disabled.

### M2.1 security acceptance audit — 2026-11-17

The detailed severity-ranked review is in `M2_1_SECURITY_AUDIT.md`. Fixed bearer-session misuse, disabled-user access, IP-wide login limiting, audit reference loss on parent deletion, and SQLite-only CI configuration. Added regression tests for expiry, revocation, role and tenant boundaries, last-owner protection, mass assignment, audit contents, and database constraints. The full suite passed on SQLite and an isolated PostgreSQL test database: 30 tests and 120 assertions on each. A separate disposable PostgreSQL upgrade preserved legacy M1 user and organization rows and defaulted the user to active. Vue build, two Python edge tests, Compose config, and OpenAPI/CI YAML checks passed. Revised remote CI has not run. Invitation/password onboarding, the M1 device/building tenant consistency constraint, database-level audit immutability, and paginated user listing remain open as described in the audit. M2.2 has not started; normal development data and equipment write gates were not changed.

### M2.1 final hardening — 2026-11-17

Added a uniform invitation request and one-time acceptance flow to prevent cross-organization account enumeration through user creation. Added PostgreSQL composite device/building tenant constraint, SQLite tenant triggers, database-level append-only audit protection, and paginated user listing with search and role filtering. Added regression coverage for each correction. Final SQLite suite: 35 passed, 1 skipped, 148 assertions. Final isolated PostgreSQL suite: 36 passed, 149 assertions. A separate M1-to-M2.1 PostgreSQL upgrade applied four M1 and four M2.1 migrations, preserved legacy user/organization/building/device rows, and passed hardening migration rollback/reapply. Container Vue build (11 modules), two edge tests, Compose validation, Redocly OpenAPI semantic validation (two nonblocking style warnings), `git diff --check`, and Composer/npm audits passed; dependency audits found zero known advisories. The WSL host Vue build remains blocked by the shared Alpine Rollup optional binary, while the container build passes. Remaining shared-release blockers are secure invitation delivery and recipient verification, MFA, ownership transfer, runtime database privilege separation, and M2.3 application-level device authorization. Remote CI has not run. M2.2, deployment, production access, and physical writes remain untouched.

## M1 components

| Component | State | Evidence / remaining work |
|---|---|---|
| Git | Complete | M1 committed as `ab7d7ac`; final verification performed on existing `feature/m2-core-management` branch without M2 changes. |
| Monorepo and documentation | Complete | Root guide, eight product/technical documents and standard directories created. |
| Laravel API | Complete for M1 | Laravel installed; versioned status endpoint and core migrations added. |
| PostgreSQL and Redis | Verified locally for M1 | PostgreSQL container healthy; all four migrations applied; Redis `PING` returned `PONG`. |
| Vue 3 / TypeScript | Complete for M1 | Shell and Vite configuration added; production build passed. |
| Flutter | Source shell and test present; runtime checks pending | SDK absent; platform runners must be generated with Flutter CLI. |
| Python edge | Complete for M1 | Inert process started in simulation mode with writes disabled; 2 unit tests passed. |
| CI | Configured | GitHub Actions jobs for API, web and edge. |

## Test results

On 2026-11-16, `composer test` in `apps/api` passed 4 tests and 6 assertions, including the status endpoint and schema/default checks. `npm run build` in `apps/web` passed TypeScript checking and Vite production compilation. `python3 -m unittest discover -s tests -v` in `services/edge-agent` passed 2 tests. The first web build failed because `@types/node` was missing; the dependency and TypeScript configuration were corrected before the passing build. The initial environment audit below is retained for history; the later local Docker checks supersede its Docker and PostgreSQL limitations.

### Final M1 environment verification — 2026-11-16

- Available: PHP 8.3.6, Composer 2.9.5, Node 22.22.0, npm 11.21.0, Python 3.12.3 and PyYAML 6.0.1. `pdo_sqlite` is present.
- Missing: Docker CLI/Compose, Podman, PostgreSQL server/client tools (`postgres`, `psql`, `pg_isready`), PHP `pdo_pgsql`, Flutter and Dart. No local PostgreSQL socket exists. No system packages were installed.
- `composer test` in `apps/api`: passed, 4 tests and 6 assertions.
- `python3 -m unittest discover -s tests -v` in `services/edge-agent`: passed, 2 tests.
- `npm run build` in `apps/web`: passed TypeScript check and Vite build (11 modules, 551 ms).
- PyYAML parsed `compose.yaml`; static assertions verified all five intended services, API PostgreSQL/Redis wiring, PostgreSQL health dependency, localhost-only published API/web ports, and edge simulation/write-disabled environment. Official `docker compose config` and container startup remain unverified because Docker is absent.
- PostgreSQL migrations against an isolated database were not run because no PostgreSQL server or Docker runtime is available and CLI PHP lacks `pdo_pgsql`. Laravel migration tests did run against SQLite in memory.
- `flutter analyze` and `flutter test` were not run because Flutter/Dart are absent. Native Android/iOS runner projects have not been generated.
- Physical writes remain disabled by default in `EdgeConfig`, are forced off in Compose, and are denied by both edge unit tests. No protocol adapter or equipment control API exists in M1.

### Local Docker verification — 2026-11-16

- `docker compose config --quiet` passed. API, web, PostgreSQL and Redis containers were running; PostgreSQL was healthy. The edge-agent container was then built and started; its log confirmed `mode=simulation writes_enabled=False`.
- `GET http://127.0.0.1:8000/api/v1/status` returned HTTP 200 and `{"service":"bms-api","version":"0.1.0","status":"ok"}`. The same request through Vite at port 5173 returned HTTP 200 and the same JSON. `App.vue` fetches this route on mount and displays `API online` only when the response is successful and `status` is `ok`.
- `docker compose exec -T redis redis-cli PING` returned `PONG`. `docker compose exec -T api php artisan migrate:status` showed all four migrations as `Ran` in batch 1.
- `composer test` passed 4 tests and 6 assertions after the safe-default assertion was made compatible with SQLite's integer `0` representation of false. `python3 -m unittest discover -s tests` passed 2 tests. `docker compose exec -T web npm run build` passed TypeScript checking and Vite compilation.
- A host `npm run build` currently fails because the shared `node_modules` directory contains Rollup's Alpine/musl binary from the web container, while the WSL host needs the GNU/Linux binary. The container build is the validated M1 build path. Flutter and Dart are still unavailable, so mobile analysis and widget tests remain unrun.

## Known limitations

No authentication, tenant data APIs, protocol adapters, MQTT/WebSocket transport, historical telemetry or control features are implemented in M1. These belong to later milestones. The local development stack has been booted, including the inert edge process, and its API, web, PostgreSQL and Redis paths verified. Host PHP still lacks `pdo_pgsql`, but PostgreSQL migrations were verified inside the API container. The generated Laravel `.env` and SQLite file are local ignored artifacts from `composer create-project`. Flutter SDK installation and platform runner generation are needed before mobile analysis and widget tests; iOS builds additionally require macOS/Xcode. CI jobs are configured, but no remote CI run was verified in this check. Equipment writes remain disabled by default and in Compose.
## M2.1F Android authentication validation — 2026-11-19

- Applied the pending M2.1 PostgreSQL migrations locally.
- Created a local development organization with an active owner membership.
- Corrected Laravel database configuration for Docker PostgreSQL.
- Confirmed successful communication between Android and Laravel.
- Successfully logged in using the Flutter Android application.
- Successfully selected the BMS Local Development organization.
- Verified session persistence after closing and reopening Android BMS.
- Verified logout returns to the Sign in screen.
- Verified the application remains logged out after reopening.
- Server-side token revocation still requires independent verification.
- Secure-storage failure handling remains a commercial-release blocker.
- No production database or physical BMS equipment was modified.
