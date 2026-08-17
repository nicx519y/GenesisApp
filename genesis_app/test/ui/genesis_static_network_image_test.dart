import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

void main() {
  testWidgets('caps target decode dimensions at global image DPR', (
    tester,
  ) async {
    GenesisStaticNetworkImageProvider? capturedProvider;
    debugGenesisStaticNetworkImageCompleter = (provider) {
      capturedProvider = provider;
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(StateError('decode sizing probe')),
      );
    };
    addTearDown(() => debugGenesisStaticNetworkImageCompleter = null);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisStaticNetworkImage(
            imageUrl: 'https://cache.test/dpr-capped.png',
            width: 40,
            height: 30,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(capturedProvider?.cacheWidth, 60);
    expect(capturedProvider?.cacheHeight, 45);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports a surface-specific target decode DPR cap', (
    tester,
  ) async {
    GenesisStaticNetworkImageProvider? capturedProvider;
    debugGenesisStaticNetworkImageCompleter = (provider) {
      capturedProvider = provider;
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(StateError('decode sizing probe')),
      );
    };
    addTearDown(() => debugGenesisStaticNetworkImageCompleter = null);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisStaticNetworkImage(
            imageUrl: 'https://cache.test/dpr-surface.png',
            width: 40,
            height: 30,
            maxDevicePixelRatio: 2.4,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(capturedProvider?.cacheWidth, 96);
    expect(capturedProvider?.cacheHeight, 72);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reuses a decoded first frame for the same URL', (tester) async {
    const imageUrl = 'https://cache.test/avatar-static-frame.png';
    const placeholderKey = ValueKey<String>('static-image-placeholder');
    final fileSystem = MemoryFileSystem();
    final asset = await rootBundle.load('assets/images/default_list_image.png');
    final imageFile = fileSystem.file('/avatar-static-frame.png');
    await imageFile.writeAsBytes(asset.buffer.asUint8List());
    final cacheManager = _MemoryCacheManager(imageFile);
    final provider = GenesisStaticNetworkImageProvider(
      imageUrl: imageUrl,
      cacheManager: cacheManager,
    );
    var loadedCount = 0;
    await provider.evict();
    addTearDown(provider.evict);

    Widget image() {
      return MaterialApp(
        home: Scaffold(
          body: GenesisStaticNetworkImage(
            imageUrl: imageUrl,
            width: 40,
            height: 40,
            cacheManager: cacheManager,
            onImageLoaded: () => loadedCount += 1,
            placeholder: (_) =>
                const SizedBox(key: placeholderKey, width: 40, height: 40),
          ),
        ),
      );
    }

    await tester.pumpWidget(image());
    expect(find.byKey(placeholderKey), findsOneWidget);
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 100 && loadedCount == 0; attempt += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(loadedCount, 1);
    expect(find.byKey(placeholderKey), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(image());

    expect(find.byKey(placeholderKey), findsNothing);
    expect(cacheManager.getSingleFileCalls, 1);
  });

  testWidgets('does not fail when a pending image completes after removal', (
    tester,
  ) async {
    const imageUrl = 'https://cache.test/slow-static-frame.png';
    const placeholderKey = ValueKey<String>('slow-static-image-placeholder');
    final fileSystem = MemoryFileSystem();
    final asset = await rootBundle.load('assets/images/default_list_image.png');
    final imageFile = fileSystem.file('/slow-static-frame.png');
    await imageFile.writeAsBytes(asset.buffer.asUint8List());
    final releaseLoad = Completer<void>();
    final cacheManager = _DelayedMemoryCacheManager(
      imageFile,
      releaseLoad.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenesisStaticNetworkImage(
            imageUrl: imageUrl,
            width: 40,
            height: 40,
            cacheManager: cacheManager,
            placeholder: (_) =>
                const SizedBox(key: placeholderKey, width: 40, height: 40),
          ),
        ),
      ),
    );
    expect(find.byKey(placeholderKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    releaseLoad.complete();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('decodes a cached image near its target display size', (
    tester,
  ) async {
    const imageUrl = 'https://cache.test/target-sized-frame.png';
    final fileSystem = MemoryFileSystem();
    final asset = await rootBundle.load('assets/images/default_list_image.png');
    final imageFile = fileSystem.file('/target-sized-frame.png');
    await imageFile.writeAsBytes(asset.buffer.asUint8List());
    final cacheManager = _MemoryCacheManager(imageFile);
    final provider = GenesisStaticNetworkImageProvider(
      imageUrl: imageUrl,
      cacheManager: cacheManager,
      cacheWidth: 8,
      cacheHeight: 8,
      fit: BoxFit.contain,
    );
    await provider.evict();
    addTearDown(provider.evict);

    ImageInfo? imageInfo;
    await tester.runAsync(() async {
      imageInfo = await _resolveImage(provider);
    });

    final decoded = imageInfo;
    expect(decoded, isNotNull);
    expect(decoded!.image.width, lessThanOrEqualTo(8));
    expect(decoded.image.height, lessThanOrEqualTo(8));
    decoded.dispose();
  });

  testWidgets('evicts a failed stream so the same key can be retried', (
    tester,
  ) async {
    const imageUrl = 'https://cache.test/retry-static-frame.png';
    final fileSystem = MemoryFileSystem();
    final asset = await rootBundle.load('assets/images/default_list_image.png');
    final imageFile = fileSystem.file('/retry-static-frame.png');
    await imageFile.writeAsBytes(asset.buffer.asUint8List());
    final cacheManager = _FailOnceMemoryCacheManager(imageFile);
    final provider = GenesisStaticNetworkImageProvider(
      imageUrl: imageUrl,
      cacheManager: cacheManager,
    );
    final imageCache = PaintingBinding.instance.imageCache;
    await provider.evict();
    addTearDown(provider.evict);

    Object? firstError;
    await tester.runAsync(() async {
      try {
        await _resolveImage(provider);
      } catch (error) {
        firstError = error;
      }
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    expect(firstError, isA<StateError>());
    final failedStatus = imageCache.statusForKey(provider);
    expect(failedStatus.pending, false);
    expect(failedStatus.live, false);
    expect(failedStatus.untracked, true);

    ImageInfo? imageInfo;
    await tester.runAsync(() async {
      imageInfo = await _resolveImage(provider);
    });

    expect(imageInfo, isNotNull);
    expect(cacheManager.getSingleFileCalls, 2);
    imageInfo!.dispose();
  });

  testWidgets('deletes a corrupt disk image and retries once', (tester) async {
    const imageUrl = 'https://cache.test/corrupt-then-valid.png';
    final fileSystem = MemoryFileSystem();
    final corruptFile = fileSystem.file('/corrupt.png');
    await corruptFile.writeAsBytes(<int>[0, 1, 2, 3]);
    final asset = await rootBundle.load('assets/images/default_list_image.png');
    final validFile = fileSystem.file('/valid.png');
    await validFile.writeAsBytes(asset.buffer.asUint8List());
    final cacheManager = _CorruptThenValidCacheManager(corruptFile, validFile);
    final provider = GenesisStaticNetworkImageProvider(
      imageUrl: imageUrl,
      cacheManager: cacheManager,
    );
    await provider.evict();
    addTearDown(provider.evict);

    ImageInfo? imageInfo;
    await tester.runAsync(() async {
      imageInfo = await _resolveImage(provider);
    });

    expect(imageInfo, isNotNull);
    expect(cacheManager.getSingleFileCalls, 2);
    expect(cacheManager.removedKeys, <String>[imageUrl]);
    imageInfo!.dispose();
  });

  testWidgets('stops after one retry when the disk image stays corrupt', (
    tester,
  ) async {
    const imageUrl = 'https://cache.test/always-corrupt.png';
    final fileSystem = MemoryFileSystem();
    final corruptFile = fileSystem.file('/always-corrupt.png');
    await corruptFile.writeAsBytes(<int>[0, 1, 2, 3]);
    final cacheManager = _AlwaysCorruptCacheManager(corruptFile);
    final provider = GenesisStaticNetworkImageProvider(
      imageUrl: imageUrl,
      cacheManager: cacheManager,
    );
    await provider.evict();
    addTearDown(provider.evict);

    Object? decodeError;
    await tester.runAsync(() async {
      try {
        await _resolveImage(provider);
      } catch (error) {
        decodeError = error;
      }
    });

    expect(decodeError, isNotNull);
    expect(cacheManager.getSingleFileCalls, 2);
    expect(cacheManager.removedKeys, <String>[imageUrl, imageUrl]);
  });
}

Future<ImageInfo> _resolveImage(ImageProvider provider) {
  final completer = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, synchronousCall) {
      if (!completer.isCompleted) completer.complete(image.clone());
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

class _MemoryCacheManager implements BaseCacheManager {
  _MemoryCacheManager(this.file);

  final File file;
  int getSingleFileCalls = 0;

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    getSingleFileCalls += 1;
    return file;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedMemoryCacheManager implements BaseCacheManager {
  _DelayedMemoryCacheManager(this.file, this.loadGate);

  final File file;
  final Future<void> loadGate;

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    await loadGate;
    return file;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailOnceMemoryCacheManager implements BaseCacheManager {
  _FailOnceMemoryCacheManager(this.file);

  final File file;
  int getSingleFileCalls = 0;

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    getSingleFileCalls += 1;
    if (getSingleFileCalls == 1) {
      throw StateError('first image request failed');
    }
    return file;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CorruptThenValidCacheManager implements BaseCacheManager {
  _CorruptThenValidCacheManager(this.corruptFile, this.validFile);

  final File corruptFile;
  final File validFile;
  int getSingleFileCalls = 0;
  final List<String> removedKeys = <String>[];

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    getSingleFileCalls += 1;
    return getSingleFileCalls == 1 ? corruptFile : validFile;
  }

  @override
  Future<void> removeFile(String key) async {
    removedKeys.add(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AlwaysCorruptCacheManager implements BaseCacheManager {
  _AlwaysCorruptCacheManager(this.file);

  final File file;
  int getSingleFileCalls = 0;
  final List<String> removedKeys = <String>[];

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    getSingleFileCalls += 1;
    return file;
  }

  @override
  Future<void> removeFile(String key) async {
    removedKeys.add(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
