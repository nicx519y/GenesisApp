import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/loading/tilemap_prerender_cache.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_model.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

void main() {
  test('warms only one real instance at a time and caps the pool at four', () {
    final controller = TilemapPrerenderController(onChanged: () {});
    addTearDown(controller.dispose);

    final active = _singleTileConfig('active-map');
    const warmMapIds = <String>['first-warm', 'second-warm', 'third-warm'];
    controller.activateMap(active, preferredMapIds: warmMapIds);
    controller.configure(
      environmentKey: 'environment',
      activeMapId: active.id,
      preferredMapIds: warmMapIds,
    );

    expect(controller.residentMapIds, <String>['active-map']);
    expect(controller.warmingMapId, 'active-map');
    controller.markReady(active.id);

    controller.rememberConfig(_singleTileConfig('first-warm'));
    controller.rememberConfig(_singleTileConfig('second-warm'));
    controller.rememberConfig(_singleTileConfig('third-warm'));

    expect(controller.warmingMapId, 'first-warm');
    expect(controller.residentMapIds, <String>['active-map', 'first-warm']);
    expect(controller.pendingMapIds, <String>['second-warm', 'third-warm']);

    controller.markReady('first-warm');

    expect(controller.warmingMapId, 'second-warm');
    expect(controller.residentMapIds, <String>[
      'active-map',
      'first-warm',
      'second-warm',
    ]);
    controller.markReady('second-warm');

    expect(controller.warmingMapId, 'third-warm');
    expect(controller.residentMapIds, <String>[
      'active-map',
      'first-warm',
      'second-warm',
      'third-warm',
    ]);
    expect(
      controller.residentInstanceCount,
      tilemapPrerenderMaxResidentInstances,
    );

    controller.markReady('third-warm');
    controller.rememberConfig(_singleTileConfig('over-budget'));

    expect(controller.residentInstanceCount, 4);
    expect(controller.isResident('over-budget'), isFalse);
  });

  test('activating a ready warm map reuses the resident instance', () {
    final controller = TilemapPrerenderController(onChanged: () {});
    addTearDown(controller.dispose);

    final root = _singleTileConfig('root');
    final child = _singleTileConfig('child');
    controller.activateMap(root, preferredMapIds: <String>[child.id]);
    controller.configure(
      environmentKey: 'environment',
      activeMapId: root.id,
      preferredMapIds: <String>[child.id],
    );
    controller.markReady(root.id);
    controller.rememberConfig(child);
    controller.markReady(child.id);

    final residentBeforeActivation = controller.residentMapIds.toSet();
    final wasReady = controller.activateMap(
      child,
      preferredMapIds: <String>[root.id],
    );

    expect(wasReady, isTrue);
    expect(controller.activeMapId, child.id);
    expect(controller.isReady(child.id), isTrue);
    expect(controller.residentMapIds.toSet(), residentBeforeActivation);
  });

  test('navigation keeps only the requested parent and warm targets', () {
    final controller = TilemapPrerenderController(onChanged: () {});
    addTearDown(controller.dispose);

    final root = _singleTileConfig('root');
    const initialWarmMapIds = <String>[
      'oldest-warm',
      'newest-warm',
      'spare-warm',
    ];
    controller.activateMap(root, preferredMapIds: initialWarmMapIds);
    controller.configure(
      environmentKey: 'environment',
      activeMapId: root.id,
      preferredMapIds: initialWarmMapIds,
    );
    controller.markReady(root.id);

    controller.rememberConfig(_singleTileConfig('oldest-warm'));
    controller.markReady('oldest-warm');
    controller.rememberConfig(_singleTileConfig('newest-warm'));
    controller.markReady('newest-warm');
    controller.rememberConfig(_singleTileConfig('spare-warm'));
    controller.markReady('spare-warm');

    final target = _singleTileConfig('target');
    final wasReady = controller.activateMap(
      target,
      preferredMapIds: <String>[root.id, 'newest-warm'],
    );

    expect(wasReady, isFalse);
    expect(controller.residentInstanceCount, 3);
    expect(controller.isResident('root'), isTrue);
    expect(controller.isResident('oldest-warm'), isFalse);
    expect(controller.isResident('newest-warm'), isTrue);
    expect(controller.isResident('spare-warm'), isFalse);
    expect(controller.isResident('target'), isTrue);
    expect(controller.warmingMapId, 'target');
  });

  test('memory pressure releases warm instances and queued work', () {
    final controller = TilemapPrerenderController(onChanged: () {});
    addTearDown(controller.dispose);

    final active = _singleTileConfig('active');
    const warmMapIds = <String>['warm', 'candidate', 'third'];
    controller.activateMap(active, preferredMapIds: warmMapIds);
    controller.configure(
      environmentKey: 'environment',
      activeMapId: active.id,
      preferredMapIds: warmMapIds,
    );
    controller.markReady(active.id);
    controller.rememberConfig(_singleTileConfig('warm'));
    controller.markReady('warm');
    controller.rememberConfig(_singleTileConfig('candidate'));
    controller.markReady('candidate');
    controller.rememberConfig(_singleTileConfig('third'));

    expect(controller.residentInstanceCount, 4);
    controller.handleMemoryPressure();

    expect(controller.residentMapIds, <String>['active']);
    expect(controller.pendingMapIds, isEmpty);
    expect(controller.isReady('active'), isTrue);
    expect(controller.isResident('warm'), isFalse);
    expect(controller.isResident('candidate'), isFalse);
  });

  test(
    'environment changes keep active state and invalidate warm instances',
    () {
      final controller = TilemapPrerenderController(onChanged: () {});
      addTearDown(controller.dispose);

      final active = _singleTileConfig('active');
      controller.activateMap(active, preferredMapIds: const <String>['warm']);
      controller.configure(
        environmentKey: 'first-environment',
        activeMapId: active.id,
        preferredMapIds: const <String>['warm'],
      );
      controller.markReady(active.id);
      controller.rememberConfig(_singleTileConfig('warm'));
      controller.markReady('warm');

      controller.configure(
        environmentKey: 'second-environment',
        activeMapId: active.id,
        preferredMapIds: const <String>['warm'],
      );

      expect(controller.residentMapIds, <String>['active']);
      expect(controller.isReady('active'), isFalse);
      expect(controller.warmingMapId, 'active');
    },
  );

  testWidgets('warm real renderer keeps the normal viewport tile culling', (
    tester,
  ) async {
    await _primeSuccessfulTileImage(tester);
    final config = TilemapConfig.fromTiles(
      id: 'offscreen-culling',
      width: 100,
      height: 100,
      tileTypes: const {
        'tile': 'https://invalid.example.test/prerender-tile.png',
      },
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'tile', shadow: 1),
        TilemapCell(x: 50, y: 50, type: 'tile'),
        TilemapCell(x: 51, y: 50, type: 'tile', shadow: 1),
        TilemapCell(x: 60, y: 50, type: 'tile', shadow: 1),
        TilemapCell(x: 99, y: 99, type: 'tile', shadow: 1),
      ],
    );

    await tester.pumpWidget(
      _surfaceHarness(
        viewportSize: const Size(320, 480),
        child: TilemapRenderer(
          config: config,
          waitForVisibleTileImageFrames: false,
          isForeground: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('tile-50-50')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tile-51-50')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tile-0-0')), findsNothing);
    expect(find.byKey(const ValueKey<String>('tile-60-50')), findsNothing);
    expect(find.byKey(const ValueKey<String>('tile-99-99')), findsNothing);
    expect(find.byType(Image), findsNWidgets(2));
  });
}

Future<void> _primeSuccessfulTileImage(WidgetTester tester) async {
  final image = (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = Colors.green,
    );
    return recorder.endRecording().toImage(1, 1);
  }))!;
  debugGenesisStaticNetworkImageCompleter = (_) => OneFrameImageStreamCompleter(
    SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
  );
  addTearDown(() {
    debugGenesisStaticNetworkImageCompleter = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
}

Widget _surfaceHarness({required Size viewportSize, required Widget child}) {
  return MaterialApp(
    home: Center(
      child: MediaQuery(
        data: MediaQueryData(size: viewportSize, devicePixelRatio: 1),
        child: SizedBox(
          width: viewportSize.width,
          height: viewportSize.height,
          child: TilemapPrerenderSurface(interactive: false, child: child),
        ),
      ),
    ),
  );
}

TilemapConfig _singleTileConfig(String id) {
  return TilemapConfig.fromTiles(
    id: id,
    width: 1,
    height: 1,
    tileTypes: const {
      'tile': 'https://invalid.example.test/prerender-tile.png',
    },
    tiles: const [TilemapCell(x: 0, y: 0, type: 'tile')],
  );
}
