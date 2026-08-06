import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_performance_monitoring.dart';
import 'package:genesis_flutter_android/components/tilemap/loading/tilemap_loading_coordinator.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_settings_button_visibility.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_settings_store.dart';
import 'package:genesis_flutter_android/components/world_map_contract.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _liveTilemapRendererFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is TilemapRenderer && widget.isForeground,
    description: 'foreground TilemapRenderer',
  );
}

Finder _tilemapRendererForMap(String mapId) {
  return find.byWidgetPredicate(
    (widget) => widget is TilemapRenderer && widget.config.id == mapId,
    description: 'TilemapRenderer for $mapId',
  );
}

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugGenesisStaticNetworkImageCompleter = (_) =>
        _PendingImageStreamCompleter();
    FirebasePerformanceMonitoring.resetForTesting();
    tilemapVisualModeController.resetForTesting();
    tilemapSettingsButtonVisibility.resetForTesting();
    final loadingSettings = TilemapRenderSettings.defaults().toJson()
      ..['loading_style'] = TilemapLoadingStyle.minimalProgress.name;
    SharedPreferences.setMockInitialValues(<String, Object>{
      TilemapSettingsButtonVisibilityController.storageKey: true,
      TilemapSettingsStore.storageKey: jsonEncode(loadingSettings),
    });
  });

  tearDown(() {
    debugGenesisStaticNetworkImageCompleter = null;
    FirebasePerformanceMonitoring.resetForTesting();
  });

  testWidgets('Tilemap reports current display readiness and load errors', (
    tester,
  ) async {
    final transport = _DelayedTilemapTransport();
    final services = _servicesWithTransport(transport);
    final readiness = <bool>[];
    final errors = <Object>[];
    Widget buildTilemap(String bubbleContent) {
      return AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.world(
              key: const ValueKey<String>('readiness-tilemap'),
              worldId: 'w_1',
              messageBubbles: [
                WorldMapMessageBubble(
                  characterId: 'char_1',
                  content: bubbleContent,
                ),
              ],
              tileImageLoader: _completeTileImageLoad,
              onDisplayReadinessChanged: readiness.add,
              onDisplayError: errors.add,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTilemap('stable bubble'));
    await tester.pump();

    expect(readiness, contains(false));
    expect(errors, isEmpty);

    transport.complete(_locationTilemapData('leaf'));
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump();
    }

    expect(readiness.last, isTrue);
    expect(errors, isEmpty);

    final stableCallbackCount = readiness.length;
    await tester.pumpWidget(buildTilemap('stable bubble'));
    await tester.pump();
    expect(readiness, hasLength(stableCallbackCount));

    await tester.pumpWidget(buildTilemap('updated bubble'));
    await tester.pump();
    expect(readiness.skip(stableCallbackCount), contains(false));

    for (var frame = 0; frame < 4; frame += 1) {
      await tester.pump();
    }
    expect(readiness.last, isTrue);
  });

  testWidgets(
    'Tilemap reports unique locations after the current map is live',
    (tester) async {
      debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
      final transport = _DelayedTilemapTransport();
      final reportedMapIds = <String>[];
      final reportedLocationIds = <Set<String>>[];

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: Tilemap.world(
                worldId: 'w_1',
                locationNodes: [_locationNode('loc_a'), _locationNode('loc_b')],
                tileImageLoader: _completeTileImageLoad,
                onCurrentLocationsChanged: (mapId, locationIds) {
                  reportedMapIds.add(mapId);
                  reportedLocationIds.add(locationIds);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(reportedLocationIds, isEmpty);

      transport.complete(
        _tilemapData(
          tileLocationIds: const ['loc_a', 'loc_a', 'loc_b'],
          assetName: 'root',
        ),
      );
      for (var frame = 0; frame < 10; frame += 1) {
        await tester.pump();
      }

      expect(reportedMapIds, const ['world:w_1:root']);
      expect(reportedLocationIds, [
        const {'loc_a', 'loc_b'},
      ]);
    },
  );

  testWidgets('Tilemap reports locations after drilling into a new map', (
    tester,
  ) async {
    final transport = _LocationTilemapTransport({
      'root': _locationTilemapData('branch', assetName: 'root'),
      'branch': _locationTilemapData('leaf', assetName: 'branch'),
    });
    final reports = <String, Set<String>>{};

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.world(
              worldId: 'w_1',
              locationNodes: [
                _locationNode(
                  'branch',
                  children: [_locationNode('leaf'), _locationNode('leaf_2')],
                ),
              ],
              tileImageLoader: _completeTileImageLoad,
              onCurrentLocationsChanged: (mapId, locationIds) {
                reports[mapId] = locationIds;
              },
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump();
    }

    expect(reports, {
      'world:w_1:root': const {'branch'},
    });

    final rootRenderer = tester.widget<TilemapRenderer>(
      _liveTilemapRendererFinder(),
    );
    await rootRenderer.onTileAction!(rootRenderer.config.tiles.single);
    for (var frame = 0; frame < 6; frame += 1) {
      await tester.pump();
    }

    expect(reports, {
      'world:w_1:root': const {'branch'},
      'world:w_1:branch': const {'leaf'},
    });
  });

  testWidgets('Tilemap records Firebase load performance', (tester) async {
    final transport = _DelayedTilemapTransport();
    final traces = <String, _RecordingPerformanceTrace>{};
    final traceNames = <String>[];
    FirebasePerformanceMonitoring.setReadyForTesting(true);
    FirebasePerformanceMonitoring.setTraceFactoryForTesting((name) {
      traceNames.add(name);
      return traces.putIfAbsent(name, _RecordingPerformanceTrace.new);
    });

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: const MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(traceNames, const <String>['tilemap_load']);
    final trace = traces['tilemap_load']!;
    expect(trace.started, isTrue);
    expect(trace.stopped, isFalse);
    expect(trace.attributes, const <String, String>{'source': 'origin'});

    transport.complete(_locationTilemapData('leaf', shadow: 1));
    await tester.pump();
    await tester.pump();

    expect(traceNames, contains('tilemap_first_render'));
    expect(trace.stopped, isTrue);
    expect(trace.attributes, const <String, String>{
      'source': 'origin',
      'result': 'success',
    });
    expect(trace.metrics, const <String, int>{
      'tile_count': 1,
      'map_width': 1,
      'map_height': 1,
    });
  });

  testWidgets(
    'Tilemap first render trace ignores offscreen background images',
    (tester) async {
      final pendingLoads = <String, Completer<void>>{};
      final traces = <String, _RecordingPerformanceTrace>{};
      FirebasePerformanceMonitoring.setReadyForTesting(true);
      FirebasePerformanceMonitoring.setTraceFactoryForTesting(
        (name) => traces.putIfAbsent(name, _RecordingPerformanceTrace.new),
      );

      Future<void> loadTileImage(String assetUrl) {
        return pendingLoads.putIfAbsent(assetUrl, Completer<void>.new).future;
      }

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(
            _TilemapTransport(data: _visibleFirstTilemapData()),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                tileImageLoader: loadTileImage,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final requestTrace = traces['tilemap_load']!;
      final firstRenderTrace = traces['tilemap_first_render']!;
      expect(requestTrace.stopped, isTrue);
      expect(firstRenderTrace.started, isTrue);
      expect(firstRenderTrace.stopped, isFalse);
      expect(pendingLoads, hasLength(1));

      pendingLoads.values.single.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(firstRenderTrace.stopped, isTrue);
      expect(pendingLoads, hasLength(4));
      expect(
        pendingLoads.values.where((completer) => !completer.isCompleted),
        hasLength(tilemapBackgroundImagePreloadConcurrency),
      );
      expect(firstRenderTrace.attributes, const <String, String>{
        'source': 'origin',
        'result': 'success',
      });
      expect(firstRenderTrace.metrics, const <String, int>{
        'visible_tile_count': 1,
        'image_count': 1,
        'map_width': 100,
        'map_height': 100,
      });

      for (final completer in pendingLoads.values) {
        if (!completer.isCompleted) completer.complete();
      }
      await tester.pump();

      expect(pendingLoads, hasLength(5));
      pendingLoads.values
          .singleWhere((completer) => !completer.isCompleted)
          .complete();
      await tester.pump();
    },
  );

  testWidgets('Tilemap first render trace records only the first map', (
    tester,
  ) async {
    final locationId = ValueNotifier<String>('root');
    addTearDown(locationId.dispose);
    final traces = <String, List<_RecordingPerformanceTrace>>{};
    FirebasePerformanceMonitoring.setReadyForTesting(true);
    FirebasePerformanceMonitoring.setTraceFactoryForTesting((name) {
      final trace = _RecordingPerformanceTrace();
      traces.putIfAbsent(name, () => <_RecordingPerformanceTrace>[]).add(trace);
      return trace;
    });
    final transport = _LocationTilemapTransport({
      'root': _locationTilemapData('root_leaf', assetName: 'root'),
      'branch': _locationTilemapData('branch_leaf', assetName: 'branch'),
    });

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: locationId,
              builder: (context, currentLocationId, _) => Tilemap.origin(
                key: const ValueKey<String>('first-render-tilemap'),
                originId: 'o_1',
                locationId: currentLocationId,
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump();
    }

    expect(traces['tilemap_first_render'], hasLength(1));
    expect(traces['tilemap_first_render']!.single.stopped, isTrue);

    locationId.value = 'branch';
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump();
    }

    expect(transport.requestCount('branch'), 1);
    expect(traces['tilemap_first_render'], hasLength(1));
  });

  testWidgets(
    'Tilemap hides the settings button by default and reacts when enabled',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tilemapSettingsButtonVisibility.resetForTesting();

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(_DelayedTilemapTransport()),
          child: const MaterialApp(
            home: Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tilemap-settings-button')),
        findsNothing,
      );

      await tilemapSettingsButtonVisibility.setVisible(true);
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tilemap-settings-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Tilemap defaults the Loading screen setting to Off', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TilemapSettingsButtonVisibilityController.storageKey: true,
    });

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(_DelayedTilemapTransport()),
        child: const MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-settings-button')),
    );
    await tester.pump();
    expect(
      tester
          .widget<DropdownButton<TilemapLoadingStyle>>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-loading-style'),
            ),
          )
          .value,
      TilemapLoadingStyle.disabled,
    );
  });

  testWidgets('Tilemap offers Off and all five persisted loading styles', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(_DelayedTilemapTransport()),
        child: const MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('tilemap-loading-style-minimalProgress'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-settings-button')),
    );
    await tester.pump();
    final dropdownFinder = find.byKey(
      const ValueKey<String>('tilemap-settings-loading-style'),
    );
    expect(
      tester
          .widget<DropdownButton<TilemapLoadingStyle>>(dropdownFinder)
          .items
          ?.map((item) => item.value),
      TilemapLoadingStyle.values,
    );

    Future<void> select(TilemapLoadingStyle style) async {
      tester
          .widget<DropdownButton<TilemapLoadingStyle>>(dropdownFinder)
          .onChanged!(style);
      await tester.pump();
    }

    for (final style in <TilemapLoadingStyle>[
      TilemapLoadingStyle.tileAssembly,
      TilemapLoadingStyle.worldPortal,
      TilemapLoadingStyle.progressiveReveal,
      TilemapLoadingStyle.coordinatePulse,
      TilemapLoadingStyle.minimalProgress,
    ]) {
      await select(style);
      expect(
        find.byKey(ValueKey<String>('tilemap-loading-style-${style.name}')),
        findsOneWidget,
      );
    }

    await select(TilemapLoadingStyle.disabled);
    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-background')),
      findsOneWidget,
    );

    // Turning the first-entry screen off completes this Tilemap session's
    // one-time gate. Re-enabling a style must not make it appear again.
    await select(TilemapLoadingStyle.minimalProgress);
    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-settings-close')),
    );
    await tester.pump();
    expect(
      (await const TilemapSettingsStore().load()).loadingStyle,
      TilemapLoadingStyle.minimalProgress,
    );
  });

  testWidgets('Tilemap minimal loading style shows muted progress on black', (
    tester,
  ) async {
    final settings = TilemapRenderSettings.defaults().toJson()
      ..['loading_style'] = TilemapLoadingStyle.minimalProgress.name;
    SharedPreferences.setMockInitialValues(<String, Object>{
      TilemapSettingsButtonVisibilityController.storageKey: true,
      TilemapSettingsStore.storageKey: jsonEncode(settings),
    });

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(_DelayedTilemapTransport()),
        child: const MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final overlay = find.byKey(
      const ValueKey<String>('tilemap-loading-overlay'),
    );
    expect(
      find.byKey(
        const ValueKey<String>('tilemap-loading-style-minimalProgress'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey<String>('tilemap-loading-background')),
          )
          .color,
      Colors.black,
    );
    final progressBar = find.descendant(
      of: overlay,
      matching: find.byType(LinearProgressIndicator),
    );
    expect(progressBar, findsOneWidget);
    final progressIndicator = tester.widget<LinearProgressIndicator>(
      progressBar,
    );
    expect(progressIndicator.valueColor?.value, const Color(0xFF2F9663));
    final percentText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tilemap-loading-percent')),
    );
    expect(percentText.style?.color, const Color(0xFF2F9663));
    expect(percentText.data, '0%');
  });

  testWidgets(
    'Tilemap Off skips the first-map gate but keeps silent child preload',
    (tester) async {
      final disabledSettings = TilemapRenderSettings.defaults().toJson()
        ..['loading_style'] = TilemapLoadingStyle.disabled.name;
      SharedPreferences.setMockInitialValues(<String, Object>{
        TilemapSettingsButtonVisibilityController.storageKey: true,
        TilemapSettingsStore.storageKey: jsonEncode(disabledSettings),
      });
      final loadedAssets = <String>[];
      final transport = _LocationTilemapTransport({
        'root': _locationTilemapData('branch', assetName: 'root'),
        'branch': _locationTilemapData('leaf_a', assetName: 'branch'),
      });

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                locationNodes: [
                  _locationNode(
                    'branch',
                    children: [
                      _locationNode('leaf_a'),
                      _locationNode('leaf_b'),
                    ],
                  ),
                ],
                tileImageLoader: (assetUrl) async {
                  loadedAssets.add(assetUrl);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        loadedAssets.any((assetUrl) => assetUrl.contains('/root.png?')),
        isFalse,
      );
      expect(
        loadedAssets.any((assetUrl) => assetUrl.contains('/branch.png?')),
        isTrue,
      );
      expect(
        transport.requests
            .map((request) => request.uri.queryParameters['location_id'])
            .toSet(),
        {'root', 'branch'},
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
      expect(_liveTilemapRendererFinder(), findsOneWidget);
    },
  );

  testWidgets('Tilemap progress weights loaded assets by their tile count', (
    tester,
  ) async {
    final pendingLoads = <String, Completer<void>>{};

    Future<void> loadTileImage(String assetUrl) {
      return pendingLoads.putIfAbsent(assetUrl, Completer<void>.new).future;
    }

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(
          _TilemapTransport(data: _weightedTilemapData()),
        ),
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              tileImageLoader: loadTileImage,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(pendingLoads, hasLength(2));
    expect(_liveTilemapRendererFinder(), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('tilemap-loading-style-minimalProgress'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey<String>('tilemap-loading-progress')),
          )
          .value,
      0,
    );

    pendingLoads.entries
        .singleWhere((entry) => entry.key.contains('/a.png?'))
        .value
        .complete();
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey<String>('tilemap-loading-progress')),
          )
          .value,
      closeTo(2 / 3, 0.0001),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('tilemap-loading-percent')),
          )
          .data,
      '67%',
    );
    expect(_liveTilemapRendererFinder(), findsNothing);

    pendingLoads.entries
        .singleWhere((entry) => entry.key.contains('/b.png?'))
        .value
        .complete();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('tilemap-grid')), findsOneWidget);
  });

  testWidgets('Tilemap limits initial visible image preload concurrency', (
    tester,
  ) async {
    final pendingLoads = <String, Completer<void>>{};

    Future<void> loadTileImage(String assetUrl) {
      return pendingLoads.putIfAbsent(assetUrl, Completer<void>.new).future;
    }

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(
          _TilemapTransport(data: _threeVisibleAssetTilemapData()),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              tileImageLoader: loadTileImage,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(pendingLoads, hasLength(tilemapInitialImagePreloadConcurrency));
    pendingLoads.values.first.complete();
    await tester.pump();
    expect(pendingLoads, hasLength(3));

    for (final completer in pendingLoads.values) {
      if (!completer.isCompleted) completer.complete();
    }
    await tester.pump();
    await tester.pump();
  });

  testWidgets(
    'Tilemap loads the current viewport before background tile assets',
    (tester) async {
      final pendingLoads = <String, Completer<void>>{};

      Future<void> loadTileImage(String assetUrl) {
        return pendingLoads.putIfAbsent(assetUrl, Completer<void>.new).future;
      }

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(
            _TilemapTransport(data: _visibleFirstTilemapData()),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                tileImageLoader: loadTileImage,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(pendingLoads, hasLength(1));
      expect(pendingLoads.keys.single, contains('/a.png?'));
      expect(_liveTilemapRendererFinder(), findsNothing);

      pendingLoads.values.single.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
      expect(_liveTilemapRendererFinder(), findsOneWidget);
      expect(pendingLoads, hasLength(4));
      expect(
        pendingLoads.keys.where((assetUrl) => !assetUrl.contains('/a.png?')),
        hasLength(tilemapBackgroundImagePreloadConcurrency),
      );

      pendingLoads.entries
          .singleWhere((entry) => entry.key.contains('/b.png?'))
          .value
          .complete();
      await tester.pump();

      expect(
        pendingLoads.keys.where((assetUrl) => !assetUrl.contains('/a.png?')),
        hasLength(4),
      );
      for (final completer in pendingLoads.values) {
        if (!completer.isCompleted) completer.complete();
      }
      await tester.pump();
    },
  );

  testWidgets(
    'animationsPaused keeps initial loading but defers background images',
    (tester) async {
      final animationsPaused = ValueNotifier<bool>(true);
      addTearDown(animationsPaused.dispose);
      final pendingLoads = <String, Completer<void>>{};

      Future<void> loadTileImage(String assetUrl) {
        return pendingLoads.putIfAbsent(assetUrl, Completer<void>.new).future;
      }

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(
            _TilemapTransport(data: _visibleFirstTilemapData()),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: animationsPaused,
                builder: (context, paused, _) {
                  return Tilemap.origin(
                    originId: 'o_1',
                    animationsPaused: paused,
                    tileImageLoader: loadTileImage,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(pendingLoads, hasLength(1));
      expect(pendingLoads.keys.single, contains('/a.png?'));
      pendingLoads.values.single.complete();
      for (var frame = 0; frame < 6; frame += 1) {
        await tester.pump();
      }

      expect(_liveTilemapRendererFinder(), findsOneWidget);
      expect(
        pendingLoads,
        hasLength(1),
        reason: 'background decode work must stay queued while the sheet is up',
      );

      animationsPaused.value = false;
      for (var frame = 0; frame < 4; frame += 1) {
        await tester.pump();
      }

      expect(pendingLoads, hasLength(4));
      expect(
        pendingLoads.keys.where((assetUrl) => !assetUrl.contains('/a.png?')),
        hasLength(tilemapBackgroundImagePreloadConcurrency),
      );

      animationsPaused.value = true;
      await tester.pump();
      pendingLoads.entries
          .firstWhere((entry) => entry.key.contains('/b.png?'))
          .value
          .complete();
      await tester.pump();
      expect(
        pendingLoads,
        hasLength(4),
        reason: 'workers must not claim another background asset after pause',
      );
      for (final completer in pendingLoads.values) {
        if (!completer.isCompleted) completer.complete();
      }
      await tester.pump();
      await tester.pump();
      expect(pendingLoads, hasLength(4));

      animationsPaused.value = false;
      for (var frame = 0; frame < 4; frame += 1) {
        await tester.pump();
      }
      expect(
        pendingLoads.keys.where((assetUrl) => assetUrl.contains('/e.png?')),
        hasLength(1),
      );
      for (final completer in pendingLoads.values) {
        if (!completer.isCompleted) completer.complete();
      }
      await tester.pump();
    },
  );

  testWidgets(
    'Tilemap enables foreground interaction before viewport readiness',
    (tester) async {
      final pendingLoad = Completer<void>();

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(
            _TilemapTransport(data: _locationTilemapData('leaf')),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                tileImageLoader: (_) => pendingLoad.future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(_liveTilemapRendererFinder(), findsNothing);

      pendingLoad.complete();
      await tester.pump();
      await tester.pump();

      final foregroundRenderer = _liveTilemapRendererFinder();
      expect(foregroundRenderer, findsOneWidget);
      final interactionGate = find.ancestor(
        of: foregroundRenderer,
        matching: find.byType(IgnorePointer),
      );
      expect(interactionGate, findsWidgets);
      expect(
        interactionGate
            .evaluate()
            .map((element) => element.widget)
            .whereType<IgnorePointer>()
            .every((gate) => !gate.ignoring),
        isTrue,
      );
      expect(
        tester.widget<TilemapRenderer>(foregroundRenderer).onTileAction,
        isNotNull,
      );
    },
  );

  testWidgets(
    'Tilemap ignores stale image failure after the load plan changes',
    (tester) async {
      final pendingLoads = <String, Completer<void>>{};

      Future<void> loadTileImage(String assetUrl) {
        return pendingLoads.putIfAbsent(assetUrl, Completer<void>.new).future;
      }

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(
            _TilemapTransport(data: _locationTilemapData('leaf')),
          ),
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                tileImageLoader: loadTileImage,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final firstLoad = pendingLoads.entries.single;
      expect(firstLoad.key, contains('resize,w_512'));

      await tester.tap(
        find.byKey(const ValueKey<String>('tilemap-settings-button')),
      );
      await tester.pump();
      tester
          .widget<Slider>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-initial-scale'),
            ),
          )
          .onChanged!(5);
      await tester.pump();
      await tester.pump();

      expect(pendingLoads, hasLength(2));
      final currentLoad = pendingLoads.entries.singleWhere(
        (entry) => entry.key.contains('resize,w_256'),
      );
      firstLoad.value.completeError(StateError('stale image failure'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('tilemap-error')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsOneWidget,
      );

      currentLoad.value.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('tilemap-error')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Tilemap reset to Off invalidates an in-flight loading-screen image',
    (tester) async {
      final cachedSettings = TilemapRenderSettings.defaults().toJson()
        ..['initial_scale'] = 5.0
        ..['loading_style'] = TilemapLoadingStyle.minimalProgress.name;
      SharedPreferences.setMockInitialValues(<String, Object>{
        TilemapSettingsButtonVisibilityController.storageKey: true,
        TilemapSettingsStore.storageKey: jsonEncode(cachedSettings),
      });
      final pendingLoads = <String, Completer<void>>{};

      Future<void> loadTileImage(String assetUrl) {
        return pendingLoads.putIfAbsent(assetUrl, Completer<void>.new).future;
      }

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(
            _TilemapTransport(data: _locationTilemapData('leaf')),
          ),
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                tileImageLoader: loadTileImage,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final oldScaleLoad = pendingLoads.entries.single;
      expect(oldScaleLoad.key, contains('resize,w_256'));

      await tester.tap(
        find.byKey(const ValueKey<String>('tilemap-settings-button')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('tilemap-settings-reset')),
      );
      await tester.pump();
      await tester.pump();

      expect(pendingLoads, hasLength(1));
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
      expect(_liveTilemapRendererFinder(), findsOneWidget);

      oldScaleLoad.value.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('tilemap-error')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
      expect(_liveTilemapRendererFinder(), findsOneWidget);
    },
  );

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
                tileImageLoader: _completeTileImageLoad,
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
        Colors.black,
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
      final loadingStyleDropdown = tester
          .widget<DropdownButton<TilemapLoadingStyle>>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-loading-style'),
            ),
          );
      expect(loadingStyleDropdown.value, TilemapLoadingStyle.minimalProgress);
      loadingStyleDropdown.onChanged!(TilemapLoadingStyle.tileAssembly);
      final initialScaleSlider = tester.widget<Slider>(
        find.byKey(const ValueKey<String>('tilemap-settings-initial-scale')),
      );
      expect(initialScaleSlider.value, 12);
      expect(initialScaleSlider.min, 5);
      expect(initialScaleSlider.max, 30);
      expect(initialScaleSlider.divisions, 25);
      initialScaleSlider.onChanged!(22);
      tester
          .widget<Slider>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-drag-boundary-padding'),
            ),
          )
          .onChanged!(7);
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
            find.byKey(
              const ValueKey<String>('tilemap-settings-fog-bitmap-cache'),
            ),
          )
          .onChanged!(false);
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
      expect(savedSettings.loadingStyle, TilemapLoadingStyle.tileAssembly);
      expect(savedSettings.fogControlPoints[1].opacity, 0.4);
      expect(savedSettings.fogControlPoints[2].position, greaterThan(0.5));
      expect(savedSettings.fogControlPoints[2].opacity, greaterThan(0.5));
      expect(savedSettings.blendFogWithShadowTiles, true);
      expect(savedSettings.cacheFogTileBitmaps, false);
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
      expect(savedSettings.initialScale, 22);
      expect(savedSettings.dragBoundaryPaddingTiles, 7);

      transport.complete(_locationTilemapData('leaf', shadow: 1));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final renderer = tester.widget<TilemapRenderer>(
        _liveTilemapRendererFinder(),
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
      expect(renderer.cacheFogTileBitmaps, false);
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
      expect(renderer.initialScale, 22);
      expect(renderer.dragBoundaryPaddingTiles, 7);
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
            .widget<TilemapRenderer>(_liveTilemapRendererFinder())
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

  testWidgets('Tilemap keeps the mounted renderer while viewport is resized', (
    tester,
  ) async {
    final viewportSize = ValueNotifier<Size>(const Size(320, 480));
    addTearDown(viewportSize.dispose);

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(
          _TilemapTransport(data: _locationTilemapData('leaf')),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<Size>(
                valueListenable: viewportSize,
                builder: (context, size, _) {
                  return SizedBox(
                    width: size.width,
                    height: size.height,
                    child: const Tilemap.origin(
                      key: ValueKey<String>('resized-tilemap'),
                      originId: 'o_1',
                      tileImageLoader: _completeTileImageLoad,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('tilemap-transition-background')),
      findsNothing,
    );
    final rendererState = tester.state(_liveTilemapRendererFinder());

    viewportSize.value = const Size(640, 480);
    await tester.pump();

    expect(_liveTilemapRendererFinder(), findsOneWidget);
    expect(tester.state(_liveTilemapRendererFinder()), same(rendererState));
    expect(
      find.byKey(const ValueKey<String>('tilemap-transition-background')),
      findsNothing,
    );

    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('tilemap-transition-background')),
      findsNothing,
    );
  });

  testWidgets(
    'Tilemap restores drilled state after returning from location chat',
    (tester) async {
      final locationChatOpen = ValueNotifier<bool>(false);
      final restorationController = TilemapRestorationController();
      final transport = _LocationTilemapTransport({
        'root': _locationTilemapData('branch', assetName: 'root'),
        'branch': _locationTilemapData('leaf_a', assetName: 'branch'),
      });
      final branch = _locationNode(
        'branch',
        children: [_locationNode('leaf_a'), _locationNode('leaf_b')],
      );
      addTearDown(locationChatOpen.dispose);

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: locationChatOpen,
                builder: (context, chatOpen, _) {
                  if (chatOpen) {
                    return const ColoredBox(
                      key: ValueKey<String>('location-chat-map-placeholder'),
                      color: Colors.black,
                    );
                  }
                  return Tilemap.world(
                    key: const ValueKey<String>('location-chat-tilemap'),
                    worldId: 'w_1',
                    locationNodes: [branch],
                    restorationController: restorationController,
                    messageBubbles: const <WorldMapMessageBubble>[
                      WorldMapMessageBubble(
                        characterId: 'char-a',
                        content: 'Visible before opening chat.',
                      ),
                    ],
                    tileImageLoader: _completeTileImageLoad,
                  );
                },
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 7; frame += 1) {
        await tester.pump();
      }

      expect(
        find.byKey(const ValueKey<String>('tilemap-transition-background')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('tilemap-grid')), findsWidgets);
      final rootRenderer = tester.widget<TilemapRenderer>(
        _liveTilemapRendererFinder(),
      );
      await rootRenderer.onTileAction!(rootRenderer.config.tiles.single);
      await tester.pump();

      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:branch',
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-exit-location')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tilemap-exit-location')),
          matching: find.text('branch'),
        ),
        findsOneWidget,
      );
      final rendererState = tester.state(_liveTilemapRendererFinder());

      locationChatOpen.value = true;
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tilemap-transition-background')),
        findsNothing,
      );
      expect(_liveTilemapRendererFinder(), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('location-chat-map-placeholder')),
        findsOneWidget,
      );

      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('tilemap-transition-background')),
        findsNothing,
      );

      locationChatOpen.value = false;
      for (var frame = 0; frame < 7; frame += 1) {
        await tester.pump();
      }

      expect(
        find.byKey(const ValueKey<String>('tilemap-transition-background')),
        findsNothing,
      );
      expect(
        tester.state(_liveTilemapRendererFinder()),
        isNot(same(rendererState)),
      );
      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:branch',
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-exit-location')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tilemap-exit-location')),
          matching: find.text('branch'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-grid')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Tilemap opens the requested target parent after chat switches location',
    (tester) async {
      final locationChatOpen = ValueNotifier<bool>(false);
      final restorationController = TilemapRestorationController();
      final transport = _LocationTilemapTransport({
        'root': _locationTilemapData('branch_a', assetName: 'root'),
        'branch_b': _locationTilemapData('leaf_b2', assetName: 'branch_b'),
      });
      final branchA = _locationNode(
        'branch_a',
        children: [_locationNode('leaf_a1'), _locationNode('leaf_a2')],
      );
      final branchB = _locationNode(
        'branch_b',
        children: [_locationNode('leaf_b1'), _locationNode('leaf_b2')],
      );
      addTearDown(locationChatOpen.dispose);
      addTearDown(restorationController.dispose);

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: locationChatOpen,
                builder: (context, chatOpen, _) {
                  if (chatOpen) return const ColoredBox(color: Colors.black);
                  return Tilemap.world(
                    worldId: 'w_1',
                    locationNodes: [branchA, branchB],
                    restorationController: restorationController,
                    tileImageLoader: _completeTileImageLoad,
                  );
                },
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 7; frame += 1) {
        await tester.pump();
      }
      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:root',
      );

      locationChatOpen.value = true;
      await tester.pump();
      expect(_liveTilemapRendererFinder(), findsNothing);

      restorationController.requestLocationNavigation('leaf_b2');
      locationChatOpen.value = false;
      for (var frame = 0; frame < 7; frame += 1) {
        await tester.pump();
      }

      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:branch_b',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tilemap-exit-location')),
          matching: find.text('branch_b'),
        ),
        findsOneWidget,
      );
      expect(
        transport.requests.any(
          (request) => request.uri.queryParameters['location_id'] == 'branch_b',
        ),
        isTrue,
      );
    },
  );

  testWidgets('Tilemap applies a requested chat target while still mounted', (
    tester,
  ) async {
    final restorationController = TilemapRestorationController();
    final transport = _LocationTilemapTransport({
      'root': _locationTilemapData('branch_a', assetName: 'root'),
      'branch_b': _locationTilemapData('leaf_b2', assetName: 'branch_b'),
    });
    final branchA = _locationNode(
      'branch_a',
      children: [_locationNode('leaf_a1'), _locationNode('leaf_a2')],
    );
    final branchB = _locationNode(
      'branch_b',
      children: [_locationNode('leaf_b1'), _locationNode('leaf_b2')],
    );
    addTearDown(restorationController.dispose);

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.world(
              worldId: 'w_1',
              locationNodes: [branchA, branchB],
              restorationController: restorationController,
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 7; frame += 1) {
      await tester.pump();
    }

    restorationController.requestLocationNavigation('leaf_b2');
    for (var frame = 0; frame < 7; frame += 1) {
      await tester.pump();
    }

    expect(
      tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
      'world:w_1:branch_b',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-exit-location')),
    );
    for (var frame = 0; frame < 5; frame += 1) {
      await tester.pump();
    }
    expect(
      tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
      'world:w_1:root',
    );
  });

  testWidgets('Tilemap restores cached settings before creating its renderer', (
    tester,
  ) async {
    const cachedSettings = TilemapRenderSettings(
      visualMode: TilemapVisualMode.light,
      loadingStyle: TilemapLoadingStyle.worldPortal,
      fogControlPoints: [
        TilemapFogControlPoint(position: 0, opacity: 0.05),
        TilemapFogControlPoint(position: 0.2, opacity: 0.25),
        TilemapFogControlPoint(position: 0.45, opacity: 0.55),
        TilemapFogControlPoint(position: 0.7, opacity: 0.8),
        TilemapFogControlPoint(position: 1, opacity: 0.9),
      ],
      blendFogWithShadowTiles: true,
      cacheFogTileBitmaps: false,
      showShadowZeroBorders: false,
      showLocationImageFlow: false,
      locationImageFlowAngleDegrees: 135,
      locationImageFlowGradientPoints:
          tilemapDefaultLocationImageFlowGradientPoints,
      locationImageFlowOpacity: 0.6,
      locationImageFlowDurationSeconds: 5,
      locationImageFlowBlendMode: TilemapLocationImageFlowBlendMode.screen,
      initialScale: 18,
      dragBoundaryPaddingTiles: 9,
    );
    await const TilemapSettingsStore().save(cachedSettings);
    final transport = _DelayedTilemapTransport();

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: const Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
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
    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-style-worldPortal')),
      findsOneWidget,
    );

    transport.complete(_locationTilemapData('leaf', shadow: 1));
    await tester.pump();
    await tester.pump();

    final renderer = tester.widget<TilemapRenderer>(
      _liveTilemapRendererFinder(),
    );
    expect(renderer.visualMode, TilemapVisualMode.light);
    expect(renderer.fogControlPoints, cachedSettings.fogControlPoints);
    expect(renderer.blendFogWithShadowTiles, true);
    expect(renderer.cacheFogTileBitmaps, false);
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
    expect(renderer.initialScale, 18);
    expect(renderer.dragBoundaryPaddingTiles, 9);

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
      tester
          .widget<Switch>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-fog-bitmap-cache'),
            ),
          )
          .value,
      false,
    );
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
      find.byKey(
        const ValueKey<String>('tilemap-settings-drag-boundary-padding'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DropdownButton<TilemapLoadingStyle>>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-loading-style'),
            ),
          )
          .value,
      TilemapLoadingStyle.worldPortal,
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
    expect(
      tester
          .widget<DropdownButton<TilemapLoadingStyle>>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-loading-style'),
            ),
          )
          .value,
      tilemapDefaultLoadingStyle,
    );
    expect(
      tester
          .widget<Switch>(
            find.byKey(
              const ValueKey<String>('tilemap-settings-fog-bitmap-cache'),
            ),
          )
          .value,
      tilemapDefaultCacheFogTileBitmaps,
    );
    expect(
      tester
          .widget<TilemapRenderer>(_liveTilemapRendererFinder())
          .cacheFogTileBitmaps,
      tilemapDefaultCacheFogTileBitmaps,
    );
    await tester.tap(copyButton);
    await tester.pump();
    expect(copiedValues, hasLength(1));
    final copiedDefaults = jsonDecode(copiedValues.single);
    expect(copiedDefaults['cache_fog_tile_bitmaps'], true);
    expect(copiedDefaults, defaults.toJson());
  });

  testWidgets('Tilemap copies all current settings as serialized JSON', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TilemapSettingsButtonVisibilityController.storageKey: true,
    });
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
          home: const Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
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
    expect(copiedJson['cache_fog_tile_bitmaps'], true);
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
            tileImageLoader: _completeTileImageLoad,
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
            tileImageLoader: _completeTileImageLoad,
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
            tileImageLoader: _completeTileImageLoad,
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
            body: Tilemap.origin(
              originId: 'o_1',
              locationId: 'root',
              tileImageLoader: _completeTileImageLoad,
            ),
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
    debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
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

  testWidgets(
    'Tilemap promotes the same mounted warm renderer and reuses it on back',
    (tester) async {
      debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
      final transport = _LocationTilemapTransport({
        'root': _locationTilemapData('branch', assetName: 'root'),
        'branch': _locationTilemapData('leaf_a', assetName: 'branch'),
      });
      final branch = _locationNode(
        'branch',
        children: [_locationNode('leaf_a'), _locationNode('leaf_b')],
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: Tilemap.world(
                worldId: 'w_1',
                locationNodes: [branch],
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 7; frame += 1) {
        await tester.pump();
      }

      final rootFinder = _tilemapRendererForMap('world:w_1:root');
      final branchFinder = _tilemapRendererForMap('world:w_1:branch');
      expect(rootFinder, findsOneWidget);
      expect(branchFinder, findsOneWidget);
      final rootState = tester.state(rootFinder);
      final branchState = tester.state(branchFinder);
      expect(tester.widget<TilemapRenderer>(branchFinder).onTileAction, isNull);

      final rootRenderer = tester.widget<TilemapRenderer>(
        _liveTilemapRendererFinder(),
      );
      await rootRenderer.onTileAction!(rootRenderer.config.tiles.single);
      await tester.pump();

      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:branch',
      );
      expect(tester.state(branchFinder), same(branchState));
      expect(find.byType(RawImage), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('tilemap-transition-background')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('tilemap-exit-location')),
      );
      await tester.pump();

      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:root',
      );
      expect(tester.state(rootFinder), same(rootState));
      expect(tester.state(branchFinder), same(branchState));
    },
  );

  testWidgets(
    'animationsPaused defers warm maps and offstages existing warm renderers',
    (tester) async {
      debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
      final animationsPaused = ValueNotifier<bool>(true);
      addTearDown(animationsPaused.dispose);
      final branchResponse = Completer<Map<String, dynamic>>();
      final transport = _ScriptedLocationTilemapTransport({
        'root': [
          Future<Map<String, dynamic>>.value(
            _locationTilemapData('branch', assetName: 'root'),
          ),
        ],
        'branch': [branchResponse.future],
      });
      final loadedAssets = <String>[];
      final branch = _locationNode(
        'branch',
        children: [_locationNode('leaf_a'), _locationNode('leaf_b')],
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: animationsPaused,
                builder: (context, paused, _) {
                  return Tilemap.world(
                    worldId: 'w_1',
                    locationNodes: [branch],
                    animationsPaused: paused,
                    tileImageLoader: (assetUrl) async {
                      loadedAssets.add(assetUrl);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump();
      }

      expect(transport.requestCount('root'), 1);
      expect(transport.requestCount('branch'), 0);
      expect(_tilemapRendererForMap('world:w_1:root'), findsOneWidget);
      expect(_tilemapRendererForMap('world:w_1:branch'), findsNothing);

      animationsPaused.value = false;
      for (
        var frame = 0;
        frame < 10 && transport.requestCount('branch') == 0;
        frame += 1
      ) {
        await tester.pump();
      }

      expect(transport.requestCount('branch'), 1);
      animationsPaused.value = true;
      await tester.pump();
      branchResponse.complete(
        _locationTilemapData('leaf_a', assetName: 'branch'),
      );
      for (var frame = 0; frame < 4; frame += 1) {
        await tester.pump();
      }
      expect(
        loadedAssets.any((assetUrl) => assetUrl.contains('/branch.png?')),
        isFalse,
      );
      expect(_tilemapRendererForMap('world:w_1:branch'), findsNothing);

      animationsPaused.value = false;
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump();
      }
      expect(
        loadedAssets.any((assetUrl) => assetUrl.contains('/branch.png?')),
        isTrue,
      );
      final visibleWarmRenderer = _tilemapRendererForMap('world:w_1:branch');
      expect(visibleWarmRenderer, findsOneWidget);
      final warmRendererState = tester.state(visibleWarmRenderer);

      animationsPaused.value = true;
      await tester.pump();

      final offstageWarmRenderer = find.byWidgetPredicate(
        (widget) =>
            widget is TilemapRenderer && widget.config.id == 'world:w_1:branch',
        description: 'offstage warm TilemapRenderer',
        skipOffstage: false,
      );
      expect(offstageWarmRenderer, findsOneWidget);
      expect(tester.state(offstageWarmRenderer), same(warmRendererState));
      expect(_tilemapRendererForMap('world:w_1:branch'), findsNothing);
      expect(
        tester
            .widgetList<Offstage>(
              find.ancestor(
                of: offstageWarmRenderer,
                matching: find.byType(Offstage, skipOffstage: false),
              ),
            )
            .any((widget) => widget.offstage),
        isTrue,
      );
      expect(_tilemapRendererForMap('world:w_1:root'), findsOneWidget);

      animationsPaused.value = false;
      await tester.pump();

      expect(
        tester.state(_tilemapRendererForMap('world:w_1:branch')),
        same(warmRendererState),
      );
    },
  );

  testWidgets('Tilemap keeps one parent and two child warm renderers', (
    tester,
  ) async {
    debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
    final transport = _LocationTilemapTransport({
      'root': _locationTilemapData('branch', assetName: 'root'),
      'branch': _tilemapData(
        tileLocationIds: const ['child_a', 'child_b'],
        assetName: 'branch',
      ),
      'child_a': _locationTilemapData('leaf_a', assetName: 'child_a'),
      'child_b': _locationTilemapData('leaf_b', assetName: 'child_b'),
    });
    final branch = _locationNode(
      'branch',
      children: [
        _locationNode(
          'child_a',
          children: [_locationNode('leaf_a'), _locationNode('leaf_a_2')],
        ),
        _locationNode(
          'child_b',
          children: [_locationNode('leaf_b'), _locationNode('leaf_b_2')],
        ),
      ],
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.world(
              worldId: 'w_1',
              locationNodes: [branch],
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump();
    }

    final rootRenderer = tester.widget<TilemapRenderer>(
      _liveTilemapRendererFinder(),
    );
    await rootRenderer.onTileAction!(rootRenderer.config.tiles.single);
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump();
    }

    expect(find.byType(TilemapRenderer), findsNWidgets(4));
    expect(_tilemapRendererForMap('world:w_1:root'), findsOneWidget);
    expect(_tilemapRendererForMap('world:w_1:branch'), findsOneWidget);
    expect(_tilemapRendererForMap('world:w_1:child_a'), findsOneWidget);
    expect(_tilemapRendererForMap('world:w_1:child_b'), findsOneWidget);
  });

  testWidgets('Tilemap map-result LRU stays bounded at eight locations', (
    tester,
  ) async {
    final locationIds = List<String>.generate(10, (index) => 'location_$index');
    final transport = _LocationTilemapTransport({
      for (final locationId in locationIds)
        locationId: _locationTilemapData(
          'leaf_$locationId',
          assetName: locationId,
        ),
    });
    final currentLocation = ValueNotifier<String>(locationIds.first);
    addTearDown(currentLocation.dispose);

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: currentLocation,
              builder: (context, locationId, _) {
                return Tilemap.world(
                  key: const ValueKey<String>('bounded-map-results'),
                  worldId: 'w_1',
                  locationId: locationId,
                  tileImageLoader: _completeTileImageLoad,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    for (final locationId in locationIds.skip(1)) {
      currentLocation.value = locationId;
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    expect(transport.requestCount(locationIds.first), 1);
    currentLocation.value = locationIds.first;
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(transport.requestCount(locationIds.first), 2);
    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
      findsNothing,
    );
  });

  testWidgets(
    'Tilemap keeps only the parent after drilling into an uncached target',
    (tester) async {
      debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
      final transport = _LocationTilemapTransport({
        'root': _tilemapData(
          tileLocationIds: const ['branch_a', 'branch_b', 'branch_c'],
          assetName: 'root',
        ),
        'branch_a': _locationTilemapData('leaf_a', assetName: 'branch_a'),
        'branch_b': _locationTilemapData('leaf_b', assetName: 'branch_b'),
        'branch_c': _locationTilemapData('leaf_c', assetName: 'branch_c'),
      });
      final locationNodes = [
        for (final branchId in const ['branch_a', 'branch_b', 'branch_c'])
          _locationNode(
            branchId,
            children: [
              _locationNode('leaf_${branchId}_a'),
              _locationNode('leaf_${branchId}_b'),
            ],
          ),
      ];

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: Tilemap.world(
                worldId: 'w_1',
                locationNodes: locationNodes,
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 9; frame += 1) {
        await tester.pump();
      }

      expect(find.byType(TilemapRenderer), findsNWidgets(3));
      expect(transport.requestCount('branch_c'), 0);
      final rootFinder = _tilemapRendererForMap('world:w_1:root');
      final rootState = tester.state(rootFinder);
      final rootRenderer = tester.widget<TilemapRenderer>(
        _liveTilemapRendererFinder(),
      );

      await rootRenderer.onTileAction!(rootRenderer.config.tiles.last);
      await tester.pump();
      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:branch_c',
      );
      expect(
        tester
            .widget<TilemapRenderer>(_liveTilemapRendererFinder())
            .onTileAction,
        isNotNull,
      );
      for (var frame = 0; frame < 3; frame += 1) {
        await tester.pump();
      }

      expect(transport.requestCount('branch_c'), 1);
      expect(find.byType(TilemapRenderer), findsNWidgets(2));
      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:branch_c',
      );
      expect(tester.state(rootFinder), same(rootState));
    },
  );

  testWidgets(
    'Tilemap map reload refetches warm maps without remounting unchanged renderers',
    (tester) async {
      debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
      final rootData = _locationTilemapData('branch', assetName: 'root');
      final branchData = _locationTilemapData('leaf', assetName: 'branch');
      final transport = _ScriptedLocationTilemapTransport({
        'root': [
          Future<Map<String, dynamic>>.value(rootData),
          Future<Map<String, dynamic>>.value(rootData),
        ],
        'branch': [
          Future<Map<String, dynamic>>.value(branchData),
          Future<Map<String, dynamic>>.value(branchData),
        ],
      });
      final reloadRevision = ValueNotifier<int>(0);
      addTearDown(reloadRevision.dispose);

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: reloadRevision,
                builder: (context, revision, _) => Tilemap.world(
                  worldId: 'w_1',
                  reloadRevision: revision,
                  locationNodes: [
                    _locationNode(
                      'branch',
                      children: [
                        _locationNode('leaf'),
                        _locationNode('leaf-2'),
                      ],
                    ),
                  ],
                  tileImageLoader: _completeTileImageLoad,
                ),
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 12; frame += 1) {
        await tester.pump();
      }

      final rootFinder = _tilemapRendererForMap('world:w_1:root');
      final branchFinder = _tilemapRendererForMap('world:w_1:branch');
      expect(rootFinder, findsOneWidget);
      expect(branchFinder, findsOneWidget);
      final rootState = tester.state(rootFinder);
      final branchState = tester.state(branchFinder);

      reloadRevision.value = 1;
      for (var frame = 0; frame < 16; frame += 1) {
        await tester.pump();
      }

      expect(transport.requestCount('root'), 2);
      expect(transport.requestCount('branch'), 2);
      expect(tester.state(rootFinder), same(rootState));
      expect(tester.state(branchFinder), same(branchState));
    },
  );

  testWidgets('Tilemap map reload remounts only a changed current renderer', (
    tester,
  ) async {
    debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
    final transport = _ScriptedLocationTilemapTransport({
      'root': [
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('branch', assetName: 'root'),
        ),
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('branch', assetName: 'root-v2'),
        ),
      ],
      'branch': [
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf', assetName: 'branch'),
        ),
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf', assetName: 'branch'),
        ),
      ],
    });
    final reloadRevision = ValueNotifier<int>(0);
    addTearDown(reloadRevision.dispose);

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: reloadRevision,
              builder: (context, revision, _) => Tilemap.world(
                worldId: 'w_1',
                reloadRevision: revision,
                locationNodes: [
                  _locationNode(
                    'branch',
                    children: [_locationNode('leaf'), _locationNode('leaf-2')],
                  ),
                ],
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump();
    }

    final rootFinder = _tilemapRendererForMap('world:w_1:root');
    final branchFinder = _tilemapRendererForMap('world:w_1:branch');
    final rootState = tester.state(rootFinder);
    final branchState = tester.state(branchFinder);

    reloadRevision.value = 1;
    for (var frame = 0; frame < 16; frame += 1) {
      await tester.pump();
    }

    expect(transport.requestCount('root'), 2);
    expect(transport.requestCount('branch'), 2);
    expect(tester.state(rootFinder), isNot(same(rootState)));
    expect(tester.state(branchFinder), same(branchState));
    expect(
      tester
          .widget<TilemapRenderer>(_liveTilemapRendererFinder())
          .config
          .tileTypes['tile'],
      contains('root-v2.png'),
    );
  });

  testWidgets('Tilemap map reload remounts only a changed warm renderer', (
    tester,
  ) async {
    debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
    final rootData = _locationTilemapData('branch', assetName: 'root');
    final transport = _ScriptedLocationTilemapTransport({
      'root': [
        Future<Map<String, dynamic>>.value(rootData),
        Future<Map<String, dynamic>>.value(rootData),
      ],
      'branch': [
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf', assetName: 'branch'),
        ),
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf', assetName: 'branch-v2'),
        ),
      ],
    });
    final reloadRevision = ValueNotifier<int>(0);
    addTearDown(reloadRevision.dispose);

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: reloadRevision,
              builder: (context, revision, _) => Tilemap.world(
                worldId: 'w_1',
                reloadRevision: revision,
                locationNodes: [
                  _locationNode(
                    'branch',
                    children: [_locationNode('leaf'), _locationNode('leaf-2')],
                  ),
                ],
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump();
    }

    final rootFinder = _tilemapRendererForMap('world:w_1:root');
    final branchFinder = _tilemapRendererForMap('world:w_1:branch');
    final rootState = tester.state(rootFinder);
    final branchState = tester.state(branchFinder);

    reloadRevision.value = 1;
    for (var frame = 0; frame < 20; frame += 1) {
      await tester.pump();
    }

    expect(transport.requestCount('root'), 2);
    expect(transport.requestCount('branch'), 2);
    expect(tester.state(rootFinder), same(rootState));
    expect(tester.state(branchFinder), isNot(same(branchState)));
    expect(
      tester.widget<TilemapRenderer>(branchFinder).config.tileTypes['tile'],
      contains('branch-v2.png'),
    );
  });

  testWidgets('Tilemap ignores an older load that finishes after map reload', (
    tester,
  ) async {
    debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
    final staleInitialResponse = Completer<Map<String, dynamic>>();
    final transport = _ScriptedLocationTilemapTransport({
      'root': [
        staleInitialResponse.future,
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf', assetName: 'root-v2'),
        ),
      ],
    });
    final reloadRevision = ValueNotifier<int>(0);
    addTearDown(reloadRevision.dispose);

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: reloadRevision,
              builder: (context, revision, _) => Tilemap.world(
                worldId: 'w_1',
                reloadRevision: revision,
                locationNodes: [_locationNode('leaf')],
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(transport.requestCount('root'), 1);

    reloadRevision.value = 1;
    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump();
    }
    expect(transport.requestCount('root'), 2);
    expect(
      tester
          .widget<TilemapRenderer>(_liveTilemapRendererFinder())
          .config
          .tileTypes['tile'],
      contains('root-v2.png'),
    );

    staleInitialResponse.complete(
      _locationTilemapData('leaf', assetName: 'root-stale'),
    );
    for (var frame = 0; frame < 6; frame += 1) {
      await tester.pump();
    }
    expect(
      tester
          .widget<TilemapRenderer>(_liveTilemapRendererFinder())
          .config
          .tileTypes['tile'],
      contains('root-v2.png'),
    );
  });

  testWidgets(
    'Tilemap coalesces map reloads and applies the trailing response',
    (tester) async {
      debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
      final firstRefresh = Completer<Map<String, dynamic>>();
      final trailingRefresh = Completer<Map<String, dynamic>>();
      final transport = _ScriptedLocationTilemapTransport({
        'root': [
          Future<Map<String, dynamic>>.value(
            _locationTilemapData('leaf', assetName: 'root'),
          ),
          firstRefresh.future,
          trailingRefresh.future,
        ],
      });
      final reloadRevision = ValueNotifier<int>(0);
      addTearDown(reloadRevision.dispose);

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: reloadRevision,
                builder: (context, revision, _) => Tilemap.world(
                  worldId: 'w_1',
                  reloadRevision: revision,
                  locationNodes: [_locationNode('leaf')],
                  tileImageLoader: _completeTileImageLoad,
                ),
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump();
      }

      reloadRevision.value = 1;
      for (var frame = 0; frame < 6; frame += 1) {
        await tester.pump();
      }
      expect(transport.requestCount('root'), 2);

      reloadRevision.value = 2;
      await tester.pump();
      expect(transport.requestCount('root'), 2);

      firstRefresh.complete(
        _locationTilemapData('leaf', assetName: 'root-stale'),
      );
      for (
        var frame = 0;
        frame < 10 && transport.requestCount('root') < 3;
        frame += 1
      ) {
        await tester.pump();
      }
      expect(transport.requestCount('root'), 3);

      trailingRefresh.complete(
        _locationTilemapData('leaf', assetName: 'root-v2'),
      );
      for (var frame = 0; frame < 10; frame += 1) {
        await tester.pump();
      }
      expect(
        tester
            .widget<TilemapRenderer>(_liveTilemapRendererFinder())
            .config
            .tileTypes['tile'],
        contains('root-v2.png'),
      );
    },
  );

  testWidgets('Tilemap keeps the last renderer when map reload fails', (
    tester,
  ) async {
    debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
    final failedRefresh = Completer<Map<String, dynamic>>();
    final transport = _ScriptedLocationTilemapTransport({
      'root': [
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf', assetName: 'root'),
        ),
        failedRefresh.future,
      ],
    });
    final reloadRevision = ValueNotifier<int>(0);
    addTearDown(reloadRevision.dispose);

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: reloadRevision,
              builder: (context, revision, _) => Tilemap.world(
                worldId: 'w_1',
                reloadRevision: revision,
                locationNodes: [_locationNode('leaf')],
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump();
    }
    final rendererFinder = _liveTilemapRendererFinder();
    final rendererState = tester.state(rendererFinder);

    reloadRevision.value = 1;
    for (var frame = 0; frame < 4; frame += 1) {
      await tester.pump();
    }
    failedRefresh.completeError(StateError('map reload failed'));
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump();
    }

    expect(transport.requestCount('root'), 2);
    expect(tester.state(rendererFinder), same(rendererState));
    expect(
      tester.widget<TilemapRenderer>(rendererFinder).config.tileTypes['tile'],
      contains('root.png'),
    );
  });

  testWidgets('Tilemap recovers an image error when map reload changes URLs', (
    tester,
  ) async {
    final transport = _ScriptedLocationTilemapTransport({
      'root': [
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf', assetName: 'root-bad'),
        ),
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf', assetName: 'root-good'),
        ),
      ],
    });
    final reloadRevision = ValueNotifier<int>(0);
    addTearDown(reloadRevision.dispose);

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: reloadRevision,
              builder: (context, revision, _) => Tilemap.world(
                worldId: 'w_1',
                reloadRevision: revision,
                locationNodes: [_locationNode('leaf')],
                tileImageLoader: (assetUrl) async {
                  if (assetUrl.contains('root-bad')) {
                    throw StateError('bad tile image');
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump();
    }
    expect(find.byKey(const ValueKey<String>('tilemap-retry')), findsOneWidget);

    reloadRevision.value = 1;
    for (var frame = 0; frame < 16; frame += 1) {
      await tester.pump();
    }

    expect(find.byKey(const ValueKey<String>('tilemap-retry')), findsNothing);
    expect(
      tester
          .widget<TilemapRenderer>(_liveTilemapRendererFinder())
          .config
          .tileTypes['tile'],
      contains('root-good.png'),
    );
  });

  testWidgets('Tilemap reload evicts an unrefreshed grandparent cache', (
    tester,
  ) async {
    debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
    final rootV1 = _locationTilemapData('branch', assetName: 'root');
    final branchV1 = _locationTilemapData('subbranch', assetName: 'branch');
    final subbranchV1 = _locationTilemapData('leaf', assetName: 'subbranch');
    final transport = _ScriptedLocationTilemapTransport({
      'root': [
        Future<Map<String, dynamic>>.value(rootV1),
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('branch', assetName: 'root-v2'),
        ),
      ],
      'branch': [
        Future<Map<String, dynamic>>.value(branchV1),
        Future<Map<String, dynamic>>.value(branchV1),
      ],
      'subbranch': [
        Future<Map<String, dynamic>>.value(subbranchV1),
        Future<Map<String, dynamic>>.value(subbranchV1),
      ],
    });
    final reloadRevision = ValueNotifier<int>(0);
    addTearDown(reloadRevision.dispose);
    final locationNodes = [
      _locationNode(
        'branch',
        children: [
          _locationNode(
            'subbranch',
            children: [_locationNode('leaf'), _locationNode('leaf-2')],
          ),
          _locationNode('branch-leaf'),
        ],
      ),
    ];

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: reloadRevision,
              builder: (context, revision, _) => Tilemap.world(
                worldId: 'w_1',
                reloadRevision: revision,
                locationNodes: locationNodes,
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump();
    }

    var renderer = tester.widget<TilemapRenderer>(_liveTilemapRendererFinder());
    await renderer.onTileAction!(renderer.config.tiles.single);
    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump();
    }
    renderer = tester.widget<TilemapRenderer>(_liveTilemapRendererFinder());
    expect(renderer.config.id, 'world:w_1:branch');
    await renderer.onTileAction!(renderer.config.tiles.single);
    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump();
    }
    expect(
      tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
      'world:w_1:subbranch',
    );

    reloadRevision.value = 1;
    for (var frame = 0; frame < 16; frame += 1) {
      await tester.pump();
    }
    expect(transport.requestCount('subbranch'), 2);
    expect(transport.requestCount('branch'), 2);

    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-exit-location')),
    );
    await tester.pump();
    expect(
      tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
      'world:w_1:branch',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-exit-location')),
    );
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump();
    }

    expect(transport.requestCount('root'), 2);
    expect(
      tester
          .widget<TilemapRenderer>(_liveTilemapRendererFinder())
          .config
          .tileTypes['tile'],
      contains('root-v2.png'),
    );
  });

  testWidgets(
    'Tilemap silently preloads drillable maps and never reloads on drill/back',
    (tester) async {
      debugGenesisStaticNetworkImageCompleter = (_) => _failedImageCompleter();
      final transport = _LocationTilemapTransport({
        'root': _tilemapData(
          tileLocationIds: const ['branch_a', 'branch_b', 'leaf'],
          assetName: 'root',
        ),
        'branch_a': _locationTilemapData('leaf_a', assetName: 'branch_a'),
        'branch_b': _locationTilemapData('leaf_b', assetName: 'branch_b'),
      });
      final services = _servicesWithTransport(transport);
      final pendingImages = <String, Completer<void>>{};
      Future<void> loadImage(String assetUrl) {
        return pendingImages.putIfAbsent(assetUrl, Completer<void>.new).future;
      }

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: Scaffold(
              body: Tilemap.world(
                worldId: 'w_1',
                locationNodes: [
                  _locationNode(
                    'branch_a',
                    children: [
                      _locationNode('leaf_a'),
                      _locationNode('leaf_a_2'),
                    ],
                  ),
                  _locationNode(
                    'branch_b',
                    children: [
                      _locationNode('leaf_b'),
                      _locationNode('leaf_b_2'),
                    ],
                  ),
                  _locationNode('leaf'),
                ],
                tileImageLoader: loadImage,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsOneWidget,
      );
      expect(_liveTilemapRendererFinder(), findsNothing);
      pendingImages.entries
          .singleWhere((entry) => entry.key.contains('/root.png?'))
          .value
          .complete();
      for (
        var frame = 0;
        frame < 10 && transport.requestCount('branch_a') == 0;
        frame += 1
      ) {
        await tester.pump();
      }

      expect(
        transport.requests
            .map((request) => request.uri.queryParameters['location_id'])
            .toSet(),
        {'root', 'branch_a'},
      );
      expect(
        transport.requests.every(
          (request) => request.uri.path == '/api/v1/world/map',
        ),
        isTrue,
      );
      expect(
        pendingImages.keys.any((url) => url.contains('/branch_a.png?')),
        isTrue,
      );
      expect(
        pendingImages.keys.any((url) => url.contains('/branch_b.png?')),
        isFalse,
      );
      pendingImages.entries
          .singleWhere((entry) => entry.key.contains('/branch_a.png?'))
          .value
          .complete();
      for (
        var frame = 0;
        frame < 10 && transport.requestCount('branch_b') == 0;
        frame += 1
      ) {
        await tester.pump();
      }

      expect(
        transport.requests
            .map((request) => request.uri.queryParameters['location_id'])
            .toSet(),
        {'root', 'branch_a', 'branch_b'},
      );
      expect(
        pendingImages.keys.any((url) => url.contains('/branch_b.png?')),
        isTrue,
      );

      final rootRenderer = tester.widget<TilemapRenderer>(
        _liveTilemapRendererFinder(),
      );
      expect(rootRenderer.config.id, 'world:w_1:root');
      await rootRenderer.onTileAction!(rootRenderer.config.tiles.first);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:branch_a',
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-exit-location')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('tilemap-exit-location')),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:root',
      );
      expect(transport.requestCount('root'), 1);
      expect(transport.requestCount('branch_a'), 1);
      expect(transport.requestCount('branch_b'), 1);

      for (final completer in pendingImages.values) {
        if (!completer.isCompleted) completer.complete();
      }
      await tester.pump();
    },
  );

  testWidgets(
    'Tilemap reuses an in-flight silent request without reopening Loading',
    (tester) async {
      final branchResponse = Completer<Map<String, dynamic>>();
      final transport = _ScriptedLocationTilemapTransport({
        'root': [
          Future<Map<String, dynamic>>.value(
            _locationTilemapData('branch', assetName: 'root'),
          ),
        ],
        'branch': [branchResponse.future],
      });
      final branch = _locationNode(
        'branch',
        children: [_locationNode('leaf_a'), _locationNode('leaf_b')],
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: _servicesWithTransport(transport),
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: Scaffold(
              body: Tilemap.world(
                worldId: 'w_1',
                locationNodes: [branch],
                tileImageLoader: _completeTileImageLoad,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(transport.requestCount('branch'), 1);
      final rootRenderer = tester.widget<TilemapRenderer>(
        _liveTilemapRendererFinder(),
      );
      await rootRenderer.onTileAction!(rootRenderer.config.tiles.single);
      await tester.pump();

      expect(transport.requestCount('branch'), 1);
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
      expect(_liveTilemapRendererFinder(), findsNothing);
      expect(
        tester
            .widget<TilemapRenderer>(_tilemapRendererForMap('world:w_1:root'))
            .isForeground,
        isFalse,
      );
      expect(
        tester
            .widget<TilemapRenderer>(_tilemapRendererForMap('world:w_1:root'))
            .onTileAction,
        isNull,
        reason: 'the previous map is retained only as a non-interactive parent',
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-transition-background')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('tilemap-exit-location')),
      );
      await tester.pump();
      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:root',
      );

      branchResponse.complete(
        _locationTilemapData('leaf_a', assetName: 'branch'),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:root',
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );

      final cachedRootRenderer = tester.widget<TilemapRenderer>(
        _liveTilemapRendererFinder(),
      );
      await cachedRootRenderer.onTileAction!(
        cachedRootRenderer.config.tiles.single,
      );
      await tester.pump();
      await tester.pump();

      expect(transport.requestCount('branch'), 1);
      expect(
        tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
        'world:w_1:branch',
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
        findsNothing,
      );
    },
  );

  testWidgets('Tilemap silent map failure does not poison interactive retry', (
    tester,
  ) async {
    final transport = _ScriptedLocationTilemapTransport({
      'root': [
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('branch', assetName: 'root'),
        ),
      ],
      'branch': [
        Future<Map<String, dynamic>>.value(<String, dynamic>{}),
        Future<Map<String, dynamic>>.value(
          _locationTilemapData('leaf_a', assetName: 'branch'),
        ),
      ],
    });
    final branch = _locationNode(
      'branch',
      children: [_locationNode('leaf_a'), _locationNode('leaf_b')],
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              locationNodes: [branch],
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(transport.requestCount('branch'), 1);
    expect(find.byKey(const ValueKey<String>('tilemap-error')), findsNothing);
    expect(_liveTilemapRendererFinder(), findsOneWidget);

    final rootRenderer = tester.widget<TilemapRenderer>(
      _liveTilemapRendererFinder(),
    );
    await rootRenderer.onTileAction!(rootRenderer.config.tiles.single);
    await tester.pump();
    await tester.pump();

    expect(transport.requestCount('branch'), 2);
    expect(
      tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
      'origin:o_1:branch',
    );
    expect(find.byKey(const ValueKey<String>('tilemap-error')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
      findsNothing,
    );
  });

  testWidgets('Tilemap silent tile failure stays out of the foreground UI', (
    tester,
  ) async {
    final transport = _LocationTilemapTransport({
      'root': _locationTilemapData('branch', assetName: 'root'),
      'branch': _locationTilemapData('leaf_a', assetName: 'branch'),
    });
    final branch = _locationNode(
      'branch',
      children: [_locationNode('leaf_a'), _locationNode('leaf_b')],
    );

    Future<void> loadImage(String assetUrl) async {
      if (assetUrl.contains('/branch.png?')) {
        throw StateError('silent branch image failed');
      }
    }

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.world(
              worldId: 'w_1',
              locationNodes: [branch],
              tileImageLoader: loadImage,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('tilemap-error')), findsNothing);
    expect(
      tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
      'world:w_1:root',
    );

    final rootRenderer = tester.widget<TilemapRenderer>(
      _liveTilemapRendererFinder(),
    );
    await rootRenderer.onTileAction!(rootRenderer.config.tiles.single);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('tilemap-error')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('tilemap-loading-overlay')),
      findsNothing,
    );
    expect(
      tester.widget<TilemapRenderer>(_liveTilemapRendererFinder()).config.id,
      'world:w_1:branch',
    );
  });

  testWidgets('Tilemap also silently preloads origin drillable maps', (
    tester,
  ) async {
    final transport = _LocationTilemapTransport({
      'root': _locationTilemapData('branch', assetName: 'root'),
      'branch': _locationTilemapData('leaf_a', assetName: 'branch'),
    });
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
            body: Tilemap.origin(
              originId: 'o_1',
              locationNodes: [branch],
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

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
      {'root', 'branch'},
    );
  });

  testWidgets('Tilemap leaf location uses the existing chat callback', (
    tester,
  ) async {
    final transport = _TilemapTransport(data: _locationTilemapData('leaf'));
    final services = _servicesWithTransport(transport);
    WorldPoint? openedPoint;
    var mapTapCount = 0;
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
              onMapTap: () => mapTapCount += 1,
              onPointTap: (point) => openedPoint = point,
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('leaf'), findsOneWidget);
    final avatarFinder = find.byKey(
      const ValueKey<String>('tilemap-location-avatar-char-a'),
    );
    expect(avatarFinder, findsOneWidget);

    await tester.tap(avatarFinder);
    await tester.pump();

    expect(openedPoint?.id, 'leaf');
    expect(mapTapCount, 1);
    expect(transport.requests, hasLength(1));
  });

  testWidgets('Tilemap location label reports map tap and opens chat once', (
    tester,
  ) async {
    final transport = _TilemapTransport(data: _locationTilemapData('leaf'));
    final services = _servicesWithTransport(transport);
    WorldPoint? openedPoint;
    var mapTapCount = 0;

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              locationNodes: [_locationNode('leaf')],
              onMapTap: () => mapTapCount += 1,
              onPointTap: (point) => openedPoint = point,
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('leaf'));
    await tester.pump();

    expect(openedPoint?.id, 'leaf');
    expect(mapTapCount, 1);
  });

  testWidgets('Tilemap single-child location chain opens the sole leaf chat', (
    tester,
  ) async {
    final transport = _TilemapTransport(data: _locationTilemapData('loc_1'));
    final services = _servicesWithTransport(transport);
    WorldPoint? openedPoint;
    final locationTree = _locationNode(
      'loc_1',
      children: [
        _locationNode('loc_1_1', children: [_locationNode('loc_1_1_1')]),
      ],
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: Tilemap.origin(
              originId: 'o_1',
              locationNodes: [locationTree],
              onPointTap: (point) => openedPoint = point,
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final renderer = tester.widget<TilemapRenderer>(
      _liveTilemapRendererFinder(),
    );
    await renderer.onTileAction!(renderer.config.tiles.single);

    expect(openedPoint?.id, 'loc_1_1_1');
    expect(transport.requests, hasLength(1));
    expect(
      transport.requests.single.uri.queryParameters['location_id'],
      'root',
    );
  });

  testWidgets('Tilemap shows a character bubble and opens its location', (
    tester,
  ) async {
    final transport = _TilemapTransport(data: _locationTilemapData('leaf'));
    final services = _servicesWithTransport(transport);
    WorldPoint? openedPoint;
    var mapTapCount = 0;
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
              messageBubbles: const [
                WorldMapMessageBubble(
                  characterId: 'char-a',
                  content: 'Ada checks the tilemap.',
                ),
              ],
              onMapTap: () => mapTapCount += 1,
              onPointTap: (point) => openedPoint = point,
              tileImageLoader: _completeTileImageLoad,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('tilemap-character-message-bubble-body'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ada checks the tilemap.'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tilemap-character-message-bubble-body'),
      ),
    );
    await tester.pump();

    expect(openedPoint?.id, 'leaf');
    expect(mapTapCount, 1);
  });
}

class _PendingImageStreamCompleter extends ImageStreamCompleter {}

ImageStreamCompleter _failedImageCompleter() {
  return OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('test image load failure')),
  );
}

Map<String, dynamic> _locationTilemapData(
  String locationId, {
  int shadow = 0,
  String assetName = 'tile',
}) {
  return _tilemapData(
    tileLocationIds: [locationId],
    assetName: assetName,
    shadow: shadow,
  );
}

Map<String, dynamic> _tilemapData({
  required List<String> tileLocationIds,
  required String assetName,
  int shadow = 0,
}) {
  return {
    'tile_types': {'tile': 'https://invalid.example.test/tile/$assetName.png'},
    'map_json': {
      'width': tileLocationIds.length,
      'height': 1,
      'tiles': [
        for (var index = 0; index < tileLocationIds.length; index++)
          {
            'x': index,
            'y': 0,
            'type': 'tile',
            'shadow': shadow,
            'location_id': tileLocationIds[index],
          },
      ],
    },
  };
}

Future<void> _completeTileImageLoad(String _) async {}

Map<String, dynamic> _weightedTilemapData() {
  return {
    'tile_types': {
      'a': 'https://invalid.example.test/tile/a.png',
      'b': 'https://invalid.example.test/tile/b.png',
    },
    'map_json': {
      'width': 3,
      'height': 1,
      'tiles': [
        {'x': 0, 'y': 0, 'type': 'a', 'shadow': 0},
        {'x': 1, 'y': 0, 'type': 'a', 'shadow': 0},
        {'x': 2, 'y': 0, 'type': 'b', 'shadow': 0},
      ],
    },
  };
}

Map<String, dynamic> _threeVisibleAssetTilemapData() {
  return {
    'tile_types': {
      'a': 'https://invalid.example.test/tile/a.png',
      'b': 'https://invalid.example.test/tile/b.png',
      'c': 'https://invalid.example.test/tile/c.png',
    },
    'map_json': {
      'width': 3,
      'height': 1,
      'tiles': [
        {'x': 0, 'y': 0, 'type': 'a', 'shadow': 0},
        {'x': 1, 'y': 0, 'type': 'b', 'shadow': 0},
        {'x': 2, 'y': 0, 'type': 'c', 'shadow': 0},
      ],
    },
  };
}

Map<String, dynamic> _visibleFirstTilemapData() {
  return {
    'tile_types': {
      'a': 'https://invalid.example.test/tile/a.png',
      'b': 'https://invalid.example.test/tile/b.png',
      'c': 'https://invalid.example.test/tile/c.png',
      'd': 'https://invalid.example.test/tile/d.png',
      'e': 'https://invalid.example.test/tile/e.png',
    },
    'map_json': {
      'width': 100,
      'height': 100,
      'tiles': [
        {'x': 0, 'y': 0, 'type': 'a', 'shadow': 0, 'location_id': 'focus'},
        {'x': 90, 'y': 90, 'type': 'a', 'shadow': 0},
        {'x': 91, 'y': 91, 'type': 'b', 'shadow': 0},
        {'x': 92, 'y': 92, 'type': 'c', 'shadow': 0},
        {'x': 93, 'y': 93, 'type': 'd', 'shadow': 0},
        {'x': 94, 'y': 94, 'type': 'e', 'shadow': 0},
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

class _LocationTilemapTransport implements HttpTransport {
  _LocationTilemapTransport(this.dataByLocation);

  final Map<String, Map<String, dynamic>> dataByLocation;
  final requests = <TransportRequest>[];

  int requestCount(String locationId) {
    return requests
        .where(
          (request) => request.uri.queryParameters['location_id'] == locationId,
        )
        .length;
  }

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final locationId = request.uri.queryParameters['location_id'] ?? '';
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'err_no': 0,
        'err_msg': 'succ',
        'data': dataByLocation[locationId] ?? <String, dynamic>{},
      }),
    );
  }
}

class _ScriptedLocationTilemapTransport implements HttpTransport {
  _ScriptedLocationTilemapTransport(this.responsesByLocation);

  final Map<String, List<Future<Map<String, dynamic>>>> responsesByLocation;
  final requests = <TransportRequest>[];
  final Map<String, int> _nextResponseIndex = <String, int>{};

  int requestCount(String locationId) {
    return requests
        .where(
          (request) => request.uri.queryParameters['location_id'] == locationId,
        )
        .length;
  }

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final locationId = request.uri.queryParameters['location_id'] ?? '';
    final responseIndex = _nextResponseIndex.update(
      locationId,
      (index) => index + 1,
      ifAbsent: () => 0,
    );
    final responses =
        responsesByLocation[locationId] ??
        const <Future<Map<String, dynamic>>>[];
    if (responseIndex >= responses.length) {
      throw StateError('No scripted Tilemap response for $locationId');
    }
    final data = await responses[responseIndex];
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
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

class _RecordingPerformanceTrace implements AppPerformanceTrace {
  final Map<String, String> attributes = <String, String>{};
  final Map<String, int> metrics = <String, int>{};
  bool started = false;
  bool stopped = false;

  @override
  void putAttribute(String name, String value) {
    attributes[name] = value;
  }

  @override
  void setMetric(String name, int value) {
    metrics[name] = value;
  }

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
