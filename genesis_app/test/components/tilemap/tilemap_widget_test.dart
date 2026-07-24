import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_settings_store.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'Tilemap hides the grid until root map and initial transform are ready',
    (tester) async {
      final transport = _DelayedTilemapTransport();
      final services = _servicesWithTransport(transport);
      var mapTapCount = 0;

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                visualModeToggleTop: 24,
                visualModeToggleRight: 12,
                onMapTap: () => mapTapCount += 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(transport.requests, hasLength(1));
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-background')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('tilemap-grid')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('tilemap-grid-background')),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('tilemap-fog-layer')),
        findsNothing,
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey<String>('tilemap-loading-background')),
            )
            .color,
        const Color(0xFF37362E),
      );
      final settingsButton = find.byKey(
        const ValueKey<String>('tilemap-settings-button'),
      );
      expect(settingsButton, findsOneWidget);
      expect(tester.getTopRight(settingsButton), const Offset(788, 24));
      expect(
        find.byKey(const ValueKey<String>('tilemap-visual-mode-toggle')),
        findsNothing,
      );

      await tester.tap(settingsButton);
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tilemap-settings-panel')),
        findsOneWidget,
      );
      final settingsPanelRect = tester.getRect(
        find.byKey(const ValueKey<String>('tilemap-settings-panel')),
      );
      expect(settingsPanelRect.left, 0);
      expect(settingsPanelRect.right, 800);
      expect(settingsPanelRect.height, 500);
      await tester.tap(
        find.byKey(const ValueKey<String>('tilemap-settings-mode-light')),
      );
      await tester.pump();
      tester
          .widget<Slider>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-initial-scale'),
            ),
          )
          .onChanged!(1.2);
      final fogCurve = find.byKey(
        const ValueKey<String>('tilemap-settings-fog-curve'),
      );
      expect(fogCurve, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('tilemap-settings-fog-position-1')),
        findsNothing,
      );
      await tester.ensureVisible(fogCurve);
      await tester.pump();
      final fogCurveRect = tester.getRect(fogCurve);
      final fogCurvePlotWidth = fogCurveRect.width - 48;
      final fogCurvePlotHeight = fogCurveRect.height - 36;
      final curveGesture = await tester.startGesture(
        Offset(
          fogCurveRect.left + 34 + fogCurvePlotWidth * 0.5,
          fogCurveRect.top + 12 + fogCurvePlotHeight * 0.5,
        ),
      );
      await curveGesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await curveGesture.moveBy(const Offset(10, -12));
      await curveGesture.up();
      await tester.pump();
      tester
          .widget<Slider>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-fog-opacity-1'),
            ),
          )
          .onChanged!(0.4);
      tester
          .widget<Switch>(
            find.byKey(const ValueKey<String>('tilemap-settings-fog-blend')),
          )
          .onChanged!(true);
      tester
          .widget<Switch>(
            find.byKey(const ValueKey<String>('tilemap-settings-wireframe')),
          )
          .onChanged!(false);
      tester
          .widget<Slider>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-location-flow-angle'),
            ),
          )
          .onChanged!(120);
      tester
          .widget<Slider>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-location-flow-hue'),
            ),
          )
          .onChanged!(180);
      final shimmerGradientCurve = find.byKey(
        const ValueKey<String>('tilemap-settings-location-flow-gradient-curve'),
      );
      await tester.ensureVisible(shimmerGradientCurve);
      await tester.pump();
      final shimmerGradientRect = tester.getRect(shimmerGradientCurve);
      expect(shimmerGradientRect.width, greaterThan(200));
      final shimmerGradient = tester.widget<GestureDetector>(
        shimmerGradientCurve,
      );
      shimmerGradient.onHorizontalDragStart!(
        DragStartDetails(
          globalPosition: shimmerGradientRect.center,
          localPosition: Offset(shimmerGradientRect.width * 0.5, 31),
        ),
      );
      shimmerGradient.onHorizontalDragUpdate!(
        DragUpdateDetails(
          globalPosition: shimmerGradientRect.center + const Offset(36, 0),
          localPosition: Offset(shimmerGradientRect.width * 0.62, 31),
          delta: const Offset(36, 0),
          primaryDelta: 36,
        ),
      );
      await tester.pump();
      tester
          .widget<Slider>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-location-flow-opacity'),
            ),
          )
          .onChanged!(0.55);
      tester
          .widget<Slider>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-location-flow-duration'),
            ),
          )
          .onChanged!(4);
      tester
          .widget<DropdownButton<TilemapLocationImageFlowBlendMode>>(
            find.byKey(
              const ValueKey<String>(
                'tilemap-settings-location-flow-blend-mode',
              ),
            ),
          )
          .onChanged!(TilemapLocationImageFlowBlendMode.overlay);
      tester
          .widget<Switch>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-location-flow'),
            ),
          )
          .onChanged!(false);
      await tester.pump();

      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey<String>('tilemap-loading-background')),
            )
            .color,
        const Color(0xFFFAFAF8),
      );
      expect(transport.requests, hasLength(1));
      await tester.tap(settingsButton);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('tilemap-settings-panel')),
        findsNothing,
      );
      final savedSettings = await const TilemapSettingsStore().load();
      expect(savedSettings.visualMode, TilemapVisualMode.light);
      expect(savedSettings.fogControlPoints[1].opacity, 0.4);
      expect(savedSettings.fogControlPoints[2].position, greaterThan(0.5));
      expect(savedSettings.fogControlPoints[2].opacity, greaterThan(0.5));
      expect(savedSettings.blendFogWithShadowTiles, true);
      expect(savedSettings.showShadowZeroBorders, false);
      expect(savedSettings.showLocationImageFlow, false);
      expect(savedSettings.locationImageFlowAngleDegrees, 120);
      expect(
        HSLColor.fromColor(
          savedSettings.locationImageFlowGradientPoints[2].color,
        ).hue,
        closeTo(180, 0.1),
      );
      expect(
        savedSettings.locationImageFlowGradientPoints[2].position,
        greaterThan(0.5),
      );
      expect(savedSettings.locationImageFlowOpacity, 0.55);
      expect(savedSettings.locationImageFlowDurationSeconds, 4);
      expect(
        savedSettings.locationImageFlowBlendMode,
        TilemapLocationImageFlowBlendMode.overlay,
      );
      expect(savedSettings.initialScaleFactor, 1.2);

      transport.complete(_locationTilemapData('leaf', shadow: 1));
      await tester.pump();
      await tester.pump();

      final renderer = tester.widget<TilemapRenderer>(
        find.byType(TilemapRenderer),
      );
      expect(renderer.visualMode, TilemapVisualMode.light);
      expect(renderer.fogControlPoints[1].opacity, 0.4);
      final renderedFogPoints = renderer.fogControlPoints
          .map((point) => (point.position, point.opacity))
          .toList(growable: false);
      expect(
        renderer.fogControlPoints[2].position,
        greaterThan(0.5),
        reason: '$renderedFogPoints',
      );
      expect(
        renderer.fogControlPoints[2].opacity,
        greaterThan(0.5),
        reason: '$renderedFogPoints',
      );
      expect(renderer.blendFogWithShadowTiles, true);
      expect(renderer.showShadowZeroBorders, false);
      expect(renderer.showLocationImageFlow, false);
      expect(renderer.locationImageFlowAngleDegrees, 120);
      expect(
        renderer.locationImageFlowGradientPoints[2].position,
        greaterThan(0.5),
      );
      expect(renderer.locationImageFlowOpacity, 0.55);
      expect(renderer.locationImageFlowDurationSeconds, 4);
      expect(
        renderer.locationImageFlowBlendMode,
        TilemapLocationImageFlowBlendMode.overlay,
      );
      expect(renderer.initialScaleFactor, 1.2);
      expect(
        find.byKey(const ValueKey<String>('tilemap-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-background')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-fog-layer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-fog-paint')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TilemapRenderer>(find.byType(TilemapRenderer))
            .config
            .tiles
            .single
            .shadow,
        1,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('tilemap-gesture-layer')),
      );
      await tester.pump();

      expect(mapTapCount, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('Tilemap restores cached settings before creating its renderer', (
    tester,
  ) async {
    const cachedSettings = TilemapRenderSettings(
      visualMode: TilemapVisualMode.light,
      fogControlPoints: [
        TilemapFogControlPoint(position: 0, opacity: 0.05),
        TilemapFogControlPoint(position: 0.2, opacity: 0.25),
        TilemapFogControlPoint(position: 0.45, opacity: 0.55),
        TilemapFogControlPoint(position: 0.7, opacity: 0.8),
        TilemapFogControlPoint(position: 1, opacity: 0.9),
      ],
      blendFogWithShadowTiles: true,
      showShadowZeroBorders: false,
      showLocationImageFlow: false,
      locationImageFlowAngleDegrees: 135,
      locationImageFlowGradientPoints:
          tilemapDefaultLocationImageFlowGradientPoints,
      locationImageFlowOpacity: 0.6,
      locationImageFlowDurationSeconds: 5,
      locationImageFlowBlendMode: TilemapLocationImageFlowBlendMode.screen,
      initialScaleFactor: 1.3,
    );
    await const TilemapSettingsStore().save(cachedSettings);
    final transport = _DelayedTilemapTransport();

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(body: Tilemap.origin(originId: 'o_1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(transport.requests, hasLength(1));
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey<String>('tilemap-loading-background')),
          )
          .color,
      const Color(0xFFFAFAF8),
    );

    transport.complete(_locationTilemapData('leaf', shadow: 1));
    await tester.pump();
    await tester.pump();

    final renderer = tester.widget<TilemapRenderer>(
      find.byType(TilemapRenderer),
    );
    expect(renderer.visualMode, TilemapVisualMode.light);
    expect(renderer.fogControlPoints, cachedSettings.fogControlPoints);
    expect(renderer.blendFogWithShadowTiles, true);
    expect(renderer.showShadowZeroBorders, false);
    expect(renderer.showLocationImageFlow, false);
    expect(renderer.locationImageFlowAngleDegrees, 135);
    expect(
      renderer.locationImageFlowGradientPoints,
      tilemapDefaultLocationImageFlowGradientPoints,
    );
    expect(renderer.locationImageFlowOpacity, 0.6);
    expect(renderer.locationImageFlowDurationSeconds, 5);
    expect(
      renderer.locationImageFlowBlendMode,
      TilemapLocationImageFlowBlendMode.screen,
    );
    expect(renderer.initialScaleFactor, 1.3);

    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-settings-button')),
    );
    await tester.pump();
    final copyButton = find.byKey(
      const ValueKey<String>('tilemap-settings-copy-json'),
    );
    final resetButton = find.byKey(
      const ValueKey<String>('tilemap-settings-reset'),
    );
    final closeButton = find.byKey(
      const ValueKey<String>('tilemap-settings-close'),
    );
    expect(resetButton, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('tilemap-settings-location-flow-angle'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('tilemap-settings-location-flow-gradient'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('tilemap-settings-location-flow-opacity'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('tilemap-settings-location-flow-duration'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('tilemap-settings-location-flow-blend-mode'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('The effect is off; parameters can still be edited.'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(resetButton).dx,
      greaterThan(tester.getTopLeft(copyButton).dx),
    );
    expect(
      tester.getTopLeft(resetButton).dx,
      lessThan(tester.getTopLeft(closeButton).dx),
    );
    final copiedValues = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<dynamic, dynamic>;
            copiedValues.add('${arguments['text']}');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.tap(resetButton);
    await tester.pump();
    await tester.pump();

    final defaults = TilemapRenderSettings.defaults();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(TilemapSettingsStore.storageKey), false);
    expect(find.text('Tilemap settings reset'), findsOneWidget);
    await tester.tap(copyButton);
    await tester.pump();
    expect(copiedValues, hasLength(1));
    expect(jsonDecode(copiedValues.single), defaults.toJson());
  });

  testWidgets('Tilemap copies all current settings as serialized JSON', (
    tester,
  ) async {
    final copiedValues = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<dynamic, dynamic>;
            copiedValues.add('${arguments['text']}');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(_DelayedTilemapTransport()),
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(body: Tilemap.origin(originId: 'o_1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-settings-button')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-settings-copy-json')),
    );
    await tester.pump();

    expect(copiedValues, hasLength(1));
    final copiedJson = jsonDecode(copiedValues.single);
    expect(copiedJson, TilemapRenderSettings.defaults().toJson());
    expect(find.text('Tilemap settings JSON copied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'Tilemap routes origin and world requests without rebuild reload',
    (tester) async {
      final transport = _TilemapTransport();
      final services = _servicesWithTransport(transport);

      Widget build(Widget tilemap) {
        return AppServicesScope(
          services: services,
          child: MaterialApp(home: Scaffold(body: tilemap)),
        );
      }

      await tester.pumpWidget(
        build(
          const Tilemap.origin(
            key: ValueKey<String>('subject-map'),
            originId: 'o_1',
            locationId: 'root',
          ),
        ),
      );
      await tester.pump();

      expect(transport.requests, hasLength(1));
      expect(transport.requests.single.uri.path, '/api/v1/origin/map');
      expect(transport.requests.single.uri.queryParameters, {
        'origin_id': 'o_1',
        'location_id': 'root',
      });

      await tester.pumpWidget(
        build(
          const Tilemap.origin(
            key: ValueKey<String>('subject-map'),
            originId: 'o_1',
            locationId: 'root',
          ),
        ),
      );
      await tester.pump();
      expect(transport.requests, hasLength(1));

      await tester.pumpWidget(
        build(
          const Tilemap.world(
            key: ValueKey<String>('subject-map'),
            worldId: 'w_1',
            locationId: 'loc_2',
          ),
        ),
      );
      await tester.pump();

      expect(transport.requests, hasLength(2));
      expect(transport.requests.last.uri.path, '/api/v1/world/map');
      expect(transport.requests.last.uri.queryParameters, {
        'world_id': 'w_1',
        'location_id': 'loc_2',
      });
    },
  );

  testWidgets('Tilemap empty response shows error and retry reloads', (
    tester,
  ) async {
    final transport = _TilemapTransport();
    final services = _servicesWithTransport(transport);

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: const Scaffold(
            body: Tilemap.origin(originId: 'o_1', locationId: 'root'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('tilemap-error')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tilemap-grid')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('tilemap-grid-background')),
      findsNothing,
    );
    expect(transport.requests, hasLength(1));

    await tester.tap(find.byKey(const ValueKey<String>('tilemap-retry')));
    await tester.pump();
    await tester.pump();

    expect(transport.requests, hasLength(2));
    expect(find.byKey(const ValueKey<String>('tilemap-error')), findsOneWidget);
  });

  testWidgets('Tilemap image retry keeps the cached map json', (tester) async {
    final transport = _TilemapTransport(data: _locationTilemapData('leaf'));
    final services = _servicesWithTransport(transport);

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: const MaterialApp(
          home: Scaffold(body: Tilemap.origin(originId: 'o_1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('tilemap-error')), findsOneWidget);
    expect(transport.requests, hasLength(1));

    await tester.tap(find.byKey(const ValueKey<String>('tilemap-retry')));
    await tester.pump();

    expect(transport.requests, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Tilemap loads drillable locations on demand and caches maps', (
    tester,
  ) async {
    final transport = _TilemapTransport(data: _locationTilemapData('branch'));
    final services = _servicesWithTransport(transport);
    final branch = _locationNode(
      'branch',
      children: [_locationNode('leaf_a'), _locationNode('leaf_b')],
    );

    Widget buildSubject() {
      return AppServicesScope(
        services: services,
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: Tilemap.world(worldId: 'w_1', locationNodes: [branch]),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(transport.requests, hasLength(1));
    final renderer = tester.widget<TilemapRenderer>(
      find.byType(TilemapRenderer),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(buildSubject());
    await tester.pump(const Duration(milliseconds: 49));
    expect(transport.requests, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(transport.requests, hasLength(1));
    expect(
      transport.requests
          .map((request) => request.uri.queryParameters['location_id'])
          .toSet(),
      {'root'},
    );
    expect(
      transport.requests.every(
        (request) => request.uri.path == '/api/v1/world/map',
      ),
      isTrue,
    );

    await renderer.onTileAction!(renderer.config.tiles.single);
    await tester.pump();

    expect(transport.requests, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('tilemap-exit-location')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-exit-location')),
    );
    await tester.pump();

    expect(transport.requests, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Tilemap does not preload origin location maps', (tester) async {
    final transport = _TilemapTransport(data: _locationTilemapData('branch'));
    final services = _servicesWithTransport(transport);
    final branch = _locationNode(
      'branch',
      children: [_locationNode('leaf_a'), _locationNode('leaf_b')],
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: Tilemap.origin(originId: 'o_1', locationNodes: [branch]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(transport.requests, hasLength(1));
    expect(
      transport.requests.every(
        (request) => request.uri.path == '/api/v1/origin/map',
      ),
      isTrue,
    );
    expect(
      transport.requests
          .map((request) => request.uri.queryParameters['location_id'])
          .toSet(),
      {'root'},
    );
  });

  testWidgets('Tilemap leaf location uses the existing chat callback', (
    tester,
  ) async {
    final transport = _TilemapTransport(data: _locationTilemapData('leaf'));
    final services = _servicesWithTransport(transport);
    WorldPoint? openedPoint;
    const avatar = UserAvatar('AA', id: 'char-a', name: 'Ada');

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              locationNodes: [
                _locationNode('leaf', users: [avatar]),
              ],
              onPointTap: (point) => openedPoint = point,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final renderer = tester.widget<TilemapRenderer>(
      find.byType(TilemapRenderer),
    );
    expect(find.text('leaf'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('tilemap-location-avatar-char-a')),
      findsOneWidget,
    );
    await renderer.onTileAction!(renderer.config.tiles.single);

    expect(openedPoint?.id, 'leaf');
    expect(transport.requests, hasLength(1));
  });
}

Map<String, dynamic> _locationTilemapData(String locationId, {int shadow = 0}) {
  return {
    'tile_types': {'tile': 'https://invalid.example.test/tile/tile.png'},
    'map_json': {
      'width': 1,
      'height': 1,
      'tiles': [
        {
          'x': 0,
          'y': 0,
          'type': 'tile',
          'shadow': shadow,
          'location_id': locationId,
        },
      ],
    },
  };
}

WorldMapLocationNode _locationNode(
  String id, {
  List<WorldMapLocationNode> children = const <WorldMapLocationNode>[],
  List<UserAvatar> users = const <UserAvatar>[],
}) {
  return WorldMapLocationNode(
    id: id,
    point: WorldPoint(
      id: id,
      name: id,
      type: WorldPointType.portal,
      position: Offset.zero,
      users: users,
    ),
    children: children,
  );
}

AppServices _servicesWithTransport(HttpTransport transport) {
  final base = ServiceRegistry.build(config: const AppConfig(useMock: true));
  final api = GenesisApi(
    useMock: false,
    transport: transport,
    platformConfig: base.platformConfig,
    deviceIdService: base.deviceId,
    sessionStore: base.sessionStore,
    identityAuthService: base.identityAuth,
    appHeaderProvider: () async => const <String, String>{},
  );
  return AppServices(
    config: base.config,
    platformConfig: base.platformConfig,
    deviceId: base.deviceId,
    sessionStore: base.sessionStore,
    identityAuth: base.identityAuth,
    backendAuth: base.backendAuth,
    api: api,
    chatroom: base.chatroom,
    chatroomMessages: base.chatroomMessages,
    directMessageConversations: base.directMessageConversations,
    directMessageMessages: base.directMessageMessages,
    appVersionCheck: base.appVersionCheck,
    externalUrlOpener: base.externalUrlOpener,
    startupNetworkGate: base.startupNetworkGate,
    gatewayAuth: base.gatewayAuth,
    sessionRevision: base.sessionRevision,
  );
}

class _TilemapTransport implements HttpTransport {
  _TilemapTransport({this.data});

  final Map<String, dynamic>? data;
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data ?? {}}),
    );
  }
}

class _DelayedTilemapTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  final Completer<TransportResponse> _response = Completer<TransportResponse>();

  void complete(Map<String, dynamic> data) {
    _response.complete(
      TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
      ),
    );
  }

  @override
  Future<TransportResponse> send(TransportRequest request) {
    requests.add(request);
    return _response.future;
  }
}
