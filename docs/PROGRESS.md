# Progress log

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
