# Progress log

## M1 components

| Component | State | Evidence / remaining work |
|---|---|---|
| Git | Complete | M1 committed as `ab7d7ac`; final verification performed on existing `feature/m2-core-management` branch without M2 changes. |
| Monorepo and documentation | Complete | Root guide, eight product/technical documents and standard directories created. |
| Laravel API | Complete for M1 | Laravel installed; versioned status endpoint and core migrations added. |
| PostgreSQL and Redis | Configured, unverified | Compose services and API environment configured; Docker unavailable locally. |
| Vue 3 / TypeScript | Complete for M1 | Shell and Vite configuration added; production build passed. |
| Flutter | Source skeleton, unverified | SDK absent; platform runners must be generated with Flutter CLI. |
| Python edge | Complete for M1 | Inert process, simulation default and write gate; 2 unit tests passed. |
| CI | Configured | GitHub Actions jobs for API, web and edge. |

## Test results

On 2026-11-16, `composer test` in `apps/api` passed 4 tests and 6 assertions, including the status endpoint and schema/default checks. `npm run build` in `apps/web` passed TypeScript checking and Vite production compilation. `python3 -m unittest discover -s tests -v` in `services/edge-agent` passed 2 tests. The first web build failed because `@types/node` was missing; the dependency and TypeScript configuration were corrected before the passing build. Docker Compose boot, PostgreSQL migration and Flutter widget tests could not be run because Docker and Flutter are not installed here.

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

## Known limitations

No authentication, tenant data APIs, protocol adapters, MQTT/WebSocket transport, historical telemetry or control features are implemented in M1. PHP CLI lacks `pdo_pgsql`; Docker and Flutter CLI are absent. The generated Laravel `.env` and SQLite file are local ignored artifacts from `composer create-project`. Development Compose has not been booted. Once a Docker runtime is available, run `docker compose config` and boot the isolated development stack to verify PostgreSQL migrations. Flutter SDK installation is needed before mobile analysis and widget tests; iOS builds additionally require macOS/Xcode.
