import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_model.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugGenesisStaticNetworkImageCompleter = null;
    debugTilemapCanvasRenderStatsChanged = null;
  });

  tearDown(() {
    debugGenesisStaticNetworkImageCompleter = null;
    debugTilemapCanvasRenderStatsChanged = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'canvas resolves a shared URL once and paints every cell in one batch',
    (tester) async {
      final sharedImage = await _createSolidImage(tester, Colors.red);
      addTearDown(sharedImage.dispose);
      final loadCountByUrl = <String, int>{};
      debugGenesisStaticNetworkImageCompleter = (key) {
        loadCountByUrl.update(
          key.imageUrl,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        return OneFrameImageStreamCompleter(
          Future<ImageInfo>.value(ImageInfo(image: sharedImage.clone())),
        );
      };
      TilemapCanvasRenderStats? latestStats;
      debugTilemapCanvasRenderStatsChanged = (stats) => latestStats = stats;
      final config = TilemapConfig.fromTiles(
        id: 'canvas-shared-url',
        width: 3,
        height: 1,
        tileTypes: const {'shared': 'https://canvas.test/shared.png'},
        tiles: const [
          TilemapCell(x: 0, y: 0, type: 'shared'),
          TilemapCell(x: 1, y: 0, type: 'shared'),
          TilemapCell(x: 2, y: 0, type: 'shared'),
        ],
      );

      await tester.pumpWidget(
        _rendererHarness(
          config: config,
          renderBackend: TilemapRenderBackend.canvas,
        ),
      );
      await _pumpUntil(
        tester,
        () => latestStats?.tileCount == 3 && latestStats?.imageCount == 1,
      );
      final semantics = tester.ensureSemantics();

      expect(loadCountByUrl, hasLength(1));
      expect(loadCountByUrl.values.single, 1);
      expect(
        find.byKey(const ValueKey<String>('tilemap-canvas-tile-layer')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const ValueKey<String>('tile-0-0')), findsNothing);
      expect(latestStats?.tileCount, 3);
      expect(latestStats?.imageCount, 1);
      expect(latestStats?.drawCallCount, 1);
      expect(latestStats?.renderObjectCount, 1);
      expect(find.semantics.byLabel('shared 0,0'), findsOne);
      expect(find.semantics.byLabel('shared 1,0'), findsOne);
      expect(find.semantics.byLabel('shared 2,0'), findsOne);
      semantics.dispose();
    },
  );

  testWidgets('canvas paints every URL before viewport ready runs post-frame', (
    tester,
  ) async {
    final redImage = await _createSolidImage(tester, Colors.red);
    final blueImage = await _createSolidImage(tester, Colors.blue);
    addTearDown(redImage.dispose);
    addTearDown(blueImage.dispose);
    final loadCountByUrl = <String, int>{};
    debugGenesisStaticNetworkImageCompleter = (key) {
      loadCountByUrl.update(
        key.imageUrl,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final image = key.imageUrl.contains('/red.png') ? redImage : blueImage;
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image.clone())),
      );
    };
    TilemapCanvasRenderStats? latestStats;
    debugTilemapCanvasRenderStatsChanged = (stats) {
      latestStats = stats;
    };
    TilemapCanvasRenderStats? statsSeenByReady;
    SchedulerPhase? readySchedulerPhase;
    var readyCount = 0;
    final repaintBoundaryKey = GlobalKey();
    final config = TilemapConfig.fromTiles(
      id: 'canvas-multiple-urls',
      width: 2,
      height: 1,
      tileTypes: const {
        'red': 'https://canvas.test/red.png',
        'blue': 'https://canvas.test/blue.png',
      },
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'red'),
        TilemapCell(x: 1, y: 0, type: 'blue'),
      ],
    );

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        renderBackend: TilemapRenderBackend.canvas,
        repaintBoundaryKey: repaintBoundaryKey,
        onViewportReady: () {
          statsSeenByReady = latestStats;
          readySchedulerPhase = SchedulerBinding.instance.schedulerPhase;
          readyCount += 1;
        },
      ),
    );
    await _pumpUntil(tester, () => readyCount == 1);

    expect(loadCountByUrl, hasLength(2));
    expect(loadCountByUrl.values, everyElement(1));
    expect(statsSeenByReady?.tileCount, 2);
    expect(statsSeenByReady?.imageCount, 2);
    expect(statsSeenByReady?.drawCallCount, 2);
    expect(readySchedulerPhase, SchedulerPhase.postFrameCallbacks);

    final sampledColors = await _captureDominantColors(
      tester,
      repaintBoundaryKey,
    );
    expect(sampledColors.hasRed, isTrue);
    expect(sampledColors.hasBlue, isTrue);
  });

  testWidgets('widget and canvas render backends both build explicitly', (
    tester,
  ) async {
    final image = await _createSolidImage(tester, Colors.green);
    addTearDown(image.dispose);
    debugGenesisStaticNetworkImageCompleter = (_) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image.clone())),
      );
    };
    TilemapCanvasRenderStats? latestStats;
    debugTilemapCanvasRenderStatsChanged = (stats) => latestStats = stats;
    final config = TilemapConfig.fromTiles(
      id: 'renderer-backend-switch',
      width: 2,
      height: 1,
      tileTypes: const {'tile': 'https://canvas.test/switch.png'},
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'tile'),
        TilemapCell(x: 1, y: 0, type: 'tile'),
      ],
    );

    for (final backend in TilemapRenderBackend.values) {
      latestStats = null;
      await tester.pumpWidget(
        _rendererHarness(config: config, renderBackend: backend),
      );
      await _pumpUntil(
        tester,
        () => switch (backend) {
          TilemapRenderBackend.widgets =>
            find
                .byKey(const ValueKey<String>('tile-1-0'))
                .evaluate()
                .isNotEmpty,
          TilemapRenderBackend.canvas => latestStats?.tileCount == 2,
        },
      );

      final renderer = tester.widget<TilemapRenderer>(
        find.byType(TilemapRenderer),
      );
      expect(renderer.renderBackend, backend);
      switch (backend) {
        case TilemapRenderBackend.widgets:
          expect(
            find.byKey(const ValueKey<String>('tilemap-canvas-tile-layer')),
            findsNothing,
          );
          expect(find.byType(Image), findsNWidgets(2));
        case TilemapRenderBackend.canvas:
          expect(
            find.byKey(const ValueKey<String>('tilemap-canvas-tile-layer')),
            findsOneWidget,
          );
          expect(find.byType(Image), findsNothing);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('canvas batches only consecutive cells sharing an image', (
    tester,
  ) async {
    final firstImage = await _createSolidImage(tester, Colors.orange);
    final secondImage = await _createSolidImage(tester, Colors.purple);
    addTearDown(firstImage.dispose);
    addTearDown(secondImage.dispose);
    debugGenesisStaticNetworkImageCompleter = (key) {
      final image = key.imageUrl.contains('/first.png')
          ? firstImage
          : secondImage;
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image.clone())),
      );
    };
    TilemapCanvasRenderStats? latestStats;
    debugTilemapCanvasRenderStatsChanged = (stats) => latestStats = stats;
    final config = TilemapConfig.fromTiles(
      id: 'canvas-consecutive-batches',
      width: 2,
      height: 3,
      tileTypes: const {
        'first': 'https://canvas.test/first.png',
        'second': 'https://canvas.test/second.png',
      },
      // Canonical paint order is first, first, second, first.
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'first'),
        TilemapCell(x: 0, y: 1, type: 'first'),
        TilemapCell(x: 1, y: 0, type: 'second'),
        TilemapCell(x: 0, y: 2, type: 'first'),
      ],
    );

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        renderBackend: TilemapRenderBackend.canvas,
      ),
    );
    await _pumpUntil(
      tester,
      () => latestStats?.tileCount == 4 && latestStats?.imageCount == 2,
    );

    expect(latestStats?.tileCount, 4);
    expect(latestStats?.imageCount, 2);
    expect(latestStats?.drawCallCount, 3);
    expect(latestStats?.renderObjectCount, 1);
  });

  testWidgets(
    'canvas keeps the previous CDN tier until the next image paints',
    (tester) async {
      final oldTierImage = await _createSolidImage(tester, Colors.red);
      final nextTierImage = await _createSolidImage(tester, Colors.blue);
      addTearDown(oldTierImage.dispose);
      addTearDown(nextTierImage.dispose);
      final nextTierFrame = Completer<ImageInfo>();
      final requestedUrls = <String>[];
      TilemapCanvasRenderStats? latestStats;
      debugTilemapCanvasRenderStatsChanged = (stats) => latestStats = stats;
      debugGenesisStaticNetworkImageCompleter = (key) {
        requestedUrls.add(key.imageUrl);
        if (key.imageUrl.contains('resize,w_512')) {
          return OneFrameImageStreamCompleter(
            Future<ImageInfo>.value(ImageInfo(image: oldTierImage.clone())),
          );
        }
        if (key.imageUrl.contains('resize,w_640')) {
          return OneFrameImageStreamCompleter(nextTierFrame.future);
        }
        return null;
      };
      final repaintBoundaryKey = GlobalKey();
      final config = TilemapConfig.fromTiles(
        id: 'canvas-gapless-tier',
        width: 1,
        height: 1,
        tileTypes: const {'tile': 'https://canvas.test/tier.png'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
      );

      await tester.pumpWidget(
        _rendererHarness(
          config: config,
          renderBackend: TilemapRenderBackend.canvas,
          repaintBoundaryKey: repaintBoundaryKey,
          devicePixelRatio: 2,
        ),
      );
      await _pumpUntil(
        tester,
        () =>
            requestedUrls.any((url) => url.contains('resize,w_512')) &&
            latestStats?.imageCount == 1,
      );
      var colors = await _captureDominantColors(tester, repaintBoundaryKey);
      expect(colors.hasRed, isTrue);
      expect(colors.hasBlue, isFalse);

      await _zoomInAndPump(tester);
      await _zoomInAndPump(tester);
      await _pumpUntil(
        tester,
        () => requestedUrls.any((url) => url.contains('resize,w_640')),
      );
      colors = await _captureDominantColors(tester, repaintBoundaryKey);
      expect(colors.hasRed, isTrue);
      expect(colors.hasBlue, isFalse);

      nextTierFrame.complete(ImageInfo(image: nextTierImage.clone()));
      await tester.pump();
      await tester.pump();
      colors = await _captureDominantColors(tester, repaintBoundaryKey);
      expect(colors.hasRed, isFalse);
      expect(colors.hasBlue, isTrue);
    },
  );

  testWidgets('canvas keeps the previous CDN tier when the next tier fails', (
    tester,
  ) async {
    final oldTierImage = await _createSolidImage(tester, Colors.red);
    addTearDown(oldTierImage.dispose);
    final nextTierFrame = Completer<ImageInfo>();
    var imageErrorCount = 0;
    TilemapCanvasRenderStats? latestStats;
    debugTilemapCanvasRenderStatsChanged = (stats) => latestStats = stats;
    debugGenesisStaticNetworkImageCompleter = (key) {
      if (key.imageUrl.contains('resize,w_512')) {
        return OneFrameImageStreamCompleter(
          Future<ImageInfo>.value(ImageInfo(image: oldTierImage.clone())),
        );
      }
      if (key.imageUrl.contains('resize,w_640')) {
        return OneFrameImageStreamCompleter(nextTierFrame.future);
      }
      return null;
    };
    final repaintBoundaryKey = GlobalKey();
    final config = TilemapConfig.fromTiles(
      id: 'canvas-gapless-tier-error',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://canvas.test/tier-error.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        renderBackend: TilemapRenderBackend.canvas,
        repaintBoundaryKey: repaintBoundaryKey,
        devicePixelRatio: 2,
        onImageError: (_) => imageErrorCount += 1,
      ),
    );
    await _pumpUntil(tester, () => latestStats?.imageCount == 1);
    await _zoomInAndPump(tester);
    await _zoomInAndPump(tester);

    nextTierFrame.completeError(StateError('next tier failed'));
    await _pumpUntil(tester, () => imageErrorCount == 1);

    final colors = await _captureDominantColors(tester, repaintBoundaryKey);
    expect(colors.hasRed, isTrue);
    expect(latestStats?.imageCount, 1);
    expect(latestStats?.drawCallCount, 1);
  });

  testWidgets('canvas reports the painted image again after viewport reset', (
    tester,
  ) async {
    final image = await _createSolidImage(tester, Colors.teal);
    addTearDown(image.dispose);
    debugGenesisStaticNetworkImageCompleter = (_) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image.clone())),
      );
    };
    final viewportSize = ValueNotifier<Size>(const Size(320, 480));
    addTearDown(viewportSize.dispose);
    final rendererKey = GlobalKey();
    var readyCount = 0;
    final config = TilemapConfig.fromTiles(
      id: 'canvas-viewport-reset',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://canvas.test/reset.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ValueListenableBuilder<Size>(
            valueListenable: viewportSize,
            builder: (context, size, _) => MediaQuery(
              data: MediaQueryData(size: size, devicePixelRatio: 1),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: TilemapRenderer(
                  key: rendererKey,
                  config: config,
                  renderBackend: TilemapRenderBackend.canvas,
                  blendFogWithShadowTiles: false,
                  showLocationImageFlow: false,
                  onViewportReady: () => readyCount += 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _pumpUntil(tester, () => readyCount == 1);

    viewportSize.value = const Size(300, 460);
    await _pumpUntil(tester, () => readyCount == 2);
    expect(readyCount, 2);
  });

  testWidgets('canvas ignores a stale frame after an in-place config switch', (
    tester,
  ) async {
    final firstImage = await _createSolidImage(tester, Colors.red);
    final secondImage = await _createSolidImage(tester, Colors.blue);
    addTearDown(firstImage.dispose);
    addTearDown(secondImage.dispose);
    final firstFrame = Completer<ImageInfo>();
    final secondFrame = Completer<ImageInfo>();
    final requestedUrls = <String>[];
    debugGenesisStaticNetworkImageCompleter = (key) {
      requestedUrls.add(key.imageUrl);
      if (key.imageUrl.contains('/first.png')) {
        return OneFrameImageStreamCompleter(firstFrame.future);
      }
      if (key.imageUrl.contains('/second.png')) {
        return OneFrameImageStreamCompleter(secondFrame.future);
      }
      return null;
    };
    final firstConfig = TilemapConfig.fromTiles(
      id: 'canvas-stale-first',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://canvas.test/first.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );
    final secondConfig = TilemapConfig.fromTiles(
      id: 'canvas-stale-second',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://canvas.test/second.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );
    final config = ValueNotifier<TilemapConfig>(firstConfig);
    addTearDown(config.dispose);
    final rendererKey = GlobalKey();
    final repaintBoundaryKey = GlobalKey();
    var readyCount = 0;

    await tester.pumpWidget(
      ValueListenableBuilder<TilemapConfig>(
        valueListenable: config,
        builder: (context, value, _) => _rendererHarness(
          rendererKey: rendererKey,
          config: value,
          renderBackend: TilemapRenderBackend.canvas,
          repaintBoundaryKey: repaintBoundaryKey,
          onViewportReady: () => readyCount += 1,
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => requestedUrls.any((url) => url.contains('/first.png')),
    );

    config.value = secondConfig;
    await _pumpUntil(
      tester,
      () => requestedUrls.any((url) => url.contains('/second.png')),
    );
    firstFrame.complete(ImageInfo(image: firstImage.clone()));
    await tester.pump();
    await tester.pump();

    expect(readyCount, 0);
    expect(
      await _captureHasColor(tester, repaintBoundaryKey, Colors.red),
      isFalse,
    );

    secondFrame.complete(ImageInfo(image: secondImage.clone()));
    await _pumpUntil(tester, () => readyCount == 1);
    expect(
      await _captureHasColor(tester, repaintBoundaryKey, Colors.blue),
      isTrue,
    );
  });

  testWidgets('canvas retries a failed image as progressive mounting resumes', (
    tester,
  ) async {
    final recoveredImage = await _createSolidImage(tester, Colors.blue);
    addTearDown(recoveredImage.dispose);
    final failedFrame = Completer<ImageInfo>();
    var loadCount = 0;
    var errorCount = 0;
    TilemapCanvasRenderStats? latestStats;
    debugTilemapCanvasRenderStatsChanged = (stats) => latestStats = stats;
    debugGenesisStaticNetworkImageCompleter = (_) {
      loadCount += 1;
      return OneFrameImageStreamCompleter(
        loadCount == 1
            ? failedFrame.future
            : Future<ImageInfo>.value(ImageInfo(image: recoveredImage.clone())),
      );
    };
    final config = TilemapConfig.fromTiles(
      id: 'canvas-image-error-progress',
      width: 3,
      height: 1,
      tileTypes: const {'tile': 'https://canvas.test/failure.png'},
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'tile'),
        TilemapCell(x: 1, y: 0, type: 'tile'),
        TilemapCell(x: 2, y: 0, type: 'tile'),
      ],
    );

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        renderBackend: TilemapRenderBackend.canvas,
        onImageError: (_) => errorCount += 1,
      ),
    );
    await _pumpUntil(tester, () => latestStats?.tileCount == 1);

    failedFrame.completeError(StateError('failed image'), StackTrace.current);
    await _pumpUntil(
      tester,
      () => latestStats?.tileCount == 3 && latestStats?.imageCount == 1,
    );

    expect(loadCount, 2);
    expect(errorCount, 1);
    expect(latestStats?.drawCallCount, 1);
  });

  testWidgets('canvas keeps fog and location flow in paint-order children', (
    tester,
  ) async {
    final image = await _createSolidImage(tester, Colors.green);
    addTearDown(image.dispose);
    debugGenesisStaticNetworkImageCompleter = (_) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image.clone())),
      );
    };
    final config = TilemapConfig.fromTiles(
      id: 'canvas-effects',
      width: 2,
      height: 1,
      tileTypes: const {'tile': 'https://canvas.test/effect.png'},
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'tile', shadow: 1),
        TilemapCell(x: 1, y: 0, type: 'tile', locationId: 'location'),
      ],
    );

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        renderBackend: TilemapRenderBackend.canvas,
        blendFogWithShadowTiles: true,
        showLocationImageFlow: true,
        locationNameForTile: (tile) => tile.isLocationTile ? 'Location' : null,
      ),
    );
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('tile-fog-blend-0-0'))
          .evaluate()
          .isNotEmpty,
    );

    expect(
      find.byKey(const ValueKey<String>('tile-fog-blend-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-location-image-flow-1-0')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byType(RawImage), findsNWidgets(2));
  });

  testWidgets('canvas semantics preserve plain and effect paint order', (
    tester,
  ) async {
    final image = await _createSolidImage(tester, Colors.green);
    addTearDown(image.dispose);
    debugGenesisStaticNetworkImageCompleter = (_) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image.clone())),
      );
    };
    final config = TilemapConfig.fromTiles(
      id: 'canvas-semantics-order',
      width: 1,
      height: 3,
      tileTypes: const {
        'first': 'https://canvas.test/semantics.png',
        'effect': 'https://canvas.test/semantics.png',
        'last': 'https://canvas.test/semantics.png',
      },
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'first'),
        TilemapCell(x: 0, y: 1, type: 'effect', locationId: 'location'),
        TilemapCell(x: 0, y: 2, type: 'last'),
      ],
    );
    final semantics = tester.ensureSemantics();

    Future<List<String>> labelsForBackend(TilemapRenderBackend backend) async {
      await tester.pumpWidget(
        _rendererHarness(
          config: config,
          renderBackend: backend,
          showLocationImageFlow: true,
          locationNameForTile: (tile) =>
              tile.isLocationTile ? 'Location' : null,
        ),
      );
      await _pumpUntil(
        tester,
        () => find.semantics.byLabel('last 0,2').evaluate().isNotEmpty,
      );
      final semanticsOwner =
          RendererBinding.instance.renderViews.first.owner!.semanticsOwner!;
      return _semanticLabelsInTraversalOrder(semanticsOwner.rootSemanticsNode!)
          .where(
            (label) =>
                const {'first 0,0', 'effect 0,1', 'last 0,2'}.contains(label),
          )
          .toList(growable: false);
    }

    final widgetLabels = await labelsForBackend(TilemapRenderBackend.widgets);
    final canvasLabels = await labelsForBackend(TilemapRenderBackend.canvas);
    expect(canvasLabels, widgetLabels);
    expect(canvasLabels.toSet(), <String>{
      'first 0,0',
      'effect 0,1',
      'last 0,2',
    });
    semantics.dispose();
  });

  testWidgets('canvas honors the platform invert-colors setting', (
    tester,
  ) async {
    final image = await _createSolidImage(tester, Colors.red);
    addTearDown(image.dispose);
    debugGenesisStaticNetworkImageCompleter = (_) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image.clone())),
      );
    };
    TilemapCanvasRenderStats? latestStats;
    debugTilemapCanvasRenderStatsChanged = (stats) => latestStats = stats;
    final repaintBoundaryKey = GlobalKey();
    final config = TilemapConfig.fromTiles(
      id: 'canvas-invert-colors',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://canvas.test/invert.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        renderBackend: TilemapRenderBackend.canvas,
        repaintBoundaryKey: repaintBoundaryKey,
        invertColors: true,
      ),
    );
    await _pumpUntil(tester, () => latestStats?.imageCount == 1);

    expect(
      await _captureHasColor(
        tester,
        repaintBoundaryKey,
        const Color(0xff0bbcc9),
      ),
      isTrue,
    );
  });
}

Widget _rendererHarness({
  Key? rendererKey,
  required TilemapConfig config,
  required TilemapRenderBackend renderBackend,
  Key? repaintBoundaryKey,
  VoidCallback? onViewportReady,
  double devicePixelRatio = 1,
  bool invertColors = false,
  bool blendFogWithShadowTiles = false,
  bool showLocationImageFlow = false,
  TilemapLocationNameResolver? locationNameForTile,
  ValueChanged<Object>? onImageError,
}) {
  const viewportSize = Size(320, 480);
  return MaterialApp(
    home: Center(
      child: RepaintBoundary(
        key: repaintBoundaryKey,
        child: MediaQuery(
          data: MediaQueryData(
            size: viewportSize,
            devicePixelRatio: devicePixelRatio,
            invertColors: invertColors,
          ),
          child: SizedBox(
            width: viewportSize.width,
            height: viewportSize.height,
            child: TilemapRenderer(
              key: rendererKey,
              config: config,
              renderBackend: renderBackend,
              blendFogWithShadowTiles: blendFogWithShadowTiles,
              showLocationImageFlow: showLocationImageFlow,
              locationNameForTile: locationNameForTile,
              showShadowZeroBorders: false,
              waitForVisibleTileImageFrames: true,
              onImageError: onImageError,
              onViewportReady: onViewportReady,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _zoomInAndPump(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('world-map-zoom-in')));
  await tester.pump();
  await tester.pump();
}

Future<ui.Image> _createSolidImage(WidgetTester tester, Color color) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 8), ui.Paint()..color = color);
    return recorder.endRecording().toImage(8, 8);
  }))!;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() predicate) async {
  for (var frame = 0; frame < 30; frame += 1) {
    if (predicate()) return;
    await tester.pump();
  }
  expect(predicate(), isTrue, reason: 'condition was not met after 30 frames');
}

Future<({bool hasRed, bool hasBlue})> _captureDominantColors(
  WidgetTester tester,
  GlobalKey repaintBoundaryKey,
) async {
  return (await tester.runAsync(() async {
    final boundary =
        repaintBoundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    var hasRed = false;
    var hasBlue = false;
    for (var offset = 0; offset < bytes!.lengthInBytes; offset += 4) {
      final red = bytes.getUint8(offset);
      final green = bytes.getUint8(offset + 1);
      final blue = bytes.getUint8(offset + 2);
      final alpha = bytes.getUint8(offset + 3);
      if (alpha < 200) continue;
      hasRed = hasRed || _isNearColor(red, green, blue, Colors.red);
      hasBlue = hasBlue || _isNearColor(red, green, blue, Colors.blue);
      if (hasRed && hasBlue) break;
    }
    return (hasRed: hasRed, hasBlue: hasBlue);
  }))!;
}

bool _isNearColor(int red, int green, int blue, Color target) {
  const tolerance = 4;
  final argb = target.toARGB32();
  final targetRed = (argb >> 16) & 0xff;
  final targetGreen = (argb >> 8) & 0xff;
  final targetBlue = argb & 0xff;
  return (red - targetRed).abs() <= tolerance &&
      (green - targetGreen).abs() <= tolerance &&
      (blue - targetBlue).abs() <= tolerance;
}

Future<bool> _captureHasColor(
  WidgetTester tester,
  GlobalKey repaintBoundaryKey,
  Color target,
) async {
  return (await tester.runAsync(() async {
    final boundary =
        repaintBoundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    for (var offset = 0; offset < bytes!.lengthInBytes; offset += 4) {
      if (bytes.getUint8(offset + 3) < 200) continue;
      if (_isNearColor(
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
        target,
      )) {
        return true;
      }
    }
    return false;
  }))!;
}

Iterable<String> _semanticLabelsInTraversalOrder(SemanticsNode node) sync* {
  final label = node.getSemanticsData().label;
  if (label.isNotEmpty) yield label;
  for (final child in node.debugListChildrenInOrder(
    DebugSemanticsDumpOrder.traversalOrder,
  )) {
    yield* _semanticLabelsInTraversalOrder(child);
  }
}
