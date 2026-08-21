import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/theme/genesis_theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('developer theme mode defaults to dark', () async {
    final controller = await GenesisThemeModeController.load(
      allowDeveloperOverride: true,
    );
    addTearDown(controller.dispose);

    expect(controller.value, ThemeMode.dark);
  });

  test(
    'developer theme mode loads and persists every supported mode',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        GenesisThemeModeStore.preferenceKey: 'system',
      });
      final controller = await GenesisThemeModeController.load(
        allowDeveloperOverride: true,
      );
      addTearDown(controller.dispose);

      expect(controller.value, ThemeMode.system);

      await controller.setThemeMode(ThemeMode.light);
      final preferences = await SharedPreferences.getInstance();

      expect(controller.value, ThemeMode.light);
      expect(
        preferences.getString(GenesisThemeModeStore.preferenceKey),
        'light',
      );
    },
  );

  test('production mode ignores a stored developer override', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      GenesisThemeModeStore.preferenceKey: 'light',
    });
    final controller = await GenesisThemeModeController.load(
      allowDeveloperOverride: false,
    );
    addTearDown(controller.dispose);

    expect(controller.value, ThemeMode.dark);
  });

  test('failed persistence restores the previous mode', () async {
    final controller = GenesisThemeModeController(
      store: const _FailingThemeModeStore(),
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.setThemeMode(ThemeMode.light),
      throwsA(isA<StateError>()),
    );

    expect(controller.value, ThemeMode.dark);
  });
}

class _FailingThemeModeStore extends GenesisThemeModeStore {
  const _FailingThemeModeStore();

  @override
  Future<void> write(ThemeMode mode) {
    throw StateError('save failed');
  }
}
