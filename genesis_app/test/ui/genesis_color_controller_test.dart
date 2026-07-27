import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('Light and Dark defaults cover the same unique token set', () {
    expect(
      GenesisColorToken.values.map((token) => token.id).toSet().length,
      GenesisColorToken.values.length,
    );
    expect(
      GenesisColorDefaults.light.values.keys.toSet(),
      GenesisColorToken.values.toSet(),
    );
    expect(
      GenesisColorDefaults.dark.values.keys.toSet(),
      GenesisColorToken.values.toSet(),
    );
  });

  test('Dark product accents use electric violet and keep danger red', () {
    const electricViolet = Color(0xFFA78BFA);
    for (final token in <GenesisColorToken>[
      GenesisColorToken.create,
      GenesisColorToken.bottomNavigationProminent,
      GenesisColorToken.homeFeedAccent,
      GenesisColorToken.gemAccent,
    ]) {
      expect(GenesisColorDefaults.dark.color(token), electricViolet);
    }
    expect(
      GenesisColorDefaults.dark.color(GenesisColorToken.danger),
      const Color(0xFFFF6B80),
    );
    expect(
      GenesisColorDefaults.dark
          .color(GenesisColorToken.create)
          .computeLuminance(),
      greaterThan(
        GenesisColorDefaults.light
            .color(GenesisColorToken.create)
            .computeLuminance(),
      ),
    );
  });

  test(
    'developer color settings persist independent Light and Dark overrides',
    () async {
      final controller = await GenesisColorController.load();
      addTearDown(controller.dispose);

      expect(controller.mode, ThemeMode.light);
      await controller.setColor(
        Brightness.light,
        GenesisColorToken.surface,
        const Color(0xFFFAFAFA),
      );
      await controller.setColor(
        Brightness.dark,
        GenesisColorToken.surface,
        const Color(0xFF080808),
      );
      await controller.setMode(Brightness.dark);

      final preferences = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(
                preferences.getString(
                  SharedPreferencesGenesisColorStore.colorsKey,
                )!,
              )
              as Map<String, dynamic>;
      expect(
        (stored['light'] as Map<String, dynamic>)['surface.page'],
        0xFFFAFAFA,
      );
      expect(
        (stored['dark'] as Map<String, dynamic>)['surface.page'],
        0xFF080808,
      );

      final restored = await GenesisColorController.load();
      addTearDown(restored.dispose);
      expect(restored.mode, ThemeMode.dark);
      expect(
        restored.colorFor(Brightness.light, GenesisColorToken.surface),
        const Color(0xFFFAFAFA),
      );
      expect(
        restored.colorFor(Brightness.dark, GenesisColorToken.surface),
        const Color(0xFF080808),
      );
    },
  );

  test('invalid and unknown persisted values safely fall back', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesGenesisColorStore.modeKey: 'system',
      SharedPreferencesGenesisColorStore.colorsKey: jsonEncode(<String, Object>{
        'light': <String, Object>{
          'surface.page': 'not-an-int',
          'unknown.token': 0xFF010203,
        },
        'dark': <String, Object>{'surface.page': -1},
      }),
    });

    final controller = await GenesisColorController.load();
    addTearDown(controller.dispose);
    expect(controller.mode, ThemeMode.light);
    expect(
      controller.colorFor(Brightness.light, GenesisColorToken.surface),
      GenesisColorDefaults.light.color(GenesisColorToken.surface),
    );
    expect(
      controller.colorFor(Brightness.dark, GenesisColorToken.surface),
      GenesisColorDefaults.dark.color(GenesisColorToken.surface),
    );
  });

  test('token, palette and all reset operations remove overrides', () async {
    final controller = await GenesisColorController.load();
    addTearDown(controller.dispose);
    const custom = Color(0xFF010203);

    await controller.setColor(
      Brightness.light,
      GenesisColorToken.surface,
      custom,
    );
    expect(
      controller.isOverridden(Brightness.light, GenesisColorToken.surface),
      isTrue,
    );
    await controller.resetToken(Brightness.light, GenesisColorToken.surface);
    expect(
      controller.isOverridden(Brightness.light, GenesisColorToken.surface),
      isFalse,
    );

    await controller.setColor(
      Brightness.dark,
      GenesisColorToken.surface,
      custom,
    );
    await controller.resetPalette(Brightness.dark);
    expect(
      controller.isOverridden(Brightness.dark, GenesisColorToken.surface),
      isFalse,
    );

    await controller.setMode(Brightness.dark);
    await controller.setColor(
      Brightness.light,
      GenesisColorToken.brand,
      custom,
    );
    await controller.resetAll();
    expect(controller.mode, ThemeMode.light);
    expect(
      controller.isOverridden(Brightness.light, GenesisColorToken.brand),
      isFalse,
    );
  });

  test('save failure keeps the live color override', () async {
    final controller = GenesisColorController(
      store: const _FailingColorStore(),
    );
    addTearDown(controller.dispose);
    const custom = Color(0xFF010203);

    await expectLater(
      controller.setColor(Brightness.light, GenesisColorToken.surface, custom),
      throwsA(isA<StateError>()),
    );
    expect(
      controller.colorFor(Brightness.light, GenesisColorToken.surface),
      custom,
    );
  });
}

class _FailingColorStore implements GenesisColorStore {
  const _FailingColorStore();

  @override
  Future<GenesisStoredColorSettings> load() async =>
      const GenesisStoredColorSettings(
        mode: ThemeMode.light,
        lightOverrides: <GenesisColorToken, Color>{},
        darkOverrides: <GenesisColorToken, Color>{},
      );

  @override
  Future<void> save({
    required ThemeMode mode,
    required Map<GenesisColorToken, Color> lightOverrides,
    required Map<GenesisColorToken, Color> darkOverrides,
  }) async {
    throw StateError('simulated write failure');
  }
}
