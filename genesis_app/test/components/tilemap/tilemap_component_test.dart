import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_location_avatars.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_model.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/components/world_map_contract.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

void main() {
  test('tilemap defaults to dark visual mode', () {
    expect(tilemapDefaultVisualMode, TilemapVisualMode.dark);
  });

  test('tilemap visual modes use the specified light and dark palette', () {
    expect(
      tilemapVisualStyleFor(TilemapVisualMode.light).backgroundColor,
      const Color(0xFFFAFAF8),
    );
    expect(
      tilemapVisualStyleFor(TilemapVisualMode.light).gridLineColor,
      const Color(0xFFD7D6D2),
    );
    expect(
      tilemapVisualStyleFor(TilemapVisualMode.dark).backgroundColor,
      const Color(0xFF37362E),
    );
    expect(
      tilemapVisualStyleFor(TilemapVisualMode.dark).gridLineColor,
      const Color(0xFF2E2D26),
    );
  });

  test('tilemap fog opacity follows the land-edge distance field', () {
    const tileExtent = 16.0;
    final fadeDistance = tileExtent * tilemapFogFadeTileExtents;
    final sampledOpacities = <double>[
      for (final distance in <double>[
        0,
        fadeDistance * 0.25,
        fadeDistance * 0.5,
        fadeDistance * 0.75,
        fadeDistance,
      ])
        tilemapFogOpacityForDistance(
          distance: distance,
          tileExtent: tileExtent,
        ),
    ];

    expect(
      sampledOpacities.first,
      tilemapDefaultFogControlPoints.first.opacity,
    );
    for (var index = 1; index < sampledOpacities.length; index += 1) {
      expect(sampledOpacities[index], greaterThan(sampledOpacities[index - 1]));
    }
    for (final point in tilemapDefaultFogControlPoints) {
      expect(
        tilemapFogOpacityForDistance(
          distance: fadeDistance * point.position,
          tileExtent: tileExtent,
        ),
        closeTo(point.opacity, 0.0000001),
      );
    }
    expect(
      tilemapFogOpacityForDistance(
        distance: fadeDistance,
        tileExtent: tileExtent,
      ),
      tilemapFogMaxOpacity,
    );
    expect(tilemapFogMaxOpacity, 1);
    expect(tilemapFogSamplesPerTileExtent, 4);
    expect(tilemapFogVertexBlendMode, BlendMode.modulate);
  });

  test('tilemap fog opacity interpolates editable control points', () {
    const tileExtent = 16.0;
    const controlPoints = [
      TilemapFogControlPoint(position: 0, opacity: 0.1),
      TilemapFogControlPoint(position: 0.4, opacity: 0.7),
      TilemapFogControlPoint(position: 1, opacity: 0.9),
    ];
    final fadeDistance = tileExtent * tilemapFogFadeTileExtents;

    expect(
      tilemapFogOpacityForDistance(
        distance: 0,
        tileExtent: tileExtent,
        controlPoints: controlPoints,
      ),
      0.1,
    );
    expect(
      tilemapFogOpacityForDistance(
        distance: fadeDistance * 0.2,
        tileExtent: tileExtent,
        controlPoints: controlPoints,
      ),
      closeTo(0.4, 0.0001),
    );
    expect(
      tilemapFogOpacityForDistance(
        distance: fadeDistance,
        tileExtent: tileExtent,
        controlPoints: controlPoints,
      ),
      0.9,
    );
  });

  test('tilemap fog distance follows the diamond width-to-height ratio', () {
    const projection = TilemapProjection(
      mapWidth: 32,
      mapHeight: 16,
      tileExtent: 16,
      originX: 8,
    );

    expect(projection.tileDiamondWidth, 16);
    expect(projection.tileDiamondHeight, 8);
    expect(projection.tileDiamondWidthToHeightRatio, 2);
    expect(
      tilemapFogDistanceToSegment(
        point: const Offset(8, 0),
        start: Offset.zero,
        end: Offset.zero,
        verticalScale: projection.tileDiamondWidthToHeightRatio,
      ),
      8,
    );
    expect(
      tilemapFogDistanceToSegment(
        point: const Offset(0, 4),
        start: Offset.zero,
        end: Offset.zero,
        verticalScale: projection.tileDiamondWidthToHeightRatio,
      ),
      8,
    );
    expect(
      tilemapFogDistanceToSegment(
        point: const Offset(0, 8),
        start: Offset.zero,
        end: Offset.zero,
        verticalScale: projection.tileDiamondWidthToHeightRatio,
      ),
      16,
    );
  });

  testWidgets('fog mesh preserves its interpolated alpha', (tester) async {
    final centerColor = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, const Rect.fromLTWH(0, 0, 4, 4));
      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        const [
          Offset(0, 0),
          Offset(4, 0),
          Offset(4, 4),
          Offset(0, 0),
          Offset(4, 4),
          Offset(0, 4),
        ],
        colors: List<Color>.filled(6, const Color(0x40000000)),
      );
      canvas.drawVertices(
        vertices,
        tilemapFogVertexBlendMode,
        ui.Paint()..color = Colors.white,
      );
      final image = await recorder.endRecording().toImage(4, 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = (2 * 4 + 2) * 4;
      final color = (
        red: bytes!.getUint8(offset),
        green: bytes.getUint8(offset + 1),
        blue: bytes.getUint8(offset + 2),
        alpha: bytes.getUint8(offset + 3),
      );
      image.dispose();
      return color;
    });

    expect(centerColor!.red, 0);
    expect(centerColor.green, 0);
    expect(centerColor.blue, 0);
    expect(centerColor.alpha, closeTo(0x40, 1));
  });

  testWidgets(
    'prepared fog geometry keeps the full land boundary after tile culling',
    (tester) async {
      const projection = TilemapProjection(
        mapWidth: 24,
        mapHeight: 16,
        tileExtent: 16,
        originX: 0,
      );
      const land = TilemapCell(x: 0, y: 0, type: 'a');
      const shadow = TilemapCell(x: 1, y: 0, type: 'a', shadow: 1);
      const fieldBounds = Rect.fromLTWH(0, -4, 16, 16);
      final geometry = prepareTilemapFogGeometry(
        tiles: const [land, shadow],
        polygonForTile: projection.polygonForTile,
        tileExtent: projection.tileExtent,
        verticalScale: projection.tileDiamondWidthToHeightRatio,
      );

      TilemapFogField buildField(TilemapFogGeometry? preparedGeometry) {
        return buildTilemapFogField(
          fieldBounds: fieldBounds,
          tiles: const [shadow],
          renderTiles: const [shadow],
          geometry: preparedGeometry,
          polygonForTile: projection.polygonForTile,
          imageBoundsForTile: (tile) =>
              projection.imageTopLeftForTile(tile) &
              Size.square(projection.tileExtent),
          tileExtent: projection.tileExtent,
          tileDiamondWidth: projection.tileDiamondWidth,
          tileDiamondHeight: projection.tileDiamondHeight,
          verticalScale: projection.tileDiamondWidthToHeightRatio,
          controlPoints: tilemapDefaultFogControlPoints,
        );
      }

      Future<int> sampleAlpha(TilemapFogField field) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(
          recorder,
          Offset.zero & Size(fieldBounds.width, fieldBounds.height),
        )..translate(-fieldBounds.left, -fieldBounds.top);
        canvas.drawVertices(
          field.vertices,
          tilemapFogVertexBlendMode,
          ui.Paint()..color = Colors.white,
        );
        final image = await recorder.endRecording().toImage(
          fieldBounds.width.toInt(),
          fieldBounds.height.toInt(),
        );
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final localX = 4;
        final localY = 12;
        final alpha = bytes!.getUint8(
          (localY * fieldBounds.width.toInt() + localX) * 4 + 3,
        );
        image.dispose();
        return alpha;
      }

      final alphas = await tester.runAsync(() async {
        return (
          prepared: await sampleAlpha(buildField(geometry)),
          localOnly: await sampleAlpha(buildField(null)),
        );
      });

      expect(alphas!.prepared, lessThan(alphas.localOnly));
      expect(alphas.localOnly, 255);
    },
  );

  test(
    'fog field preserves overlapping tile vertices across retained bounds',
    () {
      const projection = TilemapProjection(
        mapWidth: 48,
        mapHeight: 24,
        tileExtent: 16,
        originX: 8,
      );
      const land = TilemapCell(x: 0, y: 0, type: 'a');
      const firstShadow = TilemapCell(x: 1, y: 0, type: 'a', shadow: 1);
      const secondShadow = TilemapCell(x: 2, y: 0, type: 'a', shadow: 1);
      const tiles = [land, firstShadow, secondShadow];
      final geometry = prepareTilemapFogGeometry(
        tiles: tiles,
        polygonForTile: projection.polygonForTile,
        tileExtent: projection.tileExtent,
        verticalScale: projection.tileDiamondWidthToHeightRatio,
      );

      TilemapFogField buildField({
        required Rect bounds,
        required List<TilemapCell> renderTiles,
        Map<String, ui.Vertices>? reusableVertices,
      }) {
        return buildTilemapFogField(
          fieldBounds: bounds,
          tiles: tiles,
          renderTiles: renderTiles,
          geometry: geometry,
          polygonForTile: projection.polygonForTile,
          imageBoundsForTile: (tile) =>
              projection.imageTopLeftForTile(tile) &
              Size.square(projection.tileExtent),
          tileExtent: projection.tileExtent,
          tileDiamondWidth: projection.tileDiamondWidth,
          tileDiamondHeight: projection.tileDiamondHeight,
          verticalScale: projection.tileDiamondWidthToHeightRatio,
          controlPoints: tilemapDefaultFogControlPoints,
          reusableShadowTileVertices: reusableVertices,
        );
      }

      final initial = buildField(
        bounds: const Rect.fromLTWH(0, -8, 32, 32),
        renderTiles: const [land, firstShadow],
      );
      final shifted = buildField(
        bounds: const Rect.fromLTWH(8, -8, 40, 32),
        renderTiles: const [firstShadow, secondShadow],
        reusableVertices: initial.shadowTileVertices,
      );

      expect(
        shifted.shadowTileVertices[firstShadow.cellKey],
        same(initial.shadowTileVertices[firstShadow.cellKey]),
      );
      expect(shifted.shadowTileVertices[secondShadow.cellKey], isNotNull);
    },
  );

  test('tilemap config uses explicit sparse map bounds', () {
    final config = TilemapConfig.fromTiles(
      id: 'component_map',
      width: 4,
      height: 3,
      tileTypes: _tileTypes,
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'a'),
        TilemapCell(x: 3, y: 2, type: 'b'),
      ],
    );

    expect(config.id, 'component_map');
    expect(config.width, 4);
    expect(config.height, 3);
    expect(config.tileCount, 2);
    expect(config.baseAssetUrlForTile(config.tiles.first), endsWith('a.png'));
  });

  test('tilemap semantic equality ignores tile order but keeps full data', () {
    final first = TilemapConfig.fromTiles(
      id: 'semantic-map',
      width: 2,
      height: 1,
      tileTypes: const {
        'a': 'https://cdn.example.com/a.png?version=1',
        'b': 'https://cdn.example.com/b.webp',
      },
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc-a'),
        TilemapCell(x: 1, y: 0, type: 'b', shadow: 1),
      ],
    );
    final reordered = TilemapConfig.fromTiles(
      id: 'semantic-map',
      width: 2,
      height: 1,
      tileTypes: const {
        'b': 'https://cdn.example.com/b.webp',
        'a': 'https://cdn.example.com/a.png?version=1',
      },
      tiles: const [
        TilemapCell(x: 1, y: 0, type: 'b', shadow: 1),
        TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc-a'),
      ],
    );
    final changedUrl = TilemapConfig.fromTiles(
      id: 'semantic-map',
      width: 2,
      height: 1,
      tileTypes: const {
        'a': 'https://cdn.example.com/a.png?version=2',
        'b': 'https://cdn.example.com/b.webp',
      },
      tiles: reordered.tiles,
    );
    final changedCell = TilemapConfig.fromTiles(
      id: 'semantic-map',
      width: 2,
      height: 1,
      tileTypes: reordered.tileTypes,
      tiles: const [
        TilemapCell(x: 1, y: 0, type: 'b'),
        TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc-b'),
      ],
    );

    expect(tilemapConfigDataEquals(first, reordered), isTrue);
    expect(tilemapConfigDataEquals(first, changedUrl), isFalse);
    expect(tilemapConfigDataEquals(first, changedCell), isFalse);
  });

  test('tilemap config rejects unknown tile types', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: 0, y: 0, type: 'unknown')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('tilemap config accepts png and webp asset URLs', () {
    final config = TilemapConfig.fromTiles(
      id: 'supported_asset_formats',
      width: 2,
      height: 1,
      tileTypes: const {
        'png': 'https://cdn.example.com/tile/a.png',
        'webp': 'https://cdn.example.com/tile/b.webp',
      },
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'png'),
        TilemapCell(x: 1, y: 0, type: 'webp'),
      ],
    );

    expect(config.tileTypes.keys, containsAll(<String>['png', 'webp']));
  });

  test('tilemap config rejects duplicate and negative coordinates', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [
          TilemapCell(x: 0, y: 0, type: 'a'),
          TilemapCell(x: 0, y: 0, type: 'b'),
        ],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: -1, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('tilemap config rejects invalid dimensions and out-of-bounds tiles', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 0,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: 1, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('tilemap cell exposes optional location interaction', () {
    const locationTile = TilemapCell(
      x: 0,
      y: 0,
      type: 'a',
      locationId: 'loc_1',
    );
    const plainTile = TilemapCell(x: 0, y: 0, type: 'a');

    expect(locationTile.isLocationTile, true);
    expect(plainTile.isLocationTile, false);
    expect(locationTile.hasShadow, false);
    expect(const TilemapCell(x: 0, y: 0, type: 'a', shadow: 1).hasShadow, true);
  });

  test('tilemap config rejects shadow values other than zero or one', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'invalid_shadow',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a', shadow: 2)],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('tilemap config rejects empty tiles and invalid asset URLs', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const <TilemapCell>[],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://cdn.example.com/tile/a_256_256.webp'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://cdn.example.com/tile/a.jpg'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://cdn.example.com/tile/a_256_256.png'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('projection maps grid coordinates to isometric positions', () {
    const projection = TilemapProjection(
      mapWidth: 32,
      mapHeight: 16,
      tileExtent: 16,
      originX: 8,
    );

    expect(
      projection.topLeftForTile(const TilemapCell(x: 1, y: 0, type: 'a')),
      const Offset(16, 4),
    );
  });

  test('tile image pixel size caps device pixel ratio at two', () {
    final projection = TilemapProjection.fixed(mapWidth: 1, mapHeight: 1);

    expect(projection.tilePixelSize(scale: 12, devicePixelRatio: 1.5), 288);
    expect(projection.tilePixelSize(scale: 12, devicePixelRatio: 3), 384);
  });

  test('projection hit tests the tile diamond', () {
    const projection = TilemapProjection(
      mapWidth: 32,
      mapHeight: 16,
      tileExtent: 16,
      originX: 8,
    );
    const tile = TilemapCell(x: 0, y: 0, type: 'a');

    expect(projection.containsPointInTile(tile, const Offset(8, 4)), true);
    expect(projection.containsPointInTile(tile, const Offset(20, 12)), false);
  });

  test('location bubble offset scales together with its tile', () {
    const projection = TilemapProjection(
      mapWidth: 32,
      mapHeight: 16,
      tileExtent: 16,
      originX: 8,
    );
    const tile = TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc_1');
    final center = projection.centerForTile(tile);
    final anchor = tilemapLocationBubbleSceneAnchor(projection, tile);

    final normalTransform = tilemapTransformForSceneFocalPoint(
      sceneFocalPoint: Offset.zero,
      viewportFocalPoint: Offset.zero,
      scale: 8,
    );
    final minimumTransform = tilemapTransformForSceneFocalPoint(
      sceneFocalPoint: Offset.zero,
      viewportFocalPoint: Offset.zero,
      scale: 4,
    );

    expect(
      MatrixUtils.transformPoint(normalTransform, anchor).dy -
          MatrixUtils.transformPoint(normalTransform, center).dy,
      -16,
    );
    expect(
      MatrixUtils.transformPoint(minimumTransform, anchor).dy -
          MatrixUtils.transformPoint(minimumTransform, center).dy,
      -8,
    );
  });

  test('location image flow keeps sweep-pause ratio across durations', () {
    expect(tilemapLocationImageFlowProgress(animationValue: 0, phase: 0), 0);
    expect(
      tilemapLocationImageFlowProgress(animationValue: 1 / 3, phase: 0),
      closeTo(0.5, 0.000001),
    );
    expect(
      tilemapLocationImageFlowProgress(animationValue: 2 / 3, phase: 0),
      isNull,
    );
    expect(
      tilemapLocationImageFlowProgress(animationValue: 0.99, phase: 0),
      isNull,
    );
    expect(
      tilemapLocationImageFlowDurationForSeconds(3),
      const Duration(seconds: 3),
    );
    expect(
      tilemapLocationImageFlowDurationForSeconds(0),
      const Duration(milliseconds: 500),
    );
    expect(
      tilemapLocationImageFlowDurationForSeconds(20),
      const Duration(seconds: 10),
    );
    expect(
      tilemapLocationImageFlowCanvasBlendMode(
        TilemapLocationImageFlowBlendMode.normal,
      ),
      BlendMode.srcATop,
    );
    expect(
      tilemapLocationImageFlowCanvasBlendMode(
        TilemapLocationImageFlowBlendMode.screen,
      ),
      BlendMode.screen,
    );
    expect(
      tilemapLocationImageFlowCanvasBlendMode(
        TilemapLocationImageFlowBlendMode.overlay,
      ),
      BlendMode.overlay,
    );
    expect(
      tilemapLocationImageFlowCanvasBlendMode(
        TilemapLocationImageFlowBlendMode.plus,
      ),
      BlendMode.plus,
    );
    expect(tilemapLocationImageFlowBandWidthFraction, 0.18);
    expect(
      tilemapLocationImageFlowPhase(const TilemapCell(x: 2, y: 3, type: 'a')),
      tilemapLocationImageFlowPhase(const TilemapCell(x: 2, y: 3, type: 'a')),
    );
    expect(
      tilemapLocationImageFlowPhase(const TilemapCell(x: 2, y: 3, type: 'a')),
      isNot(
        tilemapLocationImageFlowPhase(const TilemapCell(x: 3, y: 2, type: 'a')),
      ),
    );
  });

  test('gesture transform keeps the scene focal point stable', () {
    final start = tilemapInitialTransform(
      viewportSize: const Size(320, 640),
      mapSize: const Size(80, 32),
    );
    const focalPoint = Offset(160, 320);
    final scenePoint = MatrixUtils.transformPoint(
      Matrix4.inverted(start),
      focalPoint,
    );

    final transformed = tilemapGestureTransform(
      startTransform: start,
      startFocalPoint: focalPoint,
      currentFocalPoint: focalPoint,
      gestureScale: 2,
    );

    expect(MatrixUtils.transformPoint(transformed, scenePoint), focalPoint);
  });

  test('visible scene bounds cover the complete grid viewport', () {
    final transform = Matrix4.identity()
      ..setEntry(0, 0, 2)
      ..setEntry(1, 1, 2)
      ..setTranslationRaw(10, 20, 0);

    expect(
      tilemapVisibleSceneBounds(
        transform: transform,
        viewportSize: const Size(100, 80),
      ),
      const Rect.fromLTRB(-5, -10, 45, 30),
    );
  });

  test('retained scene bounds preload half a viewport on every side', () {
    expect(
      tilemapRetainedSceneBounds(const Rect.fromLTWH(10, 20, 100, 80)),
      const Rect.fromLTRB(-40, -20, 160, 140),
    );
  });

  test('initial content bounds prefer shadow-zero tiles', () {
    const mixedTiles = [
      TilemapCell(x: 0, y: 0, type: 'a', shadow: 1),
      TilemapCell(x: 1, y: 0, type: 'a', shadow: 1),
      TilemapCell(x: 2, y: 0, type: 'a'),
    ];
    const allShadowTiles = [
      TilemapCell(x: 0, y: 0, type: 'a', shadow: 1),
      TilemapCell(x: 1, y: 0, type: 'a', shadow: 1),
    ];

    expect(tilemapInitialContentTiles(mixedTiles).map((tile) => tile.cellKey), [
      '2,0',
    ]);
    expect(
      tilemapInitialContentTiles(allShadowTiles).map((tile) => tile.cellKey),
      ['0,0', '1,0'],
    );
  });

  test('drag boundary uses shadow-one tile bounds plus two tile padding', () {
    const projection = TilemapProjection(
      mapWidth: 64,
      mapHeight: 32,
      tileExtent: 16,
      originX: 24,
    );
    const tiles = [
      TilemapCell(x: 0, y: 0, type: 'a'),
      TilemapCell(x: 1, y: 1, type: 'a', shadow: 1),
      TilemapCell(x: 2, y: 1, type: 'a', shadow: 1),
    ];

    expect(
      tilemapDragBoundaryForShadowTiles(projection: projection, tiles: tiles),
      const Rect.fromLTRB(-16, -24, 72, 52),
    );
    expect(
      tilemapDragBoundaryForShadowTiles(
        projection: projection,
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      isNull,
    );
  });

  test(
    'drag boundary constraint prevents panning beyond its viewport edge',
    () {
      final oversizedBoundaryTransform = Matrix4.identity()
        ..setEntry(0, 0, 2)
        ..setEntry(1, 1, 2)
        ..setTranslationRaw(50, -200, 0);

      final constrained = tilemapConstrainTransformToBoundary(
        transform: oversizedBoundaryTransform,
        viewportSize: const Size(100, 80),
        sceneBoundary: const Rect.fromLTWH(0, 0, 100, 80),
      );
      expect(constrained.getTranslation().x, 0);
      expect(constrained.getTranslation().y, -80);

      final centered = tilemapConstrainTransformToBoundary(
        transform: Matrix4.identity()..setTranslationRaw(-100, -100, 0),
        viewportSize: const Size(100, 80),
        sceneBoundary: const Rect.fromLTWH(0, 0, 50, 40),
      );
      expect(centered.getTranslation().x, 25);
      expect(centered.getTranslation().y, 20);
    },
  );

  test('initial transform uses a fixed default scale', () {
    const viewportSize = Size(320, 640);
    const contentBounds = Rect.fromLTWH(40, 20, 48, 48);
    final transform = tilemapInitialTransform(
      viewportSize: viewportSize,
      mapSize: const Size(200, 100),
      contentBounds: contentBounds,
    );
    expect(tilemapTransformScale(transform), 12);
    expect(
      MatrixUtils.transformPoint(transform, contentBounds.center),
      viewportSize.center(Offset.zero) + const Offset(0, 20),
    );
  });

  test('initial scale clamps the configured fixed zoom level', () {
    expect(tilemapResolvedInitialScale(12), 12);
    expect(tilemapResolvedInitialScale(1), tilemapInitialScaleMin);
    expect(tilemapResolvedInitialScale(40), tilemapInitialScaleMax);
    expect(tilemapResolvedInitialScale(double.nan), tilemapDefaultInitialScale);
    expect(tilemapDefaultInitialScale, 12);
    expect(tilemapInitialScaleMin, 5);
    expect(tilemapInitialScaleMax, 30);
  });

  test('initial focus uses the first location with the most avatars', () {
    const tiles = [
      TilemapCell(x: 0, y: 0, type: 'a'),
      TilemapCell(x: 1, y: 0, type: 'a', locationId: 'first'),
      TilemapCell(x: 2, y: 0, type: 'a', locationId: 'most'),
      TilemapCell(x: 3, y: 0, type: 'a', locationId: 'tied'),
    ];
    const avatar = UserAvatar('AA', id: 'a', name: 'Ada');

    final selected = tilemapInitialFocusLocationTile(
      tiles: tiles,
      locationAvatarsForTile: (tile) => switch (tile.locationId) {
        'first' => const [avatar],
        'most' || 'tied' => const [avatar, avatar],
        _ => const [],
      },
    );

    expect(selected?.locationId, 'most');
  });

  test('opening location focus takes priority over avatar count', () {
    const tiles = [
      TilemapCell(x: 0, y: 0, type: 'a', locationId: 'opening'),
      TilemapCell(x: 1, y: 0, type: 'a', locationId: 'most'),
    ];
    const avatar = UserAvatar('AA', id: 'a', name: 'Ada');

    final selected = tilemapInitialFocusLocationTile(
      tiles: tiles,
      preferredLocationId: 'opening',
      locationAvatarsForTile: (tile) =>
          tile.locationId == 'most' ? const [avatar, avatar] : const [],
    );

    expect(selected?.locationId, 'opening');
  });

  test('opening focus resolves to its visible ancestor on the current map', () {
    final locationNodes = [
      _locationNode(
        'l1',
        children: [
          _locationNode(
            'l2',
            children: [_locationNode('opening'), _locationNode('other_l3')],
          ),
        ],
      ),
      _locationNode('other_l1'),
    ];

    expect(
      resolveTilemapPreferredVisibleLocationId(
        preferredLocationId: 'opening',
        visibleLocationIds: const ['l1', 'other_l1'],
        locationNodes: locationNodes,
      ),
      'l1',
    );
    expect(
      resolveTilemapPreferredVisibleLocationId(
        preferredLocationId: 'opening',
        visibleLocationIds: const ['l2'],
        locationNodes: locationNodes,
      ),
      'l2',
    );
    expect(
      resolveTilemapPreferredVisibleLocationId(
        preferredLocationId: 'opening',
        visibleLocationIds: const ['opening', 'other_l3'],
        locationNodes: locationNodes,
      ),
      'opening',
    );
  });

  test('initial focus falls back to the first location when all are empty', () {
    const tiles = [
      TilemapCell(x: 0, y: 0, type: 'a'),
      TilemapCell(x: 1, y: 0, type: 'a', locationId: 'first'),
      TilemapCell(x: 2, y: 0, type: 'a', locationId: 'second'),
    ];

    expect(
      tilemapInitialFocusLocationTile(
        tiles: tiles,
        locationAvatarsForTile: (_) => const [],
      )?.locationId,
      'first',
    );
  });

  test('initial transform centers the selected location exactly', () {
    const viewportSize = Size(320, 640);
    const focus = Offset(72, 36);
    final transform = tilemapInitialTransform(
      viewportSize: viewportSize,
      mapSize: const Size(200, 100),
      focus: focus,
    );

    expect(
      MatrixUtils.transformPoint(transform, focus),
      viewportSize.center(Offset.zero),
    );
  });

  test('gesture scale clamps directly at limits without elastic overflow', () {
    final start = tilemapInitialTransform(
      viewportSize: const Size(320, 640),
      mapSize: const Size(80, 32),
    );
    const focalPoint = Offset(160, 320);

    final maximum = tilemapGestureTransform(
      startTransform: start,
      startFocalPoint: focalPoint,
      currentFocalPoint: focalPoint,
      gestureScale: 100,
    );
    final minimum = tilemapGestureTransform(
      startTransform: start,
      startFocalPoint: focalPoint,
      currentFocalPoint: focalPoint,
      gestureScale: 0.01,
    );

    expect(tilemapTransformScale(maximum), tilemapMaxScale);
    expect(tilemapTransformScale(minimum), tilemapMinScale);
  });

  test('tile URL resolution selects each density tier', () {
    const baseUrl = 'https://cdn.example.com/tile/a.png';

    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 0),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_128,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 128),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_128,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 129),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_256,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 257),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_512,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 513),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_640,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 576),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_640,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 641),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_1024,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 2048),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_1024,image/format,webp',
    );
  });

  test('tile URL resolution replaces query and fragment with OSS resize', () {
    expect(
      resolveTilemapAssetForDisplaySize(
        'https://cdn.example.com/tile/a.png?token=abc#preview',
        200,
      ),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_256,image/format,webp',
    );
  });

  test('tile URL resolution supports webp base assets', () {
    expect(
      resolveTilemapAssetForDisplaySize(
        'https://cdn.example.com/tile/a.webp',
        200,
      ),
      'https://cdn.example.com/tile/a.webp'
      '?x-oss-process=image/resize,w_256,image/format,webp',
    );
  });

  test('tile URL resolution follows the production CDN OSS format', () {
    expect(
      resolveTilemapAssetForDisplaySize(
        'https://cdn-001.worldo.ai/predata/tiles/tile_d_1/L1/tiles/'
        'L1_default__modern__urban_dense__warm_cozy_v4.png'
        '?x-oss-process=image/format,webp',
        512,
      ),
      'https://cdn-001.worldo.ai/predata/tiles/tile_d_1/L1/tiles/'
      'L1_default__modern__urban_dense__warm_cozy_v4.png'
      '?x-oss-process=image/resize,w_512,image/format,webp',
    );
  });

  test(
    'tile image load plan de-duplicates requests and weights tile progress',
    () {
      final config = TilemapConfig.fromTiles(
        id: 'weighted-loading',
        width: 3,
        height: 1,
        tileTypes: const {
          'a': 'https://cdn.example.com/tile/a.png',
          'b': 'https://cdn.example.com/tile/b.webp',
        },
        tiles: const [
          TilemapCell(x: 0, y: 0, type: 'a'),
          TilemapCell(x: 1, y: 0, type: 'a'),
          TilemapCell(x: 2, y: 0, type: 'b'),
        ],
      );

      final plan = TilemapImageLoadPlan.forConfig(
        config: config,
        displayTilePixelSize: 200,
      );

      expect(plan.totalTileCount, 3);
      expect(plan.backgroundTileCountByAsset, isEmpty);
      expect(plan.tileCountByAsset, {
        'https://cdn.example.com/tile/a.png'
                '?x-oss-process=image/resize,w_256,image/format,webp':
            2,
        'https://cdn.example.com/tile/b.webp'
                '?x-oss-process=image/resize,w_256,image/format,webp':
            1,
      });
      expect(
        tilemapImageLoadProgress(loadedTileCount: 2, totalTileCount: 3),
        closeTo(2 / 3, 0.0001),
      );
      expect(
        tilemapImageLoadProgress(loadedTileCount: 4, totalTileCount: 3),
        1,
      );
      expect(
        tilemapImageLoadProgress(loadedTileCount: 0, totalTileCount: 0),
        0,
      );
    },
  );

  test('tile image load plan separates initial viewport from background', () {
    final config = TilemapConfig.fromTiles(
      id: 'visible-first-loading',
      width: 100,
      height: 100,
      tileTypes: const {
        'a': 'https://cdn.example.com/tile/a.png',
        'b': 'https://cdn.example.com/tile/b.webp',
      },
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'a', locationId: 'focus'),
        TilemapCell(x: 90, y: 90, type: 'a'),
        TilemapCell(x: 91, y: 91, type: 'b'),
      ],
    );

    final plan = TilemapImageLoadPlan.forConfig(
      config: config,
      displayTilePixelSize: 200,
      viewportSize: const Size(320, 480),
      initialScale: 12,
      preferredLocationId: 'focus',
    );

    expect(plan.totalTileCount, 1);
    expect(plan.tileCountByAsset, {
      'https://cdn.example.com/tile/a.png'
              '?x-oss-process=image/resize,w_256,image/format,webp':
          1,
    });
    expect(plan.backgroundTileCountByAsset, {
      'https://cdn.example.com/tile/b.webp'
              '?x-oss-process=image/resize,w_256,image/format,webp':
          1,
    });
  });

  testWidgets('renderer dispatches only location tiles without tap highlight', (
    tester,
  ) async {
    TilemapCell? tappedTile;
    final config = TilemapConfig.fromTiles(
      id: 'location_tile',
      width: 1,
      height: 1,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc_1')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: TilemapRenderer(
            config: config,
            onTileAction: (tile) async => tappedTile = tile,
            locationNameForTile: (_) => 'High School',
            showRecentChatForTile: (_) => true,
            showEventForTile: (_) => true,
          ),
        ),
      ),
    );
    await tester.pump();

    final grid = find.byKey(const ValueKey<String>('tilemap-grid'));
    final gestureLayer = find.byKey(
      const ValueKey<String>('tilemap-gesture-layer'),
    );
    expect(grid, findsOneWidget);
    expect(tester.getSize(grid), tester.getSize(gestureLayer));
    expect(find.text('High School'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('tilemap-recent-chat-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tilemap-event-icon')),
      findsOneWidget,
    );
    final eventRect = tester.getRect(
      find.byKey(const ValueKey<String>('tilemap-event-icon')),
    );
    final recentRect = tester.getRect(
      find.byKey(const ValueKey<String>('tilemap-recent-chat-icon')),
    );
    expect(eventRect.right, lessThan(recentRect.left));
    expect(
      find.byKey(const ValueKey<String>('tile-location-label-0-0')),
      findsOneWidget,
    );
    final imageFlow = find.byKey(
      const ValueKey<String>('tile-location-image-flow-0-0'),
    );
    expect(imageFlow, findsOneWidget);
    expect(
      find.ancestor(
        of: imageFlow,
        matching: find.byKey(const ValueKey<String>('tile-0-0')),
      ),
      findsOneWidget,
    );
    expect(tester.renderObject(imageFlow).isRepaintBoundary, true);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('tile-location-pointer-High School')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-location-dot-High School')),
      findsNothing,
    );
    final bubbleBody = tester.widget<Container>(
      find.byKey(
        const ValueKey<String>('tile-location-bubble-body-High School'),
      ),
    );
    final labelDecoration = bubbleBody.decoration! as BoxDecoration;
    expect(labelDecoration.color, Colors.black.withValues(alpha: 0.4));
    expect(labelDecoration.borderRadius, BorderRadius.circular(4));
    final locationName = tester.widget<Text>(find.text('High School'));
    expect(locationName.textAlign, TextAlign.center);
    expect(locationName.softWrap, true);
    expect(locationName.style?.color, Colors.white);
    expect(locationName.style?.fontSize, 12);
    expect(locationName.style?.height, 1.2);
    expect(locationName.style?.fontWeight, FontWeight.w600);

    final tileRect = tester.getRect(
      find.byKey(const ValueKey<String>('tile-0-0')),
    );
    final bubbleBodyRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('tile-location-bubble-body-High School'),
      ),
    );
    expect(
      bubbleBodyRect.bottom,
      closeTo(tileRect.center.dy + tileRect.height / 8, 0.01),
    );
    expect(bubbleBodyRect.center.dx, closeTo(tileRect.center.dx, 0.01));
    expect(eventRect.left - bubbleBodyRect.right, closeTo(3, 0.01));
    expect(recentRect.left - eventRect.right, closeTo(3, 0.01));
    await tester.tap(
      find.byKey(
        const ValueKey<String>('tile-location-bubble-body-High School'),
      ),
    );
    await tester.pump();
    expect(tappedTile?.locationId, 'loc_1');

    tappedTile = null;
    final tileCenter = tileRect.center + Offset(0, tileRect.height / 4);
    await tester.tapAt(tileCenter);
    await tester.pump();

    expect(tappedTile?.locationId, 'loc_1');
    expect(
      find.byKey(const ValueKey<String>('tile-highlight-0-0')),
      findsNothing,
    );
  });

  testWidgets(
    'multi-line location name pushes avatars and message bubble down',
    (tester) async {
      final config = TilemapConfig.fromTiles(
        id: 'wrapped_location_label',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc_1')],
      );
      const avatar = UserAvatar('AA', id: 'char_1', name: 'Ada');

      Widget harness(String name) {
        return MaterialApp(
          home: SizedBox(
            width: 320,
            height: 480,
            child: DefaultTextStyle(
              style: const TextStyle(letterSpacing: 4),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: TilemapRenderer(
                config: config,
                locationNameForTile: (_) => name,
                locationAvatarsForTile: (_) => const [avatar],
                messageBubbles: const [
                  WorldMapMessageBubble(
                    characterId: 'char_1',
                    content: 'Hello from this location.',
                  ),
                ],
              ),
            ),
          ),
        );
      }

      Size expectedLabelSize(String name) {
        final painter = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              leadingDistribution: TextLeadingDistribution.even,
              fontWeight: FontWeight.w600,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 135);
        final longestLine = painter.computeLineMetrics().fold<double>(
          0,
          (width, line) => math.max(width, line.width),
        );
        return Size(
          (longestLine.ceilToDouble() + 6).clamp(6, 141),
          painter.height + 8,
        );
      }

      const singleLineName = 'Cafe';
      await tester.pumpWidget(harness(singleLineName));
      await tester.pump();
      final singleLabelRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tile-location-bubble-body-$singleLineName'),
        ),
      );
      final singleAvatarRect = tester.getRect(
        find.byKey(const ValueKey<String>('tilemap-location-avatar-char_1')),
      );
      final singleMessageRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tilemap-character-message-bubble-body'),
        ),
      );

      for (final singleLineName in const ['Campus S', 'Hartley Hall']) {
        await tester.pumpWidget(harness(singleLineName));
        await tester.pump();
        final labelRect = tester.getRect(
          find.byKey(
            ValueKey<String>('tile-location-bubble-body-$singleLineName'),
          ),
        );

        final expectedSize = expectedLabelSize(singleLineName);

        expect(
          labelRect.height,
          closeTo(expectedSize.height, 0.01),
          reason: '$singleLineName must use the canonical 135px text layout',
        );
        expect(labelRect.width, closeTo(expectedSize.width, 0.01));
      }

      const wrappedName =
          'A Very Long Location Name That Must Wrap Onto Another Line';
      await tester.pumpWidget(harness(wrappedName));
      await tester.pump();
      final wrappedLabelRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tile-location-bubble-body-$wrappedName'),
        ),
      );
      final wrappedAvatarRect = tester.getRect(
        find.byKey(const ValueKey<String>('tilemap-location-avatar-char_1')),
      );
      final wrappedMessageRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tilemap-character-message-bubble-body'),
        ),
      );

      expect(wrappedLabelRect.height, greaterThan(singleLabelRect.height));
      final wrappedParagraph = tester.renderObject<RenderParagraph>(
        find.text(wrappedName),
      );
      expect(wrappedParagraph.maxLines, greaterThan(1));
      expect(wrappedParagraph.didExceedMaxLines, isFalse);
      expect(wrappedParagraph.size.height, greaterThan(singleLabelRect.height));
      expect(wrappedLabelRect.top, closeTo(singleLabelRect.top, 0.01));
      expect(wrappedAvatarRect.top, greaterThan(singleAvatarRect.top));
      expect(wrappedMessageRect.top, greaterThan(singleMessageRect.top));

      const unevenWrappedName = 'WWWWWWWWWW iiiiiiiiii';
      await tester.pumpWidget(harness(unevenWrappedName));
      await tester.pump();
      final unevenWrappedLabelRect = tester.getRect(
        find.byKey(
          const ValueKey<String>(
            'tile-location-bubble-body-$unevenWrappedName',
          ),
        ),
      );
      expect(
        unevenWrappedLabelRect.height,
        greaterThan(singleLabelRect.height),
      );
      final unevenExpectedSize = expectedLabelSize(unevenWrappedName);
      expect(
        unevenWrappedLabelRect.width,
        closeTo(unevenExpectedSize.width, 0.01),
      );
      expect(unevenWrappedLabelRect.width, lessThan(141));
    },
  );

  testWidgets('renderer reuses legacy zoom control in the bottom-right', (
    tester,
  ) async {
    final config = TilemapConfig.fromTiles(
      id: 'zoom_control',
      width: 1,
      height: 1,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'a', shadow: 1)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 480,
            child: TilemapRenderer(config: config),
          ),
        ),
      ),
    );
    await tester.pump();

    final transformFinder = find.byKey(
      const ValueKey<String>('tilemap-tile-transform'),
    );
    final zoomControl = find.byKey(
      const ValueKey<String>('world-map-zoom-control'),
    );
    final zoomIn = find.byKey(const ValueKey<String>('world-map-zoom-in'));
    final zoomOut = find.byKey(const ValueKey<String>('world-map-zoom-out'));
    final initialScale = tester
        .widget<Transform>(transformFinder)
        .transform
        .getMaxScaleOnAxis();

    expect(zoomControl, findsOneWidget);
    expect(zoomIn, findsOneWidget);
    expect(zoomOut, findsOneWidget);
    expect(tester.getBottomRight(zoomControl), const Offset(548, 510));

    await tester.tap(zoomIn);
    await tester.pump();

    final zoomedInScale = tester
        .widget<Transform>(transformFinder)
        .transform
        .getMaxScaleOnAxis();
    expect(
      zoomedInScale,
      closeTo(initialScale * tilemapZoomControlScaleFactor, 0.0001),
    );

    await tester.tap(zoomOut);
    await tester.pump();

    expect(
      tester.widget<Transform>(transformFinder).transform.getMaxScaleOnAxis(),
      closeTo(initialScale, 0.0001),
    );
  });

  testWidgets(
    'renderer only enables image flow for named shadow-zero location tiles',
    (tester) async {
      await _primeSuccessfulTileImage(tester);
      final config = TilemapConfig.fromTiles(
        id: 'location_image_flow',
        width: 3,
        height: 1,
        tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
        tiles: const [
          TilemapCell(x: 0, y: 0, type: 'a', locationId: 'named'),
          TilemapCell(x: 1, y: 0, type: 'a', locationId: 'blank'),
          TilemapCell(
            x: 2,
            y: 0,
            type: 'a',
            shadow: 1,
            locationId: 'shadow_named',
          ),
        ],
      );

      Widget renderer({
        bool showLocationImageFlow = true,
        bool disableAnimations = false,
      }) {
        return MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: TilemapRenderer(
              config: config,
              showLocationImageFlow: showLocationImageFlow,
              locationNameForTile: (tile) => switch (tile.locationId) {
                'named' => 'Named place',
                'shadow_named' => 'Shadow named place',
                _ => ' ',
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(renderer());
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tile-location-image-flow-0-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tile-location-image-flow-1-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('tile-location-image-flow-2-0')),
        findsNothing,
      );

      await tester.pumpWidget(renderer(showLocationImageFlow: false));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('tile-location-image-flow-0-0')),
        findsNothing,
      );

      await tester.pumpWidget(renderer(disableAnimations: true));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('tile-location-image-flow-0-0')),
        findsNothing,
      );
    },
  );

  testWidgets('shadow location tile applies fog without image flow', (
    tester,
  ) async {
    final config = TilemapConfig.fromTiles(
      id: 'shadow_location_image_flow',
      width: 2,
      height: 1,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [
        TilemapCell(
          x: 0,
          y: 0,
          type: 'a',
          shadow: 1,
          locationId: 'shadow_location',
        ),
        TilemapCell(x: 1, y: 0, type: 'a'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TilemapRenderer(
          config: config,
          locationNameForTile: (_) => 'Shadow place',
        ),
      ),
    );
    await tester.pump();

    final fogBlend = find.byKey(const ValueKey<String>('tile-fog-blend-0-0'));
    final imageFlow = find.byKey(
      const ValueKey<String>('tile-location-image-flow-0-0'),
    );
    expect(fogBlend, findsOneWidget);
    expect(imageFlow, findsNothing);
  });

  testWidgets(
    'fog-blended tile caches its stable composite and invalidates on fog changes',
    (tester) async {
      await _primeSuccessfulTileImage(tester);
      final config = TilemapConfig.fromTiles(
        id: 'fog_blend_raster_cache',
        width: 2,
        height: 1,
        tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
        tiles: const [
          TilemapCell(x: 0, y: 0, type: 'a', shadow: 1),
          TilemapCell(x: 1, y: 0, type: 'a'),
        ],
      );

      Widget renderer({
        List<TilemapFogControlPoint> fogControlPoints =
            tilemapDefaultFogControlPoints,
      }) {
        return MaterialApp(
          home: SizedBox(
            width: 320,
            height: 480,
            child: TilemapRenderer(
              config: config,
              fogControlPoints: fogControlPoints,
            ),
          ),
        );
      }

      await tester.pumpWidget(renderer());
      await tester.pump();

      final fogBlend = find.byKey(const ValueKey<String>('tile-fog-blend-0-0'));
      final initialRenderObject = tester.renderObject(fogBlend);
      final initialBoundaryLayer = initialRenderObject.debugLayer;

      expect(initialRenderObject.isRepaintBoundary, isTrue);
      expect(initialBoundaryLayer, isA<OffsetLayer>());
      expect(
        debugTilemapFogBlendPaintCount(initialRenderObject),
        greaterThanOrEqualTo(1),
      );

      await _pumpUntil(
        tester,
        () => debugTilemapFogBlendHasRasterizedComposite(initialRenderObject),
      );
      await tester.pump();

      final initialPictureLayer = _firstPictureLayer(
        initialRenderObject.debugLayer!,
      );
      final initialPicture = initialPictureLayer.picture;
      final initialBlendPaintCount = debugTilemapFogBlendPaintCount(
        initialRenderObject,
      );
      final initialRasterizedPaintCount = debugTilemapFogRasterizedPaintCount(
        initialRenderObject,
      );

      expect(initialRasterizedPaintCount, greaterThanOrEqualTo(1));
      expect(initialPictureLayer.willChangeHint, isFalse);

      await tester.pumpWidget(renderer());
      await tester.pump();

      final stableRenderObject = tester.renderObject(fogBlend);
      final stablePictureLayer = _firstPictureLayer(
        stableRenderObject.debugLayer!,
      );
      expect(stableRenderObject, same(initialRenderObject));
      expect(stableRenderObject.debugLayer, same(initialBoundaryLayer));
      expect(stablePictureLayer, same(initialPictureLayer));
      expect(stablePictureLayer.picture, same(initialPicture));
      expect(
        debugTilemapFogBlendPaintCount(stableRenderObject),
        initialBlendPaintCount,
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('tilemap-gesture-layer')),
        const Offset(-8, 0),
      );
      await tester.pump();

      final transformedRenderObject = tester.renderObject(fogBlend);
      final transformedPictureLayer = _firstPictureLayer(
        transformedRenderObject.debugLayer!,
      );
      expect(transformedRenderObject, same(initialRenderObject));
      expect(transformedRenderObject.debugLayer, same(initialBoundaryLayer));
      expect(transformedPictureLayer, same(initialPictureLayer));
      expect(transformedPictureLayer.picture, same(initialPicture));
      expect(
        debugTilemapFogBlendPaintCount(transformedRenderObject),
        initialBlendPaintCount,
      );

      await tester.pumpWidget(
        renderer(
          fogControlPoints: const [
            TilemapFogControlPoint(position: 0, opacity: 0.2),
            TilemapFogControlPoint(position: 1, opacity: 1),
          ],
        ),
      );
      await tester.pump();

      final invalidatedRenderObject = tester.renderObject(fogBlend);
      expect(invalidatedRenderObject, same(initialRenderObject));
      expect(
        debugTilemapFogBlendPaintCount(invalidatedRenderObject),
        initialBlendPaintCount + 1,
      );
      await _pumpUntil(
        tester,
        () =>
            debugTilemapFogBlendHasRasterizedComposite(invalidatedRenderObject),
      );
      await tester.pump();

      final recachedPictureLayer = _firstPictureLayer(
        invalidatedRenderObject.debugLayer!,
      );
      expect(recachedPictureLayer.picture, isNot(same(initialPicture)));
      expect(
        debugTilemapFogRasterizedPaintCount(invalidatedRenderObject),
        greaterThan(initialRasterizedPaintCount),
      );
      expect(recachedPictureLayer.willChangeHint, isFalse);
    },
  );

  testWidgets(
    'fog bitmap cache toggle releases and restores the cached composite',
    (tester) async {
      await _primeSuccessfulTileImage(tester);
      final config = TilemapConfig.fromTiles(
        id: 'fog_blend_raster_cache_toggle',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a', shadow: 1)],
      );

      Widget renderer({required bool cacheFogTileBitmaps}) {
        return MaterialApp(
          home: SizedBox(
            width: 320,
            height: 480,
            child: TilemapRenderer(
              config: config,
              cacheFogTileBitmaps: cacheFogTileBitmaps,
            ),
          ),
        );
      }

      await tester.pumpWidget(renderer(cacheFogTileBitmaps: true));
      await tester.pump();

      final fogBlend = find.byKey(const ValueKey<String>('tile-fog-blend-0-0'));
      final renderObject = tester.renderObject(fogBlend);
      await _pumpUntil(
        tester,
        () => debugTilemapFogBlendHasRasterizedComposite(renderObject),
      );
      expect(debugTilemapFogBlendHasRasterizedComposite(renderObject), isTrue);

      await tester.pumpWidget(renderer(cacheFogTileBitmaps: false));
      await tester.pump();

      final disabledRenderObject = tester.renderObject(fogBlend);
      expect(disabledRenderObject, same(renderObject));
      expect(
        debugTilemapFogBlendHasRasterizedComposite(disabledRenderObject),
        isFalse,
      );
      final disabledBlendPaintCount = debugTilemapFogBlendPaintCount(
        disabledRenderObject,
      );
      expect(disabledBlendPaintCount, greaterThanOrEqualTo(2));

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        debugTilemapFogBlendHasRasterizedComposite(disabledRenderObject),
        isFalse,
      );

      await tester.pumpWidget(renderer(cacheFogTileBitmaps: true));
      await tester.pump();
      await _pumpUntil(
        tester,
        () => debugTilemapFogBlendHasRasterizedComposite(disabledRenderObject),
      );

      expect(
        debugTilemapFogBlendHasRasterizedComposite(disabledRenderObject),
        isTrue,
      );
      expect(
        debugTilemapFogBlendPaintCount(disabledRenderObject),
        greaterThan(disabledBlendPaintCount),
      );
    },
  );

  testWidgets('fog composite refreshes when a delayed image frame arrives', (
    tester,
  ) async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final image = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = Colors.green,
      );
      return recorder.endRecording().toImage(1, 1);
    }))!;
    final delayedFrame = Completer<ImageInfo>();
    debugGenesisStaticNetworkImageCompleter = (_) =>
        OneFrameImageStreamCompleter(delayedFrame.future);
    addTearDown(_resetDebugTileImageCompleter);
    final config = TilemapConfig.fromTiles(
      id: 'delayed_fog_tile_frame',
      width: 1,
      height: 1,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'a', shadow: 1)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: TilemapRenderer(config: config),
        ),
      ),
    );
    await tester.pump();

    final renderObject = tester.renderObject(
      find.byKey(const ValueKey<String>('tile-fog-blend-0-0')),
    );
    await _pumpUntil(
      tester,
      () => debugTilemapFogBlendHasRasterizedComposite(renderObject),
    );
    await tester.pump();
    final transparentBlendPaintCount = debugTilemapFogBlendPaintCount(
      renderObject,
    );

    delayedFrame.complete(ImageInfo(image: image));
    await tester.pump();
    await tester.pump();

    expect(
      debugTilemapFogBlendPaintCount(renderObject),
      greaterThan(transparentBlendPaintCount),
    );
    await _pumpUntil(
      tester,
      () => debugTilemapFogBlendHasRasterizedComposite(renderObject),
    );
  });

  testWidgets('renderer exposes configurable fog and wireframe layers', (
    tester,
  ) async {
    await _primeSuccessfulTileImage(tester);
    final config = TilemapConfig.fromTiles(
      id: 'tile_shadow',
      width: 2,
      height: 1,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'a', shadow: 1),
        TilemapCell(x: 1, y: 0, type: 'a'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: TilemapRenderer(
            config: config,
            blendFogWithShadowTiles: false,
            showShadowZeroBorders: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final fogLayer = find.byKey(const ValueKey<String>('tilemap-fog-layer'));
    expect(fogLayer, findsOneWidget);
    expect(tester.widget<IgnorePointer>(fogLayer).ignoring, true);
    expect(
      tester.getSize(fogLayer),
      tester.getSize(
        find.byKey(const ValueKey<String>('tilemap-gesture-layer')),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('tilemap-fog-paint')),
      findsOneWidget,
    );
    final shadowZeroBorderLayer = find.byKey(
      const ValueKey<String>('tilemap-shadow-zero-border-layer'),
    );
    expect(shadowZeroBorderLayer, findsOneWidget);
    expect(tester.widget<IgnorePointer>(shadowZeroBorderLayer).ignoring, true);
    expect(
      tester.getSize(shadowZeroBorderLayer),
      tester.getSize(
        find.byKey(const ValueKey<String>('tilemap-gesture-layer')),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('tilemap-shadow-zero-border-paint')),
      findsOneWidget,
    );
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('tile-shadow-mask-0-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-shadow-mask-1-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tilemap-shadow-zero-restore-layer')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-fog-blend-0-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-fog-blend-1-0')),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: TilemapRenderer(
            config: config,
            blendFogWithShadowTiles: true,
            showShadowZeroBorders: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final renderer = tester.widget<TilemapRenderer>(
      find.byType(TilemapRenderer),
    );
    expect(renderer.blendFogWithShadowTiles, true);
    expect(renderer.showShadowZeroBorders, false);
    expect(
      find.byKey(const ValueKey<String>('tilemap-shadow-zero-border-layer')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tilemap-shadow-zero-restore-layer')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-fog-blend-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-fog-blend-1-0')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('tile-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tile-1-0')), findsOneWidget);
  });

  testWidgets('renderer creates tiles and labels only inside retained bounds', (
    tester,
  ) async {
    await _primeSuccessfulTileImage(tester);
    final config = TilemapConfig.fromTiles(
      id: 'culled_tiles',
      width: 100,
      height: 100,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'a', shadow: 1, locationId: 'far_top'),
        TilemapCell(x: 50, y: 50, type: 'a', locationId: 'center'),
        TilemapCell(x: 51, y: 50, type: 'a', shadow: 1, locationId: 'nearby'),
        TilemapCell(
          x: 60,
          y: 50,
          type: 'a',
          shadow: 1,
          locationId: 'pan_target',
        ),
        TilemapCell(
          x: 99,
          y: 99,
          type: 'a',
          shadow: 1,
          locationId: 'far_bottom',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 480,
            child: TilemapRenderer(
              config: config,
              locationNameForTile: (tile) => tile.locationId,
              locationAvatarsForTile: (tile) => tile.locationId == 'center'
                  ? const [UserAvatar('AA', id: 'a', name: 'Ada')]
                  : const [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('tile-50-50')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tile-51-50')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tile-0-0')), findsNothing);
    expect(find.byKey(const ValueKey<String>('tile-99-99')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('tile-fog-blend-51-50')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-fog-blend-0-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-location-label-50-50')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-location-label-0-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-location-image-flow-50-50')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-location-image-flow-0-0')),
      findsNothing,
    );
    expect(find.byType(Image), findsNWidgets(2));

    await tester.timedDrag(
      find.byKey(const ValueKey<String>('tilemap-gesture-layer')),
      const Offset(-1250, -625),
      const Duration(milliseconds: 500),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('tile-50-50')), findsNothing);
    expect(find.byKey(const ValueKey<String>('tile-60-50')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('tile-location-label-60-50')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-location-image-flow-60-50')),
      findsNothing,
    );
  });

  testWidgets('renderer reports network tile image failures', (tester) async {
    _primeFailedTileImage();
    Object? imageError;
    final config = TilemapConfig.fromTiles(
      id: 'network_failure',
      width: 1,
      height: 1,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: TilemapRenderer(
            config: config,
            onImageError: (error) => imageError = error,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(imageError, isNotNull);
  });

  testWidgets(
    'location avatars render below the bubble with three per centered row',
    (tester) async {
      final config = TilemapConfig.fromTiles(
        id: 'location_avatars',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc_1')],
      );
      const avatars = <UserAvatar>[
        UserAvatar('AA', id: 'a', name: 'Ada'),
        UserAvatar('BB', id: 'b', name: 'Bert'),
        UserAvatar('CC', id: 'c', name: 'Cara'),
        UserAvatar('DD', id: 'd', name: 'Drew'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 480,
            child: TilemapRenderer(
              config: config,
              locationNameForTile: (_) => 'June Coffee',
              locationAvatarsForTile: (_) => avatars,
            ),
          ),
        ),
      );
      await tester.pump();

      final bubbleRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tile-location-bubble-body-June Coffee'),
        ),
      );
      final avatarRects = <Rect>[
        for (final id in const ['a', 'b', 'c', 'd'])
          tester.getRect(
            find.byKey(ValueKey<String>('tilemap-location-avatar-$id')),
          ),
      ];

      expect(
        avatarRects.first.top - bubbleRect.bottom,
        closeTo(tilemapLocationLabelToAvatarSpacing, 0.01),
      );
      expect(avatarRects[0].top, avatarRects[1].top);
      expect(avatarRects[1].top, avatarRects[2].top);
      expect(avatarRects[3].top, greaterThan(avatarRects[0].bottom));
      expect(
        avatarRects[0].center.dx + avatarRects[2].center.dx,
        closeTo(bubbleRect.center.dx * 2, 0.01),
      );
      expect(avatarRects[3].center.dx, closeTo(bubbleRect.center.dx, 0.01));
      final avatar = tester.widget<GenesisCharacterAvatar>(
        find.byType(GenesisCharacterAvatar).first,
      );
      expect(
        avatar.boxShadow.any(
          (shadow) =>
              shadow.offset.dy > 0 &&
              shadow.blurRadius >= 10 &&
              shadow.spreadRadius > 0,
        ),
        isTrue,
      );
    },
  );
}

Future<void> _primeSuccessfulTileImage(WidgetTester tester) async {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
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
  addTearDown(_resetDebugTileImageCompleter);
}

void _primeFailedTileImage() {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  debugGenesisStaticNetworkImageCompleter = (_) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('expected tile image failure')),
  );
  addTearDown(_resetDebugTileImageCompleter);
}

void _resetDebugTileImageCompleter() {
  debugGenesisStaticNetworkImageCompleter = null;
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 30 && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(condition(), isTrue);
}

PictureLayer _firstPictureLayer(Layer layer) {
  if (layer is PictureLayer) return layer;
  if (layer is ContainerLayer) {
    for (
      var child = layer.firstChild;
      child != null;
      child = child.nextSibling
    ) {
      try {
        return _firstPictureLayer(child);
      } on StateError {
        // Continue searching sibling layers.
      }
    }
  }
  throw StateError('No PictureLayer found below $layer');
}

const _tileTypes = <String, String>{
  'a': 'https://cdn.example.com/tile/a.png',
  'b': 'https://cdn.example.com/tile/b.png',
};

WorldMapLocationNode _locationNode(
  String id, {
  List<WorldMapLocationNode> children = const [],
}) {
  return WorldMapLocationNode(
    id: id,
    point: WorldPoint(
      id: id,
      name: id,
      type: WorldPointType.portal,
      position: Offset.zero,
      users: const [],
    ),
    children: children,
  );
}
