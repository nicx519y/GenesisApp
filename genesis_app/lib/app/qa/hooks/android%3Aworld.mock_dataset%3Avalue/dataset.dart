import 'map_image.dart';
import 'response_overrides.dart' as world_responses;
import '../../../../platform/session/user_session_store.dart';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../../../network/genesis_api.dart';
import '../../../../network/http_transport.dart';
import '../../qa_bridge.dart';
import '../../../bootstrap/app_services_scope.dart';
import '../android%253Aworld.test_identity%253Avalue/identity.dart';

typedef JsonMap = Map<String, dynamic>;
JsonMap copyWorldJson(JsonMap value) =>
    jsonDecode(jsonEncode(value)) as JsonMap;

/// Owns only the selected world's read responses. Other IDs, locations, methods
/// and endpoints continue through the original transport unchanged.
class WorldDataset {
  WorldDataset({
    required this.resource,
    required this.owner,
    required this.currentOwner,
    required this.currentResource,
    required this.list,
    required this.fetch,
    this.registerResponder,
  });
  final String resource, owner;
  final Future<String?> Function() currentOwner;
  final bool Function() currentResource;
  final Future<JsonMap> Function() list;
  final Future<JsonMap> Function(String endpoint, String id) fetch;
  final world_responses.QaMockResponderRegistration Function(
    world_responses.QaMockResponder responder,
  )? registerResponder;
  world_responses.QaMockResponderRegistration? _registration;
  String? selectedId;
  Map<String, JsonMap>? _snapshot;
  Map<String, JsonMap>? _responses;
  WorldMapImage? _mapImage;
  bool _acquired = false, _restored = false;
  bool get active => _acquired && !_restored;

  Future<void> requireOwner() async {
    if (!currentResource() ||
        await currentOwner() != owner ||
        !owner.startsWith('qa_test_world_')) {
      throw StateError('World dataset resource or identity changed');
    }
  }

  Future<JsonMap> prepare() async {
    await requireOwner();
    if (_restored) throw StateError('World dataset was already restored');
    if (_acquired) return read();
    final page = await list();
    final worlds = page['list'];
    if (worlds is! List || worlds.isEmpty)
      throw StateError('Mock world list is empty');
    final first = worlds.first;
    final id = first is Map && first['info'] is Map
        ? first['info']['world_id']
        : null;
    if (id is! String || id.trim().isEmpty)
      throw StateError('Mock world ID is missing');
    final snapshot = <String, JsonMap>{};
    for (final endpoint in ['detail', 'info', 'map']) {
      snapshot[endpoint] = copyWorldJson(await fetch(endpoint, id));
    }
    if (snapshot['detail']!['info'] is! Map ||
        snapshot['detail']!['info']['world_id'] != id) {
      throw StateError('Mock world detail identity mismatch');
    }
    await requireOwner();
    selectedId = id;
    _snapshot = snapshot;
    _responses = snapshot.map(
      (key, value) => MapEntry(key, copyWorldJson(value)),
    );
    final tileTypes = _responses!['map']!['tile_types'];
    if (tileTypes is Map && tileTypes.values.contains(
        'https://cdn.example.com/tilemap/mock_tile.png')) {
      _mapImage = await WorldMapImage.open(requireOwner: requireOwner);
      for (final key in tileTypes.keys.toList()) {
        if (tileTypes[key] == 'https://cdn.example.com/tilemap/mock_tile.png') {
          tileTypes[key] = _mapImage!.url;
        }
      }
    }
    _acquired = true;
    _registration = registerResponder?.call(respond);
    return read();
  }

  Future<JsonMap> read() async {
    await requireOwner();
    if (!active)
      return {'prepared': false, 'reversible': false, 'resource': resource};
    final actual = await fetch('detail', selectedId!);
    final expected = _responses!['detail']!;
    return {
      'prepared': const DeepCollectionEqualityForWorld().equal(
        actual['info'],
        expected['info'],
      ),
      'reversible': _snapshot != null,
      'worldId': selectedId,
      'resource': resource,
    };
  }

  Future<JsonMap> selected(String endpoint) async {
    await requireOwner();
    if (!active) throw StateError('No active world dataset');
    return fetch(endpoint, selectedId!);
  }

  /// A dependent primitive can change only an existing JSON path. Its own
  /// snapshot and contract remain in that primitive's directory.
  Future<void> replace(
    String endpoint,
    List<String> path,
    Object? value,
  ) async {
    await requireOwner();
    if (!active || path.isEmpty) throw StateError('No active world dataset');
    final next = copyWorldJson(_responses![endpoint]!);
    Map target = next;
    for (final key in path.take(path.length - 1)) {
      if (target[key] is! Map) throw StateError('Unknown world response path');
      target = target[key] as Map;
    }
    if (!target.containsKey(path.last))
      throw StateError('Unknown world response field');
    target[path.last] = value;
    _responses![endpoint] = next;
  }

  Future<TransportResponse?> respond(TransportRequest request) async {
    if (!active ||
        request.method.toUpperCase() != 'GET' ||
        request.uri.queryParameters['world_id'] != selectedId)
      return null;
    final match = RegExp(
      r'^/api/v1/world/(detail|info|map)$',
    ).firstMatch(request.uri.path);
    if (match == null ||
        (match[1] == 'map' &&
            request.uri.queryParameters['location_id'] != 'root'))
      return null;
    await requireOwner();
    request.cancellationToken?.throwIfCancelled();
    if (!active) throw StateError('World dataset was restored during request');
    final body = jsonEncode({
      'err_no': 0,
      'err_msg': 'succ',
      'data': _responses![match[1]],
    });
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: body,
      bodyBytes: utf8.encode(body),
    );
  }

  void contractMapAvailable(bool available) {
    if (!active) throw StateError('No active world dataset');
    _responses!['map'] = available
        ? copyWorldJson(_snapshot!['map']!)
        : <String, dynamic>{};
    final tiles = _responses!['map']!['tile_types'];
    if (available && _mapImage != null && tiles is Map) {
      for (final key in tiles.keys.toList()) {
        if (tiles[key] == 'https://cdn.example.com/tilemap/mock_tile.png') {
          tiles[key] = _mapImage!.url;
        }
      }
    }
  }

  JsonMap contractSnapshot() {
    if (_snapshot == null)
      throw StateError('No world dataset snapshot was acquired');
    return copyWorldJson(_snapshot!);
  }

  Future<JsonMap> restore() async {
    if (!_acquired) throw StateError('No world dataset snapshot was acquired');
    await requireOwner();
    // Remove the override before re-reading through the original App API.
    _restored = true;
    _registration?.close();
    _registration = null;
    await _mapImage?.close();
    final actual = <String, JsonMap>{};
    for (final endpoint in _snapshot!.keys)
      actual[endpoint] = await fetch(endpoint, selectedId!);
    final matches = const DeepCollectionEqualityForWorld().equal(
      actual,
      _snapshot,
    );
    if (!matches)
      throw StateError(
        'Underlying world dataset changed; restoration mismatch',
      );
    return {
      'restored': !active,
      'mapImageReleased': _mapImage == null || _mapImage!.closed,
      'matchesSnapshot': matches,
      'resource': resource,
    };
  }
}

/// JSON objects are unordered; compare recursively instead of depending on
/// serialization key order. Lists retain their order.
class DeepCollectionEqualityForWorld {
  const DeepCollectionEqualityForWorld();
  bool equal(Object? a, Object? b) {
    if (a is Map && b is Map)
      return a.length == b.length &&
          a.keys.every((k) => b.containsKey(k) && equal(a[k], b[k]));
    if (a is List && b is List)
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => equal(a[i], b[i]));
    return a == b;
  }
}

final _datasets = Expando<WorldDataset>();
GenesisApi _mountedApi() {
  final root = WidgetsBinding.instance.rootElement;
  GenesisApi? api;
  void visit(Element element) {
    final services = AppServicesScope.maybeRead(element);
    if (services != null) {
      if (api != null && !identical(api, services.api))
        throw StateError('Ambiguous App service scope');
      api = services.api;
    }
    element.visitChildren(visit);
  }

  if (root != null) visit(root);
  return api ?? (throw StateError('App services are not mounted'));
}

Future<WorldDataset> worldDatasetResource({bool acquire = false}) async {
  final bridge = QaBridge.current;
  if (bridge == null ||
      const String.fromEnvironment('GENESIS_API_ENV') != 'mock')
    throw StateError('Requires mock QA bridge');
  final existing = _datasets[bridge];
  if (existing != null) return existing;
  if (!acquire) throw StateError('No world dataset snapshot was acquired');
  final identity = await worldIdentityResource().read();
  if (identity['isolated'] != true)
    throw StateError('Requires prepared isolated world identity');
  final api = _mountedApi();
  final dataset = WorldDataset(
    registerResponder: (respond) => world_responses.registerQaHook(
      'android:world.mock_dataset:value', respond,
    ),
    resource: bridge.resource,
    owner: identity['uid'] as String,
    currentOwner: bridge.store.readLoginUid,
    currentResource: () => identical(QaBridge.current, bridge),
    list: () => api.v1.world.list(),
    fetch: (endpoint, id) => switch (endpoint) {
      'detail' => api.v1.world.detail(worldId: id),
      'info' => api.v1.world.info(worldId: id),
      'map' => api.v1.world.map(worldId: id, locationId: 'root'),
      _ => throw ArgumentError('Unsupported endpoint'),
    },
  );
  _datasets[bridge] = dataset;
  return dataset;
}

Future<TransportResponse?> respondWorldDataset(TransportRequest request) async {
  final bridge = QaBridge.current;
  return bridge == null ? null : await _datasets[bridge]?.respond(request);
}

Future<Object?> readWorldDataset(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (p.isNotEmpty) throw ArgumentError('Dataset read takes no parameters');
  final bridge = QaBridge.current;
  if (bridge == null) throw StateError('Requires QA bridge');
  final dataset = _datasets[bridge];
  return dataset == null
      ? {'prepared': false, 'reversible': false, 'resource': bridge.resource}
      : dataset.read();
}

Future<Object?> prepareWorldDataset(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (prepared || !started || p.isNotEmpty)
    throw StateError('Requires started Case session');
  return (await worldDatasetResource(acquire: true)).prepare();
}

Future<Object?> restoreWorldDataset(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (prepared || p.isNotEmpty) throw StateError('Requires Case session');
  return (await worldDatasetResource()).restore();
}

Future<Object?> contractWorldDataset(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Requires started isolated contract');
  if (p['operation'] == 'map_absent' || p['operation'] == 'map_reset') {
    final dataset = await worldDatasetResource();
    await dataset.requireOwner();
    dataset.contractMapAvailable(p['operation'] == 'map_reset');
    return dataset.selected('map');
  }
  return switch (p['operation']) {
    'snapshot' => (await worldDatasetResource()).contractSnapshot(),
    'prepare' => (await worldDatasetResource(acquire: true)).prepare(),
    'restore' => (await worldDatasetResource()).restore(),
    _ => throw ArgumentError('Unknown dataset contract operation'),
  };
}
