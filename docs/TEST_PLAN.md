# Test plan

## M1

- Laravel feature test verifies the versioned status endpoint and migration relationships/default nonwritable point.
- Vue TypeScript compile and Vite production build verify the web shell.
- Python unit tests verify simulation mode blocks physical writes, including when a write flag is set.
- Flutter widget test verifies the mobile shell once the Flutter SDK and platform scaffolding are installed.
- Compose configuration and container boot checks require Docker; API PostgreSQL migration check requires a PostgreSQL runtime.

## Later milestone gates

Tenant tests attempt cross-organization reads and writes for every endpoint. Adapter tests use protocol simulators, malformed frames, disconnects and replay. Telemetry tests cover quality, duplicates, retention and timestamp drift. Command tests cover unauthorized roles, wrong tenant, disabled gateway, expired/duplicate request, out-of-range values and physical write denial. Load tests exercise point fan-out and history queries. Recovery tests restore PostgreSQL and replay edge buffers. No automated test targets live equipment.
