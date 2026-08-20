import 'package:shared_preferences/shared_preferences.dart';

class AppVersionOverrides {
  const AppVersionOverrides({this.versionName, this.versionCode});

  static const empty = AppVersionOverrides();

  final String? versionName;
  final String? versionCode;

  bool get hasAny => versionName != null || versionCode != null;
}

class AppVersionOverrideStore {
  const AppVersionOverrideStore._();

  static const String versionNameKey = 'developer_app_version_name_override_v1';
  static const String versionCodeKey = 'developer_app_version_code_override_v1';

  static Future<AppVersionOverrides> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppVersionOverrides(
        versionName: _storedValue(prefs, versionNameKey),
        versionCode: _storedValue(prefs, versionCodeKey),
      );
    } catch (_) {
      return AppVersionOverrides.empty;
    }
  }

  static Future<void> save(AppVersionOverrides overrides) async {
    final versionName = _normalizeOptionalValue(overrides.versionName);
    final versionCode = _normalizeVersionCode(overrides.versionCode);
    final prefs = await SharedPreferences.getInstance();
    await _setOptionalValue(prefs, versionNameKey, versionName);
    await _setOptionalValue(prefs, versionCodeKey, versionCode);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(versionNameKey);
    await prefs.remove(versionCodeKey);
  }

  static String? _normalizeVersionCode(String? value) {
    final normalized = _normalizeOptionalValue(value);
    if (normalized == null) return null;
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      throw const FormatException('Version Code must be a positive integer');
    }
    return '$parsed';
  }

  static String? _normalizeOptionalValue(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
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
    if (value == null) return prefs.remove(key);
    return prefs.setString(key, value);
  }
}
