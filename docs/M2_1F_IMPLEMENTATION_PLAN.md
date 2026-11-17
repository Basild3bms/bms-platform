# M2.1F Flutter foundation plan

1. Audit the M1 mobile shell, API contract, Flutter SDK, and local toolchains. Generate Android and iOS runners without replacing application source. Configure identifiers, minimum platform versions, ignored artifacts, and mobile CI.
2. Add a modular application shell with Riverpod preferences, Dio status client, GoRouter sections, secure token storage boundary, localized English/French labels, themes, and a reusable unavailable state. Keep every dashboard section free of simulated building values.
3. Validate dependency resolution, static analysis, unit/widget tests, and the existing API regression suite. Build Android only where an SDK is available. Document setup, architecture, limitations, and release blockers.
4. Review this foundation before implementing login, bearer token attachment, organization selection, or authenticated navigation.

The next phase will use the exact authentication endpoints and response shapes in `packages/contracts/openapi.yaml`. It needs tests for token expiry, disabled accounts, failed login, logout revocation, unauthorized requests, and tenant selection before shipping an authenticated screen. Organization selection cannot be backed by a dedicated membership-list endpoint in the current contract; that API gap must be resolved before implementing it.
