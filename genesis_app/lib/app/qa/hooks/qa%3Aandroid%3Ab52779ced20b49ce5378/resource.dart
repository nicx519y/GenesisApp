import '../../fixtures/http/mock_response_registry.dart' as mock_responses;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../bootstrap/app_services_scope.dart';
import '../../../bootstrap/service_registry.dart';
import '../../../genesis_navigator.dart';
import '../../../../network/http_transport.dart';
import '../../qa_bridge.dart';
import '../android%253Aworld.test_identity%253Avalue/identity.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import '../android%253Aworld.selected.map_renderable%253Avalid/observation.dart';
import '../qa%253Aandroid%253Abf448f29b28c4fce0618/resource.dart'
    show WorldMembership;
import '../qa%253Aandroid%253A72754e52110558afc990/resource.dart'
    show WorldProgression;
import '../qa%253Aandroid%253A538adf49de88c951fcbe/socket.dart';

TransportResponse jsonResponse(Object? data) {
  final body = jsonEncode({'err_no': 0, 'err_msg': 'success', 'data': data});
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: body,
    bodyBytes: utf8.encode(body),
  );
}

class TickPreparation {
  TickPreparation(this.bridge);
  final QaBridge bridge;
  WorldDataset? dataset;
  bool identityAcquired = false,
      quotaActive = false,
      restored = false,
      servicesMounted = false,
      servicesReleased = false;
  int? quotaBefore;
  mock_responses.QaMockResponderRegistration? quotaRegistration;
  AppServices? isolatedServices;
  LocationChatPeer? peer;
  Route<void>? route;
  Route<dynamic>? previousRoute;
  final restorers = <Future<void> Function()>[];
  Map<String, Object?>? restoration;
  String get worldId => dataset!.selectedId!;
  String get attempt => 'tick:${bridge.resource}';
  AppServices get services =>
      AppServicesScope.read(genesisNavigatorKey.currentContext!);
  Future<void> requireOwner() async {
    if (restored || !identical(QaBridge.current, bridge) || dataset == null)
      throw StateError('No active tick preparation');
    await dataset!.requireOwner();
  }

  Future<Map<String, Object?>> prepare() async {
    if (identityAcquired) throw StateError('Tick preparation already acquired');
    identityAcquired = true;
    await worldIdentityResource().prepare();
    dataset = await worldDatasetResource(acquire: true);
    await dataset!.prepare();
    await WorldMembership(dataset!).prepare();
    await WorldProgression(dataset!).prepare();
    quotaBefore = (await services.api.v1.gem.wallet()).balanceCent;
    quotaActive = true;
    quotaRegistration = mock_responses.registerQaHook(
      'qa:android:b52779ced20b49ce5378:quota',
      respondQuota,
    );
    peer = LocationChatPeer(worldId, worldIdentityResource().uid);
    await peer!.open();
    isolatedServices = ServiceRegistry.build(
      config: services.config.copyWith(chatroomWsBaseUrl: peer!.url),
      deviceIdOverride: services.deviceId,
      sessionStoreOverride: bridge.store,
    );
    return read();
  }

  Future<Map<String, Object?>> read() async {
    await requireOwner();
    final identity = await worldIdentityResource().read();
    final world = await services.api.getWorld(worldId);
    final quota = await services.api.v1.gem.wallet();
    return {
      'resource': bridge.resource,
      'attempt': attempt,
      'source': 'mock',
      'isolated': identity['isolated'],
      'loggedIn': identity['loggedIn'],
      'joinedTargetWorld': ['joined', 'owner'].contains(world.relationStatus),
      'worldIdentityComplete':
          world.worldId == worldId &&
          world.name.isNotEmpty &&
          world.currentTime.isNotEmpty,
      'mapDataAvailable': extractObservation(await dataset!.selected('map')),
      'canProgress':
          !world.isProgressing &&
          ['joined', 'owner'].contains(world.relationStatus),
      'quotaSufficient': quota.balanceCent >= 1000000,
      'quotaCent': quota.balanceCent,
      'snapshotCaptured':
          dataset!.active && quotaBefore != null && identityAcquired,
    };
  }

  Future<Map<String, Object?>> restore() async {
    if (!identityAcquired || !identical(QaBridge.current, bridge))
      throw StateError('No owned tick snapshot');
    if (restored) return restoration!;
    if (route?.isActive == true) {
      if (!route!.isCurrent)
        throw StateError('Unknown overlay above owned tick world');
      route!.navigator!.removeRoute(route!);
      await WidgetsBinding.instance.endOfFrame;
      servicesReleased = true;
    }
    if (!servicesMounted && !servicesReleased && isolatedServices != null) {
      isolatedServices!.dispose();
      servicesReleased = true;
    }
    final errors = <Object>[];
    for (final release in restorers.reversed) {
      try {
        await release();
      } catch (error) {
        errors.add(error);
      }
    }
    quotaActive = false;
    try {
      quotaRegistration?.close();
      quotaRegistration = null;
    } catch (error) {
      errors.add(error);
    }
    bool quotaMatches = false;
    try {
      quotaMatches =
          quotaBefore == null ||
          (await services.api.v1.gem.wallet()).balanceCent == quotaBefore;
    } catch (error) {
      errors.add(error);
    }
    try {
      if (peer?.acquired == true && !peer!.closed) await peer!.close();
    } catch (error) {
      errors.add(error);
    }
    Map<String, dynamic>? world;
    try {
      if (dataset?.active == true) world = await dataset!.restore();
    } catch (error) {
      errors.add(error);
    }
    Map<String, Object?>? identity;
    // Preserve ownership while any world recovery is unresolved.
    if (dataset == null || world?['matchesSnapshot'] == true) {
      try {
        identity = await worldIdentityResource().restore();
      } catch (error) {
        errors.add(error);
      }
    }
    final configRestored =
        !quotaActive &&
        quotaRegistration == null &&
        (peer == null || !peer!.acquired || peer!.closed) &&
        (isolatedServices == null || servicesReleased);
    if (errors.isNotEmpty) throw TickCleanupFailure(errors);
    restoration = {
      'resource': bridge.resource,
      'progressStateMatchesSnapshot': world?['matchesSnapshot'],
      'eventsMatchSnapshot': eventsRestored,
      'quotaMatchesSnapshot': quotaMatches,
      'isolatedIdentityMatchesSnapshot': identity?['matchesSnapshot'],
      'mockConfigurationMatchesSnapshot': configRestored,
    };
    if (!quotaMatches ||
        !configRestored ||
        identity?['matchesSnapshot'] != true ||
        (dataset != null && world?['matchesSnapshot'] != true) ||
        !eventsRestored)
      throw StateError('Tick restoration mismatch');
    restored = true;
    return restoration!;
  }

  bool eventsRestored = true;
}

final resources = Expando<TickPreparation>();
TickPreparation resource({bool acquire = false}) {
  final b = QaBridge.current;
  if (b == null || const String.fromEnvironment('GENESIS_API_ENV') != 'mock')
    throw StateError('Authenticated mock session required');
  final old = resources[b];
  if (old != null) return old;
  if (!acquire) throw StateError('Tick preparation required');
  return resources[b] = TickPreparation(b);
}

Future<TransportResponse?> respondQuota(TransportRequest request) async {
  final b = QaBridge.current, r = b == null ? null : resources[b];
  if (r == null ||
      !r.quotaActive ||
      request.method != 'GET' ||
      request.uri.path != '/api/v1/gem/wallet')
    return null;
  await r.requireOwner();
  request.cancellationToken?.throwIfCancelled();
  return jsonResponse({
    'wallet': {'balance_cent': 1000000},
  });
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1)
    throw ArgumentError('Ready parameterless operation required');
  if (p['operation'] == 'read') return resource().read();
  if (prepared)
    throw StateError('Case preparation cannot use contract session');
  return switch (p['operation']) {
    'prepare' => resource(acquire: true).prepare(),
    'cleanup' => resource().restore(),
    _ => throw ArgumentError('Unsupported operation'),
  };
}

Future<Object?> contract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  return switch (p['operation']) {
    'prepare' => resource(acquire: true).prepare(),
    'read' => resource().read(),
    'restore' => resource().restore(),
    _ => throw ArgumentError('Unsupported contract operation'),
  };
}

class TickCleanupFailure implements Exception {
  TickCleanupFailure(this.errors);
  final List<Object> errors;
  @override
  String toString() =>
      'Tick cleanup failed: ' + errors.map((e) => '$e').join(' | ');
}
