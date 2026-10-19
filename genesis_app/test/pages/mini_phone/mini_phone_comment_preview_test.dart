import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mini_phone_chat_backend.dart';

Future<void> flushPreview() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Object commentPage(int id) => ok(
  page([
    {
      'comment_id': id,
      'post_id': 8,
      'author_id': 'c',
      'author_type': 2,
      'comment_type': 2,
      'author_name': 'Character',
      'text': 'Comment $id',
    },
  ], rn: 3),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'feed refresh releases a superseded preview and rejects its late result',
    () async {
      final backend = PhoneBackend();
      final store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      store.phoneVisible = store.postsVisible = true;
      final oldRequest = Completer<Object>();
      var reads = 0;
      backend.respond = (request) {
        if (request.uri.path.endsWith('/posts')) {
          return ok(
            page([
              {...phonePost(), 'comment_count': 1},
            ]),
          );
        }
        if (request.uri.path.endsWith('/comments')) {
          reads++;
          return reads == 1 ? oldRequest.future : commentPage(2);
        }
        return null;
      };
      await store.refreshPosts();
      store.postsController.ensureCommentPreviews(store.posts);
      await flushPreview();
      expect(store.busy, contains('commentPreview:8'));
      await store.refreshPosts();
      expect(store.busy, isNot(contains('commentPreview:8')));
      store.postsController.ensureCommentPreviews(store.posts);
      await flushPreview();
      expect(reads, 2);
      expect(store.postsController.commentPreviews[8]!.single.id, 2);
      oldRequest.complete(commentPage(1));
      await flushPreview();
      expect(store.postsController.commentPreviews[8]!.single.id, 2);
      expect(store.busy, isNot(contains('commentPreview:8')));
      expect(backend.calls('comments').last.uri.queryParameters['rn'], '3');
      expect(backend.calls('post/detail'), isEmpty);
    },
  );

  test(
    'feed refresh keeps loaded preview until replacement, zero count clears it',
    () async {
      final backend = PhoneBackend();
      final store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      store.phoneVisible = store.postsVisible = true;
      var count = 1;
      backend.respond = (request) {
        if (request.uri.path.endsWith('/posts')) {
          return ok(
            page([
              {...phonePost(), 'comment_count': count},
            ]),
          );
        }
        if (request.uri.path.endsWith('/comments')) return commentPage(1);
        return null;
      };
      await store.refreshPosts();
      store.postsController.ensureCommentPreviews(store.posts);
      await flushPreview();
      expect(store.postsController.commentPreviews[8]!.single.id, 1);
      await store.refreshPosts();
      expect(store.postsController.commentPreviews[8]!.single.id, 1);
      count = 0;
      await store.refreshPosts();
      expect(store.postsController.commentPreviews[8], isNull);
    },
  );
}
