import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/miniphone_info.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/wallpaper/mini_phone_wallpaper_cache.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/wallpaper/mini_phone_wallpaper_controller.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

const oldUrl = 'https://cdn.example/old.png';
const newUrl = 'https://cdn.example/new.png';
MiniphoneInfo info(String url) => MiniphoneInfo(
  backgroundImage: url,
  wallpapers: const [MiniphoneWallpaper(imageUrl: newUrl, title: 'New')],
);
final oldBytes = Uint8List.fromList([1]);
final newBytes = Uint8List.fromList([2]);

class _Cache implements MiniPhoneWallpaperCache {
  final snapshots = <String, CachedMiniPhoneWallpaper>{};
  final downloads = <String>[];
  final events = <String>[];
  final images = <String, Uint8List>{};
  Future<Uint8List> Function(String) download = (_) async => newBytes;
  @override
  Future<CachedMiniPhoneWallpaper?> read(String owner, String worldId) async =>
      snapshots[owner];
  @override
  Future<Uint8List> loadImage(String url) {
    downloads.add(url);
    return download(url);
  }

  @override
  Future<void> write(String owner, String worldId, MiniphoneInfo value) async {
    events.add('metadata:${value.backgroundImage}');
    snapshots[owner] = CachedMiniPhoneWallpaper(
      value,
      images[value.backgroundImage] ??
          (value.backgroundImage == oldUrl ? oldBytes : newBytes),
    );
  }

  @override
  Future<void> writeImage(
    String url,
    Uint8List bytes,
    String contentType,
  ) async {
    events.add('image:$url:$contentType');
    images[url] = bytes;
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MemoryUserSessionStore session;
  late _Cache cache;
  setUp(() async {
    session = MemoryUserSessionStore();
    await session.saveUid('u_a');
    cache = _Cache()
      ..snapshots['u_a'] = CachedMiniPhoneWallpaper(info(oldUrl), oldBytes);
  });
  MiniPhoneWallpaperController make(Future<MiniphoneInfo> Function() load) {
    final controller = MiniPhoneWallpaperController(
      worldId: 'w_1',
      sessionStore: session,
      cache: cache,
      load: load,
      save: (_) async {},
      upload: (_, _) async => newUrl,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test(
    'Apply waits for the original image after the setter succeeds',
    () async {
      final saved = Completer<void>();
      final image = Completer<Uint8List>();
      cache.download = (_) => image.future;
      final controller = MiniPhoneWallpaperController(
        worldId: 'w_1',
        sessionStore: session,
        cache: cache,
        load: () async => info(oldUrl),
        save: (_) => saved.future,
        upload: (_, _) async => newUrl,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      controller.select(newUrl);
      var finished = false;
      final pending = controller.apply().then((result) {
        finished = true;
        return result;
      });
      await flush();
      expect(cache.downloads, isEmpty);
      saved.complete();
      await flush();
      expect(cache.downloads, [newUrl]);
      expect(controller.backgroundImage, newUrl);
      expect(controller.displayBytes, same(oldBytes));
      expect(controller.saving, isTrue);
      expect(controller.saveProgress, lessThan(1));
      expect(finished, isFalse);
      expect(await controller.apply(), isFalse);
      controller.select(oldUrl);
      expect(controller.draftImage, newUrl);
      image.complete(newBytes);
      expect(await pending, isTrue);
      expect(controller.saving, isFalse);
      expect(controller.saveProgress, 1);
      expect(controller.displayBackgroundImage, newUrl);
      expect(controller.displayBytes, same(newBytes));
      expect(cache.snapshots['u_a']!.info.backgroundImage, newUrl);
    },
  );

  test('Apply releases loading after a failed original download', () async {
    final image = Completer<Uint8List>();
    cache.download = (_) => image.future;
    final controller = make(() async => info(oldUrl));
    await controller.refresh();
    controller.select(newUrl);
    final pending = controller.apply();
    await flush();
    expect(controller.saving, isTrue);
    image.completeError(StateError('offline'));
    // The server save remains successful; retain the last usable desktop.
    expect(await pending, isTrue);
    expect(controller.saving, isFalse);
    expect(controller.backgroundImage, newUrl);
    expect(controller.displayBackgroundImage, oldUrl);
    expect(controller.displayBytes, same(oldBytes));
  });

  test('Apply discards an original download after an account switch', () async {
    final image = Completer<Uint8List>();
    cache.download = (_) => image.future;
    var server = info(oldUrl);
    final controller = make(() async => server);
    await controller.refresh();
    controller.select(newUrl);
    final pending = controller.apply();
    await flush();
    expect(controller.saving, isTrue);
    await session.saveUid('u_b');
    server = info('');
    await controller.refresh();
    image.complete(newBytes);
    expect(await pending, isFalse);
    expect(controller.displayBytes, isNull);
    expect(controller.saving, isFalse);
    expect(controller.feedback, isNull);
    expect(cache.snapshots['u_a']!.info.backgroundImage, oldUrl);
    expect(cache.snapshots['u_b']!.info.backgroundImage, isEmpty);
  });

  test(
    'closing during Apply prevents a late original from being stored',
    () async {
      final image = Completer<Uint8List>();
      cache.download = (_) => image.future;
      final controller = MiniPhoneWallpaperController(
        worldId: 'w_1',
        sessionStore: session,
        cache: cache,
        load: () async => info(oldUrl),
        save: (_) async {},
        upload: (_, _) async => newUrl,
      );
      await controller.refresh();
      controller.select(newUrl);
      final pending = controller.apply();
      await flush();
      expect(controller.saving, isTrue);
      controller.dispose();
      image.complete(newBytes);
      expect(await pending, isFalse);
      expect(controller.feedback, isNull);
      expect(cache.snapshots['u_a']!.info.backgroundImage, oldUrl);
    },
  );

  test(
    'local photo renders from memory and commits bytes only after upload and save',
    () async {
      final uploadDone = Completer<String>();
      final saveDone = Completer<void>();
      final controller = MiniPhoneWallpaperController(
        worldId: 'w_1',
        sessionStore: session,
        cache: cache,
        load: () async => info(oldUrl),
        upload: (_, _) {
          cache.events.add('upload');
          return uploadDone.future;
        },
        save: (url) {
          cache.events.add('save:$url');
          return saveDone.future;
        },
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      cache.events.clear();
      final photo = MiniWallpaperPhoto(
        bytes: newBytes,
        filename: 'wallpaper.webp',
        contentType: 'image/webp',
      );
      controller.selectPhoto(photo);
      expect(controller.draftPhoto!.bytes, same(newBytes));
      expect(cache.events, isEmpty);
      final apply = controller.apply();
      await flush();
      expect(controller.saving, isTrue);
      expect(cache.events, ['upload']);
      uploadDone.complete(newUrl);
      await flush();
      expect(controller.saving, isTrue);
      expect(cache.events, ['upload', 'save:$newUrl']);
      expect(controller.displayBytes, same(oldBytes));
      saveDone.complete();
      expect(await apply, isTrue);
      expect(controller.saving, isFalse);
      expect(controller.displayBytes, same(newBytes));
      expect(cache.events, [
        'upload',
        'save:$newUrl',
        'image:$newUrl:image/webp',
        'metadata:$newUrl',
      ]);
      expect(cache.downloads, isEmpty);
      expect(cache.snapshots['u_a']!.bytes, same(newBytes));
    },
  );

  test(
    'failed save never caches the local image; retry reuses uploaded URL',
    () async {
      var reject = true;
      var uploads = 0;
      final controller = MiniPhoneWallpaperController(
        worldId: 'w_1',
        sessionStore: session,
        cache: cache,
        load: () async => info(oldUrl),
        upload: (_, _) async {
          uploads++;
          return newUrl;
        },
        save: (_) async {
          if (reject) throw StateError('save failed');
        },
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      cache.events.clear();
      controller.selectPhoto(
        MiniWallpaperPhoto(
          bytes: newBytes,
          filename: 'wallpaper.png',
          contentType: 'image/png',
        ),
      );
      expect(await controller.apply(), isFalse);
      expect(cache.events, isEmpty);
      expect(controller.displayBytes, same(oldBytes));
      expect(controller.draftPhoto!.bytes, same(newBytes));
      reject = false;
      expect(await controller.apply(), isTrue);
      expect(uploads, 1);
      expect(cache.events, ['image:$newUrl:image/png', 'metadata:$newUrl']);
      expect(cache.downloads, isEmpty);
    },
  );

  test(
    'entry always requests while cached background and catalogue render before response',
    () async {
      final network = Completer<MiniphoneInfo>();
      var requests = 0;
      final controller = make(() {
        requests++;
        return network.future;
      });
      final pending = controller.refresh();
      await flush();
      expect(requests, 1);
      expect(controller.backgroundImage, oldUrl);
      expect(controller.displayBytes, same(oldBytes));
      expect(controller.wallpapers.single.title, 'New');
      expect(controller.cacheReady, isTrue);
      network.complete(info(oldUrl));
      await pending;
      expect(cache.downloads, isEmpty);
      expect(controller.displayBytes, same(oldBytes));
      await controller.beginEditing();
      expect(requests, 1);
    },
  );

  test(
    'new URL keeps cached image until download completes then persists it',
    () async {
      final image = Completer<Uint8List>();
      cache.download = (_) => image.future;
      final controller = make(() async => info(newUrl));
      final pending = controller.refresh();
      await flush();
      expect(controller.backgroundImage, newUrl);
      expect(controller.displayBackgroundImage, oldUrl);
      expect(controller.displayBytes, same(oldBytes));
      image.complete(newBytes);
      await pending;
      expect(controller.displayBackgroundImage, newUrl);
      expect(controller.displayBytes, same(newBytes));
      expect(cache.snapshots['u_a']!.info.backgroundImage, newUrl);
    },
  );

  test('API failure and broken replacement retain last usable cache', () async {
    var failRequest = true;
    cache.download = (_) async => throw StateError('broken image');
    final controller = make(() async {
      if (failRequest) throw StateError('offline');
      return info(newUrl);
    });
    await controller.refresh();
    expect(controller.loadError, isNotNull);
    expect(controller.displayBytes, same(oldBytes));
    failRequest = false;
    await controller.refresh();
    expect(controller.displayBytes, same(oldBytes));
    expect(cache.snapshots['u_a']!.info.backgroundImage, oldUrl);
  });

  test(
    'reopening restores persisted background but still performs a fresh GET',
    () async {
      final first = make(() async => info(newUrl));
      await first.refresh();
      final nextRequest = Completer<MiniphoneInfo>();
      var requests = 0;
      final reopened = make(() {
        requests++;
        return nextRequest.future;
      });
      final pending = reopened.refresh();
      await flush();
      expect(reopened.displayBytes, same(newBytes));
      expect(reopened.displayBackgroundImage, newUrl);
      expect(requests, 1);
      nextRequest.complete(info(newUrl));
      await pending;
      expect(cache.downloads, [newUrl]);
    },
  );

  test(
    'late image download cannot overwrite a more recent saved wallpaper',
    () async {
      final staleImage = Completer<Uint8List>();
      cache.download = (_) => staleImage.future;
      final controller = make(() async => info(newUrl));
      final pending = controller.refresh();
      await flush();
      controller.select('');
      expect(await controller.apply(), isTrue);
      await flush();
      staleImage.complete(newBytes);
      await pending;
      expect(controller.displayBackgroundImage, isEmpty);
      expect(controller.displayBytes, isNull);
      expect(cache.snapshots['u_a']!.info.backgroundImage, isEmpty);
    },
  );

  test(
    'account switch never displays or stores a previous account pending image',
    () async {
      final image = Completer<Uint8List>();
      cache.download = (_) => image.future;
      var server = info(newUrl);
      final controller = make(() async => server);
      final pending = controller.refresh();
      await flush();
      await session.saveUid('u_b');
      server = info('');
      await controller.refresh();
      expect(controller.displayBytes, isNull);
      image.complete(newBytes);
      await pending;
      expect(controller.displayBytes, isNull);
      expect(cache.snapshots['u_a']!.info.backgroundImage, oldUrl);
      expect(cache.snapshots['u_b']!.info.backgroundImage, isEmpty);
    },
  );
}
