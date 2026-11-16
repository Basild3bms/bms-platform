# Progress log

## M1 components

| Component | State | Evidence / remaining work |
|---|---|---|
| Git | Complete | Existing empty repository on `main`; preserved. |
| Monorepo and documentation | Complete | Root guide, eight product/technical documents and standard directories created. |
| Laravel API | Complete for M1 | Laravel installed; versioned status endpoint and core migrations added. |
| PostgreSQL and Redis | Configured, unverified | Compose services and API environment configured; Docker unavailable locally. |
| Vue 3 / TypeScript | Complete for M1 | Shell and Vite configuration added; production build passed. |
| Flutter | Source skeleton, unverified | SDK absent; platform runners must be generated with Flutter CLI. |
| Python edge | Complete for M1 | Inert process, simulation default and write gate; 2 unit tests passed. |
| CI | Configured | GitHub Actions jobs for API, web and edge. |

## Test results

On 2026-11-16, `composer test` in `apps/api` passed 4 tests and 6 assertions, including the status endpoint and schema/default checks. `npm run build` in `apps/web` passed TypeScript checking and Vite production compilation. `python3 -m unittest discover -s tests -v` in `services/edge-agent` passed 2 tests. The first web build failed because `@types/node` was missing; the dependency and TypeScript configuration were corrected before the passing build. Docker Compose boot, PostgreSQL migration and Flutter widget tests could not be run because Docker and Flutter are not installed here.

## Known limitations

No authentication, tenant data APIs, protocol adapters, MQTT/WebSocket transport, historical telemetry or control features are implemented in M1. PHP CLI lacks `pdo_pgsql`; Docker and Flutter CLI are absent. The generated Laravel `.env` and SQLite file are local ignored artifacts from `composer create-project`. Development Compose has not been booted.
