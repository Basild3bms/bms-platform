# Mobile test plan

The Stage 2 configuration gate adds API origin tests and an overview status-button widget test. Android development defaults to `http://10.0.2.2:8000`; other development platforms keep loopback. Release builds require an explicit HTTPS origin, and release Android disallows cleartext traffic. On 2026-11-18, the updated debug APK on `emulator-5554` displayed the overview and reached the public API status route. Subsequent Android authentication and M2.2B Buildings results are recorded in `PROGRESS.md`.

## Foundation gate

- `flutter pub get` resolves the locked dependencies with Flutter 3.50.0.
- `flutter analyze` reports no errors or warnings.
- Widget tests verify the overview Buildings entry, explicit absence of live readings, navigation to an unavailable section, and French shell labels.
- API client tests verify the exact public status path and reject unexpected response data without a network connection.
- `flutter doctor -v` records Android and iOS build availability. Mobile CI builds a debug APK on its Android-equipped runner. Run `flutter build apk --debug` locally when the Android SDK is installed. Build the iOS Runner on macOS/Xcode.
- `composer test` in `apps/api` protects the existing backend contract. Mobile tests never access the development database.

## Stage 3 authentication gate

Unit and widget tests exercise login success and generic failure, 401/422/429 and server/transport errors, exact contract shapes and bearer attachment, secure token/expiry/selection storage, expired and revoked tokens, restoration, disabled-account rejection, protected deep links, organization selection/refresh/switching, empty or revoked membership, and logout with unconfirmed revocation. Delayed response tests check concurrent login, logout during pending work, and organization changes while storage or discovery is pending. Widget tests check English/French text and light/dark modes. `flutter analyze` and the full `flutter test` suite must pass before review.

Stage 3 has no tenant data request. Each tenant-scoped request must include an explicit organization identifier and retain a context snapshot; reject results after switching or logout and clear displayed tenant data. Laravel remains the authorization authority. M2.2B automated tests cover Buildings bearer and organization paths, response validation, list/detail, empty and paginated states, safe errors and retry, switching during requests, logout, and protected navigation. Windows Android runtime validation for commit `66fcbbe` confirmed authenticated local PostgreSQL listing and detail, offline detail error and retry recovery, organization reselection, and logout/back/reopen protection. Pull-to-refresh and switching between two distinct organizations remain manual checks; independent server-side logout-token revocation verification also remains pending.

## Later feature gates

Add widget and API tests for each contracted section and all loading, empty, error, stale, and unauthorized states. Telemetry tests must distinguish source timestamp, quality, and unit. Commands need authorization and disabled gateway tests before any UI can issue a write request. No automated test targets a production building or physical controller.
