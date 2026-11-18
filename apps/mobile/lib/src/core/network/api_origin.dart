import 'package:flutter/foundation.dart';

class ApiOrigin {
  const ApiOrigin._();

  static const _configuredUrl = String.fromEnvironment('BMS_API_BASE_URL');
  static const _localHosts = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};

  static String resolve({
    String? configuredUrl,
    TargetPlatform? platform,
    bool? release,
  }) {
    final isRelease = release ?? kReleaseMode;
    final target = platform ?? defaultTargetPlatform;
    final supplied = configuredUrl ?? _configuredUrl;
    if (isRelease && supplied.isEmpty) {
      throw StateError('BMS_API_BASE_URL must be set for release builds.');
    }

    final value = supplied.isNotEmpty
        ? supplied
        : target == TargetPlatform.android
            ? 'http://10.0.2.2:8000'
            : 'http://127.0.0.1:8000';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError('BMS_API_BASE_URL must be an HTTP or HTTPS origin.');
    }
    if (isRelease && uri.scheme != 'https') {
      throw ArgumentError('Release API traffic requires HTTPS.');
    }
    if (!isRelease && uri.scheme == 'http' && !_localHosts.contains(uri.host)) {
      throw ArgumentError('Development HTTP is limited to local API hosts.');
    }

    return uri.origin;
  }
}
