# Flutter setup

The mobile app targets Flutter 3.50.0, Dart 3.14.0, and Material UI 1.11.1. Android and iOS runners were generated with Flutter 3.50.0. Android uses application ID `com.bms.mobile` and API 24 minimum; iOS uses bundle ID `com.bms.mobile` and iOS 15 minimum. Confirm ownership of these identifiers before store distribution and configure release signing separately. No signing key is stored in Git. The app's Android backup is disabled to avoid restoring encrypted token data without its Keystore key.

From `apps/mobile`:

```sh
flutter pub get
flutter analyze
flutter test
```

The Android development default is `http://10.0.2.2:8000`, the emulator alias for the host loopback address. Other development platforms default to `http://127.0.0.1:8000`. Override either with `--dart-define=BMS_API_BASE_URL=https://dev.example.test`. Development HTTP is accepted only for localhost, 127.0.0.1, the IPv6 loopback address, and 10.0.2.2. Release builds require an explicit HTTPS origin. The Android debug manifest allows cleartext only for local development destinations; the release network security policy explicitly denies cleartext, including localhost on Android 17. The overview's **Check API connection** button requests only the public `/api/v1/status` endpoint and reports API process responsiveness, not database, Redis, or building connectivity. Do not point this foundation at production buildings.

The Windows environment has been reported as having an operational Flutter SDK at `C:\dev\flutter\bin\flutter.bat`, an Android 17/API 37 emulator, Android NDK 28.2.13676358, an installed BMS APK, a running BMS process, and Windows access to the Laravel API. WSL remains the primary development environment and cannot locate the Windows Android SDK. The app's direct connection to the API has not yet been verified on Windows.

Use the dedicated Windows Git checkout at `C:\projects\bms-platform` for Android compilation and runtime testing. Once the new branch has been committed and pushed with approval, run these commands in Windows PowerShell. Stop `flutter run` with Ctrl+C after the on-screen check. Do not run Windows Flutter from the WSL UNC path.

```powershell
$Repo = 'C:\projects\bms-platform'
$Flutter = 'C:\dev\flutter\bin\flutter.bat'
$Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
Set-Location $Repo
git status --short
git fetch origin
git switch feature/m2-1f-organization-discovery
git pull --ff-only
& $Adb devices
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:8000/api/v1/status'
Set-Location (Join-Path $Repo 'apps\mobile')
& $Flutter pub get
& $Flutter devices
& $Flutter build apk --debug --dart-define=BMS_API_BASE_URL=http://10.0.2.2:8000
& $Flutter run -d emulator-5554 --debug --dart-define=BMS_API_BASE_URL=http://10.0.2.2:8000
```

Tap **Check API connection** in the app. **API process reachable** is the success result. A Windows host response alone does not prove emulator-to-API connectivity. Avoid putting bearer tokens or credentials into command output.

The Windows Android SDK and Java toolchain are already installed. On macOS with Xcode and CocoaPods, open the generated iOS project and build its Runner scheme. iOS builds cannot run on Linux or WSL. The Flutter CLI in this WSL installation is at `/home/basil/development/flutter/bin/flutter` and is not on `PATH`.

Mobile CI runs `flutter pub get`, `flutter analyze`, `flutter test`, and an Android debug APK build using Flutter 3.50.0 and Java 17 on a GitHub runner. No mobile build artifact is published by CI. Generated build outputs, IDE files, local SDK configuration, and signing files are ignored. Flutter's `.metadata` is tracked for future platform migrations.
