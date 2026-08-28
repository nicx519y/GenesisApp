import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final originWorldSheetDebugSettings = OriginWorldSheetDebugSettingsController();

class OriginWorldSheetDebugSettingsController {
  static const String storageKey =
      'developer_origin_world_sheet_expand_on_entry_v1';

  final ValueNotifier<bool> _expandOnEntry = ValueNotifier<bool>(false);
  int _revision = 0;
  Future<void>? _pendingSave;

  ValueListenable<bool> get listenable => _expandOnEntry;

  bool get expandOnEntry => _expandOnEntry.value;

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
      _expandOnEntry.value = storedValue;
    }
    return _expandOnEntry.value;
  }

  Future<void> setExpandOnEntry(bool enabled) async {
    final previousValue = _expandOnEntry.value;
    final revision = ++_revision;
    _expandOnEntry.value = enabled;
    final save = _save(enabled);
    _pendingSave = save;
    try {
      await save;
    } catch (_) {
      if (revision == _revision) {
        _expandOnEntry.value = previousValue;
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
      throw StateError('Failed to save the Worldo sheet debug setting.');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _revision += 1;
    _expandOnEntry.value = false;
  }
}
