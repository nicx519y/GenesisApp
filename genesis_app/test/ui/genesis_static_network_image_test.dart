import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

void main() {
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
