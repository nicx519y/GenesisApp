import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_feed_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mini_phone_chat_backend.dart';

Map<String, dynamic> feedComment(int id) => {
  'comment_id': id,
  'post_id': 8,
  'author_id': 'c',
  'author_type': 2,
  'comment_type': 2,
  'author_name': 'Character',
  'text': 'Comment $id',
  'published_at': '2026-10-20T08:00:00Z',
  'reply_to_comment_id': 9007199254740993,
  'reply_to_char_id': 'player-char',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final count in [0, 1, 3, 4]) {
    testWidgets(
      'feed shows latest three of $count embedded comments without reads',
      (tester) async {
        final backend = PhoneBackend();
        backend.respond = (request) => request.uri.path.endsWith('/posts')
            ? ok(
                page([
                  {
                    ...phonePost(),
                    'comments': [
                      for (var i = count; i > 0; i--) feedComment(i),
                    ],
                  },
                ]),
              )
            : null;
        final store = (await tester.runAsync(() async {
          final store = backend.store();
          await store.ready;
          store.phoneVisible = store.postsVisible = true;
          await store.refreshPosts();
          return store;
        }))!;
        addTearDown(store.dispose);
        int? opened;
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
                onOpenPost: (id) => opened = id,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final visible = count > 3 ? 3 : count;
        for (var i = count; i > count - visible; i--) {
          expect(
            find.textContaining('Comment $i', findRichText: true),
            findsOneWidget,
          );
        }
        if (count == 4) {
          expect(
            find.textContaining('Comment 1', findRichText: true),
            findsNothing,
          );
          final positions = [
            for (final id in [4, 3, 2])
              tester
                  .getTopLeft(
                    find.textContaining('Comment $id', findRichText: true),
                  )
                  .dy,
          ];
          expect(positions[0], lessThan(positions[1]));
          expect(positions[1], lessThan(positions[2]));
          await tester.tap(find.text('View all comments'));
        } else {
          expect(find.text('View all comments'), findsNothing);
          await tester.tap(find.bySemanticsLabel('Comments'));
        }
        expect(opened, 8);
        expect(find.bySemanticsLabel('Comments, 0'), findsNothing);
        expect(backend.calls('comments'), isEmpty);
        expect(backend.calls('post/detail'), isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test(
    'feed refresh replaces embedded comments and failures retain the old feed',
    () async {
      final backend = PhoneBackend();
      final store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      var ids = [4, 3, 2, 1];
      var fail = false;
      backend.respond = (request) {
        if (!request.uri.path.endsWith('/posts')) return null;
        if (fail) throw ApiException(message: 'Feed unavailable');
        return ok(
          page([
            {...phonePost(), 'comments': ids.map(feedComment).toList()},
          ]),
        );
      };
      await store.refreshPosts();
      expect(store.posts.single.comments.map((c) => c.id), ids);
      fail = true;
      expect(await store.refreshPosts(), isFalse);
      expect(store.posts.single.comments.map((c) => c.id), ids);
      fail = false;
      ids = [5];
      await store.refreshPosts();
      expect(store.posts.single.comments.single.id, 5);
      ids = [];
      await store.refreshPosts();
      expect(store.posts.single.comments, isEmpty);
      expect(backend.calls('comments'), isEmpty);
      expect(backend.calls('post/detail'), isEmpty);
    },
  );
}
