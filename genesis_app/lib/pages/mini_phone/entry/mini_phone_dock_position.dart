import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Device-local dock preference. Keep the existing keys to preserve placement.
final miniPhoneDockPosition = MiniPhoneDockPosition();
final miniPhoneMapDockPosition = MiniPhoneDockPosition(
  'worldo.debug.mini_phone.map_dock_position.v1',
);

class MiniPhoneDockPosition {
  MiniPhoneDockPosition([
    this._key = 'worldo.debug.mini_phone.dock_position.v1',
  ]);
  final String _key;
  bool right = true;
  double vertical = 1;
  int _revision = 0;
  Future<void>? _loading;
  Future<void> _writing = Future.value();
  Future<void> load() => _loading ??= _read();
  Future<void> _read() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || revision != _revision) return;
      final value = jsonDecode(raw);
      if (value is List &&
          value.length == 2 &&
          value[0] is bool &&
          value[1] is num) {
        final height = (value[1] as num).toDouble();
        if (height.isFinite) {
          right = value[0] as bool;
          vertical = height.clamp(0.0, 1.0);
        }
      }
    } catch (_) {
      debugPrint('Mini phone position could not be restored.');
    }
  }

  Future<void> save(bool side, double height) {
    right = side;
    vertical = height.clamp(0.0, 1.0);
    _revision++;
    final raw = jsonEncode([right, vertical]);
    return _writing = _writing.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, raw);
      } catch (_) {
        debugPrint('Mini phone position could not be saved.');
      }
    });
  }
}
