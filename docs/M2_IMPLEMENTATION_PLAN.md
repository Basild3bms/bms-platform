# M2 implementation plan

## Scope and sequence

M2 is developed on `feature/m2-implementation` against the local development stack. No production building, controller, or physical write is involved. Each phase adds its contract and tests before exposing new routes. M2.2 starts only after review of M2.1.

### M2.1 — Identity and security

1. Add Sanctum bearer tokens and a private login/logout flow. There is no public registration or default administrator account. Provision the first administrator through an explicit local administrative process.
2. Add organization memberships, roles, permissions, and an append-only audit trail. Membership checks require both the organization ID and an active membership; missing or foreign tenant resources return 404. Role grants and user management require explicit permissions. A user cannot grant a role more powerful than their own.
3. Add policy-backed, organization-scoped user administration and membership endpoints. Validate all input; keep credentials and token values out of audit records. Limit login attempts by both normalized email and client IP; return a generic authentication failure.
4. Test authentication, throttling, token revocation, membership lifecycle, cross-tenant isolation, role permissions, validation, and audit events with in-memory SQLite. Verify PostgreSQL migrations against a separate disposable database; never reset the normal development database.
5. Update OpenAPI, API/security/database documents, and progress. Run API, web, and edge regressions plus Docker checks.

### M2.2 — Portfolio management (after review)

Add organizations, sites, buildings, floors, zones, and rooms with stable UUIDs, tenant-aware foreign keys, uniqueness, and safe deletion rules. Expose permission-checked CRUD with bounded search, filters, and cursor pagination. Test every read/write against another tenant and each authorization boundary before implementation.

### M2.3 — Equipment management (after M2.2)

Add tenant-scoped categories, assets, manufacturers, profiles, gateways, devices, and points. Enforce building/device tenant consistency in the database and API. Validate protocol configuration and duplicate identities. Keep points read-only by default and expose no physical write route. Add adapter tests before any protocol implementation.

### M2.4 — Web application (after API contracts)

Build a responsive, localized English/French application with login, organization selector, navigation, dashboard, portfolio, inventory, and user/role views. Use the versioned API, handle loading/empty/error states, and show only authorized actions. Verify TypeScript/Vite builds and API integration against local test data.

## M2 exit gate

PostgreSQL migrations, authentication and cross-tenant tests, role/permission tests, API integration tests, Vue build, Docker runtime checks, M1 regressions, CI, and OpenAPI all pass. Flutter runtime validation remains deferred until its SDK and platform runners exist. M3 and deployment are outside this plan.
