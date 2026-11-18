# Test plan

## M2.1F organization discovery and mobile connectivity

- API feature tests cover missing, invalid, expired, and revoked bearer tokens; disabled accounts and web sessions; no, one, and multiple active memberships; revoked and inactive memberships; foreign tenants; all four roles; current server-derived permissions; an exact minimal JSON response; and JSON 401 responses without an `Accept` header.
- Existing authentication tests and the full Laravel suite must pass on SQLite and an isolated PostgreSQL database. Remote CI should repeat both paths after these changes are committed; never reset the development database.
- Flutter tests cover Android emulator versus host defaults, explicit HTTPS configuration, rejection of release HTTP and nonlocal development HTTP, malformed origins, and on-demand status checks and network failure states.
- Windows emulator runtime validation must confirm the status request from the app. A passing mock test or a Windows host request alone does not prove Flutter-to-API connectivity.

## M1

- Laravel feature test verifies the versioned status endpoint and migration relationships/default nonwritable point.
- Vue TypeScript compile and Vite production build verify the web shell.
- Python unit tests verify simulation mode blocks physical writes, including when a write flag is set.
- Flutter widget test verifies the mobile shell once the Flutter SDK and platform scaffolding are installed.
- Compose configuration and container boot checks require Docker; API PostgreSQL migration check requires a PostgreSQL runtime.

## Later milestone gates

Tenant tests attempt cross-organization reads and writes for every endpoint. Adapter tests use protocol simulators, malformed frames, disconnects and replay. Telemetry tests cover quality, duplicates, retention and timestamp drift. Command tests cover unauthorized roles, wrong tenant, disabled gateway, expired/duplicate request, out-of-range values and physical write denial. Load tests exercise point fan-out and history queries. Recovery tests restore PostgreSQL and replay edge buffers. No automated test targets live equipment.
