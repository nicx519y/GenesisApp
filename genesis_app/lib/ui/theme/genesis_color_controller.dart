import 'package:flutter/material.dart';

import 'genesis_color_store.dart';
import 'genesis_color_token.dart';
import 'genesis_semantic_colors.dart';

class GenesisColorController extends ChangeNotifier {
  GenesisColorController({
    GenesisColorStore? store,
    ThemeMode mode = ThemeMode.light,
    Map<GenesisColorToken, Color> lightOverrides = const {},
    Map<GenesisColorToken, Color> darkOverrides = const {},
  }) : _store = store,
       _mode = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
       _lightOverrides = Map<GenesisColorToken, Color>.of(lightOverrides),
       _darkOverrides = Map<GenesisColorToken, Color>.of(darkOverrides);

  static Future<GenesisColorController> load({GenesisColorStore? store}) async {
    final resolvedStore = store ?? const SharedPreferencesGenesisColorStore();
    final settings = await resolvedStore.load();
    return GenesisColorController(
      store: resolvedStore,
      mode: settings.mode,
      lightOverrides: settings.lightOverrides,
      darkOverrides: settings.darkOverrides,
    );
  }

  final GenesisColorStore? _store;
  ThemeMode _mode;
  Map<GenesisColorToken, Color> _lightOverrides;
  Map<GenesisColorToken, Color> _darkOverrides;
  int _revision = 0;

  ThemeMode get mode => _mode;
  int get revision => _revision;
  Brightness get activeBrightness =>
      _mode == ThemeMode.dark ? Brightness.dark : Brightness.light;

  GenesisSemanticColorConfig get lightConfig =>
      GenesisColorDefaults.light.copyWithOverrides(_lightOverrides);
  GenesisSemanticColorConfig get darkConfig =>
      GenesisColorDefaults.dark.copyWithOverrides(_darkOverrides);

  GenesisSemanticColorConfig configFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkConfig : lightConfig;

  Color colorFor(Brightness brightness, GenesisColorToken token) =>
      configFor(brightness).color(token);

  Color defaultColorFor(Brightness brightness, GenesisColorToken token) =>
      (brightness == Brightness.dark
              ? GenesisColorDefaults.dark
              : GenesisColorDefaults.light)
          .color(token);

  bool isOverridden(Brightness brightness, GenesisColorToken token) =>
      _overridesFor(brightness).containsKey(token);

  Future<void> setMode(Brightness brightness) async {
    final next = brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    if (_mode == next) return;
    _mode = next;
    _markChanged();
    await _persist();
  }

  Future<void> setColor(
    Brightness brightness,
    GenesisColorToken token,
    Color color,
  ) async {
    final overrides = _overridesFor(brightness);
    final defaultColor = defaultColorFor(brightness, token);
    if (color == defaultColor) {
      overrides.remove(token);
    } else {
      overrides[token] = color;
    }
    _markChanged();
    await _persist();
  }

  Future<void> resetToken(
    Brightness brightness,
    GenesisColorToken token,
  ) async {
    if (_overridesFor(brightness).remove(token) == null) return;
    _markChanged();
    await _persist();
  }

  Future<void> resetPalette(Brightness brightness) async {
    final overrides = _overridesFor(brightness);
    if (overrides.isEmpty) return;
    overrides.clear();
    _markChanged();
    await _persist();
  }

  Future<void> resetAll() async {
    _lightOverrides = <GenesisColorToken, Color>{};
    _darkOverrides = <GenesisColorToken, Color>{};
    _mode = ThemeMode.light;
    _markChanged();
    await _persist();
  }

  Map<GenesisColorToken, Color> _overridesFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkOverrides : _lightOverrides;

  void _markChanged() {
    _revision += 1;
    notifyListeners();
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) return;
    await store.save(
      mode: _mode,
      lightOverrides: _lightOverrides,
      darkOverrides: _darkOverrides,
    );
  }
}

class GenesisColorScope extends InheritedNotifier<GenesisColorController> {
  const GenesisColorScope({
    super.key,
    required GenesisColorController controller,
    required super.child,
  }) : super(notifier: controller);

  static GenesisColorController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GenesisColorScope>();
    assert(scope != null, 'GenesisColorScope is missing above this context.');
    return scope!.notifier!;
  }

  static GenesisColorController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GenesisColorScope>()?.notifier;
}
