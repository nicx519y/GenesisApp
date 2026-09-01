import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final worldNewContentDebugSettings = WorldNewContentDebugSettingsController();

bool shouldMarkWorldContentAsNew(bool serverIsNew) {
  return serverIsNew || worldNewContentDebugSettings.forceNewBadges;
}

class WorldNewContentDebugSettingsController {
  static const String storageKey =
      'developer_world_new_content_force_new_badges_v1';

  final ValueNotifier<bool> _forceNewBadges = ValueNotifier<bool>(false);
  int _revision = 0;
  Future<void>? _pendingSave;

  ValueListenable<bool> get listenable => _forceNewBadges;

  bool get forceNewBadges => _forceNewBadges.value;

  Future<bool> load() async {
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
      _forceNewBadges.value = storedValue;
    }
    return _forceNewBadges.value;
  }

  Future<void> setForceNewBadges(bool enabled) async {
    final previousValue = _forceNewBadges.value;
    final revision = ++_revision;
    _forceNewBadges.value = enabled;
    final save = _save(enabled);
    _pendingSave = save;
    try {
      await save;
    } catch (_) {
      if (revision == _revision) {
        _forceNewBadges.value = previousValue;
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
      throw StateError('Failed to save the World New badge debug setting.');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _revision += 1;
    _pendingSave = null;
    _forceNewBadges.value = false;
  }
}
