import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/origin_world_sheet_debug_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    originWorldSheetDebugSettings.resetForTesting();
  });

  test('defaults to keeping the Worldo sheet collapsed', () async {
    expect(await originWorldSheetDebugSettings.load(), isFalse);
    expect(originWorldSheetDebugSettings.expandOnEntry, isFalse);
  });

  test('persists the Worldo sheet expand-on-entry setting', () async {
    await originWorldSheetDebugSettings.setExpandOnEntry(true);

    expect(originWorldSheetDebugSettings.expandOnEntry, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(OriginWorldSheetDebugSettingsController.storageKey),
      isTrue,
    );

    originWorldSheetDebugSettings.resetForTesting();
    expect(await originWorldSheetDebugSettings.load(), isTrue);
  });
}
