# Flutter setup

The supplied Windows 11 runtime report for M2.2C.3 commit `9d94787` records a successful debug build (141.6 seconds), install, and launch on `emulator-5554`. It reports all 15 manual checks passing, including three floors, basement level -1 and zones, Floors refresh, offline recovery, French and dark-mode screens, and logout/back/reopen protection. This is Windows runtime evidence supplied for documentation; WSL did not rerun the emulator. iOS, switching between two distinct organizations, Buildings pull-to-refresh, and release-mode performance remain to validate. Startup skipped-frame warnings were observed.

For repeat M2.2C.3 runtime validation, build and run a debug APK against the local API. Sign in, open the demonstration building, verify three floor entries including basement level -1, and open its zones to verify the plant-room type. Check list refresh, detail, back navigation, offline error and recovery, organization reselection, logout/back/reopen, and a deep link opened while signed out. Use macOS/Xcode separately for iOS. WSL Flutter tests and analyzer do not substitute for runtime checks. Do not alter demonstration records or use production equipment.

The mobile app targets Flutter 3.50.0, Dart 3.14.0, and Material UI 1.11.1. Android and iOS runners were generated with Flutter 3.50.0. Android uses application ID `com.bms.mobile` and API 24 minimum; iOS uses bundle ID `com.bms.mobile` and iOS 15 minimum. Confirm ownership of these identifiers before store distribution and configure release signing separately. No signing key is stored in Git. The app's Android backup is disabled to avoid restoring encrypted token data without its Keystore key.

From `apps/mobile`:

```sh
flutter pub get
flutter analyze
flutter test
```

The Android development default is `http://10.0.2.2:8000`, the emulator alias for the host loopback address. Other development platforms default to `http://127.0.0.1:8000`. Override either with `--dart-define=BMS_API_BASE_URL=https://dev.example.test`. Development HTTP is accepted only for localhost, 127.0.0.1, the IPv6 loopback address, and 10.0.2.2. Release builds require an explicit HTTPS origin. The Android debug manifest allows cleartext only for local development destinations; the release network security policy explicitly denies cleartext, including localhost on Android 17. The overview's **Check API connection** button requests only the public `/api/v1/status` endpoint and reports API process responsiveness, not database, Redis, or building connectivity. Do not point this foundation at production buildings.

The Windows environment has an operational Flutter SDK at `C:\dev\flutter\bin\flutter.bat` and an Android 17/API 37 emulator. On 2026-11-18, commit `54413b0` was compiled into an updated debug APK, installed, and launched on `emulator-5554`. The overview displayed correctly, and **Check API connection** returned **API process reachable**. Later local Android validation confirmed login, organization selection, session restoration, and logout. The Windows report for M2.2B commit `66fcbbe` confirms the debug APK launched and the authenticated Buildings list and detail displayed real local PostgreSQL data; offline detail retry recovered, and logout/back/reopen protected the screen. See `PROGRESS.md` for the exact scope and pending checks. WSL remains the primary development environment and cannot locate the Windows Android SDK.

Use the dedicated Windows Git checkout at `C:\projects\bms-platform` for M2.2B Android compilation and runtime testing. Run these commands in Windows PowerShell **after this branch has been reviewed and pushed**. The checkout must be clean; the first guard stops if it has uncommitted work. Stop `flutter run` with Ctrl+C after the on-screen check. Do not run Windows Flutter from the WSL UNC path.

```powershell
$Repo = 'C:\projects\bms-platform'
$Flutter = 'C:\dev\flutter\bin\flutter.bat'
$Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
Set-Location $Repo
git status --short
if (git status --porcelain) { throw 'Windows checkout has uncommitted changes; preserve or resolve them before switching branches.' }
git fetch origin
if (git branch --list feature/m2-2b-flutter-buildings) {
  git switch feature/m2-2b-flutter-buildings
} else {
  git switch --track origin/feature/m2-2b-flutter-buildings
}
git pull --ff-only origin feature/m2-2b-flutter-buildings
& $Adb devices
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:8000/api/v1/status'
Set-Location (Join-Path $Repo 'apps\mobile')
& $Flutter pub get
& $Flutter devices
& $Flutter analyze
& $Flutter test
& $Flutter build apk --debug --dart-define=BMS_API_BASE_URL=http://10.0.2.2:8000
& $Flutter run -d emulator-5554 --debug --dart-define=BMS_API_BASE_URL=http://10.0.2.2:8000
```

On the emulator, sign in with a development account and select **BMS Local Development**. Open **Buildings** from the overview or drawer and confirm **BMS Demo Building Updated**, code **DEMO-M22A-01**, its address when present, and time zone. Open its detail and confirm the same fields. Pull to refresh, test loading and offline retry, switch between two distinct organizations and confirm the previous organization's records disappear, then log out and use Back to confirm protected screens stay closed. Verify pagination with development data only if multiple pages exist; do not create buildings for this check. Tap **Check API connection** to recheck the public route. Keep credentials and bearer tokens out of commands, screenshots, and logs. The supplied Windows report confirms listing, detail, offline detail retry, organization reselection, and logout/back/reopen; pull-to-refresh, two-organization switching, and independent server-side token revocation still need confirmation.

The Windows Android SDK and Java toolchain are already installed. On macOS with Xcode and CocoaPods, open the generated iOS project and build its Runner scheme. iOS builds cannot run on Linux or WSL. The Flutter CLI in this WSL installation is at `/home/basil/development/flutter/bin/flutter` and is not on `PATH`.

Mobile CI runs `flutter pub get`, `flutter analyze`, `flutter test`, and an Android debug APK build using Flutter 3.50.0 and Java 17 on a GitHub runner. No mobile build artifact is published by CI. Generated build outputs, IDE files, local SDK configuration, and signing files are ignored. Flutter's `.metadata` is tracked for future platform migrations.
