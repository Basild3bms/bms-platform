# Mobile test plan

The Stage 2 configuration gate adds API origin tests and an overview status-button widget test. Android development defaults to `http://10.0.2.2:8000`; other development platforms keep loopback. Release builds require an explicit HTTPS origin, and release Android disallows cleartext traffic. On 2026-11-18, the updated debug APK on `emulator-5554` displayed the overview and reached the public API status route. Authentication, organization access, and building data still require separate runtime tests.

## Foundation gate

- `flutter pub get` resolves the locked dependencies with Flutter 3.50.0.
- `flutter analyze` reports no errors or warnings.
- Widget tests verify the M1 overview message, explicit absence of live readings, navigation to an unavailable section, and French shell labels.
- API client tests verify the exact public status path and reject unexpected response data without a network connection.
- `flutter doctor -v` records Android and iOS build availability. Mobile CI builds a debug APK on its Android-equipped runner. Run `flutter build apk --debug` locally when the Android SDK is installed. Build the iOS Runner on macOS/Xcode.
- `composer test` in `apps/api` protects the existing backend contract. Mobile tests never access the development database.

## Authentication gate after foundation review

Before implementing authentication, add tests for login success and generic failure, 401/422/429 handling, bearer header attachment, secure token write/read/delete, expiry and revocation, disabled user response, unauthorized route redirects, and logout. The organization discovery contract now exposes the user's active memberships; add selection tests when implementing the selector. Verify every future tenant-scoped request carries an explicit organization identifier and that unauthorized or foreign tenant responses never display cached data.

## Later feature gates

Add widget and API tests for each contracted section and all loading, empty, error, stale, and unauthorized states. Telemetry tests must distinguish source timestamp, quality, and unit. Commands need authorization and disabled gateway tests before any UI can issue a write request. No automated test targets a production building or physical controller.
