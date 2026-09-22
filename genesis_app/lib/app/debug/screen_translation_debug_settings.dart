import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final screenTranslationDebugSettings =
    ScreenTranslationDebugSettingsController();

class ScreenTranslationDebugSettingsController {
  static const String storageKey = 'developer_screen_translation_debug_v1';

  final ValueNotifier<bool> _enabled = ValueNotifier<bool>(false);
  int _revision = 0;
  Future<void>? _pendingSave;

  ValueListenable<bool> get listenable => _enabled;

  bool get enabled => kDebugMode && _enabled.value;

  Future<bool> load() async {
    if (!kDebugMode) return false;
    final pendingSave = _pendingSave;
    if (pendingSave != null) {
      try {
        await pendingSave;
      } catch (_) {
        // The save path restores the previous value before loading continues.
      }
    }
    final revision = _revision;
    var storedValue = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      storedValue = preferences.getBool(storageKey) ?? false;
    } catch (_) {
      storedValue = false;
    }
    if (revision == _revision) {
      _enabled.value = storedValue;
    }
    return _enabled.value;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!kDebugMode) return;
    final previousValue = _enabled.value;
    final revision = ++_revision;
    _enabled.value = enabled;
    final save = _save(enabled);
    _pendingSave = save;
    try {
      await save;
    } catch (_) {
      if (revision == _revision) {
        _enabled.value = previousValue;
      }
      rethrow;
    } finally {
      if (identical(_pendingSave, save)) {
        _pendingSave = null;
      }
    }
  }

  Future<void> _save(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(storageKey, enabled);
    if (!saved) {
      throw StateError('Failed to save the screen translation debug setting.');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _revision += 1;
    _pendingSave = null;
    _enabled.value = false;
  }
}
