import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/l10n/genesis_l10n.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/messages/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';
import '../support/mini_phone_chat_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GenesisL10n.bind(lookupAppLocalizations(const Locale('en')));
  });
  tearDown(() => GenesisL10n.bind(lookupAppLocalizations(const Locale('en'))));

  test('all phone locales preserve dynamic content and plural counts', () {
    for (final locale in AppLanguageController.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final count in [0, 1, 2, 100]) {
        expect(l10n.miniPhoneCommentCount(count: count), contains('$count'));
        expect(l10n.miniPhoneOpenUnread(count: count), contains('$count'));
      }
      const name = 'Alex {not_a_placeholder} 김';
      expect(l10n.miniPhoneTyping(name: name), contains(name));
      expect(l10n.miniPhoneMessageHint(name: name), contains(name));
      expect(l10n.miniPhoneReplyHint(name: name), contains(name));
      expect(l10n.miniPhoneLikeTrack(title: name), contains(name));
      expect(l10n.miniPhoneOwnMessage(message: name), contains(name));
      if (locale.languageCode != 'en') {
        expect(
          l10n.miniPhonePrivateConversation,
          isNot('Private conversation'),
        );
        expect(
          l10n.miniPhoneLoadFailed,
          isNot('Unable to load. Please try again.'),
        );
      }
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.miniPhoneCommentCount(count: 1), '1 comment');
    expect(en.miniPhoneCommentCount(count: 0), '0 comments');
    expect(
      en.miniPhoneOpenUnread(count: 1),
      'Open Mini phone, 1 unread message',
    );
  });

  test(
    'helpers follow current language without altering backend errors or time',
    () async {
      final store = PhoneBackend().store();
      await store.ready;
      addTearDown(store.dispose);
      store.currentTime = 'Day 12/10:05';
      expect(store.worldDay, 'Day 12');
      GenesisL10n.bind(lookupAppLocalizations(const Locale('zh', 'TW')));
      expect(store.worldDay, '第 12 天');
      expect(store.clockTime, '10:05');
      expect(store.currentTime, 'Day 12/10:05');
      expect(miniPhoneErrorText(StateError('technical')), '無法載入，請再試一次。');
      expect(
        miniPhoneErrorText(ApiException(message: 'server original')),
        'server original',
      );
      store.currentTime = 'invalid';
      expect(store.worldDay, isEmpty);
      GenesisL10n.bind(lookupAppLocalizations(const Locale('ja')));
      store.currentTime = 'day 2/08:00';
      expect(store.worldDay, '2日目');
    },
  );

  testWidgets('live chat updates visible copy when locale changes', (
    tester,
  ) async {
    final store = (await tester.runAsync(() async {
      final store = PhoneBackend().store();
      await store.ready;
      return store;
    }))!;
    Future<void> show(Locale locale) async {
      GenesisL10n.bind(lookupAppLocalizations(locale));
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: MiniPhoneLiveChat(
              store: store,
              person: const PhonePerson('c', 'Alex', ''),
              header: const SizedBox(height: 56),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    }

    await show(const Locale('zh', 'TW'));
    expect(find.textContaining('私人對話'), findsOneWidget);
    expect(find.text('傳訊息給 Alex…'), findsOneWidget);
    expect(find.text('傳送'), findsOneWidget);
    await show(const Locale('ja'));
    expect(find.textContaining('プライベートチャット'), findsOneWidget);
    expect(find.text('Alexにメッセージ…'), findsOneWidget);
    expect(find.textContaining('私人對話'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('French locked home apps fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = (await tester.runAsync(() async {
      final store = PhoneBackend().store();
      await store.ready;
      return store;
    }))!;
    final session = MiniPhoneSession(data: store);
    session.resume.homePage = 1;
    GenesisL10n.bind(lookupAppLocalizations(const Locale('fr')));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MiniPhonePage(session: session),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Appareil photo'), findsOneWidget);
    expect(find.text('Calendrier'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
