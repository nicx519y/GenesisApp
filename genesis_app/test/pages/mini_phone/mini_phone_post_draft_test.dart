import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_draft.dart';
import 'package:genesis_flutter_android/utils/image_upload_processing.dart';

import '../../support/mini_phone_chat_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final photo = ProcessedUploadImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    filename: 'prepared.jpg',
    contentType: 'image/jpeg',
  );

  test(
    'selection stays local; submit locks draft through upload and write',
    () async {
      final backend = PhoneBackend();
      final store = backend.store();
      await store.ready;
      final draft = MiniPhonePostDraft(store)..setText('Original');
      addTearDown(() {
        draft.dispose();
        store.dispose();
      });
      final prepared = Completer<ProcessedUploadImage?>();
      final selecting = draft.choose(() => prepared.future);
      expect(draft.preparing, isTrue);
      expect(draft.submitting, isFalse);
      expect(draft.canSubmit, isFalse);
      prepared.complete(photo);
      await selecting;
      expect(backend.calls('post/create'), isEmpty);
      final uploaded = Completer<String>();
      final writing = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/post/create') ? writing.future : null;
      var uploads = 0;
      final sending = draft.submit((image) {
        uploads++;
        return uploaded.future;
      });
      expect(draft.submitting, isTrue);
      expect(draft.locked, isTrue);
      draft.setText('Changed');
      draft.removePhoto();
      await draft.choose(() async => throw StateError('Picker must not open'));
      expect(
        await draft.submit((_) async => throw StateError('Duplicate')),
        isFalse,
      );
      expect(draft.text, 'Original');
      expect(draft.photo, same(photo));
      uploaded.complete('https://cdn.example/post.jpg?full=1');
      await Future<void>.delayed(Duration.zero);
      await store.writesSaved;
      expect(draft.submitting, isTrue);
      writing.complete(ok({}));
      expect(await sending, isTrue);
      expect(uploads, 1);
      final body = backend.body(backend.calls('post/create').single);
      expect(body['content'], 'Original');
      expect(body['image'], 'https://cdn.example/post.jpg?full=1');
      expect(draft.submitting, isFalse);
      expect(draft.photo, isNull);
      expect(draft.text, isEmpty);
    },
  );

  test('upload failure retains editable draft and can retry', () async {
    final backend = PhoneBackend();
    final store = backend.store();
    await store.ready;
    final draft = MiniPhonePostDraft(store)..setText('Draft');
    addTearDown(() {
      draft.dispose();
      store.dispose();
    });
    await draft.choose(() async => photo);
    expect(
      await draft.submit((_) async => throw StateError('Offline')),
      isFalse,
    );
    expect(draft.locked, isFalse);
    expect(draft.photo, same(photo));
    expect(draft.text, 'Draft');
    expect(backend.calls('post/create'), isEmpty);
    expect(
      await draft.submit((_) async => 'https://cdn.example/retry.jpg'),
      isTrue,
    );
  });

  test(
    'uncertain post preserves original URL and request without reupload',
    () async {
      final backend = PhoneBackend();
      final store = backend.store();
      await store.ready;
      final draft = MiniPhonePostDraft(store)..setText('Original');
      addTearDown(() {
        draft.dispose();
        store.dispose();
      });
      await draft.choose(() async => photo);
      backend.respond = (r) {
        if (r.uri.path.endsWith('/post/create')) {
          throw TimeoutException('Unknown');
        }
        return null;
      };
      expect(
        await draft.submit((_) async => 'https://cdn.example/original.jpg?q=1'),
        isFalse,
      );
      final original = backend.body(backend.calls('post/create').single);
      expect(draft.locked, isTrue);
      draft.setText('Changed');
      backend.respond = null;
      expect(
        await draft.submit((_) async => throw StateError('Must reuse URL')),
        isTrue,
      );
      expect(backend.body(backend.calls('post/create').last), original);
    },
  );

  test(
    'changing accounts during upload never publishes into the new account',
    () async {
      final backend = PhoneBackend();
      final store = backend.store();
      await store.ready;
      final draft = MiniPhonePostDraft(store)..setText('Old account');
      addTearDown(() {
        draft.dispose();
        store.dispose();
      });
      await draft.choose(() async => photo);
      final upload = Completer<String>();
      final sending = draft.submit((_) => upload.future);
      backend.uid = 'new-user';
      backend.revision.value++;
      await store.ready;
      upload.complete('https://cdn.example/old.jpg');
      expect(await sending, isFalse);
      expect(backend.calls('post/create'), isEmpty);
      expect(draft.text, isEmpty);
      expect(draft.photo, isNull);
      expect(draft.submitting, isFalse);
    },
  );

  test(
    'rejected post reuses uploaded image until the image is changed',
    () async {
      final backend = PhoneBackend();
      final store = backend.store();
      await store.ready;
      final draft = MiniPhonePostDraft(store)..setText('Original');
      addTearDown(() {
        draft.dispose();
        store.dispose();
      });
      await draft.choose(() async => photo);
      backend.respond = (r) => r.uri.path.endsWith('/post/create')
          ? {'err_no': 400, 'err_msg': 'Rejected', 'data': {}}
          : null;
      expect(
        await draft.submit((_) async => 'https://cdn.example/photo.jpg'),
        isFalse,
      );
      expect(draft.locked, isFalse);
      draft.setText('Edited');
      backend.respond = null;
      expect(
        await draft.submit((_) async => throw StateError('Must reuse upload')),
        isTrue,
      );
      expect(
        backend.body(backend.calls('post/create').last)['content'],
        'Edited',
      );
    },
  );
}
