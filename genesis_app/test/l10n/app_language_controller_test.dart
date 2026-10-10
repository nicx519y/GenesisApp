import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'launch restores cache and identical server language does not refresh data',
    () async {
      SharedPreferences.setMockInitialValues({'app_language': 'zh-TW'});
      final controller = AppLanguageController();
      await controller.load();
      expect(controller.locale, const Locale('zh', 'TW'));
      expect(controller.settingLanguage, 'zh-TW');
      final dataRevision = controller.dataRevision;
      var notifications = 0;
      controller.addListener(() => notifications++);
      expect(
        AppLanguageController.resolve([
          const Locale('zh', 'TW'),
        ], AppLanguageController.supportedLocales),
        const Locale('zh', 'TW'),
      );
      expect(
        AppLanguageController.resolve([
          const Locale('de'),
        ], AppLanguageController.supportedLocales),
        const Locale('de'),
      );
      controller.applyConfigLanguage('', requestRevision: controller.revision);
      expect(controller.locale, const Locale('zh', 'TW'));
      controller.applyConfigLanguage(
        'zh-TW',
        requestRevision: controller.revision,
      );
      expect(controller.locale, const Locale('zh', 'TW'));
      expect(controller.settingLanguage, 'zh-TW');
      controller.applyUserLanguage(
        'zh-TW',
        requestRevision: controller.revision,
      );
      expect(controller.dataRevision, dataRevision);
      expect(notifications, 0);
    },
  );

  test(
    'missing or invalid cache uses system without a setting header',
    () async {
      for (final cached in [null, '', 'zh_TW', 'invalid']) {
        SharedPreferences.setMockInitialValues({
          if (cached != null) 'app_language': cached,
        });
        final controller = AppLanguageController();
        await controller.load();
        expect(controller.locale, isNull);
        expect(controller.settingLanguage, isNull);
      }
    },
  );

  test(
    'supported regional system locales resolve without an explicit setting',
    () {
      final controller = AppLanguageController();
      for (final locale in const [
        Locale('en', 'US'),
        Locale('en', 'GB'),
        Locale('es', 'ES'),
        Locale('es', 'MX'),
        Locale('pt', 'BR'),
        Locale('pt', 'PT'),
        Locale('fr'),
        Locale('fr', 'FR'),
        Locale('fr', 'CA'),
        Locale('de', 'DE'),
        Locale('it', 'IT'),
        Locale('ja', 'JP'),
        Locale('ko', 'KR'),
      ]) {
        expect(
          AppLanguageController.resolve([
            locale,
          ], AppLanguageController.supportedLocales),
          Locale(locale.languageCode),
        );
      }
      expect(
        AppLanguageController.resolve([
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ], AppLanguageController.supportedLocales),
        const Locale('zh', 'TW'),
      );
      expect(
        AppLanguageController.resolve([
          const Locale('zh', 'CN'),
        ], AppLanguageController.supportedLocales),
        const Locale('en'),
      );
      expect(controller.settingLanguage, isNull);
    },
  );

  test(
    'each added language saves, restores, and ignores identical server settings',
    () async {
      for (final code in ['es', 'pt', 'fr', 'de', 'it', 'ja', 'ko']) {
        SharedPreferences.setMockInitialValues({});
        final controller = AppLanguageController();
        await controller.load();
        final server = Completer<void>();
        final selection = controller.select(
          Locale(code),
          saveLanguage: (language) {
            expect(language, code);
            return server.future;
          },
        );
        expect(controller.settingLanguage, isNull);
        server.complete();
        await selection;
        expect(controller.locale, Locale(code));
        final restarted = AppLanguageController();
        await restarted.load();
        expect(restarted.locale, Locale(code));
        final revision = restarted.dataRevision;
        var notifications = 0;
        restarted.addListener(() => notifications++);
        restarted.applyConfigLanguage(
          code,
          requestRevision: restarted.revision,
        );
        restarted.applyUserLanguage(code, requestRevision: restarted.revision);
        expect(restarted.dataRevision, revision);
        expect(notifications, 0);
      }
    },
  );

  test('server override updates cache for the next launch', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'zh-TW'});
    final controller = AppLanguageController();
    await controller.load();
    final dataRevision = controller.dataRevision;
    controller.applyConfigLanguage('en', requestRevision: controller.revision);
    expect(controller.locale, const Locale('en'));
    expect(controller.dataRevision, dataRevision + 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'en');
    controller.applyUserLanguage('zh-TW', requestRevision: controller.revision);
    expect(prefs.getString('app_language'), 'zh-TW');
    final restarted = AppLanguageController();
    await restarted.load();
    expect(restarted.settingLanguage, 'zh-TW');
  });

  test(
    'nonempty account language wins and empty account retains config',
    () async {
      final controller = AppLanguageController();
      await controller.load();
      final revision = controller.revision;
      controller.applyConfigLanguage('zh-TW', requestRevision: revision);
      controller.applyUserLanguage('', requestRevision: revision);
      expect(controller.settingLanguage, 'zh-TW');
      controller.applyUserLanguage('en', requestRevision: revision);
      controller.applyConfigLanguage('zh-TW', requestRevision: revision);
      expect(controller.settingLanguage, 'en');
    },
  );

  test('all nine wire values are preserved without aliases', () {
    expect(AppLanguageController.languageCodes, {
      'en',
      'zh-TW',
      'es',
      'pt',
      'fr',
      'de',
      'it',
      'ja',
      'ko',
    });
    for (final code in AppLanguageController.languageCodes) {
      final controller = AppLanguageController();
      controller.applyConfigLanguage(
        code,
        requestRevision: controller.revision,
      );
      expect(controller.settingLanguage, code);
    }
    final controller = AppLanguageController();
    controller.applyConfigLanguage(
      'zh_TW',
      requestRevision: controller.revision,
    );
    expect(controller.settingLanguage, isNull);
  });

  test(
    'manual setting updates only after server success and prevents duplicates',
    () async {
      final controller = AppLanguageController();
      controller.applyConfigLanguage(
        'en',
        requestRevision: controller.revision,
      );
      final oldRevision = controller.revision;
      final server = Completer<void>();
      var calls = 0;
      Future<void> save(String language) {
        calls++;
        expect(language, 'zh-TW');
        return server.future;
      }

      final switching = controller.select(
        const Locale('zh', 'TW'),
        saveLanguage: save,
      );
      expect(controller.settingLanguage, 'en');
      expect(controller.locale, const Locale('en'));
      await controller.select(const Locale('en'), saveLanguage: save);
      expect(calls, 1);
      server.complete();
      await switching;
      expect(controller.settingLanguage, 'zh-TW');
      expect(
        (await SharedPreferences.getInstance()).getString('app_language'),
        'zh-TW',
      );
      controller.applyConfigLanguage('en', requestRevision: oldRevision);
      controller.applyUserLanguage('en', requestRevision: oldRevision);
      expect(controller.settingLanguage, 'zh-TW');
    },
  );

  test('failed manual save preserves original language and cache', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    final controller = AppLanguageController();
    controller.applyConfigLanguage('en', requestRevision: controller.revision);
    await expectLater(
      controller.select(
        const Locale('zh', 'TW'),
        saveLanguage: (_) async => throw StateError('failed'),
      ),
      throwsStateError,
    );
    expect(controller.settingLanguage, 'en');
    expect(controller.locale, const Locale('en'));
    expect(
      (await SharedPreferences.getInstance()).getString('app_language'),
      'en',
    );
    await controller.select(
      const Locale('zh', 'TW'),
      saveLanguage: (_) async {},
    );
    expect(controller.settingLanguage, 'zh-TW');
  });
}
