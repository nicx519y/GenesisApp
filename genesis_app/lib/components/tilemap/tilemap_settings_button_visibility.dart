import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tilemapSettingsButtonVisibility =
    TilemapSettingsButtonVisibilityController();

class TilemapSettingsButtonVisibilityController {
  static const String storageKey =
      'developer_tilemap_settings_button_visible_v1';

  final ValueNotifier<bool> _visible = ValueNotifier<bool>(false);
  int _revision = 0;
  Future<void>? _pendingSave;

  ValueListenable<bool> get listenable => _visible;

  bool get value => _visible.value;

  Future<bool> load() async {
    final pendingSave = _pendingSave;
    if (pendingSave != null) {
      try {
        await pendingSave;
      } catch (_) {
        // The save path restores the last value before this load continues.
      }
    }
    final revision = _revision;
    var storedValue = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      storedValue = prefs.getBool(storageKey) ?? false;
    } catch (_) {
      storedValue = false;
    }
    if (revision == _revision) {
      _visible.value = storedValue;
    }
    return _visible.value;
  }

  Future<void> setVisible(bool visible) async {
    final previousValue = _visible.value;
    final revision = ++_revision;
    _visible.value = visible;
    final save = _save(visible);
    _pendingSave = save;
    try {
      await save;
    } catch (_) {
      if (revision == _revision) {
        _visible.value = previousValue;
      }
      rethrow;
    } finally {
      if (identical(_pendingSave, save)) {
        _pendingSave = null;
      }
    }
  }

  Future<void> _save(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(storageKey, visible);
    if (!saved) {
      throw StateError('Failed to save Tilemap settings button visibility.');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _revision += 1;
    _visible.value = false;
  }
}
