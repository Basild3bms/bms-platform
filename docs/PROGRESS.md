# Progress log

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
