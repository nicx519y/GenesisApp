import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/models/miniphone_info.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_wallpaper_cache.dart';

class _Images implements BaseCacheManager {
  _Images(this.file);
  final File file;
  bool cached = false;
  int downloads = 0;
  String? writtenExtension;
  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    await file.writeAsBytes(fileBytes);
    writtenExtension = fileExtension;
    cached = true;
    return file;
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async =>
      cached ? FileInfo(file, FileSource.Cache, DateTime(2000), key) : null;
  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    downloads++;
    cached = true;
    return file;
  }

  @override
  Future<void> removeFile(String key) async {
    cached = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const url = 'https://cdn.example/wallpaper.png';
  const info = MiniphoneInfo(
    backgroundImage: url,
    wallpapers: [MiniphoneWallpaper(imageUrl: url, title: 'Wallpaper')],
  );

  test(
    'selected bytes are written under uploaded URL and restored without a download',
    () async {
      final image = await rootBundle.load(
        'assets/images/default_list_image.png',
      );
      final bytes = image.buffer.asUint8List();
      final images = _Images(MemoryFileSystem().file('/selected.png'));
      final cache = LocalMiniPhoneWallpaperCache(
        namespace: 'dev',
        images: images,
      );
      await cache.writeImage(url, bytes, 'image/png');
      await cache.write('u_a', 'w_1', info);
      final reopened = LocalMiniPhoneWallpaperCache(
        namespace: 'dev',
        images: images,
      );
      final restored = await reopened.read('u_a', 'w_1');
      expect(restored!.bytes, orderedEquals(bytes));
      expect(restored.info.backgroundImage, url);
      expect(images.writtenExtension, 'png');
      expect(images.downloads, 0);
    },
  );

  test(
    'new cache instance restores metadata and local file without HTTP, even after expiry',
    () async {
      final image = await rootBundle.load(
        'assets/images/default_list_image.png',
      );
      final file = MemoryFileSystem().file('/background.png')
        ..writeAsBytesSync(image.buffer.asUint8List());
      final images = _Images(file);
      final first = LocalMiniPhoneWallpaperCache(
        namespace: 'dev',
        images: images,
      );
      final bytes = await first.loadImage(url);
      await first.write('u_a', 'w_1', info);
      final reopened = LocalMiniPhoneWallpaperCache(
        namespace: 'dev',
        images: images,
      );
      final restored = await reopened.read('u_a', 'w_1');
      expect(restored!.info.backgroundImage, url);
      expect(restored.info.wallpapers.single.title, 'Wallpaper');
      expect(restored.bytes, orderedEquals(bytes));
      await reopened.loadImage(url);
      expect(images.downloads, 1);
      // Background is global to this account; catalogues remain World-scoped.
      final otherWorld = await reopened.read('u_a', 'w_2');
      expect(otherWorld!.info.backgroundImage, url);
      expect(otherWorld.info.wallpapers, isEmpty);
      expect(await reopened.read('u_b', 'w_1'), isNull);
      expect(
        await LocalMiniPhoneWallpaperCache(
          namespace: 'prod',
          images: images,
        ).read('u_a', 'w_1'),
        isNull,
      );
    },
  );

  test(
    'missing or corrupt image cache does not hide metadata or make a read download',
    () async {
      final file = MemoryFileSystem().file('/corrupt.png')
        ..writeAsBytesSync([1, 2, 3]);
      final images = _Images(file)..cached = true;
      final cache = LocalMiniPhoneWallpaperCache(
        namespace: 'dev',
        images: images,
      );
      await cache.write('u_a', 'w_1', info);
      final snapshot = await cache.read('u_a', 'w_1');
      expect(snapshot!.info.backgroundImage, url);
      expect(snapshot.bytes, isNull);
      expect(images.downloads, 0);
      images.cached = false;
      expect((await cache.read('u_a', 'w_1'))!.bytes, isNull);
      expect(images.downloads, 0);
    },
  );

  test(
    'cleared background restores as default without loading an image',
    () async {
      final images = _Images(MemoryFileSystem().file('/unused.png'));
      final cache = LocalMiniPhoneWallpaperCache(
        namespace: 'dev',
        images: images,
      );
      await cache.write(
        'u_a',
        'w_1',
        const MiniphoneInfo(backgroundImage: '', wallpapers: []),
      );
      final snapshot = await cache.read('u_a', 'w_1');
      expect(snapshot!.info.backgroundImage, isEmpty);
      expect(snapshot.bytes, isNull);
      expect(images.downloads, 0);
    },
  );
}
