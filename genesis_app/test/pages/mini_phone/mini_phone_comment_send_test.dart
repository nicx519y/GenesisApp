import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_comments_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mini_phone_chat_backend.dart';

int _nextStore = 0;
Map<String, dynamic> reply(int id, {String? text}) => {
  'comment_id': id,
  'post_id': 8,
  'author_id': text == null ? 'c' : 'u',
  'author_type': text == null ? 2 : 1,
  'author_name': text == null ? 'Character' : 'Player',
  'comment_type': 1,
  'text': text ?? 'Reply $id',
};

Widget screen(MiniPhoneStore store) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MiniPhoneCommentsPage(
      store: store,
      postId: 8,
      active: true,
      header: const SizedBox(),
      onOpenPost: (_) {},
    ),
  ),
);

Future<MiniPhoneStore> open(
  WidgetTester tester,
  PhoneBackend b, {
  int count = 12,
}) async {
  b.respond = (r) => r.uri.path.endsWith('/comments')
      ? ok(page([for (var i = 1; i <= count; i++) reply(i)], rn: 100))
      : null;
  final s = (await tester.runAsync(() async {
    final s = b.store(namespace: 'comment-send-${_nextStore++}');
    await s.ready;
    await s.refreshPosts();
    return s;
  }))!;
  s.phoneVisible = true;
  await tester.pumpWidget(screen(s));
  await tester.pumpAndSettle();
  return s;
}

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  final l10n = AppLocalizations.of(
    tester.element(find.byType(MiniPhoneCommentsPage)),
  );
  await tester.tap(find.byTooltip(l10n.miniPhoneSend));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'a comments read started before acceptance cannot consume the local row',
    () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'comment-read-fence');
      addTearDown(s.dispose);
      await s.ready;
      final w = PhoneWrite('request', 'comment', '8', 'Local reply');
      s.postsController.trackComment(w, s.person('u', type: 1));
      final read = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/comments') ? read.future : null;
      final loading = s.refreshComments(8);
      w.accepted = true;
      s.postsController.updateComment(w);
      read.complete(ok(page([], rn: 100)));
      expect(await loading, isTrue);
      expect(s.postsController.outgoingComments(8).length, 1);
      b.respond = (r) => r.uri.path.endsWith('/comments')
          ? ok(page([reply(1, text: 'Local reply')], rn: 100))
          : null;
      expect(await s.refreshComments(8), isTrue);
      expect(s.postsController.outgoingComments(8), isEmpty);
    },
  );
  testWidgets(
    'sending during initial skeleton follows the local row and yields to manual reading',
    (tester) async {
      final b = PhoneBackend();
      final s = await open(tester, b, count: 0);
      addTearDown(s.dispose);
      await tester.pumpWidget(const SizedBox());
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final initial = Completer<Object?>();
      final write = Completer<Object?>();
      var reads = 0;
      b.respond = (r) => r.uri.path.endsWith('/comment/create')
          ? write.future
          : r.uri.path.endsWith('/comments')
          ? (++reads == 1
                ? initial.future
                : ok(
                    page([
                      for (var i = 1; i <= 20; i++) reply(i),
                      reply(21, text: 'Cold reply'),
                    ], rn: 100),
                  ))
          : null;
      await tester.pumpWidget(screen(s));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      await send(tester, 'Cold reply');
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, .5),
      );
      expect(s.postsController.outgoingComments(8).length, 1);
      final row = find.byKey(
        ValueKey(
          'mini-phone-outgoing-comment-${s.postsController.outgoingComments(8).single.write.id}',
        ),
      );
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('Cold reply', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        tester.getBottomRight(row).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField)).dy),
      );
      await tester.drag(find.byType(ListView), const Offset(0, 120));
      await tester.pumpAndSettle();
      initial.complete(
        ok(page([for (var i = 1; i <= 20; i++) reply(i)], rn: 100)),
      );
      await tester.pumpAndSettle();
      expect(s.postsController.outgoingComments(8).length, 1);
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
      write.complete(ok({}));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(s.postsController.outgoingComments(8), isEmpty);
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final newDraft in [false, true]) {
    testWidgets(
      'rejection removes the local row and preserves draft, edited=$newDraft',
      (tester) async {
        final b = PhoneBackend();
        final s = await open(tester, b, count: 3);
        addTearDown(s.dispose);
        await tester.tap(find.textContaining('Reply 1', findRichText: true));
        final write = Completer<Object?>();
        b.respond = (r) =>
            r.uri.path.endsWith('/comment/create') ? write.future : null;
        await send(tester, 'Rejected reply');
        expect(s.postsController.outgoingComments(8).length, 1);
        expect(
          find.textContaining('@Character Rejected reply', findRichText: true),
          findsOneWidget,
        );
        if (newDraft) {
          await tester.enterText(find.byType(TextField), 'Next draft');
        }
        write.complete({'err_no': 2060, 'err_msg': 'Rejected', 'data': {}});
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(s.postsController.outgoingComments(8), isEmpty);
        final input = tester.widget<TextField>(find.byType(TextField));
        expect(
          input.controller!.text,
          newDraft ? 'Next draft' : 'Rejected reply',
        );
        if (!newDraft) {
          expect(input.decoration!.hintText, contains('Character'));
        }
        expect(b.calls('comments').length, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'uncertain retry reuses request and reply target without duplicating the row',
    (tester) async {
      final b = PhoneBackend();
      final s = await open(tester, b, count: 3);
      addTearDown(s.dispose);
      await tester.tap(find.textContaining('Reply 1', findRichText: true));
      final first = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/comment/create') ? first.future : null;
      await send(tester, 'Uncertain reply');
      first.completeError(StateError('offline'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(s.postsController.outgoingComments(8).length, 1);
      final original = b.body(b.calls('comment/create').single);
      final second = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/comment/create')
          ? second.future
          : r.uri.path.endsWith('/comments')
          ? ok(
              page([
                for (var i = 1; i <= 3; i++) reply(i),
                {
                  ...reply(4, text: 'Uncertain reply'),
                  'reply_to_comment_id': 1,
                  'reply_to_char_id': 'c',
                },
              ], rn: 100),
            )
          : null;
      await send(tester, 'Uncertain reply');
      expect(s.postsController.outgoingComments(8).length, 1);
      expect(b.body(b.calls('comment/create').last), original);
      second.complete(ok({}));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(s.postsController.outgoingComments(8), isEmpty);
      expect(
        find.textContaining('Uncertain reply', findRichText: true),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'accepted comment survives a failed read and page reopen until a complete refresh',
    (tester) async {
      final b = PhoneBackend();
      final s = await open(tester, b, count: 0);
      addTearDown(s.dispose);
      b.respond = (r) {
        if (r.uri.path.endsWith('/comments')) throw StateError('offline');
        return null;
      };
      await send(tester, 'Accepted reply');
      expect(
        s.postsController.outgoingComments(8).single.write.accepted,
        isTrue,
      );
      expect(
        find.textContaining('Accepted reply', findRichText: true),
        findsOneWidget,
      );
      expect(s.pending['comment:8'], isNull);
      await tester.pumpWidget(const SizedBox());
      final read = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/comments') ? read.future : null;
      await tester.pumpWidget(screen(s));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Accepted reply', findRichText: true),
        findsOneWidget,
      );
      read.complete(ok(page([reply(1, text: 'Accepted reply')], rn: 100)));
      await tester.pumpAndSettle();
      expect(s.postsController.outgoingComments(8), isEmpty);
      expect(
        find.textContaining('Accepted reply', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'account reset discards pending local comments and late acceptance',
    () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'comment-account-reset');
      addTearDown(s.dispose);
      await s.ready;
      final write = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/comment/create') ? write.future : null;
      final sending = s.write('comment', '8', 'Old account');
      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(s.postsController.outgoingComments(8).length, 1);
      b.uid = 'another-user';
      b.revision.value++;
      await s.ready;
      write.complete(ok({}));
      expect(await sending, isFalse);
      expect(s.postsController.outgoingComments(8), isEmpty);
      expect(s.comments[8], isNull);
    },
  );
  testWidgets(
    'comment renders and follows immediately, then atomically becomes a real reply',
    (tester) async {
      final b = PhoneBackend();
      final s = await open(tester, b);
      addTearDown(s.dispose);
      final write = Completer<Object?>();
      final read = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/comment/create')
          ? write.future
          : r.uri.path.endsWith('/comments')
          ? read.future
          : null;
      await send(tester, 'Optimistic reply');
      expect(
        find.textContaining('Optimistic reply', findRichText: true),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, .5),
      );
      await tester.enterText(find.byType(TextField), 'Next draft');
      write.complete(ok({}));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Optimistic reply', findRichText: true),
        findsOneWidget,
      );
      read.complete(
        ok(
          page([
            for (var i = 1; i <= 12; i++) reply(i),
            reply(13, text: 'Optimistic reply'),
          ], rn: 100),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Optimistic reply', findRichText: true),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Next draft',
      );
      expect(s.comments[8]!.last.id, 13);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
