# Flutter setup

The mobile app targets Flutter 3.50.0, Dart 3.14.0, and Material UI 1.11.1. Android and iOS runners were generated with Flutter 3.50.0. Android uses application ID `com.bms.mobile` and API 24 minimum; iOS uses bundle ID `com.bms.mobile` and iOS 15 minimum. Confirm ownership of these identifiers before store distribution and configure release signing separately. No signing key is stored in Git. The app's Android backup is disabled to avoid restoring encrypted token data without its Keystore key.

From `apps/mobile`:

```sh
flutter pub get
flutter analyze
flutter test
```

Set the API origin at build time with `--dart-define=BMS_API_BASE_URL=https://your-development-api.example`. The default is `http://127.0.0.1:8000` for local development. Android emulators use a different host address from WSL localhost, so provide an address reachable from the emulator. The app currently makes no startup API request; the Dio client is prepared for the public status endpoint only. Use HTTPS for any shared environment. Do not point this foundation at production buildings.

For Android builds, install an Android SDK and Java toolchain, accept licenses, then run `flutter build apk --debug`. On macOS with Xcode and CocoaPods, open the generated iOS project and build its Runner scheme. iOS builds cannot run on Linux or WSL. The Flutter CLI in this WSL installation is at `/home/basil/development/flutter/bin/flutter` and is not on `PATH`.

Mobile CI runs `flutter pub get`, `flutter analyze`, `flutter test`, and an Android debug APK build using Flutter 3.50.0 and Java 17 on a GitHub runner. No mobile build artifact is published by CI. Generated build outputs, IDE files, local SDK configuration, and signing files are ignored. Flutter's `.metadata` is tracked for future platform migrations.
