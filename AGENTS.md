# BMS repository guide

This monorepo implements a commercial building management system. M1 is a development foundation only. Never connect to production buildings or enable physical writes while working on M1.

## Layout

- `apps/api`: Laravel JSON API and schema
- `apps/web`: Vue 3 and TypeScript web shell
- `apps/mobile`: Flutter mobile shell
- `services/edge-agent`: Python edge gateway shell
- `packages/contracts`: shared API and event contracts
- `infra`: local Docker and future deployment manifests
- `tests`: cross-component test plans and fixtures
- `docs`: requirements, architecture, operations, and progress

## Working rules

- Keep tenant scope explicit in every future query and authorization check.
- All equipment writes require server authorization and a separate gateway enablement gate. The gateway defaults to disabled writes.
- Do not store credentials or private keys in Git. Keep example configuration non-secret.
- Add tests for tenant isolation, command authorization, and protocol adapters before implementing them.
- Update `docs/PROGRESS.md` when completing a component or finding a blocker.

## M1 checks

Run `composer test` in `apps/api`, `npm run build` in `apps/web`, and `python3 -m unittest discover -s tests` in `services/edge-agent`. Docker Compose and Flutter checks require their respective CLIs.
