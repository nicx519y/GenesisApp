import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AdjustLocalAdidStore {
  Future<String?> read();
  Future<void> write(String adid);
}

/// Stores only an ADID that was previously returned by the Adjust SDK.
class SharedPreferencesAdjustLocalAdidStore implements AdjustLocalAdidStore {
  const SharedPreferencesAdjustLocalAdidStore();

  static String get _key =>
      kReleaseMode ? 'adjust_adid_production_v1' : 'adjust_adid_sandbox_v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final adid = preferences.getString(_key)?.trim() ?? '';
    return adid.isEmpty ? null : adid;
  }

  @override
  Future<void> write(String adid) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_key, adid)) {
      throw StateError('Failed to save Adjust ADID');
    }
  }
}
