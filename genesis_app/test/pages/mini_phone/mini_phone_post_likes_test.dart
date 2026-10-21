import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_comments_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_feed_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/shared/mini_phone_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mini_phone_chat_backend.dart';

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'rapid like unlike like projects the latest intent without double counting',
    () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'like-rapid');
      addTearDown(s.dispose);
      await s.ready;
      await s.refreshPosts();
      final write = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/post/like')
          ? write.future
          : r.uri.path.endsWith('/post/detail')
          ? ok(phoneDetail(liked: true))
          : null;
      final pending = s.setLiked(8, true);
      expect(s.postsController.likeState(8), (count: 1, liked: true));
      await flush();
      await s.setLiked(8, false);
      expect(s.postsController.likeState(8), (count: 0, liked: false));
      await s.setLiked(8, true);
      expect(s.postsController.likeState(8), (count: 1, liked: true));
      write.complete(ok({}));
      await pending;
      expect(s.postsController.likeState(8), (count: 1, liked: true));
      expect(b.calls('post/like').length, 1);
      expect(b.calls('post/unlike'), isEmpty);
    },
  );
  test(
    'queued unlike failure rolls back to the confirmed like before its read completes',
    () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'like-queued-failure');
      addTearDown(s.dispose);
      await s.ready;
      await s.refreshPosts();
      final like = Completer<Object?>();
      final unlike = Completer<Object?>();
      final confirm = Completer<Object?>();
      var reads = 0;
      b.respond = (r) => r.uri.path.endsWith('/post/like')
          ? like.future
          : r.uri.path.endsWith('/post/unlike')
          ? unlike.future
          : r.uri.path.endsWith('/post/detail')
          ? (++reads == 1 ? ok(phoneDetail(liked: true)) : confirm.future)
          : null;
      final pending = s.setLiked(8, true);
      await flush();
      await s.setLiked(8, false);
      like.complete(ok({}));
      await flush();
      expect(b.calls('post/unlike').length, 1);
      expect(s.postsController.likeState(8), (count: 0, liked: false));
      unlike.complete({'err_no': 2060, 'err_msg': 'Rejected', 'data': {}});
      await flush();
      expect(s.postsController.likeState(8), (count: 1, liked: true));
      confirm.complete(ok(phoneDetail(liked: true)));
      await pending;
      expect(s.postsController.likeState(8), (count: 1, liked: true));
    },
  );
  test(
    'accepted like survives a failed confirmation and fresh feed replaces its baseline',
    () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'like-confirm-failure');
      addTearDown(s.dispose);
      await s.ready;
      await s.refreshPosts();
      b.respond = (r) {
        if (r.uri.path.endsWith('/post/detail')) throw StateError('offline');
        return null;
      };
      await s.setLiked(8, true);
      expect(s.likeTargets, isEmpty);
      expect(s.postsController.likeState(8), (count: 1, liked: true));
      b.respond = (r) => r.uri.path.endsWith('/posts')
          ? ok(
              page([
                {...phonePost(liked: true), 'like_count': 3},
              ]),
            )
          : null;
      await s.refreshPosts();
      expect(s.postsController.likeState(8), (count: 3, liked: true));
    },
  );
  test(
    'account reset discards a pending optimistic like and its late response',
    () async {
      final b = PhoneBackend();
      final s = b.store(namespace: 'like-account-reset');
      addTearDown(s.dispose);
      await s.ready;
      await s.refreshPosts();
      final write = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/post/like') ? write.future : null;
      final pending = s.setLiked(8, true);
      await flush();
      b.uid = 'another-user';
      b.revision.value++;
      await s.ready;
      write.complete(ok({}));
      await pending;
      expect(s.likeTargets, isEmpty);
      expect(s.postsController.likeState(8), (count: 0, liked: false));
    },
  );
  for (final detail in [false, true]) {
    for (final initiallyLiked in [false, true]) {
      for (final succeeds in [false, true]) {
        testWidgets(
          'optimistic like detail=$detail liked=$initiallyLiked success=$succeeds',
          (tester) async {
            final b = PhoneBackend();
            b.respond = (r) => r.uri.path.endsWith('/posts')
                ? ok(
                    page([
                      {...phonePost(liked: initiallyLiked), 'like_count': 7},
                    ]),
                  )
                : r.uri.path.endsWith('/post/detail')
                ? ok({...phoneDetail(liked: initiallyLiked), 'like_count': 7})
                : null;
            final s = (await tester.runAsync(() async {
              final s = b.store(
                namespace: 'likes-$detail-$initiallyLiked-$succeeds',
              );
              await s.ready;
              await s.refreshPosts();
              return s;
            }))!;
            addTearDown(s.dispose);
            s.phoneVisible = true;
            await tester.pumpWidget(
              MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: detail
                      ? MiniPhoneCommentsPage(
                          store: s,
                          postId: 8,
                          active: true,
                          header: const SizedBox(),
                          onOpenPost: (_) {},
                        )
                      : MiniPhonePostFeedPage(
                          store: s,
                          active: true,
                          header: const SizedBox(),
                          onCreate: () {},
                          onOpenPost: (_) {},
                        ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final heart = find.byWidgetPredicate(
              (w) => w is MiniIcon && w.name == 'heart',
            );
            final action = find
                .ancestor(of: heart, matching: find.byType(InkWell))
                .first;
            void expectLike(bool liked, int count) {
              expect(
                tester.widget<MiniIcon>(heart).color,
                liked ? miniPink : miniSecondary,
              );
              expect(
                find.descendant(of: action, matching: find.text('$count')),
                findsOneWidget,
              );
            }

            expectLike(initiallyLiked, 7);
            final write = Completer<Object?>();
            final confirm = Completer<Object?>();
            b.respond = (r) =>
                r.uri.path.endsWith('/post/like') ||
                    r.uri.path.endsWith('/post/unlike')
                ? write.future
                : r.uri.path.endsWith('/post/detail')
                ? confirm.future
                : null;
            await tester.tap(heart);
            await tester.pump();
            final changed = initiallyLiked ? 6 : 8;
            expectLike(!initiallyLiked, changed);
            write.complete(
              succeeds
                  ? ok({})
                  : {'err_no': 2060, 'err_msg': 'Rejected', 'data': {}},
            );
            await tester.pumpAndSettle();
            expectLike(
              succeeds ? !initiallyLiked : initiallyLiked,
              succeeds ? changed : 7,
            );
            confirm.complete(
              ok({
                ...phoneDetail(
                  liked: succeeds ? !initiallyLiked : initiallyLiked,
                ),
                'like_count': succeeds ? changed : 7,
              }),
            );
            await tester.pumpAndSettle();
            expectLike(
              succeeds ? !initiallyLiked : initiallyLiked,
              succeeds ? changed : 7,
            );
            expect(b.calls('posts').length, 1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
