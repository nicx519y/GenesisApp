import 'dart:async';
import 'dart:ui' as ui;
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_comments_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/shared/mini_phone_ui.dart';
import 'package:genesis_flutter_android/pages/mini_phone/shared/mini_phone_controls.dart';
import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_memory_cache.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_store.dart';
import 'package:genesis_flutter_android/network/models/world.dart';

// Isolate the static request-journal queue across Flutter test zones.
int _nextStore = 0;

Map<String, dynamic> comment(int id) => {
  'comment_id': id,
  'post_id': 8,
  'author_id': 'c',
  'author_type': 2,
  'comment_type': 1,
  'author_name': 'Character',
  'text': 'Reply $id',
  'published_at': '2026-10-20T08:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scale in [1.0, 2.0]) {
    testWidgets('comment action count slot stays fixed at scale $scale', (
      tester,
    ) async {
      Widget build(int? count) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Row(
              children: [
                miniPhonePostAction(
                  'messages',
                  'Comments',
                  count,
                  () {},
                  reserveCountSpace: true,
                ),
                const SizedBox(width: 20),
                miniPhonePostAction('heart', 'Like', 0, () {}),
              ],
            ),
          ),
        ),
      );
      final icons = find.byType(MiniIcon);
      await tester.pumpWidget(build(null));
      final commentRect = tester.getRect(icons.at(0));
      final likeRect = tester.getRect(icons.at(1));
      for (final count in [0, 1, 99, 100, 1234, 9007199254740993]) {
        await tester.pumpWidget(build(count));
        expect(tester.getRect(icons.at(0)), commentRect);
        expect(tester.getRect(icons.at(1)), likeRect);
        expect(tester.takeException(), isNull);
      }
    });
  }

  test(
    'loads every page atomically, deduplicates and orders full int64 IDs',
    () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'comments-full-${_nextStore++}');
      addTearDown(s.dispose);
      await s.ready;
      final second = Completer<Object?>();
      b.respond = (r) {
        if (!r.uri.path.endsWith('/comments')) return null;
        expect(r.uri.queryParameters['rn'], '100');
        final pn = int.parse(r.uri.queryParameters['pn']!);
        return pn == 1
            ? ok(
                page(
                  [comment(9007199254740993), comment(2)],
                  rn: 100,
                  total: 101,
                ),
              )
            : second.future;
      };
      final read = s.refreshComments(8);
      await Future<void>.delayed(Duration.zero);
      expect(s.comments.containsKey(8), isFalse);
      second.complete(
        ok(
          page(
            [comment(2), comment(9007199254740992)],
            pn: 2,
            rn: 100,
            total: 101,
          ),
        ),
      );
      expect(await read, isTrue);
      expect(s.comments[8]!.map((c) => c.id), [
        2,
        9007199254740992,
        9007199254740993,
      ]);
      expect(b.calls('comments').length, 2);
    },
  );

  test('later-page failure retains last complete list', () async {
    final b = PhoneBackend();
    final s = b.store(namespace: 'comments-full-${_nextStore++}');
    addTearDown(s.dispose);
    await s.ready;
    s.comments[8] = [PhoneComment.fromJson(comment(7))];
    b.respond = (r) {
      if (!r.uri.path.endsWith('/comments')) return null;
      if (r.uri.queryParameters['pn'] == '2') throw StateError('offline');
      return ok(page([comment(1)], rn: 100, total: 101));
    };
    expect(await s.refreshComments(8), isFalse);
    expect(s.comments[8]!.single.id, 7);
    expect(s.errors['comments:8'], isNotNull);
  });

  testWidgets(
    'feed renders immediately while replies wait independently of detail',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        await s.ready;
        await s.refreshPosts();
        return s;
      }))!;
      addTearDown(s.dispose);
      s.phoneVisible = true;
      s.comments[8] = [PhoneComment.fromJson(comment(99))];
      final detail = Completer<Object?>();
      final replies = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/post/detail')
          ? detail.future
          : r.uri.path.endsWith('/comments')
          ? replies.future
          : null;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MiniPhoneCommentsPage(
              store: s,
              postId: 8,
              active: true,
              header: const SizedBox(),
              onOpenPost: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Post body'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsOneWidget,
      );
      expect(find.textContaining('Reply 99', findRichText: true), findsNothing);
      replies.complete(ok(page([comment(1)], rn: 100)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Reply 1', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsNothing,
      );
      detail.complete(ok({...phoneDetail(), 'content': 'Updated post'}));
      await tester.pumpAndSettle();
      expect(find.text('Updated post'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final scale in [1.0, 2.0]) {
    for (final detailFirst in [true, false]) {
      testWidgets(
        'comment header reserves space at scale $scale, detail first: $detailFirst',
        (tester) async {
          final b = PhoneBackend();
          final s = (await tester.runAsync(() async {
            final s = b.store(namespace: 'comments-full-${_nextStore++}');
            await s.ready;
            await s.refreshPosts();
            return s;
          }))!;
          addTearDown(s.dispose);
          s.phoneVisible = true;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final detail = Completer<Object?>();
          final replies = Completer<Object?>();
          b.respond = (r) => r.uri.path.endsWith('/post/detail')
              ? detail.future
              : r.uri.path.endsWith('/comments')
              ? replies.future
              : null;
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: MiniPhoneCommentsPage(
                  store: s,
                  postId: 8,
                  active: true,
                  header: const SizedBox(),
                  onOpenPost: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final skeleton = find.byKey(
            const ValueKey('mini-phone-comments-skeleton'),
          );
          final initialTop = tester.getTopLeft(skeleton).dy;
          Finder action(String icon) => find
              .ancestor(
                of: find.byWidgetPredicate(
                  (w) => w is MiniIcon && w.name == icon,
                ),
                matching: find.byType(InkWell),
              )
              .first;
          final commentAction = tester.getRect(action('messages'));
          final likeAction = tester.getRect(action('heart'));
          void expectStableActions() {
            expect(tester.getRect(action('messages')), commentAction);
            expect(tester.getRect(action('heart')), likeAction);
          }

          if (detailFirst) {
            detail.complete(ok(phoneDetail()));
            await tester.pumpAndSettle();
            expectStableActions();
            expect(tester.getTopLeft(skeleton).dy, closeTo(initialTop, .01));
          }
          replies.complete(ok(page([comment(1)], rn: 100)));
          await tester.pumpAndSettle();
          expectStableActions();
          final firstRow = find
              .ancestor(
                of: find.textContaining('Reply 1', findRichText: true),
                matching: find.byType(InkWell),
              )
              .first;
          expect(tester.getTopLeft(firstRow).dy, closeTo(initialTop, .01));
          if (!detailFirst) {
            detail.complete(ok(phoneDetail()));
            await tester.pumpAndSettle();
            expectStableActions();
            expect(tester.getTopLeft(firstRow).dy, closeTo(initialTop, .01));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final count in [0, 1, 100, 205]) {
    test('fully loads $count replies and replaces an older cache', () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'comments-full-${_nextStore++}');
      addTearDown(s.dispose);
      await s.ready;
      s.comments[8] = [PhoneComment.fromJson(comment(999))];
      b.respond = (r) {
        if (!r.uri.path.endsWith('/comments')) return null;
        final pn = int.parse(r.uri.queryParameters['pn']!);
        expect(r.uri.queryParameters['rn'], '100');
        final start = (pn - 1) * 100;
        return ok(
          page(
            [
              for (var n = start + 1; n <= count && n <= start + 100; n++)
                comment(n),
            ],
            pn: pn,
            rn: 100,
            total: count,
          ),
        );
      };
      expect(await s.refreshComments(8), isTrue);
      expect(s.comments[8]!.map((c) => c.id), [
        for (var n = 1; n <= count; n++) n,
      ]);
      expect(b.calls('comments').length, count == 0 ? 1 : (count / 100).ceil());
    });
  }

  test(
    'coalesces duplicate full loads and rejects superseded responses',
    () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'comments-full-${_nextStore++}');
      addTearDown(s.dispose);
      await s.ready;
      final old = Completer<Object?>();
      var calls = 0;
      b.respond = (r) {
        if (!r.uri.path.endsWith('/comments')) return null;
        return ++calls == 1 ? old.future : ok(page([comment(3)], rn: 100));
      };
      final first = s.refreshComments(8);
      final duplicate = s.refreshComments(8);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(await s.refreshComments(8, afterWrite: true), isTrue);
      old.complete(ok(page([comment(1)], rn: 100, total: 101)));
      expect(await first, isFalse);
      expect(await duplicate, isFalse);
      expect(s.comments[8]!.single.id, 3);
      expect(calls, 2);
      expect(s.errors['comments:8'], isNull);
    },
  );

  for (final cancel in ['background', 'account', 'dispose']) {
    test(
      '$cancel stops subsequent pages and discards incomplete data',
      () async {
        final b = PhoneBackend();
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        await s.ready;
        if (cancel != 'dispose') addTearDown(s.dispose);
        final pending = Completer<Object?>();
        b.respond = (r) =>
            r.uri.path.endsWith('/comments') ? pending.future : null;
        final read = s.refreshComments(8);
        await Future<void>.delayed(Duration.zero);
        if (cancel == 'background') s.foreground = false;
        if (cancel == 'account') s.requests.reset();
        if (cancel == 'dispose') s.dispose();
        pending.complete(ok(page([comment(1)], rn: 100, total: 101)));
        expect(await read, isFalse);
        expect(s.comments.containsKey(8), isFalse);
        expect(b.calls('comments').length, 1);
        expect(s.errors['comments:8'], isNull);
      },
    );
  }

  for (final invalid in ['empty', 'wrong-page']) {
    test(
      'rejects $invalid pagination without publishing a partial result',
      () async {
        final b = PhoneBackend();
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        addTearDown(s.dispose);
        await s.ready;
        b.respond = (r) => r.uri.path.endsWith('/comments')
            ? ok(
                page(
                  invalid == 'empty' ? [] : [comment(1)],
                  pn: invalid == 'wrong-page' ? 2 : 1,
                  rn: 100,
                  total: 101,
                ),
              )
            : null;
        expect(await s.refreshComments(8), isFalse);
        expect(s.comments.containsKey(8), isFalse);
        expect(s.errors['comments:8'], isNotNull);
        expect(b.calls('comments').length, 1);
      },
    );
  }

  test('sorts by publication instant before int64 comment ID', () async {
    final b = PhoneBackend();
    final s = b.store(namespace: 'comments-full-${_nextStore++}');
    addTearDown(s.dispose);
    await s.ready;
    b.respond = (r) => r.uri.path.endsWith('/comments')
        ? ok(
            page([
              {...comment(1), 'published_at': '2026-10-20T09:00:00Z'},
              {...comment(3), 'published_at': '2026-10-20T16:00:00+08:00'},
              comment(2),
            ], rn: 100),
          )
        : null;
    expect(await s.refreshComments(8), isTrue);
    expect(s.comments[8]!.map((c) => c.id), [2, 3, 1]);
  });

  testWidgets(
    'keyboard waits for full replies, follows layout and yields to manual reading',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        await s.ready;
        await s.refreshPosts();
        return s;
      }))!;
      addTearDown(s.dispose);
      s.phoneVisible = true;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final pending = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/comments') ? pending.future : null;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MiniPhoneCommentsPage(
              store: s,
              postId: 8,
              active: true,
              header: const SizedBox(),
              onOpenPost: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      expect(controller.offset, 0);
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        0,
        reason: 'Skeletons must not be treated as the final reply list.',
      );
      pending.complete(
        ok(page([for (var i = 1; i <= 25; i++) comment(i)], rn: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, .5),
      );
      expect(
        find.textContaining('Reply 25', findRichText: true),
        findsOneWidget,
      );
      expect(
        tester
            .getBottomLeft(find.textContaining('Reply 25', findRichText: true))
            .dy,
        lessThanOrEqualTo(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('mini-phone-comment-input')),
              )
              .dy,
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'line1\nline2\nline3\nline4',
      );
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, .5),
      );
      await tester.drag(find.byType(ListView), const Offset(0, 250));
      await tester.pumpAndSettle();
      final readOffset = controller.offset;
      expect(readOffset, lessThan(controller.position.maxScrollExtent - 20));
      b.respond = (r) => r.uri.path.endsWith('/comments')
          ? ok(page([for (var i = 1; i <= 26; i++) comment(i)], rn: 100))
          : null;
      await tester.runAsync(() => s.refreshComments(8));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(readOffset, .5));
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, .5),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failure ends skeleton, retry restores it, empty success shows empty state',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        await s.ready;
        await s.refreshPosts();
        return s;
      }))!;
      addTearDown(s.dispose);
      s.phoneVisible = true;
      final failed = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/comments') ? failed.future : null;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MiniPhoneCommentsPage(
              store: s,
              postId: 8,
              active: true,
              header: const SizedBox(),
              onOpenPost: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      failed.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsNothing,
      );
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(MiniPhoneCommentsPage)),
          ).miniPhoneFirstComment,
        ),
        findsNothing,
      );
      final pending = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/comments') ? pending.future : null;
      final retry = s.refreshComments(8);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsOneWidget,
      );
      pending.complete(ok(page([], rn: 100)));
      await tester.pumpAndSettle();
      await retry;
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsNothing,
      );
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(MiniPhoneCommentsPage)),
          ).miniPhoneFirstComment,
        ),
        findsOneWidget,
      );
      final refreshing = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/comments') ? refreshing.future : null;
      final refresh = s.refreshComments(8);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsNothing,
      );
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(MiniPhoneCommentsPage)),
          ).miniPhoneFirstComment,
        ),
        findsOneWidget,
      );
      refreshing.complete(ok(page([comment(1)], rn: 100)));
      await tester.pumpAndSettle();
      await refresh;
      expect(
        find.textContaining('Reply 1', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'entering again hides old replies, retains feed snapshot and starts at top',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        await s.ready;
        await s.refreshPosts();
        return s;
      }))!;
      addTearDown(s.dispose);
      s.phoneVisible = true;
      s.details[8] = PhonePostDetail.fromJson({
        ...phoneDetail(liked: true),
        'content': 'Old detail',
      });
      var detail = Completer<Object?>();
      var replies = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/post/detail')
          ? detail.future
          : r.uri.path.endsWith('/comments')
          ? replies.future
          : null;
      Widget screen() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MiniPhoneCommentsPage(
            store: s,
            postId: 8,
            active: true,
            header: const SizedBox(),
            onOpenPost: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(find.text('Post body'), findsOneWidget);
      expect(find.text('Old detail'), findsNothing);
      detail.completeError(StateError('detail offline'));
      replies.complete(
        ok(page([for (var i = 1; i <= 20; i++) comment(i)], rn: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Post body'), findsOneWidget);
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      expect(controller.offset, 0);
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      detail = Completer<Object?>();
      replies = Completer<Object?>();
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsOneWidget,
      );
      expect(find.textContaining('Reply 1', findRichText: true), findsNothing);
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        0,
      );
      detail.complete(ok({...phoneDetail(), 'content': 'Fresh detail'}));
      await tester.pumpAndSettle();
      expect(find.text('Fresh detail'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsOneWidget,
      );
      replies.complete(ok(page([], rn: 100)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'sending a reply reloads every page and lands on the newest item',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        await s.ready;
        await s.refreshPosts();
        return s;
      }))!;
      addTearDown(s.dispose);
      s.phoneVisible = true;
      var count = 105;
      b.respond = (r) {
        if (r.uri.path.endsWith('/comment/create')) {
          count++;
          return ok({});
        }
        if (!r.uri.path.endsWith('/comments')) return null;
        final pn = int.parse(r.uri.queryParameters['pn']!);
        final start = (pn - 1) * 100;
        return ok(
          page(
            [
              for (var i = start + 1; i <= count && i <= start + 100; i++)
                comment(i),
            ],
            pn: pn,
            rn: 100,
            total: count,
          ),
        );
      };
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MiniPhoneCommentsPage(
              store: s,
              postId: 8,
              active: true,
              header: const SizedBox(),
              onOpenPost: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('Reply 1', findRichText: true).first,
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
        contains('Character'),
      );
      await tester.enterText(find.byType(TextField), 'New reply');
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MiniPhoneCommentsPage)),
      );
      await tester.tap(find.byTooltip(l10n.miniPhoneSend));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(
        b.body(b.calls('comment/create').single)['reply_to_comment_id'],
        1,
      );
      expect(b.calls('comments').map((r) => r.uri.queryParameters['pn']), [
        '1',
        '2',
        '1',
        '2',
      ]);
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, .5),
      );
      expect(
        find.textContaining('Reply 106', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'narrow large-text skeleton keeps three rows and cancels pending positioning on exit',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        await s.ready;
        await s.refreshPosts();
        return s;
      }))!;
      addTearDown(s.dispose);
      s.phoneVisible = true;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final pending = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/comments') ? pending.future : null;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: MiniPhoneCommentsPage(
              store: s,
              postId: 8,
              active: true,
              header: const SizedBox(),
              onOpenPost: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final skeleton = find.byKey(
        const ValueKey('mini-phone-comments-skeleton'),
      );
      expect(tester.widget<Column>(skeleton).children.length, 3);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      pending.complete(ok(page([comment(1)], rn: 100)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'detail entry waits for local identity without waiting for Home',
    (tester) async {
      final b = PhoneBackend();
      final identity = Completer<String?>();
      final home = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/home') ? home.future : null;
      final s = MiniPhoneStore(
        api: b.api,
        worldId: 'w',
        namespace: 'comments-full-${_nextStore++}',
        readUid: () => identity.future,
        loadWorld: () async => WorldDetail.fromJson({}),
        accountRevision: b.revision,
        cacheStorage: MemoryMiniPhoneCacheStorage(),
      );
      addTearDown(s.dispose);
      s.phoneVisible = true;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MiniPhoneCommentsPage(
              store: s,
              postId: 8,
              active: true,
              header: const SizedBox(),
              onOpenPost: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('mini-phone-comments-skeleton')),
        findsOneWidget,
      );
      expect(b.calls('comments'), isEmpty);
      identity.complete('u');
      await tester.pumpAndSettle();
      expect(b.calls('comments').length, 1);
      expect(b.calls('post/detail').length, 1);
      expect(find.text('Post body'), findsOneWidget);
      home.complete(b.defaultResponse(b.calls('home').single));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'late detail image keeps fixed height and the latest reply above the keyboard',
    (tester) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 500, 100),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final decoded = (await tester.runAsync(() => picture.toImage(500, 100)))!;
      picture.dispose();
      addTearDown(decoded.dispose);
      final image = Completer<ImageInfo>();
      debugGenesisStaticNetworkImageCompleter = (_) =>
          OneFrameImageStreamCompleter(image.future);
      addTearDown(() {
        debugGenesisStaticNetworkImageCompleter = null;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store(namespace: 'comments-full-${_nextStore++}');
        await s.ready;
        await s.refreshPosts();
        return s;
      }))!;
      addTearDown(s.dispose);
      s.phoneVisible = true;
      b.respond = (r) => r.uri.path.endsWith('/post/detail')
          ? ok({
              ...phoneDetail(),
              'image': 'https://example.test/delayed-detail.png',
            })
          : r.uri.path.endsWith('/comments')
          ? ok(page([for (var i = 1; i <= 4; i++) comment(i)], rn: 100))
          : null;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MiniPhoneCommentsPage(
              store: s,
              postId: 8,
              active: true,
              header: const SizedBox(),
              onOpenPost: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      final before = controller.position.maxScrollExtent;
      expect(controller.offset, closeTo(before, .5));
      image.complete(ImageInfo(image: decoded.clone()));
      await tester.pumpAndSettle();
      expect(controller.position.maxScrollExtent, before);
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, .5),
      );
      expect(
        tester
            .getBottomLeft(find.textContaining('Reply 4', findRichText: true))
            .dy,
        lessThanOrEqualTo(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('mini-phone-comment-input')),
              )
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
