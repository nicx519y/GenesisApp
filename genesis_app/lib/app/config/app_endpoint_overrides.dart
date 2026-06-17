import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class AppEndpointOverrides {
  const AppEndpointOverrides({
    this.apiBaseUrl,
    this.chatroomHttpBaseUrl,
    this.chatroomWsBaseUrl,
  });

  static const empty = AppEndpointOverrides();

  final String? apiBaseUrl;
  final String? chatroomHttpBaseUrl;
  final String? chatroomWsBaseUrl;

  bool get hasAny {
    return apiBaseUrl != null ||
        chatroomHttpBaseUrl != null ||
        chatroomWsBaseUrl != null;
  }

  AppConfig applyTo(AppConfig config) {
    return config.copyWith(
      apiBaseUrl: apiBaseUrl,
      chatroomHttpBaseUrl: chatroomHttpBaseUrl,
      chatroomWsBaseUrl: chatroomWsBaseUrl,
    );
  }
}

class AppEndpointOverrideStore {
  const AppEndpointOverrideStore._();

  static const String _apiBaseUrlKey = 'developer_api_base_url_override_v1';
  static const String _chatroomHttpBaseUrlKey =
      'developer_chatroom_http_base_url_override_v1';
  static const String _chatroomWsBaseUrlKey =
      'developer_chatroom_ws_base_url_override_v1';

  static Future<AppEndpointOverrides> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppEndpointOverrides(
      apiBaseUrl: _storedValue(prefs, _apiBaseUrlKey),
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
    await prefs.remove(_chatroomHttpBaseUrlKey);
    await prefs.remove(_chatroomWsBaseUrlKey);
  }

  static String? normalizeHttpsApiBaseUrl(String value) {
    final normalized = _normalizeHttpBaseUrl(
      value,
      appendApiPathWhenEmpty: true,
    );
    return normalized;
  }

  static String? normalizeHttpsBaseUrl(String value) {
    return _normalizeHttpBaseUrl(value);
  }

  static String? normalizeWssBaseUrl(String value) {
    final trimmed = _withScheme(value, 'wss');
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'wss' ||
        uri.host.trim().isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('WSS URL must start with wss://');
    }
    return uri.toString();
  }

  static String displayWithoutScheme(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty) return trimmed;
    final schemePrefix = '${uri.scheme}://';
    return trimmed.startsWith(schemePrefix)
        ? trimmed.substring(schemePrefix.length)
        : trimmed;
  }

  static String? _normalizeHttpBaseUrl(
    String value, {
    bool appendApiPathWhenEmpty = false,
  }) {
    final trimmed = _withScheme(value, 'https');
    if (trimmed.isEmpty) return null;
    var uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('HTTPS URL must start with https://');
    }
    if (appendApiPathWhenEmpty && (uri.path.isEmpty || uri.path == '/')) {
      uri = uri.replace(path: '/api/');
    } else if (!uri.path.endsWith('/')) {
      uri = uri.replace(path: '${uri.path}/');
    }
    return uri.toString();
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
