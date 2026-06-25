import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class AppEndpointOverrides {
  const AppEndpointOverrides({
    this.apiBaseUrl,
    this.gatewayApiBaseUrl,
    this.chatroomHttpBaseUrl,
    this.chatroomWsBaseUrl,
  });

  static const empty = AppEndpointOverrides();

  final String? apiBaseUrl;
  final String? gatewayApiBaseUrl;
  final String? chatroomHttpBaseUrl;
  final String? chatroomWsBaseUrl;

  bool get hasAny {
    return apiBaseUrl != null ||
        gatewayApiBaseUrl != null ||
        chatroomHttpBaseUrl != null ||
        chatroomWsBaseUrl != null;
  }

  AppConfig applyTo(AppConfig config) {
    return config.copyWith(
      apiBaseUrl: apiBaseUrl,
      gatewayApiBaseUrl: gatewayApiBaseUrl,
      chatroomHttpBaseUrl: chatroomHttpBaseUrl,
      chatroomWsBaseUrl: chatroomWsBaseUrl,
    );
  }
}

class AppEndpointOverrideStore {
  const AppEndpointOverrideStore._();

  static const String _apiBaseUrlKey = 'developer_api_base_url_override_v1';
  static const String _gatewayApiBaseUrlKey =
      'developer_gateway_api_base_url_override_v1';
  static const String _chatroomHttpBaseUrlKey =
      'developer_chatroom_http_base_url_override_v1';
  static const String _chatroomWsBaseUrlKey =
      'developer_chatroom_ws_base_url_override_v1';
  static const String _apiPath = '/api/';
  static const String _gatewayApiPath = '/apix/';
  static const String _chatroomWsPath = '/aitown-chat/ws';

  static Future<AppEndpointOverrides> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppEndpointOverrides(
      apiBaseUrl: _storedValue(prefs, _apiBaseUrlKey),
      gatewayApiBaseUrl: _storedValue(prefs, _gatewayApiBaseUrlKey),
      chatroomHttpBaseUrl: _storedValue(prefs, _chatroomHttpBaseUrlKey),
      chatroomWsBaseUrl: _storedValue(prefs, _chatroomWsBaseUrlKey),
    );
  }

  static Future<AppConfig> loadConfig({
    AppConfig baseConfig = const AppConfig(),
  }) async {
    final overrides = await load();
    return overrides.applyTo(baseConfig);
  }

  static Future<void> save(AppEndpointOverrides overrides) async {
    final prefs = await SharedPreferences.getInstance();
    await _setOptionalValue(prefs, _apiBaseUrlKey, overrides.apiBaseUrl);
    await _setOptionalValue(
      prefs,
      _gatewayApiBaseUrlKey,
      overrides.gatewayApiBaseUrl,
    );
    await _setOptionalValue(
      prefs,
      _chatroomHttpBaseUrlKey,
      overrides.chatroomHttpBaseUrl,
    );
    await _setOptionalValue(
      prefs,
      _chatroomWsBaseUrlKey,
      overrides.chatroomWsBaseUrl,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiBaseUrlKey);
    await prefs.remove(_gatewayApiBaseUrlKey);
    await prefs.remove(_chatroomHttpBaseUrlKey);
    await prefs.remove(_chatroomWsBaseUrlKey);
  }

  static String? normalizeHttpsApiBaseUrl(String value) {
    final uri = _normalizeDomainUrl(value, scheme: 'https');
    if (uri == null) return null;
    return uri.replace(path: _apiPath).toString();
  }

  static String? normalizeHttpsGatewayApiBaseUrl(String value) {
    final uri = _normalizeDomainUrl(value, scheme: 'https');
    if (uri == null) return null;
    return uri.replace(path: _gatewayApiPath).toString();
  }

  static String? normalizeHttpsBaseUrl(String value) {
    final uri = _normalizeDomainUrl(value, scheme: 'https');
    if (uri == null) return null;
    return uri.replace(path: '/').toString();
  }

  static String? normalizeWssBaseUrl(String value) {
    final uri = _normalizeDomainUrl(value, scheme: 'wss');
    if (uri == null) return null;
    return uri.replace(path: _chatroomWsPath).toString();
  }

  static String displayDomain(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty || uri.host.trim().isEmpty) {
      return trimmed;
    }
    if (uri.hasPort) return '${uri.host}:${uri.port}';
    return uri.host;
  }

  static Uri? _normalizeDomainUrl(String value, {required String scheme}) {
    final trimmed = _withScheme(value, scheme);
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme.toLowerCase() != scheme ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw FormatException(
        '${scheme.toUpperCase()} endpoint must be a domain only',
      );
    }
    return uri.replace(path: '/', query: null, fragment: null);
  }

  static String _withScheme(String value, String scheme) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('://')) return trimmed;
    return '$scheme://$trimmed';
  }

  static String? _storedValue(SharedPreferences prefs, String key) {
    final value = prefs.getString(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> _setOptionalValue(
    SharedPreferences prefs,
    String key,
    String? value,
  ) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return prefs.remove(key);
    }
    return prefs.setString(key, normalized);
  }
}
