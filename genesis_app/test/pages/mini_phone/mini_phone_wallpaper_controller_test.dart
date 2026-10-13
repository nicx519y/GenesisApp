import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/miniphone_info.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_wallpaper_controller.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

const oldUrl = 'https://cdn.example/old.png';
const newUrl = 'https://cdn.example/new.png';
const info = MiniphoneInfo(
  backgroundImage: oldUrl,
  wallpapers: [MiniphoneWallpaper(imageUrl: newUrl, title: 'New')],
);
final photo = MiniWallpaperPhoto(
  bytes: Uint8List.fromList([1, 2]),
  filename: 'wallpaper.webp',
  contentType: 'image/webp',
);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MemoryUserSessionStore session;
  late MiniPhoneWallpaperController controller;
  late Future<MiniphoneInfo> Function() load;
  late Future<void> Function(String) save;
  late MiniWallpaperUploader upload;
  late List<String> events;
  setUp(() async {
    session = MemoryUserSessionStore();
    await session.saveUid('u_a');
    events = [];
    load = () async => info;
    save = (url) async {
      events.add('save:$url');
    };
    upload = (picked, progress) async {
      expect(picked.contentType, 'image/webp');
      expect(picked.filename, 'wallpaper.webp');
      events.add('upload');
      progress(1, 2);
      return newUrl;
    };
    controller = MiniPhoneWallpaperController(
      worldId: 'w_1',
      sessionStore: session,
      load: () => load(),
      save: (url) => save(url),
      upload: (photo, progress) => upload(photo, progress),
    );
  });
  tearDown(() => controller.dispose());

  testWidgets(
    'submission advances slowly while pending and only success completes it',
    (tester) async {
      await controller.refresh();
      controller.select(newUrl);
      final pending = Completer<void>();
      save = (_) => pending.future;
      final result = controller.apply();
      await tester.pump();
      expect(controller.saveProgress, .91);
      await tester.pump(const Duration(seconds: 2));
      final first = controller.saveProgress;
      expect(first, greaterThan(.91));
      expect(first, lessThan(.95));
      await tester.pump(const Duration(seconds: 2));
      final second = controller.saveProgress;
      expect(second, greaterThan(first));
      expect(second - first, lessThan(first - .91));
      await tester.pump(const Duration(minutes: 2));
      expect(controller.saveProgress, lessThanOrEqualTo(.99));
      expect(controller.saving, isTrue);
      pending.complete();
      await tester.pump();
      expect(await result, isTrue);
      expect(controller.saveProgress, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.saveProgress, 1);
    },
  );

  testWidgets(
    'failed submission stops simulated progress and retry restarts it',
    (tester) async {
      await controller.refresh();
      controller.select(newUrl);
      final pending = Completer<void>();
      save = (_) => pending.future;
      final result = controller.apply();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      pending.completeError(StateError('offline'));
      await tester.pump();
      expect(await result, isFalse);
      final stopped = controller.saveProgress;
      await tester.pump(const Duration(seconds: 5));
      expect(controller.saveProgress, stopped);
      expect(stopped, lessThan(1));
      expect(controller.backgroundImage, oldUrl);
      final retry = Completer<void>();
      save = (_) => retry.future;
      final retryResult = controller.apply();
      await tester.pump();
      expect(controller.saveProgress, .91);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.saveProgress, greaterThan(.91));
      retry.complete();
      await tester.pump();
      expect(await retryResult, isTrue);
    },
  );

  testWidgets('account change cancels old submission progress', (tester) async {
    await controller.refresh();
    controller.select(newUrl);
    final pending = Completer<void>();
    save = (_) => pending.future;
    final result = controller.apply();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await session.saveUid('u_b');
    await controller.refresh();
    expect(controller.saveProgress, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(controller.saveProgress, 0);
    pending.complete();
    await tester.pump();
    expect(await result, isFalse);
    expect(controller.saveProgress, 0);
  });

  testWidgets('closing the controller cancels submission progress', (
    tester,
  ) async {
    final pending = Completer<void>();
    final local = MiniPhoneWallpaperController(
      worldId: 'w_1',
      sessionStore: session,
      load: () async => info,
      save: (_) => pending.future,
      upload: upload,
    );
    await local.refresh();
    local.select(newUrl);
    final result = local.apply();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final stopped = local.saveProgress;
    local.dispose();
    await tester.pump(const Duration(seconds: 5));
    expect(local.saveProgress, stopped);
    pending.complete();
    await tester.pump();
    expect(await result, isFalse);
  });

  test(
    'weighted progress waits for preparation, upload URL and server success',
    () async {
      await controller.refresh();
      final preparation = Completer<MiniWallpaperPhoto>();
      final uploaded = Completer<String>();
      final saved = Completer<void>();
      late void Function(double) prepareProgress;
      late void Function(int, int) sendProgress;
      final progress = <double>[];
      controller.addListener(() => progress.add(controller.saveProgress));
      controller.selectPhoto(
        MiniWallpaperPhoto(
          bytes: photo.bytes,
          filename: photo.filename,
          contentType: photo.contentType,
          prepareUpload: (callback) {
            prepareProgress = callback;
            return preparation.future;
          },
        ),
      );
      upload = (value, callback) {
        expect(value, same(photo));
        sendProgress = callback;
        return uploaded.future;
      };
      save = (_) => saved.future;
      final result = controller.apply();
      await flush();
      expect(controller.saveProgress, 0);
      expect(controller.preparing, isTrue);
      prepareProgress(.5);
      expect(controller.saveProgress, .1);
      prepareProgress(1);
      expect(controller.saveProgress, .2);
      preparation.complete(photo);
      await flush();
      expect(controller.saveProgress, .21);
      sendProgress(50, 100);
      expect(controller.saveProgress, closeTo(.555, .0001));
      sendProgress(25, 100);
      expect(controller.saveProgress, closeTo(.555, .0001));
      sendProgress(100, 100);
      expect(controller.saveProgress, closeTo(.9, .0001));
      expect(controller.saving, isTrue);
      uploaded.complete(newUrl);
      await flush();
      expect(controller.saveProgress, .91);
      sendProgress(100, 100);
      expect(controller.saveProgress, .91);
      saved.complete();
      expect(await result, isTrue);
      expect(controller.saveProgress, 1);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
    },
  );

  test(
    'retry reuses preparation and upload; failures never finish progress',
    () async {
      await controller.refresh();
      var preparations = 0;
      controller.selectPhoto(
        MiniWallpaperPhoto(
          bytes: photo.bytes,
          filename: photo.filename,
          contentType: photo.contentType,
          prepareUpload: (_) async {
            preparations++;
            return photo;
          },
        ),
      );
      save = (_) async => throw StateError('offline');
      expect(await controller.apply(), isFalse);
      expect(controller.saveProgress, .91);
      save = (_) async {};
      expect(await controller.apply(), isTrue);
      expect(preparations, 1);
      expect(events, ['upload']);
      expect(controller.saveProgress, 1);
    },
  );

  test('preparation failure preserves the draft without uploading', () async {
    await controller.refresh();
    final selection = MiniWallpaperPhoto(
      bytes: photo.bytes,
      filename: photo.filename,
      contentType: photo.contentType,
      prepareUpload: (_) async => throw StateError('decode failed'),
    );
    controller.selectPhoto(selection);
    expect(await controller.apply(), isFalse);
    expect(events, isEmpty);
    expect(controller.draftPhoto, same(selection));
    expect(controller.backgroundImage, oldUrl);
    expect(controller.saveProgress, lessThan(1));
    expect(controller.feedback, contains('Unable to prepare'));
  });

  test(
    'selection is a draft until server success; concurrent apply is ignored',
    () async {
      await controller.refresh();
      controller.select(newUrl);
      expect(controller.backgroundImage, oldUrl);
      final pending = Completer<void>();
      save = (url) {
        events.add(url);
        return pending.future;
      };
      final first = controller.apply();
      final second = controller.apply();
      await flush();
      expect(controller.saving, isTrue);
      controller.select('https://cdn.example/ignored.png');
      expect(controller.draftImage, newUrl);
      pending.complete();
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(events, [newUrl]);
      expect(controller.backgroundImage, newUrl);
    },
  );

  test('failed save keeps previous background and selection', () async {
    await controller.refresh();
    controller.select(newUrl);
    save = (_) async => throw StateError('failed');
    expect(await controller.apply(), isFalse);
    expect(controller.backgroundImage, oldUrl);
    expect(controller.draftImage, newUrl);
    expect(controller.feedback, contains('Unable to save'));
    expect(controller.saving, isFalse);
  });

  test('upload precedes save and is reused when only saving failed', () async {
    await controller.refresh();
    controller.selectPhoto(photo);
    var failures = 1;
    save = (url) async {
      events.add('save:$url');
      if (failures-- > 0) throw StateError('failed');
    };
    expect(await controller.apply(), isFalse);
    expect(controller.backgroundImage, oldUrl);
    expect(controller.draftPhoto, same(photo));
    expect(await controller.apply(), isTrue);
    expect(events, ['upload', 'save:$newUrl', 'save:$newUrl']);
    expect(controller.backgroundImage, newUrl);
    expect(controller.draftPhoto, isNull);
  });

  test('failed or empty upload never calls background setter', () async {
    await controller.refresh();
    controller.selectPhoto(photo);
    upload = (_, _) async => throw StateError('upload failed');
    expect(await controller.apply(), isFalse);
    expect(controller.feedback, contains('Unable to upload'));
    upload = (_, _) async => '';
    expect(await controller.apply(), isFalse);
    expect(events, isEmpty);
    expect(controller.backgroundImage, oldUrl);
    expect(controller.draftPhoto, same(photo));
  });

  test('changing draft discards previously uploaded URL', () async {
    await controller.refresh();
    controller.selectPhoto(photo);
    save = (_) async => throw StateError('save failed');
    await controller.apply();
    controller.select(newUrl);
    controller.selectPhoto(photo);
    await controller.apply();
    expect(events, ['upload', 'upload']);
  });

  test('late GET cannot undo a successful write', () async {
    await controller.refresh();
    final pending = Completer<MiniphoneInfo>();
    load = () => pending.future;
    final read = controller.refresh();
    await flush();
    controller.select(newUrl);
    expect(await controller.apply(), isTrue);
    pending.complete(info);
    await read;
    expect(controller.backgroundImage, newUrl);
    expect(controller.draftImage, newUrl);
    expect(controller.loading, isFalse);
  });

  test(
    'opening Settings during initial load deduplicates and fills preview',
    () async {
      final pending = Completer<MiniphoneInfo>();
      var calls = 0;
      load = () {
        calls++;
        return pending.future;
      };
      final first = controller.refresh();
      await flush();
      final settings = controller.refresh(resetDraft: true);
      await flush();
      pending.complete(info);
      await Future.wait([first, settings]);
      expect(calls, 1);
      expect(controller.backgroundImage, oldUrl);
      expect(controller.draftImage, oldUrl);
    },
  );

  test(
    'GET updates current background without overwriting a newer draft',
    () async {
      await controller.refresh();
      final pending = Completer<MiniphoneInfo>();
      load = () => pending.future;
      final read = controller.refresh();
      await flush();
      controller.selectPhoto(photo);
      pending.complete(info);
      await read;
      expect(controller.draftPhoto, same(photo));
    },
  );

  test(
    'read failure is retryable and retains previous successful data',
    () async {
      await controller.refresh();
      load = () async => throw StateError('offline');
      await controller.refresh();
      expect(controller.backgroundImage, oldUrl);
      expect(controller.loadError, isNotNull);
      load = () async =>
          const MiniphoneInfo(backgroundImage: '', wallpapers: []);
      await controller.refresh();
      expect(controller.backgroundImage, isEmpty);
      expect(controller.wallpapers, isEmpty);
      expect(controller.loadError, isNull);
    },
  );

  test('guest may read but cannot write', () async {
    await session.clearUid();
    await controller.refresh();
    controller.select(newUrl);
    expect(await controller.apply(), isFalse);
    expect(events, isEmpty);
    expect(controller.loaded, isTrue);
  });

  test(
    'account change clears draft and prevents posting an old upload',
    () async {
      await controller.refresh();
      controller.selectPhoto(photo);
      final pending = Completer<String>();
      upload = (_, _) => pending.future;
      final apply = controller.apply();
      await flush();
      load = () async =>
          const MiniphoneInfo(backgroundImage: '', wallpapers: []);
      await session.saveUid('u_b');
      await session.saveUserInfo({'uid': 'u_b'});
      await flush();
      pending.complete(newUrl);
      expect(await apply, isFalse);
      expect(controller.backgroundImage, isEmpty);
      expect(controller.draftPhoto, isNull);
      expect(events, isEmpty);
    },
  );

  test('old account GET cannot replace new account background', () async {
    final pending = Completer<MiniphoneInfo>();
    load = () => pending.future;
    final oldRead = controller.refresh();
    await flush();
    await session.saveUid('u_b');
    load = () async =>
        const MiniphoneInfo(backgroundImage: newUrl, wallpapers: []);
    await controller.refresh();
    pending.complete(info);
    await oldRead;
    expect(controller.backgroundImage, newUrl);
  });

  test('leaving the page during upload prevents subsequent save', () async {
    final scoped = MiniPhoneWallpaperController(
      worldId: 'w_1',
      sessionStore: session,
      load: () async => info,
      save: save,
      upload: (_, _) async {
        await flush();
        return newUrl;
      },
    );
    await scoped.refresh();
    scoped.selectPhoto(photo);
    final apply = scoped.apply();
    // apply first checks identity; let the upload begin before disposing.
    await Future<void>.microtask(() {});
    scoped.dispose();
    expect(await apply, isFalse);
    expect(events, isEmpty);
  });

  test('no World performs no network operations', () async {
    final preview = MiniPhoneWallpaperController(
      worldId: ' ',
      sessionStore: session,
      load: () async {
        fail('Unexpected GET');
      },
      save: save,
      upload: upload,
    );
    await preview.refresh();
    expect(await preview.apply(), isFalse);
    expect(events, isEmpty);
    preview.dispose();
  });
}
