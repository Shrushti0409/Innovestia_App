import 'package:flutter/foundation.dart';

class AppConstants {
  static const appName = 'Innovestia';
  static const tagline = 'Connecting Ideas with Capital';
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final apiBaseUrl = _normalizeApiBaseUrl(
    _configuredApiBaseUrl.trim().isNotEmpty
        ? _configuredApiBaseUrl.trim()
        : kIsWeb
        ? 'http://localhost:8081/api'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8081/api'
        : 'http://localhost:8081/api',
  );

  static String _normalizeApiBaseUrl(String value) {
    final base = value.replaceFirst(RegExp(r'/+$'), '');
    return base.endsWith('/api') ? base : '$base/api';
  }

  static const requestTimeout = Duration(seconds: 45);
}
