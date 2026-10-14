import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import '../../support/mini_phone_chat_backend.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'send keeps keyboard, creates no optimistic bubble, shows and ends typing',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store();
        await s.ready;
        return s;
      }))!;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(platform: TargetPlatform.iOS),
          home: MiniPhoneLiveChat(
            store: s,
            person: const PhonePerson('c', 'Character', ''),
            header: const SizedBox(height: 56),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Hello');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding();
      await settle(tester);
      final composer = tester.widget<ChatComposer>(find.byType(ChatComposer));
      expect(composer.focusNode!.hasFocus, isTrue);
      await tester.runAsync(composer.onSend);
      await tester.pump();
      expect(composer.focusNode!.hasFocus, isTrue);
      expect(tester.view.viewInsets.bottom, 300);
      expect(
        tester.getBottomRight(find.byType(ChatComposer)).dy,
        lessThanOrEqualTo(544),
      );
      expect(find.text('Character is typing…'), findsOneWidget);
      expect(
        tester
            .widget<LocationChatAnchoredMessageList>(
              find.byType(LocationChatAnchoredMessageList),
            )
            .replyWaitingPositioningEnabled,
        isFalse,
      );
      expect(s.history('c'), isEmpty);
      final id = s.waiting('c')!.id;
      await tester.runAsync(() async {
        s.receive(
          phoneEvent('user', [
            phoneMessage(1, sender: 'user', requestId: id),
          ], requestId: id),
        );
        s.receive(phoneEvent('reply', [phoneMessage(2)], requestId: id));
        await s.writesSaved;
      });
      await settle(tester);
      expect(find.text('Character is typing…'), findsNothing);
      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => s.writesSaved);
      s.dispose();
    },
  );
  testWidgets('history reader stays detached while new messages arrive', (
    tester,
  ) async {
    final b = PhoneBackend();
    b.respond = (r) => r.uri.path.endsWith('/messages')
        ? ok(page([for (var i = 40; i >= 1; i--) phoneMessage(i)], rn: 40))
        : null;
    final s = (await tester.runAsync(() async {
      final s = b.store();
      await s.ready;
      return s;
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MiniPhoneLiveChat(
          store: s,
          person: const PhonePerson('c', 'Character', ''),
          header: const SizedBox(height: 56),
        ),
      ),
    );
    await settle(tester);
    final list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    await tester.drag(
      find.byType(LocationChatAnchoredMessageList),
      const Offset(0, 400),
    );
    await settle(tester);
    final before = list.coordinator.controller.offset;
    expect(list.coordinator.isReadingHistory, isTrue);
    await tester.runAsync(() async {
      s.receive(phoneEvent('new', [phoneMessage(41)]));
      await s.writesSaved;
    });
    await settle(tester);
    expect(list.coordinator.controller.offset, closeTo(before, 1));
    expect(find.text('New messages ↓'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => s.writesSaved);
    s.dispose();
  });
  testWidgets(
    'Posts entry reads once; feed and details use live content on a narrow large-text screen',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store();
        await s.ready;
        return s;
      }))!;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = MiniPhoneSession(data: s);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MiniPhonePage(
            session: session,
            initialScreen: MiniPhoneScreen.posts,
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Post body'), findsOneWidget);
      expect(b.calls('post/notifications/read').length, 1);
      expect(find.text('Vivienne'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Be the first to comment'));
      await tester.tap(find.text('Be the first to comment'));
      await settle(tester);
      expect(find.text('Post body'), findsOneWidget);
      expect(b.calls('post/detail'), isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
}
