# Flutter architecture

`lib/main.dart` starts a Riverpod `ProviderScope`. `lib/src/app.dart` configures Material UI, GoRouter, English/French locales, and light/dark themes. The `core` directory owns networking, storage, localization, routing, theme preferences, and shared widgets. `features/shell` owns common navigation, while `features/overview` and `features/settings` own their screens. New features should live under `features/<feature>` with their own models, providers, screens, and tests.

The overview preserves the M1 foundation message and explicitly says that no live building data is available. Buildings, equipment, live monitoring, alarms, automation, energy, maintenance, and profile routes display a reusable unavailable state. Settings can change language and theme for the current process; preference persistence is a later feature. No screen renders mock telemetry as live data.

The Dio client currently calls only `GET /api/v1/status`, as described by `packages/contracts/openapi.yaml`; it does not attach a bearer token. The `TokenStore` wraps `flutter_secure_storage` for later Sanctum integration but no token is issued, read, or used by the UI yet. Authentication and organization selection begin after foundation review. Do not expose tenant data routes without an active organization and matching server authorization. The current API contract has no endpoint for listing a user's organizations, so that contract must be extended before a real organization selector can be built.

All equipment writes remain subject to server authorization and a separate disabled-by-default edge gate. Mobile clients never communicate with a building network directly. Release blockers listed in `SECURITY.md` and `M2_1_SECURITY_AUDIT.md` still apply.

Dependency versions resolved with Flutter 3.50.0: `material_ui` 1.11.1, `flutter_riverpod` 3.5.0, `dio` 5.11.1, `go_router` 18.1.4, and `flutter_secure_storage` 11.2.0. The secure storage plugin's Android module requires API 24, which sets the app minimum. The lockfile records the complete dependency graph.
