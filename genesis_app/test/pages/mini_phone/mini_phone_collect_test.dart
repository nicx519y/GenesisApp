import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/network/models/miniphone_info.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_analytics.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_draft.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/wallpaper/mini_phone_wallpaper_controller.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/utils/image_upload_processing.dart';

import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_collect_probe.dart';

Map<String, dynamic> extra(CollectEvent event) =>
    jsonDecode(event.extData) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MiniPhoneCollectProbe probe;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probe = MiniPhoneCollectProbe();
  });
  tearDown(() => probe.dispose());

  test(
    'DM records submit and HTTP acceptance with zero session and no content',
    () async {
      final b = PhoneBackend(), store = b.store();
      addTearDown(store.dispose);
      await store.ready;
      store.analytics.beginOpen();
      expect(await store.write('dm', 'new-char', 'SECRET MESSAGE'), isTrue);
      final events = await probe.take();
      expect(events.map((e) => e.action).toSet(), {'mini_phone_dm_send'});
      expect(events.map((e) => e.object3), ['submit', 'accepted']);
      expect(events.map((e) => e.object4).toSet(), hasLength(1));
      expect(extra(events.first)['dm_session_id'], '0');
      expect(extra(events.first)['peer_type'], 'ai');
      expect(
        extra(events.first)['client_request_id'],
        extra(events.last)['client_request_id'],
      );
      expect(
        jsonEncode(events.map((e) => e.toWireMap()).toList()),
        isNot(contains('SECRET')),
      );
      await store.refreshMessages('new-char');
      expect(await probe.take(), isEmpty);
    },
  );

  test(
    'timeout then manual retry reuses request, not attempt, and suppresses busy taps',
    () async {
      final b = PhoneBackend(), store = b.store();
      addTearDown(store.dispose);
      await store.ready;
      b.respond = (r) => r.uri.path.endsWith('/dm/send')
          ? throw TimeoutException('secret')
          : null;
      expect(await store.write('dm', 'c', 'text'), isFalse);
      final first = await probe.take();
      expect(first.map((e) => e.object3), ['submit', 'uncertain']);
      final gate = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/dm/send') ? gate.future : null;
      final sending = store.write('dm', 'c', 'text', retry: true);
      await Future<void>.delayed(Duration.zero);
      expect(await store.write('dm', 'c', 'text', retry: true), isFalse);
      gate.complete(ok({}));
      expect(await sending, isTrue);
      final second = await probe.take();
      expect(second.map((e) => e.object3), ['submit', 'accepted']);
      expect(first.first.object4, isNot(second.first.object4));
      expect(
        extra(first.first)['client_request_id'],
        extra(second.first)['client_request_id'],
      );
      expect(extra(second.first)['is_retry'], isTrue);
    },
  );

  test(
    'comment rejection keeps full int64 target and reply IDs but no server text',
    () async {
      final b = PhoneBackend(), store = b.store();
      addTearDown(store.dispose);
      await store.ready;
      b.respond = (r) => r.method == 'POST'
          ? {'err_no': 4001, 'err_msg': 'SECRET rejection'}
          : null;
      expect(
        await store.write(
          'comment',
          '9223372036854775806',
          'SECRET',
          replyTo: 9223372036854775805,
        ),
        isFalse,
      );
      final events = await probe.take();
      expect(events.map((e) => e.object3), ['submit', 'rejected']);
      expect(events.last.object2, '9223372036854775806');
      expect(extra(events.last)['reply_to_comment_id'], '9223372036854775805');
      expect(extra(events.last)['error_code'], '4001');
      expect(events.last.extData, isNot(contains('SECRET')));
    },
  );

  test(
    'post starts before upload, upload failure is local, retry has one accepted result',
    () async {
      final b = PhoneBackend(), store = b.store();
      addTearDown(store.dispose);
      await store.ready;
      final draft = MiniPhonePostDraft(store)..setText('SECRET');
      addTearDown(draft.dispose);
      await draft.choose(
        () async => ProcessedUploadImage(
          bytes: Uint8List.fromList([1]),
          filename: 'secret.jpg',
          contentType: 'image/jpeg',
        ),
      );
      expect(
        await draft.submit((_) async => throw StateError('secret')),
        isFalse,
      );
      var events = await probe.take();
      expect(events.map((e) => e.object3), ['submit', 'local_failed']);
      expect(extra(events.last)['error_stage'], 'upload');
      expect(b.calls('post/create'), isEmpty);
      final gate = Completer<String>();
      final sending = draft.submit((_) => gate.future);
      events = await probe.take();
      expect(events.single.object3, 'submit');
      final attempt = events.single.object4;
      store.phoneVisible = false;
      store.analytics.endOpen(store.analytics.openId);
      gate.complete('https://cdn.example/secret.jpg');
      expect(await sending, isTrue);
      events = await probe.take();
      expect(events.single.object3, 'accepted');
      expect(events.single.object4, attempt);
      expect(extra(events.single)['has_image'], isTrue);
      expect(events.single.extData, isNot(contains('secret.jpg')));
    },
  );

  test(
    'post refresh failure cannot turn accepted submission into failure',
    () async {
      final b = PhoneBackend(), store = b.store();
      addTearDown(store.dispose);
      await store.ready;
      b.respond = (r) =>
          r.method == 'GET' ? throw TimeoutException('refresh') : null;
      expect(await store.write('post', 'new', 'text'), isTrue);
      expect((await probe.take()).map((e) => e.object3), [
        'submit',
        'accepted',
      ]);
    },
  );

  test('account switch drops late results and old photo callbacks', () async {
    final b = PhoneBackend(), store = b.store();
    addTearDown(store.dispose);
    await store.ready;
    final photo = store.analytics.photoViewer();
    final gate = Completer<Object?>();
    b.respond = (r) => r.uri.path.endsWith('/dm/send') ? gate.future : null;
    final sending = store.write('dm', 'c', 'text');
    await Future<void>.delayed(Duration.zero);
    expect((await probe.take()).single.object3, 'submit');
    b.uid = 'second';
    b.revision.value++;
    await store.ready;
    gate.complete(ok({}));
    await sending;
    photo(0);
    expect(await probe.take(), isEmpty);
  });

  test(
    'unchanged rejected post retries the same request and marks both events',
    () async {
      final b = PhoneBackend(), store = b.store();
      addTearDown(store.dispose);
      await store.ready;
      final draft = MiniPhonePostDraft(store)..setText('same');
      addTearDown(draft.dispose);
      b.respond = (r) => r.uri.path.endsWith('/post/create')
          ? {'err_no': 4001, 'err_msg': 'reject'}
          : null;
      await draft.submit((_) async => '');
      final first = await probe.take();
      b.respond = null;
      expect(await draft.submit((_) async => ''), isTrue);
      final retry = await probe.take();
      expect(retry.map((e) => extra(e)['is_retry']), [true, true]);
      expect(
        extra(first.last)['client_request_id'],
        extra(retry.first)['client_request_id'],
      );
    },
  );

  test(
    'player chat metadata and post like intent preserve operation sources',
    () async {
      final b = PhoneBackend(), store = b.store();
      addTearDown(store.dispose);
      await store.ready;
      b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
          ? ok(
              page([
                {...phoneSession(), 'peer_uid': 'another-user'},
              ]),
            )
          : null;
      await store.refreshSessions();
      expect(await store.write('dm', 'c', 'text'), isTrue);
      final sent = await probe.take();
      expect(extra(sent.first)['peer_type'], 'player');
      expect(extra(sent.first)['dm_session_id'], '9');
      await store.setLiked(8, true, source: 'posts');
      await store.setLiked(8, false, source: 'comments');
      final likes = await probe.take();
      expect(likes.map((e) => e.action).toSet(), {'mini_phone_post_like'});
      expect(likes.map((e) => e.object3), ['like', 'unlike']);
      expect(likes.map((e) => extra(e)['source']), ['posts', 'comments']);
    },
  );

  test('photo payload stays minimal; preview is silent', () async {
    final live = MiniPhoneAnalytics(
      worldId: 'w',
      enabled: () => true,
      generation: () => 1,
    );
    live.beginOpen();
    live.photoViewer()(0);
    final e = (await probe.take()).single;
    expect(e.action, 'mini_phone_photo_view');
    expect(e.object1, 'w');
    expect([e.object2, e.object3, e.object4, e.extData], ['', '', '', '']);
    MiniPhoneAnalytics(
      worldId: '',
      enabled: () => true,
      generation: () => 1,
    ).photoViewer()(0);
    expect(await probe.take(), isEmpty);
  });

  test(
    'wallpaper save result survives closing route while request is in flight',
    () async {
      final user = MemoryUserSessionStore();
      await user.saveUid('u');
      final gate = Completer<void>();
      final controller = MiniPhoneWallpaperController(
        worldId: 'w',
        sessionStore: user,
        load: () async => const MiniphoneInfo(
          backgroundImage: 'https://cdn.example/a.jpg',
          wallpapers: [],
        ),
        save: (_) => gate.future,
        upload: (_, _) async => 'https://cdn.example/b.jpg',
      );
      controller.analytics = MiniPhoneAnalytics(
        worldId: 'w',
        enabled: () => true,
        generation: () => 0,
      );
      controller.analytics!.beginOpen();
      await controller.refresh();
      controller.select('https://cdn.example/b.jpg');
      final saving = controller.apply();
      await Future<void>.delayed(Duration.zero);
      expect((await probe.take()).single.object3, 'submit');
      controller.dispose();
      gate.complete();
      await saving;
      expect((await probe.take()).single.object3, 'saved');
    },
  );
}
