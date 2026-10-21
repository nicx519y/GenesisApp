import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Both surfaces use one screen-coordinate preference. Legacy keys stay intact.
final miniPhoneDockPosition = MiniPhoneDockPosition();
final miniPhoneMapDockPosition = miniPhoneDockPosition;

class MiniPhoneDockPosition extends ChangeNotifier {
  MiniPhoneDockPosition([
    this._key = 'worldo.debug.mini_phone.shared_dock_position.v2',
  ]);
  final String _key;
  bool right = false;
  // Used only to convert an old viewport-relative preference on first layout.
  double vertical = 1;
  double? screenY;
  bool loaded = false;
  int _revision = 0;
  Future<void>? _loading;
  Future<void> _writing = Future.value();
  Future<void> load() => _loading ??= _read();
  Future<void> _read() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (revision != _revision) return;
      for (final key in [
        _key,
        if (_key == 'worldo.debug.mini_phone.shared_dock_position.v2') ...[
          'worldo.debug.mini_phone.dock_position.v1',
          'worldo.debug.mini_phone.map_dock_position.v1',
        ],
      ]) {
        final raw = prefs.getString(key);
        if (raw != null && _restore(raw)) break;
      }
    } catch (_) {
      debugPrint('Mini phone position could not be restored.');
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  bool _restore(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map && value['right'] is bool && value['screenY'] is num) {
        final y = (value['screenY'] as num).toDouble();
        if (!y.isFinite) return false;
        right = value['right'] as bool;
        screenY = y.clamp(0.0, 1.0);
        return true;
      }
      if (value is List &&
          value.length == 2 &&
          value[0] is bool &&
          value[1] is num) {
        final y = (value[1] as num).toDouble();
        if (!y.isFinite) return false;
        right = value[0] as bool;
        vertical = y.clamp(0.0, 1.0);
        return true;
      }
    } catch (_) {
      // A corrupt newer value must not prevent migration of a valid old value.
    }
    return false;
  }

  void initializeScreenY(double value) {
    if (loaded && screenY == null) unawaited(save(right, value));
  }

  Future<void> save(bool side, double height) {
    right = side;
    screenY = height.clamp(0.0, 1.0);
    _revision++;
    final raw = jsonEncode({'right': right, 'screenY': screenY});
    notifyListeners();
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
