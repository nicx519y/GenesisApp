import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_api.dart';
import 'package:genesis_flutter_android/network/models/photo_task.dart';
import 'package:genesis_flutter_android/network/photo_generation_monitor.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_write.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_tasks.dart';
import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_collect_probe.dart';

PhoneCameraRequest request(String id, {String prompt = ''}) =>
    PhoneCameraRequest(
      requestId: id,
      worldId: 'w',
      characterIds: ['c'],
      aspectRatio: '2:3',
      style: 'selfie',
      prompt: prompt,
    );
PhotoTask photo(String id, String task, PhotoTaskStatus status) => PhotoTask(
  taskId: task,
  requestId: id,
  status: status,
  assetId: status == PhotoTaskStatus.succeeded ? 9007199254740993 : null,
  imageUrl: status == PhotoTaskStatus.succeeded
      ? 'https://cdn.example/photo.png'
      : '',
  description: 'Photo',
  failureCode: status == PhotoTaskStatus.failed ? 'generation_failed' : '',
  failureMessage: status == PhotoTaskStatus.failed ? 'Failed on server' : '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PhoneBackend backend;
  late MiniPhoneRequests gate;
  late Map<String, PhoneWrite> journal;
  late MiniPhoneCameraTasks tasks;
  PhotoGenerationMonitor? monitor;
  late List<List<Map<String, dynamic>>> saved;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = PhoneBackend();
    gate = MiniPhoneRequests(() {})..uid = 'u';
    journal = {};
    saved = [];
    tasks = MiniPhoneCameraTasks(
      api: backend.api,
      worldId: 'w',
      requests: gate,
      pending: journal,
      saveJournal: () async {
        saved.add(
          journal.values
              .map(
                (w) => Map<String, dynamic>.from(
                  jsonDecode(jsonEncode(w.toJson())) as Map,
                ),
              )
              .toList(),
        );
        return true;
      },
      onChanged: () {},
      onSuccess: () {},
      generationMonitor: () => monitor,
    );
  });
  tearDown(() {
    tasks.dispose();
    monitor?.dispose();
    monitor = null;
    backend.revision.dispose();
  });

  test(
    'shared phone journal survives disposal and isolates account and environment',
    () async {
      backend.respond = (r) => r.uri.path.endsWith('/photo/create')
          ? throw ApiException(
              message: 'timeout',
              kind: ApiExceptionKind.timeout,
            )
          : null;
      final first = backend.store();
      await first.ready;
      await expectLater(
        first.cameraTasks.submit(request('durable')),
        throwsA(isA<ApiException>()),
      );
      await first.writesSaved;
      first.dispose();
      final restored = backend.store();
      await restored.ready;
      expect(restored.cameraTasks.records.single.id, 'durable');
      expect(
        restored.cameraTasks.unresolved(request('another'))!.id,
        'durable',
      );
      expect(backend.calls('photo/create'), hasLength(1));
      restored.dispose();
      final anotherEnvironment = backend.store(namespace: 'other-env');
      await anotherEnvironment.ready;
      expect(anotherEnvironment.cameraTasks.records, isEmpty);
      anotherEnvironment.dispose();
      backend.uid = 'other';
      final anotherAccount = backend.store();
      await anotherAccount.ready;
      expect(anotherAccount.cameraTasks.records, isEmpty);
      anotherAccount.dispose();
    },
  );

  test(
    'receipt persists before dispatch; parallel accepted tasks and terminal wins',
    () async {
      backend.respond = (r) {
        expect(saved, isNotEmpty);
        final id = backend.body(r)['client_request_id'] as String;
        return ok({
          'source': 'camera',
          'world_id': 'w',
          'photo': photo(id, 't$id', PhotoTaskStatus.generating).toJson(),
        });
      };
      await tasks.submit(request('a'));
      await tasks.submit(request('b', prompt: 'Second'));
      expect(tasks.pendingCount, 2);
      expect(tasks.submitting, false);
      tasks.accept(photo('a', 'ta', PhotoTaskStatus.failed));
      tasks.accept(photo('', 'ta', PhotoTaskStatus.generating));
      expect(tasks.records, hasLength(2));
      expect(journal['camera:a']!.cameraPhoto!.status, PhotoTaskStatus.failed);
      tasks.beginAlbumVisit();
      expect(tasks.visibleRecords, hasLength(2));
      tasks.endAlbumVisit();
      tasks.beginAlbumVisit();
      expect(tasks.visibleRecords.map((w) => w.id), ['b']);
    },
  );

  test(
    'terminal push before HTTP preserves one job and its original body',
    () async {
      final reply = Completer<Object?>();
      backend.respond = (_) => reply.future;
      final submission = tasks.submit(request('a'));
      await Future<void>.delayed(Duration.zero);
      tasks.accept(photo('a', 'ta', PhotoTaskStatus.succeeded));
      reply.complete(
        ok({
          'source': 'camera',
          'world_id': 'w',
          'photo': photo('a', 'ta', PhotoTaskStatus.generating).toJson(),
        }),
      );
      await submission;
      expect(tasks.records, hasLength(1));
      expect(tasks.latestSuccess!.assetId, 9007199254740993);
      expect(
        jsonDecode(tasks.records.single.content)['client_request_id'],
        'a',
      );
    },
  );

  test(
    'empty request key result before receipt associates without duplicate jobs',
    () async {
      final reply = Completer<Object?>();
      backend.respond = (_) => reply.future;
      final submission = tasks.submit(request('a'));
      await Future<void>.delayed(Duration.zero);
      tasks.accept(photo('', 'ta', PhotoTaskStatus.succeeded));
      reply.complete(
        ok({
          'source': 'camera',
          'world_id': 'w',
          'photo': photo('a', 'ta', PhotoTaskStatus.generating).toJson(),
        }),
      );
      await submission;
      expect(tasks.records, hasLength(1));
      expect(tasks.records.single.id, 'a');
      expect(
        tasks.records.single.cameraPhoto!.status,
        PhotoTaskStatus.succeeded,
      );
      expect(tasks.records.single.content, isNotEmpty);
    },
  );

  test(
    'timeout retries immutable original request, changed draft creates another',
    () async {
      backend.respond = (_) => throw ApiException(
        message: 'technical diagnostic',
        kind: ApiExceptionKind.timeout,
        code: 1001,
      );
      await expectLater(
        tasks.submit(request('a')),
        throwsA(isA<ApiException>()),
      );
      expect(tasks.records.single.cameraPhoto, isNull);
      expect(tasks.records.single.rejected, false);
      final restored = PhoneWrite.fromJson(saved.last.single);
      journal
        ..clear()
        ..[restored.key] = restored;
      await expectLater(
        tasks.submit(request('new-local-id')),
        throwsA(isA<ApiException>()),
      );
      expect(backend.body(backend.requests.last)['client_request_id'], 'a');
      await expectLater(
        tasks.submit(request('b', prompt: 'changed')),
        throwsA(isA<ApiException>()),
      );
      expect(backend.body(backend.requests.last)['client_request_id'], 'b');
      expect(tasks.records, hasLength(2));
    },
  );

  for (final code in [1001, 10001, 2061, 2062, 3001, 21001, 99999]) {
    test('business $code never creates a generation failure card', () async {
      final collect = MiniPhoneCollectProbe();
      addTearDown(collect.dispose);
      monitor = PhotoGenerationMonitor('w');
      final attempt = tasks.recordCaptureClick();
      backend.respond = (_) => {
        'err_no': code,
        'err_msg': 'User reason',
        'data': {},
      };
      await expectLater(
        tasks.submit(request('a'), attemptId: attempt),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
      );
      expect(tasks.records, isEmpty);
      expect(tasks.submitting, false);
      final events = await collect.take();
      final balance = code == 3001 || code == 21001;
      expect(events.map((e) => e.object3), ['click', if (balance) 'rejected']);
      if (balance) {
        expect(events.last.object4, attempt);
        expect(jsonDecode(events.last.extData), {
          'client_request_id': 'a',
          'failure_code': 'insufficient_balance',
        });
      }
      final restored = PhoneWrite.fromJson(saved.last.single);
      journal
        ..clear()
        ..[restored.key] = restored;
      if (code == 2062) {
        expect(tasks.hasConflict(request('b')), true);
        await expectLater(
          tasks.submit(request('b')),
          throwsA(isA<ApiException>()),
        );
        expect(backend.requests, hasLength(1));
      }
    });
  }

  test(
    'late response from old account cannot update or unlock new account',
    () async {
      final reply = Completer<Object?>();
      backend.respond = (_) => reply.future;
      final submission = tasks.submit(request('a'));
      await Future<void>.delayed(Duration.zero);
      gate.reset();
      gate.uid = 'other';
      journal.clear();
      tasks.reset();
      reply.complete(
        ok({
          'source': 'camera',
          'world_id': 'w',
          'photo': photo('a', 'ta', PhotoTaskStatus.succeeded).toJson(),
        }),
      );
      await submission;
      expect(tasks.records, isEmpty);
      expect(tasks.latestSuccess, isNull);
    },
  );

  test(
    'restored failures hidden; new live failures retained until next visit',
    () {
      tasks.accept(photo('old', 'old-task', PhotoTaskStatus.failed));
      tasks.restored();
      tasks.beginAlbumVisit();
      expect(tasks.visibleRecords, isEmpty);
      tasks.accept(photo('new', 'new-task', PhotoTaskStatus.generating));
      tasks.accept(photo('new', 'new-task', PhotoTaskStatus.failed));
      tasks.accept(photo('new', 'new-task', PhotoTaskStatus.failed));
      expect(tasks.visibleRecords, hasLength(1));
      tasks.endAlbumVisit();
      tasks.beginAlbumVisit();
      expect(tasks.visibleRecords, isEmpty);
      expect(tasks.records, hasLength(2));
    },
  );

  test(
    'Inbox restores known task using exact asset ID without create or popup',
    () async {
      final collect = MiniPhoneCollectProbe();
      addTearDown(collect.dispose);
      monitor = PhotoGenerationMonitor('w');
      final attempt = tasks.recordCaptureClick();
      await tasks.submit(request('a'), attemptId: attempt);
      final create = backend.requests.single;
      await tasks.reconcileInbox(
        (pn) async => {
          'total': 1,
          'list': [
            {
              'notice_type': 'photo_succeeded',
              'biz_id': 'w',
              'obj_id': 'task-a',
              'photo_target': {
                'source': 'camera',
                'asset_id': '9007199254740993',
              },
            },
          ],
        },
        [
          PhoneAlbumAsset.fromJson({
            'asset_id': 9007199254740993,
            'image_url': 'https://cdn.example/photo.png',
            'desc': 'Album description',
          }),
        ],
      );
      expect(tasks.latestSuccess!.description, 'Album description');
      expect(backend.requests, [create]);
      final events = await collect.take();
      expect(events.map((e) => e.object3), ['click', 'accepted', 'succeeded']);
      expect(events.map((e) => e.object4), [attempt, attempt, attempt]);
      expect(jsonDecode(events.last.extData), {
        'client_request_id': 'a',
        'task_id': 'task-a',
      });
    },
  );

  test(
    'formal album acknowledgement persists even after cached pages leave',
    () {
      tasks.accept(photo('a', 'ta', PhotoTaskStatus.succeeded));
      tasks.confirmAlbum([
        PhoneAlbumAsset.fromJson({
          'asset_id': 9007199254740993,
          'image_url': 'https://cdn.example/photo.png',
        }),
      ]);
      tasks.confirmAlbum(const []);
      final restored = PhoneWrite.fromJson(tasks.records.single.toJson());
      expect(restored.cameraInAlbum, isTrue);
      expect(restored.cameraPhoto!.status, PhotoTaskStatus.succeeded);
    },
  );

  test('journal save failure prevents network submission', () async {
    tasks.dispose();
    tasks = MiniPhoneCameraTasks(
      api: backend.api,
      worldId: 'w',
      requests: gate,
      pending: journal,
      saveJournal: () async => false,
      onChanged: () {},
      onSuccess: () {},
    );
    await expectLater(tasks.submit(request('a')), throwsStateError);
    expect(backend.requests, isEmpty);
    expect(tasks.records.single.id, 'a');
  });
}
