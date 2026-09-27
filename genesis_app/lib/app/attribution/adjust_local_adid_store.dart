import 'package:adjust_sdk/adjust_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AdjustLocalAdidStore {
  Future<String?> read();
  Future<void> write(String adid);
}

/// Stores only an ADID that was previously returned by the Adjust SDK.
class SharedPreferencesAdjustLocalAdidStore implements AdjustLocalAdidStore {
  const SharedPreferencesAdjustLocalAdidStore({this.environment});

  final AdjustEnvironment? environment;

  String get _environmentKey =>
      (environment ??
              (kReleaseMode
                  ? AdjustEnvironment.production
                  : AdjustEnvironment.sandbox)) ==
          AdjustEnvironment.production
      ? 'adjust_adid_production_v1'
      : 'adjust_adid_sandbox_v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final adid = preferences.getString(_environmentKey)?.trim() ?? '';
    return adid.isEmpty ? null : adid;
  }

  @override
  Future<void> write(String adid) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_environmentKey, adid)) {
      throw StateError('Failed to save Adjust ADID');
    }
  }
}
