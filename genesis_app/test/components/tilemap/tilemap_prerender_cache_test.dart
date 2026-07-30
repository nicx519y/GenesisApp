import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/loading/tilemap_prerender_cache.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_model.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';

void main() {
  testWidgets(
    'captures only the configured viewport within the single-frame byte budget',
    (tester) async {
      const viewportSize = Size(400, 300);
      const frameBudget = 2 * 1024 * 1024;
      final boundaryKey = GlobalKey();
      final controller = TilemapPrerenderController(
        onChanged: () {},
        maxCacheBytes: frameBudget * 2,
        maxFrameBytes: frameBudget,
      );
      addTearDown(controller.dispose);
      controller.configure(
        environmentKey: 'capture-environment',
        viewportSize: viewportSize,
        devicePixelRatio: 3,
        activeMapId: 'active-map',
      );

      await tester.pumpWidget(
        _surfaceHarness(viewportSize: viewportSize, boundaryKey: boundaryKey),
      );

      await _captureAndPump(
        tester,
        controller.captureActive(mapId: 'active-map', boundaryKey: boundaryKey),
      );

      final frame = controller.frameFor('active-map');
      expect(frame, isNotNull);
      expect(frame!.logicalSize, viewportSize);
      expect(frame.estimatedByteSize, lessThanOrEqualTo(frameBudget));
      expect(controller.estimatedCacheBytes, frame.estimatedByteSize);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('rejects a boundary that does not match the viewport', (
    tester,
  ) async {
    const configuredViewport = Size(320, 480);
    const boundarySize = Size(300, 480);
    final boundaryKey = GlobalKey();
    final controller = TilemapPrerenderController(onChanged: () {});
    addTearDown(controller.dispose);
    controller.configure(
      environmentKey: 'mismatched-environment',
      viewportSize: configuredViewport,
      devicePixelRatio: 1,
      activeMapId: 'mismatched-map',
    );

    await tester.pumpWidget(
      _surfaceHarness(viewportSize: boundarySize, boundaryKey: boundaryKey),
    );

    await _captureAndPump(
      tester,
      controller.captureActive(
        mapId: 'mismatched-map',
        boundaryKey: boundaryKey,
      ),
    );

    expect(controller.frameFor('mismatched-map'), isNull);
    expect(controller.cachedFrameCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('evicts the least-recently-used frame at maxCachedFrames one', (
    tester,
  ) async {
    const viewportSize = Size(120, 80);
    final controller = TilemapPrerenderController(
      onChanged: () {},
      maxCachedFrames: 1,
    );
    addTearDown(controller.dispose);
    controller.configure(
      environmentKey: 'lru-environment',
      viewportSize: viewportSize,
      devicePixelRatio: 1,
      activeMapId: 'current-map',
    );

    controller.rememberConfig(_singleTileConfig('first-map'));
    await tester.pumpWidget(
      _surfaceHarness(
        viewportSize: viewportSize,
        boundaryKey: controller.candidateBoundaryKey,
        color: Colors.red,
      ),
    );
    await _captureAndPump(tester, controller.captureCandidate());

    expect(controller.frameFor('first-map'), isNotNull);
    expect(controller.cachedFrameCount, 1);

    controller.rememberConfig(_singleTileConfig('second-map'));
    await tester.pumpWidget(
      _surfaceHarness(
        viewportSize: viewportSize,
        boundaryKey: controller.candidateBoundaryKey,
        color: Colors.blue,
      ),
    );
    await _captureAndPump(tester, controller.captureCandidate());
    await tester.pump();

    expect(controller.cachedFrameCount, 1);
    expect(controller.frameFor('first-map'), isNull);
    expect(controller.frameFor('second-map'), isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'memory pressure retains the active frame and clears background work',
    (tester) async {
      const viewportSize = Size(120, 80);
      final activeBoundaryKey = GlobalKey();
      final controller = TilemapPrerenderController(onChanged: () {});
      addTearDown(controller.dispose);
      controller.configure(
        environmentKey: 'memory-pressure-environment',
        viewportSize: viewportSize,
        devicePixelRatio: 1,
        activeMapId: 'active-map',
      );
      controller.rememberConfig(_singleTileConfig('active-map'));

      await tester.pumpWidget(
        _surfaceHarness(
          viewportSize: viewportSize,
          boundaryKey: activeBoundaryKey,
        ),
      );
      await _captureAndPump(
        tester,
        controller.captureActive(
          mapId: 'active-map',
          boundaryKey: activeBoundaryKey,
        ),
      );

      controller.rememberConfig(_singleTileConfig('inactive-map'));
      await tester.pumpWidget(
        _surfaceHarness(
          viewportSize: viewportSize,
          boundaryKey: controller.candidateBoundaryKey,
          color: Colors.red,
        ),
      );
      await _captureAndPump(tester, controller.captureCandidate());

      controller.rememberConfig(_singleTileConfig('background-candidate'));
      controller.rememberConfig(_singleTileConfig('background-queued'));
      expect(controller.cachedFrameCount, 2);
      expect(controller.frameFor('active-map'), isNotNull);
      expect(controller.frameFor('inactive-map'), isNotNull);
      expect(controller.candidateConfig?.id, 'background-candidate');

      controller.handleMemoryPressure();
      await tester.pump();

      expect(controller.cachedFrameCount, 1);
      expect(controller.frameFor('active-map'), isNotNull);
      expect(controller.frameFor('inactive-map'), isNull);
      expect(controller.candidateConfig, isNull);

      controller.configure(
        environmentKey: 'memory-pressure-environment',
        viewportSize: viewportSize,
        devicePixelRatio: 1,
        activeMapId: 'active-map',
      );
      expect(
        controller.candidateConfig,
        isNull,
        reason: 'memory pressure must also discard queued background maps',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('offscreen renderer keeps the normal viewport tile culling', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
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
        boundaryKey: boundaryKey,
        child: TilemapRenderer(
          config: config,
          waitForVisibleTileImageFrames: false,
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

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _surfaceHarness({
  required Size viewportSize,
  required GlobalKey boundaryKey,
  Color color = Colors.black,
  Widget? child,
}) {
  return MaterialApp(
    home: Center(
      child: MediaQuery(
        data: MediaQueryData(size: viewportSize, devicePixelRatio: 1),
        child: SizedBox(
          width: viewportSize.width,
          height: viewportSize.height,
          child: TilemapPrerenderSurface(
            boundaryKey: boundaryKey,
            child: child ?? ColoredBox(color: color),
          ),
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

Future<void> _captureAndPump(WidgetTester tester, Future<void> capture) async {
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    capture.then<void>(
      (_) => completed = true,
      onError: (Object error, StackTrace stackTrace) {
        failure = error;
        failureStack = stackTrace;
        completed = true;
      },
    ),
  );

  for (var frame = 0; frame < 12 && !completed; frame += 1) {
    await tester.pump();
  }
  if (!completed) {
    fail('Tilemap prerender capture did not complete after 12 frames.');
  }
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack!);
  }
}
