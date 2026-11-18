import 'package:bms_mobile/src/core/network/api_origin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development defaults use emulator alias only on Android', () {
    expect(ApiOrigin.resolve(platform: TargetPlatform.android, release: false),
        'http://10.0.2.2:8000');
    expect(ApiOrigin.resolve(platform: TargetPlatform.iOS, release: false),
        'http://127.0.0.1:8000');
    expect(ApiOrigin.resolve(platform: TargetPlatform.windows, release: false),
        'http://127.0.0.1:8000');
  });

  test('explicit HTTPS origin overrides development defaults', () {
    expect(
      ApiOrigin.resolve(
        configuredUrl: 'https://dev.example.test:8443',
        platform: TargetPlatform.android,
        release: false,
      ),
      'https://dev.example.test:8443',
    );
  });

  test('release requires an explicit HTTPS origin', () {
    expect(() => ApiOrigin.resolve(release: true), throwsStateError);
    expect(
      () => ApiOrigin.resolve(
          configuredUrl: 'http://10.0.2.2:8000', release: true),
      throwsArgumentError,
    );
    expect(
      ApiOrigin.resolve(
          configuredUrl: 'https://api.example.test', release: true),
      'https://api.example.test',
    );
  });

  test('development HTTP is limited to local origins', () {
    expect(
      ApiOrigin.resolve(configuredUrl: 'http://localhost:8000', release: false),
      'http://localhost:8000',
    );
    expect(
      () => ApiOrigin.resolve(
          configuredUrl: 'http://example.test', release: false),
      throwsArgumentError,
    );
  });

  test('rejects credentials, paths, and unsupported schemes', () {
    for (final origin in [
      'https://user:secret@api.example.test',
      'https://api.example.test/api',
      'ftp://api.example.test',
      'not-a-url',
    ]) {
      expect(
        () => ApiOrigin.resolve(configuredUrl: origin, release: false),
        throwsArgumentError,
      );
    }
  });
}
