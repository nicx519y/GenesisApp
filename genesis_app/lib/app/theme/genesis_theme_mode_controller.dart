import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GenesisThemeModeStore {
  const GenesisThemeModeStore();

  static const String preferenceKey = 'developer_worldo_theme_mode_v1';

  Future<ThemeMode> read() async {
    final preferences = await SharedPreferences.getInstance();
    return switch (preferences.getString(preferenceKey)) {
      'system' => ThemeMode.system,
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  Future<void> write(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(preferenceKey, mode.name);
    if (!saved) {
      throw StateError('Unable to persist the Worldo theme mode.');
    }
  }
}

class GenesisThemeModeController extends ValueNotifier<ThemeMode> {
  GenesisThemeModeController({
    ThemeMode initialMode = ThemeMode.dark,
    GenesisThemeModeStore? store,
  }) : _store = store,
       super(initialMode);

  final GenesisThemeModeStore? _store;

  static Future<GenesisThemeModeController> load({
    required bool allowDeveloperOverride,
    GenesisThemeModeStore store = const GenesisThemeModeStore(),
  }) async {
    if (!allowDeveloperOverride) return GenesisThemeModeController();
    try {
      return GenesisThemeModeController(
        initialMode: await store.read(),
        store: store,
      );
    } catch (error) {
      debugPrint('[Theme] preference load failed; using dark: $error');
      return GenesisThemeModeController(store: store);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == value) return;
    final previousMode = value;
    value = mode;
    try {
      await _store?.write(mode);
    } catch (_) {
      value = previousMode;
      rethrow;
    }
  }
}
