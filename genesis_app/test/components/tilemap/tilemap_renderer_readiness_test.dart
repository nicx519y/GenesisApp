import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_model.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';

void main() {
  testWidgets(
    'viewport readiness waits only for images intersecting the initial viewport',
    (tester) async {
      final visibleImage = await _createImage(tester, Colors.red);
      final retainedImage = await _createImage(tester, Colors.blue);
      final visibleFrame = Completer<ui.Image>();
      final retainedFrame = Completer<ui.Image>();
      final visibleProvider = _primeNetworkImage(
        'https://readiness.test/visible.png',
        visibleFrame.future,
      );
      final retainedProvider = _primeNetworkImage(
        'https://readiness.test/retained.png',
        retainedFrame.future,
      );
      addTearDown(() async {
        await visibleProvider.evict();
        await retainedProvider.evict();
      });
      final config = TilemapConfig.fromTiles(
        id: 'viewport-readiness',
        width: 100,
        height: 100,
        tileTypes: const {
          'visible': 'https://readiness.test/visible.png',
          'retained': 'https://readiness.test/retained.png',
        },
        tiles: const [
          TilemapCell(x: 50, y: 50, type: 'visible'),
          TilemapCell(x: 0, y: 0, type: 'retained', shadow: 1),
          TilemapCell(x: 53, y: 53, type: 'retained', shadow: 1),
          TilemapCell(x: 99, y: 99, type: 'retained', shadow: 1),
        ],
      );
      var readyCount = 0;

      await tester.pumpWidget(
        _rendererHarness(
          config: config,
          onViewportReady: () => readyCount += 1,
        ),
      );

      expect(find.byKey(const ValueKey<String>('tile-50-50')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('tile-53-53')), findsOneWidget);
      expect(readyCount, 0);

      visibleFrame.complete(visibleImage);
      await tester.pump();
      await tester.pump();

      expect(readyCount, 1);

      retainedFrame.complete(retainedImage);
      await tester.pump();
      await tester.pump();

      expect(readyCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('ready renderer notifies each replacement callback once', (
    tester,
  ) async {
    final image = await _createImage(tester, Colors.green);
    final frame = Completer<ui.Image>();
    final provider = _primeNetworkImage(
      'https://readiness.test/reparented.png',
      frame.future,
    );
    addTearDown(provider.evict);
    final config = TilemapConfig.fromTiles(
      id: 'reparented-readiness',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://readiness.test/reparented.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );
    final rendererKey = GlobalKey();
    var firstCallbackCount = 0;
    var replacementCallbackCount = 0;
    void firstCallback() => firstCallbackCount += 1;
    void replacementCallback() => replacementCallbackCount += 1;

    await tester.pumpWidget(
      _rendererHarness(
        rendererKey: rendererKey,
        config: config,
        onViewportReady: firstCallback,
      ),
    );
    frame.complete(image);
    await tester.pump();
    await tester.pump();

    expect(firstCallbackCount, 1);
    expect(replacementCallbackCount, 0);

    await tester.pumpWidget(
      _rendererHarness(
        rendererKey: rendererKey,
        config: config,
        onViewportReady: replacementCallback,
      ),
    );
    await tester.pump();

    expect(firstCallbackCount, 1);
    expect(replacementCallbackCount, 1);

    await tester.pumpWidget(
      _rendererHarness(
        rendererKey: rendererKey,
        config: config,
        onViewportReady: replacementCallback,
      ),
    );
    await tester.pump();

    expect(firstCallbackCount, 1);
    expect(replacementCallbackCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('viewport resize waits for newly visible tile frames', (
    tester,
  ) async {
    final initiallyVisibleImage = await _createImage(tester, Colors.orange);
    final newlyVisibleImage = await _createImage(tester, Colors.purple);
    final initiallyVisibleFrame = Completer<ui.Image>();
    final newlyVisibleFrame = Completer<ui.Image>();
    final initiallyVisibleProvider = _primeNetworkImage(
      'https://readiness.test/resize-visible.png',
      initiallyVisibleFrame.future,
    );
    final newlyVisibleProvider = _primeNetworkImage(
      'https://readiness.test/resize-newly-visible.png',
      newlyVisibleFrame.future,
    );
    addTearDown(() async {
      await initiallyVisibleProvider.evict();
      await newlyVisibleProvider.evict();
    });
    final config = TilemapConfig.fromTiles(
      id: 'viewport-resize-readiness',
      width: 100,
      height: 100,
      tileTypes: const {
        'visible': 'https://readiness.test/resize-visible.png',
        'newlyVisible': 'https://readiness.test/resize-newly-visible.png',
      },
      tiles: const [
        TilemapCell(x: 50, y: 50, type: 'visible'),
        TilemapCell(x: 0, y: 0, type: 'newlyVisible', shadow: 1),
        TilemapCell(x: 51, y: 49, type: 'newlyVisible', shadow: 1),
        TilemapCell(x: 99, y: 99, type: 'newlyVisible', shadow: 1),
      ],
    );
    final rendererKey = GlobalKey();
    var initialReadyCount = 0;
    var resizedReadyCount = 0;
    void initialReady() => initialReadyCount += 1;
    void resizedReady() => resizedReadyCount += 1;

    await tester.pumpWidget(
      _rendererHarness(
        rendererKey: rendererKey,
        config: config,
        viewportSize: const Size(160, 160),
        onViewportReady: initialReady,
      ),
    );
    initiallyVisibleFrame.complete(initiallyVisibleImage);
    await tester.pump();
    await tester.pump();

    expect(initialReadyCount, 1);
    expect(resizedReadyCount, 0);

    await tester.pumpWidget(
      _rendererHarness(
        rendererKey: rendererKey,
        config: config,
        viewportSize: const Size(640, 160),
        onViewportReady: resizedReady,
      ),
    );
    await tester.pump();

    expect(initialReadyCount, 1);
    expect(resizedReadyCount, 0);

    newlyVisibleFrame.complete(newlyVisibleImage);
    await tester.pump();
    await tester.pump();

    expect(initialReadyCount, 1);
    expect(resizedReadyCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wait false reports readiness after the first paint', (
    tester,
  ) async {
    final config = TilemapConfig.fromTiles(
      id: 'no-frame-wait',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://readiness.test/never-loaded.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );
    var readyCount = 0;

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        waitForVisibleTileImageFrames: false,
        onViewportReady: () => readyCount += 1,
      ),
    );

    expect(readyCount, 1);
    await tester.pump();
    expect(readyCount, 1);
  });

  testWidgets('an empty viewport reports readiness after its first paint', (
    tester,
  ) async {
    final config = TilemapConfig.fromTiles(
      id: 'empty-viewport',
      width: 1,
      height: 1,
      tileTypes: const {
        'tile': 'https://readiness.test/outside-empty-viewport.png',
      },
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );
    var readyCount = 0;

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        viewportSize: Size.zero,
        onViewportReady: () => readyCount += 1,
      ),
    );

    expect(readyCount, 1);
    await tester.pump();
    expect(readyCount, 1);
  });
}

Widget _rendererHarness({
  Key? rendererKey,
  required TilemapConfig config,
  required VoidCallback onViewportReady,
  bool waitForVisibleTileImageFrames = true,
  Size viewportSize = const Size(320, 480),
}) {
  return MaterialApp(
    home: Center(
      child: MediaQuery(
        data: MediaQueryData(size: viewportSize, devicePixelRatio: 1),
        child: SizedBox(
          width: viewportSize.width,
          height: viewportSize.height,
          child: TilemapRenderer(
            key: rendererKey,
            config: config,
            onViewportReady: onViewportReady,
            waitForVisibleTileImageFrames: waitForVisibleTileImageFrames,
          ),
        ),
      ),
    ),
  );
}

NetworkImage _primeNetworkImage(String baseUrl, Future<ui.Image> imageFuture) {
  final resolvedUrl = resolveTilemapAssetForDisplaySize(baseUrl, 256);
  final provider = NetworkImage(resolvedUrl);
  PaintingBinding.instance.imageCache.putIfAbsent(
    provider,
    () => OneFrameImageStreamCompleter(
      imageFuture.then((image) => ImageInfo(image: image)),
    ),
  );
  return provider;
}

Future<ui.Image> _createImage(WidgetTester tester, Color color) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = color);
    return recorder.endRecording().toImage(2, 2);
  }))!;
}
