import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

void main() {
  testWidgets(
    'Tilemap hides the grid until root map and initial transform are ready',
    (tester) async {
      final transport = _DelayedTilemapTransport();
      final services = _servicesWithTransport(transport);

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const Scaffold(
              body: Tilemap.origin(
                originId: 'o_1',
                visualModeToggleTop: 24,
                visualModeToggleRight: 12,
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
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey<String>('tilemap-loading-background')),
            )
            .color,
        const Color(0xFF37362E),
      );
      final toggleFinder = find.byKey(
        const ValueKey<String>('tilemap-visual-mode-toggle'),
      );
      expect(toggleFinder, findsOneWidget);
      expect(tester.getTopRight(toggleFinder), const Offset(788, 24));

      await tester.tap(toggleFinder);
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

      transport.complete(_locationTilemapData('leaf'));
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<TilemapRenderer>(find.byType(TilemapRenderer)).visualMode,
        TilemapVisualMode.light,
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tilemap-loading-background')),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

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

Map<String, dynamic> _locationTilemapData(String locationId) {
  return {
    'tile_types': {'tile': 'https://invalid.example.test/tile/tile.png'},
    'map_json': {
      'width': 1,
      'height': 1,
      'tiles': [
        {'x': 0, 'y': 0, 'type': 'tile', 'location_id': locationId},
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
