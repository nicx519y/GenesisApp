import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/debug/rating_prompt_debug_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'unset uses server, persisted override wins including zero, reset restores server',
    () async {
      expect(await RatingPromptDebugSettings.resolve(20), 20);
      await RatingPromptDebugSettings.save(3);
      expect(await RatingPromptDebugSettings.read(), 3);
      expect(await RatingPromptDebugSettings.resolve(0), 3);
      expect(await RatingPromptDebugSettings.resolve(50), 3);
      await RatingPromptDebugSettings.save(0);
      expect(await RatingPromptDebugSettings.resolve(20), 0);
      await RatingPromptDebugSettings.save(null);
      expect(await RatingPromptDebugSettings.read(), isNull);
      expect(await RatingPromptDebugSettings.resolve(20), 20);
    },
  );
  test('invalid negative override is rejected', () async {
    await expectLater(RatingPromptDebugSettings.save(-1), throwsArgumentError);
    expect(await RatingPromptDebugSettings.resolve(20), 20);
  });
}
