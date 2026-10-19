import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
import 'package:genesis_flutter_android/l10n/genesis_l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('helpers respect cached language before the first frame', () async {
    SharedPreferences.setMockInitialValues({
      AppLanguageController.preferenceKey: 'ja',
    });
    await appLanguageController.load();
    expect(GenesisL10n.current.localeName, 'ja');
  });
}
