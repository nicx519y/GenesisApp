import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_model.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

void main() {
  final pendingImages = <String, Completer<ui.Image>>{};

  setUp(() {
    pendingImages.clear();
    debugGenesisStaticNetworkImageCompleter = (key) {
      final image = pendingImages.putIfAbsent(
        key.imageUrl,
        Completer<ui.Image>.new,
      );
      return OneFrameImageStreamCompleter(
        image.future.then((value) => ImageInfo(image: value)),
      );
    };
  });

  tearDown(() {
    debugGenesisStaticNetworkImageCompleter = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'mounts visible tiles in six-cell frames before two-cell retained frames',
    (tester) async {
      final config = _denseConfig(id: 'progressive', offset: 0);
      var readyCount = 0;

      await tester.pumpWidget(
        _rendererHarness(
          config: config,
          onViewportReady: () => readyCount += 1,
          waitForVisibleTileImageFrames: true,
        ),
      );

      var mountedKeys = _mountedTileKeys(tester);
      expect(mountedKeys, hasLength(1));
      expect(pendingImages, hasLength(1));
      expect(readyCount, 0);
      _expectCanonicalPaintOrder(mountedKeys);

      final visibleKeys = _visibleTileKeys(tester, config);
      expect(visibleKeys.length, greaterThan(6));
      expect(mountedKeys.every(visibleKeys.contains), true);

      final tileImage = await _createImage();
      pendingImages.values.single.complete(tileImage);

      var previousCount = mountedKeys.length;
      var visibleCompleted = false;
      for (var frame = 0; frame < 100; frame += 1) {
        await tester.pump();
        mountedKeys = _mountedTileKeys(tester);
        _expectCanonicalPaintOrder(mountedKeys);
        final newlyMounted = mountedKeys.length - previousCount;
        if (!visibleCompleted) {
          expect(newlyMounted, inInclusiveRange(0, 6));
          visibleCompleted = visibleKeys.every(mountedKeys.contains);
          if (!visibleCompleted) expect(readyCount, 0);
        } else {
          expect(newlyMounted, inInclusiveRange(0, 2));
        }
        previousCount = mountedKeys.length;
        if (visibleCompleted && mountedKeys.length > visibleKeys.length) break;
      }

      expect(visibleCompleted, true);
      expect(mountedKeys.length, greaterThan(visibleKeys.length));
      expect(readyCount, 1);
      await tester.pump();
      expect(readyCount, 1);
    },
  );

  testWidgets('paused progressive mounting resumes without a ticker', (
    tester,
  ) async {
    final paused = ValueNotifier<bool>(true);
    addTearDown(paused.dispose);
    final config = _denseConfig(id: 'paused', offset: 0);

    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: paused,
        builder: (context, value, _) => TickerMode(
          enabled: false,
          child: _rendererHarness(
            config: config,
            animationsPaused: value,
            isForeground: false,
          ),
        ),
      ),
    );
    expect(_mountedTileKeys(tester), isEmpty);
    await tester.pump();
    expect(_mountedTileKeys(tester), isEmpty);

    paused.value = false;
    await tester.pump();
    expect(_mountedTileKeys(tester), hasLength(1));

    paused.value = true;
    await tester.pump();
    final tileImage = await _createImage();
    pendingImages.values.single.complete(tileImage);
    await tester.pump();
    final pausedCount = _mountedTileKeys(tester).length;
    await tester.pump();
    await tester.pump();
    expect(_mountedTileKeys(tester), hasLength(pausedCount));

    paused.value = false;
    for (var frame = 0; frame < 5; frame += 1) {
      await tester.pump();
      if (_mountedTileKeys(tester).length > pausedCount) break;
    }
    expect(_mountedTileKeys(tester).length, greaterThan(pausedCount));
  });

  testWidgets('starts at most two new tile assets in each mount frame', (
    tester,
  ) async {
    final config = _uniqueAssetConfig();

    await tester.pumpWidget(_rendererHarness(config: config));
    expect(_mountedTileKeys(tester), hasLength(2));
    expect(pendingImages, hasLength(2));

    await tester.pump();
    expect(_mountedTileKeys(tester), hasLength(2));
    expect(pendingImages, hasLength(2));

    final tileImage = await _createImage();
    pendingImages.values.first.complete(tileImage);
    for (var frame = 0; frame < 5; frame += 1) {
      await tester.pump();
      if (_mountedTileKeys(tester).length > 2) break;
    }
    expect(_mountedTileKeys(tester), hasLength(3));
    expect(pendingImages, hasLength(3));
  });

  testWidgets('keeps all retained location labels while tile images mount', (
    tester,
  ) async {
    final config = TilemapConfig.fromTiles(
      id: 'stable-labels',
      width: 2,
      height: 1,
      tileTypes: const {'tile': 'https://progressive.test/labels.png'},
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'tile', locationId: 'first'),
        TilemapCell(x: 1, y: 0, type: 'tile', locationId: 'second'),
      ],
    );

    await tester.pumpWidget(
      _rendererHarness(
        config: config,
        locationNameForTile: (tile) => tile.locationId,
      ),
    );

    expect(_mountedTileKeys(tester), hasLength(1));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('animationsPaused stops and resumes location image flow', (
    tester,
  ) async {
    final paused = ValueNotifier<bool>(false);
    addTearDown(paused.dispose);
    final config = TilemapConfig.fromTiles(
      id: 'paused-image-flow',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://progressive.test/flow.png'},
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'tile', locationId: 'location'),
      ],
    );

    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: paused,
        builder: (context, value, _) => _rendererHarness(
          config: config,
          animationsPaused: value,
          showLocationImageFlow: true,
          locationNameForTile: (_) => 'Location',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final dynamic flowWidget = tester.widget(
      find.byKey(const ValueKey<String>('tile-location-image-flow-0-0')),
    );
    final animation = flowWidget.animation as Animation<double>;
    expect(animation.value, greaterThan(0));

    paused.value = true;
    await tester.pump();
    final pausedValue = animation.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(animation.value, closeTo(pausedValue, 0.000001));

    paused.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(animation.value, isNot(closeTo(pausedValue, 0.000001)));
  });

  testWidgets('locationImageFlowPaused only stops location image flow', (
    tester,
  ) async {
    final paused = ValueNotifier<bool>(false);
    addTearDown(paused.dispose);
    final config = TilemapConfig.fromTiles(
      id: 'location-image-flow-only-paused',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://progressive.test/flow-only.png'},
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'tile', locationId: 'location'),
      ],
    );

    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: paused,
        builder: (context, value, _) => _rendererHarness(
          config: config,
          locationImageFlowPaused: value,
          showLocationImageFlow: true,
          locationNameForTile: (_) => 'Location',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    TilemapRenderer renderer() =>
        tester.widget<TilemapRenderer>(find.byType(TilemapRenderer));
    final dynamic flowWidget = tester.widget(
      find.byKey(const ValueKey<String>('tile-location-image-flow-0-0')),
    );
    final animation = flowWidget.animation as Animation<double>;
    expect(renderer().animationsPaused, isFalse);
    expect(animation.value, greaterThan(0));

    paused.value = true;
    await tester.pump();
    final pausedValue = animation.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(renderer().animationsPaused, isFalse);
    expect(renderer().locationImageFlowPaused, isTrue);
    expect(animation.value, closeTo(pausedValue, 0.000001));

    paused.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(animation.value, isNot(closeTo(pausedValue, 0.000001)));
  });

  testWidgets('a config generation cannot reveal stale queued tiles', (
    tester,
  ) async {
    final config = ValueNotifier<TilemapConfig>(
      _denseConfig(id: 'first', offset: 0),
    );
    addTearDown(config.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<TilemapConfig>(
        valueListenable: config,
        builder: (context, value, _) => _rendererHarness(config: value),
      ),
    );
    expect(_mountedTileKeys(tester), hasLength(1));
    final staleImage = pendingImages.values.single;

    config.value = _denseConfig(id: 'second', offset: 30);
    await tester.pump();
    var mountedKeys = _mountedTileKeys(tester);
    expect(mountedKeys, hasLength(1));
    expect(mountedKeys.every((key) => _tileX(key) >= 30), true);

    final tileImage = await _createImage();
    staleImage.complete(tileImage);
    await tester.pump();
    await tester.pump();
    mountedKeys = _mountedTileKeys(tester);
    expect(mountedKeys, hasLength(1));
    expect(mountedKeys.every((key) => _tileX(key) >= 30), true);
  });

  testWidgets('replaces an unfinished probe when the CDN tier changes', (
    tester,
  ) async {
    final config = TilemapConfig.fromTiles(
      id: 'probe-tier-change',
      width: 1,
      height: 1,
      tileTypes: const {'tile': 'https://progressive.test/tier.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
    );

    await tester.pumpWidget(
      _rendererHarness(config: config, devicePixelRatio: 2),
    );
    expect(pendingImages.keys.single, contains('resize,w_512'));

    await _zoomInAndPump(tester);
    expect(pendingImages, hasLength(1));
    await _zoomInAndPump(tester);
    expect(pendingImages.keys.any((key) => key.contains('resize,w_640')), true);

    await _zoomInAndPump(tester);
    expect(
      pendingImages.keys.any((key) => key.contains('resize,w_1024')),
      false,
    );

    await _zoomInAndPump(tester);
    expect(
      pendingImages.keys.any((key) => key.contains('resize,w_1024')),
      true,
    );
    expect(_mountedTileKeys(tester), hasLength(1));
  });

  testWidgets('releases probes that leave the retained window', (tester) async {
    final config = TilemapConfig.fromTiles(
      id: 'probe-retained-churn',
      width: 100,
      height: 100,
      tileTypes: const {
        'start-a': 'https://progressive.test/start-a.png',
        'start-b': 'https://progressive.test/start-b.png',
        'target-a': 'https://progressive.test/target-a.png',
        'target-b': 'https://progressive.test/target-b.png',
      },
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'start-a', shadow: 1),
        TilemapCell(x: 50, y: 50, type: 'start-a', locationId: 'start'),
        TilemapCell(x: 51, y: 50, type: 'start-b'),
        TilemapCell(
          x: 60,
          y: 50,
          type: 'target-a',
          shadow: 1,
          locationId: 'target',
        ),
        TilemapCell(x: 61, y: 50, type: 'target-b'),
        TilemapCell(x: 99, y: 99, type: 'start-a', shadow: 1),
      ],
    );

    await tester.pumpWidget(
      _rendererHarness(config: config, preferredFocusLocationId: 'start'),
    );
    expect(_mountedTileKeys(tester), contains('tile-50-50'));
    expect(pendingImages, hasLength(2));

    await tester.timedDrag(
      find.byKey(const ValueKey<String>('tilemap-gesture-layer')),
      const Offset(-1250, -625),
      const Duration(milliseconds: 500),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump();

    final mountedKeys = _mountedTileKeys(tester);
    expect(mountedKeys, contains('tile-60-50'));
    expect(mountedKeys, isNot(contains('tile-50-50')));
    expect(pendingImages.length, greaterThanOrEqualTo(3));
  });
}

Widget _rendererHarness({
  required TilemapConfig config,
  VoidCallback? onViewportReady,
  bool animationsPaused = false,
  bool locationImageFlowPaused = false,
  bool isForeground = true,
  String preferredFocusLocationId = '',
  double devicePixelRatio = 1,
  TilemapLocationNameResolver? locationNameForTile,
  bool waitForVisibleTileImageFrames = false,
  bool showLocationImageFlow = false,
}) {
  const viewportSize = Size(320, 480);
  return MaterialApp(
    home: Center(
      child: MediaQuery(
        data: MediaQueryData(
          size: viewportSize,
          devicePixelRatio: devicePixelRatio,
        ),
        child: SizedBox(
          width: viewportSize.width,
          height: viewportSize.height,
          child: TilemapRenderer(
            config: config,
            waitForVisibleTileImageFrames: waitForVisibleTileImageFrames,
            showLocationImageFlow: showLocationImageFlow,
            blendFogWithShadowTiles: false,
            onViewportReady: onViewportReady,
            animationsPaused: animationsPaused,
            locationImageFlowPaused: locationImageFlowPaused,
            isForeground: isForeground,
            preferredFocusLocationId: preferredFocusLocationId,
            locationNameForTile: locationNameForTile,
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

TilemapConfig _denseConfig({required String id, required int offset}) {
  return TilemapConfig.fromTiles(
    id: id,
    width: 50,
    height: 50,
    tileTypes: {'tile': 'https://progressive.test/tile-$id.png'},
    tiles: [
      for (var y = offset; y < offset + 20; y += 1)
        for (var x = offset; x < offset + 20; x += 1)
          TilemapCell(x: x, y: y, type: 'tile'),
    ],
  );
}

Future<ui.Image> _createImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = Colors.green,
  );
  return recorder.endRecording().toImage(1, 1);
}

TilemapConfig _uniqueAssetConfig() {
  const size = 20;
  return TilemapConfig.fromTiles(
    id: 'unique-assets',
    width: size,
    height: size,
    tileTypes: <String, String>{
      for (var index = 0; index < size * size; index += 1)
        'tile-$index': 'https://progressive.test/tile-$index.png',
    },
    tiles: <TilemapCell>[
      for (var y = 0; y < size; y += 1)
        for (var x = 0; x < size; x += 1)
          TilemapCell(x: x, y: y, type: 'tile-${y * size + x}'),
    ],
  );
}

List<String> _mountedTileKeys(WidgetTester tester) {
  final dynamic layer = tester.widget(
    find.byKey(const ValueKey<String>('tilemap-canvas-tile-mount')),
  );
  return [
    for (final dynamic entry in layer.tiles as List<dynamic>)
      'tile-${entry.record.tile.x}-${entry.record.tile.y}',
  ];
}

Set<String> _visibleTileKeys(WidgetTester tester, TilemapConfig config) {
  const viewportSize = Size(320, 480);
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey<String>('tilemap-tile-transform')),
  );
  final visibleBounds = tilemapVisibleSceneBounds(
    transform: transform.transform,
    viewportSize: viewportSize,
  );
  final projection = TilemapProjection.fixed(
    mapWidth: config.width,
    mapHeight: config.height,
  );
  return <String>{
    for (final tile in config.tiles)
      if (_overlaps(
        projection.imageTopLeftForTile(tile) &
            Size.square(projection.tileExtent),
        visibleBounds,
      ))
        'tile-${tile.x}-${tile.y}',
  };
}

bool _overlaps(Rect first, Rect second) {
  final intersection = first.intersect(second);
  return intersection.width > 0 && intersection.height > 0;
}

void _expectCanonicalPaintOrder(List<String> mountedKeys) {
  for (var index = 1; index < mountedKeys.length; index += 1) {
    final previous = _tileCoordinates(mountedKeys[index - 1]);
    final current = _tileCoordinates(mountedKeys[index]);
    final previousDiagonal = previous.$1 + previous.$2;
    final currentDiagonal = current.$1 + current.$2;
    final isBefore =
        previousDiagonal < currentDiagonal ||
        (previousDiagonal == currentDiagonal && previous.$1 < current.$1);
    expect(isBefore, true);
  }
}

int _tileX(String key) => _tileCoordinates(key).$1;

(int, int) _tileCoordinates(String key) {
  final coordinates = key.substring('tile-'.length).split('-');
  return (int.parse(coordinates[0]), int.parse(coordinates[1]));
}
