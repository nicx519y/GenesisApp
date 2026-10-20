import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_content.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_feed_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mini_phone_chat_backend.dart';

Map<String, dynamic> post(int id, {String? text}) => {
  ...phonePost(),
  'post_id': id,
  'text': text ?? 'Cached post $id',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'all and each author restore their own cache before revalidation',
    () async {
      final backend = PhoneBackend();
      final store = backend.store(namespace: 'post-filter-cache');
      addTearDown(store.dispose);
      await store.ready;
      backend.respond = (r) => r.uri.path.endsWith('/posts')
          ? ok(
              page([
                post(switch (r.uri.queryParameters['char_id']) {
                  'c' => 2,
                  'player-char' => 3,
                  _ => 1,
                }),
              ]),
            )
          : null;
      await store.refreshPosts();
      final all = store.posts;
      store.authorFilter = 'c';
      expect(store.posts, isEmpty);
      await store.refreshPosts();
      final character = store.posts;
      store.authorFilter = 'player-char';
      await store.refreshPosts();
      final player = store.posts;
      store.authorFilter = null;
      expect(identical(store.posts, all), isTrue);
      store.authorFilter = 'c';
      expect(identical(store.posts, character), isTrue);
      store.authorFilter = 'player-char';
      expect(identical(store.posts, player), isTrue);
      final pending = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/posts') ? pending.future : null;
      final refresh = store.refreshPosts();
      expect(identical(store.posts, player), isTrue);
      pending.complete(ok(page([post(3), post(4)])));
      await refresh;
      expect(store.posts.map((p) => p.id), [3, 4]);
      expect(identical(store.posts.first, player.first), isTrue);
      backend.uid = 'another-user';
      backend.revision.value++;
      await store.ready;
      for (final filter in [null, 'c', 'player-char']) {
        store.authorFilter = filter;
        expect(store.posts, isEmpty);
        expect(store.pages['posts'], isNull);
      }
    },
  );

  test(
    'equal responses retain identities; changed, removed and reordered posts reconcile',
    () async {
      final backend = PhoneBackend();
      final store = backend.store(namespace: 'post-diff-cache');
      addTearDown(store.dispose);
      await store.ready;
      var rows = [post(1), post(2), post(3)];
      backend.respond = (r) =>
          r.uri.path.endsWith('/posts') ? ok(page(rows)) : null;
      await store.refreshPosts();
      final before = store.posts;
      final authors = store.authors;
      await store.refreshPosts();
      expect(identical(store.posts, before), isTrue);
      expect(identical(store.authors, authors), isTrue);
      rows = [post(3), post(2, text: 'Updated'), post(4)];
      await store.refreshPosts();
      expect(store.posts.map((p) => p.id), [3, 2, 4]);
      expect(identical(store.posts.first, before[2]), isTrue);
      expect(identical(store.posts[1], before[1]), isFalse);
      expect(store.posts[1].text, 'Updated');
      final unchanged = store.posts;
      rows = [
        {...post(3), 'like_count': 5},
        rows[1],
        rows[2],
      ];
      await store.refreshPosts();
      expect(store.posts.first.likeCount, 5);
      expect(identical(store.posts[1], unchanged[1]), isTrue);
      final beforeComment = store.posts.first;
      rows = [
        {
          ...rows.first,
          'comments': [
            {
              'comment_id': 9007199254740993,
              'post_id': 3,
              'author_id': 'c',
              'author_type': 2,
              'comment_type': 1,
              'author_name': 'Character',
              'text': 'New reply',
            },
          ],
        },
        ...rows.skip(1),
      ];
      await store.refreshPosts();
      expect(identical(store.posts.first, beforeComment), isFalse);
      expect(store.posts.first.comments.single.text, 'New reply');
      final beforeImage = store.posts.first;
      rows = [
        {...rows.first, 'image': 'https://example.test/new.png'},
        ...rows.skip(1),
      ];
      await store.refreshPosts();
      expect(identical(store.posts.first, beforeImage), isFalse);
      expect(identical(store.posts[1], unchanged[1]), isTrue);
    },
  );

  test(
    'superseded refresh cannot overwrite a cached filter and equal requests coalesce',
    () async {
      final backend = PhoneBackend();
      final store = backend.store(namespace: 'post-cache-race');
      addTearDown(store.dispose);
      await store.ready;
      backend.respond = (r) => r.uri.path.endsWith('/posts')
          ? ok(page([post(r.uri.queryParameters['char_id'] == null ? 1 : 2)]))
          : null;
      await store.refreshPosts();
      final all = store.posts;
      store.authorFilter = 'c';
      await store.refreshPosts();
      final character = store.posts;
      store.authorFilter = null;
      final pending = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/posts') ? pending.future : null;
      final count = backend.calls('posts').length;
      final first = store.refreshPosts(), duplicate = store.refreshPosts();
      await Future<void>.delayed(Duration.zero);
      expect(backend.calls('posts').length, count + 1);
      store.authorFilter = 'c';
      expect(identical(store.posts, character), isTrue);
      pending.complete(ok(page([post(99)])));
      expect(await first, isFalse);
      expect(await duplicate, isFalse);
      expect(identical(store.posts, character), isTrue);
      store.authorFilter = null;
      expect(identical(store.posts, all), isTrue);
    },
  );

  test(
    'refresh retains loaded pages until the whole cached window is reconciled',
    () async {
      final backend = PhoneBackend();
      final store = backend.store(namespace: 'post-page-cache');
      addTearDown(store.dispose);
      await store.ready;
      backend.respond = (r) {
        if (!r.uri.path.endsWith('/posts')) return null;
        final pn = int.parse(r.uri.queryParameters['pn']!);
        return ok(
          page(
            [for (var i = (pn - 1) * 10 + 1; i <= pn * 10; i++) post(i)],
            pn: pn,
            total: 30,
          ),
        );
      };
      await store.refreshPosts();
      await store.refreshPosts(next: true);
      final cached = store.posts;
      store.authorFilter = 'c';
      store.authorFilter = null;
      expect(identical(store.posts, cached), isTrue);
      expect(store.pages['posts'], 2);
      final second = Completer<Object?>();
      backend.respond = (r) {
        if (!r.uri.path.endsWith('/posts')) return null;
        if (r.uri.queryParameters['pn'] == '2') return second.future;
        return ok(
          page([post(100), for (var i = 1; i < 10; i++) post(i)], total: 31),
        );
      };
      final refresh = store.refreshPosts();
      await Future<void>.delayed(Duration.zero);
      expect(identical(store.posts, cached), isTrue);
      second.complete(
        ok(page([for (var i = 10; i < 20; i++) post(i)], pn: 2, total: 31)),
      );
      expect(await refresh, isTrue);
      expect(store.posts.map((p) => p.id), [
        100,
        for (var i = 1; i < 20; i++) i,
      ]);
      expect(identical(store.posts[1], cached.first), isTrue);
      expect(store.pages['posts'], 2);
      final updated = store.posts;
      backend.respond = (r) {
        if (!r.uri.path.endsWith('/posts')) return null;
        if (r.uri.queryParameters['pn'] == '2') throw StateError('Offline');
        return ok(page([post(200)], total: 31));
      };
      expect(await store.refreshPosts(), isFalse);
      expect(identical(store.posts, updated), isTrue);
      backend.uid = 'another-user';
      backend.revision.value++;
      await store.ready;
      expect(store.posts, isEmpty);
      store.authorFilter = 'c';
      expect(store.posts, isEmpty);
    },
  );

  testWidgets('revalidation keeps unchanged row widgets and scroll position', (
    tester,
  ) async {
    final backend = PhoneBackend();
    var rows = [for (var i = 1; i <= 10; i++) post(i)];
    backend.respond = (r) =>
        r.uri.path.endsWith('/posts') ? ok(page(rows)) : null;
    final store = (await tester.runAsync(() async {
      final store = backend.store(namespace: 'post-row-cache');
      await store.ready;
      await store.refreshPosts();
      return store;
    }))!;
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MiniPhonePostFeedPage(
            store: store,
            active: true,
            header: const SizedBox.shrink(),
            onCreate: () {},
            onOpenPost: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      ),
    );
    list.controller!.jumpTo(70);
    await tester.pumpAndSettle();
    MiniPhonePostContent card(int id) => tester.widget<MiniPhonePostContent>(
      find.byWidgetPredicate((w) => w is MiniPhonePostContent && w.id == id),
    );
    final first = card(1), second = card(2);
    final offset = list.controller!.offset;
    final pending = Completer<Object?>();
    backend.respond = (r) =>
        r.uri.path.endsWith('/posts') ? pending.future : null;
    final refresh = store.refreshPosts();
    await tester.pump();
    expect(identical(card(1), first), isTrue);
    rows = [post(1), post(2, text: 'Changed row'), ...rows.skip(2)];
    pending.complete(ok(page(rows)));
    await refresh;
    await tester.pumpAndSettle();
    expect(identical(card(1), first), isTrue);
    expect(identical(card(2), second), isFalse);
    expect(find.text('Changed row'), findsOneWidget);
    expect(list.controller!.offset, offset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
