import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../../../network/http_transport.dart';
import '../../../../platform/session/user_session_store.dart';
import '../../qa_bridge.dart';
import 'response_overrides.dart';

/// Owns only this session's identity snapshot and transient mock responses.
class WorldRetryLease {
  WorldRetryLease(this.bridge);
  final QaBridge bridge;
  static WorldRetryLease? active;
  String? beforeUid, beforeToken;
  Map<String, dynamic>? beforeInfo;
  HttpServer? server;
  Route<void>? route;
  bool acquired = false, restored = false;
  int detailRequests = 0, successfulResponses = 0;
  String get uid => 'qa_test_world_${bridge.resource}';
  String get worldId => 'qa_world_${bridge.resource}';
  String get name => 'QA Retry World ${bridge.resource}';
  String get locationName => 'QA Harbour ${bridge.resource}';
  String get mapUrl => 'http://127.0.0.1:${server!.port}/map.png';
  String get currentTime => 'Day 7, 19:10';
  Map<String, dynamic> get data => {
    'info': {
      'world_id': worldId,
      'world_name': name,
      'owner_uid': uid,
      'origin_id': 'qa_origin',
      'definition_version': 1,
      'current_time': currentTime,
      'map_url': mapUrl,
      'cover': mapUrl,
      'status': 10,
    },
    'relation_status': 'joined',
    'stats': {'location_cnt': 1},
    'characters': [],
    'locations': [
      {
        'location_id': '${worldId}_harbour',
        'name': locationName,
        'location_name': locationName,
        'x_percent': 50,
        'y_percent': 50,
        'map_url': mapUrl,
      },
    ],
  };
  Future<Map<String, Object?>> prepare() async {
    if (active != null || acquired)
      throw StateError('World resource already owned');
    beforeUid = await bridge.store.readUid();
    beforeToken = await bridge.store.readAuthToken();
    final info = await bridge.store.readUserInfo();
    beforeInfo = info == null
        ? null
        : jsonDecode(jsonEncode(info)) as Map<String, dynamic>;
    acquired = true;
    active = this; // Register ownership before any fallible mutation.
    await bridge.store.saveUid(uid);
    await bridge.store.saveAuthToken('qa_mock_${bridge.resource}');
    await bridge.store.saveUserInfo({'uid': uid, 'name': 'QA World Reader'});
    final bytes = await rootBundle.load('assets/images/default_list_image.png');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((request) async {
      if (request.uri.path != '/map.png') {
        request.response.statusCode = 404;
      } else {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      }
      await request.response.close();
    });
    return read();
  }

  Future<Map<String, Object?>> read() async {
    await sameOwner();
    final info = data['info'] as Map;
    return {
      'source': 'mock',
      'resource': bridge.resource,
      'worldId': worldId,
      'worldName': name,
      'mapUrl': mapUrl,
      'locationName': locationName,
      'isolatedIdentity': uid.startsWith('qa_test_'),
      'loggedIn': await bridge.store.readLoginUid() == uid,
      'joinedTargetWorld': data['relation_status'] == 'joined',
      'worldIdPresent': (info['world_id'] as String).isNotEmpty,
      'worldNamePresent': (info['world_name'] as String).isNotEmpty,
      'worldCurrentTimePresent': (info['current_time'] as String).isNotEmpty,
      'mapDisplayable': server != null,
      'locationsAvailable': (data['locations'] as List).isNotEmpty,
      'firstDetailRequestFails':
          detailRequests == 0 ||
          detailRequests >= 1 && successfulResponses == detailRequests - 1,
      'retryReturnsSameWorld': info['world_id'] == worldId,
      'restorationRegistered': acquired && identical(active, this),
      'detailRequests': detailRequests,
      'successfulResponses': successfulResponses,
    };
  }

  Future<void> sameOwner() async {
    if (!acquired ||
        restored ||
        !identical(active, this) ||
        !identical(QaBridge.current, bridge) ||
        await bridge.store.readUid() != uid)
      throw StateError('World resource/identity mismatch');
  }

  Future<Map<String, Object?>> restore() async {
    if (!acquired) throw StateError('No world snapshot acquired');
    if (!restored) {
      final current = await bridge.store.readUid();
      if (!identical(active, this) ||
          !identical(QaBridge.current, bridge) ||
          current != uid && current != beforeUid)
        throw StateError('Foreign world resource');
      final ownedRoute = route;
      if (ownedRoute != null && ownedRoute.isActive) {
        final navigator = ownedRoute.navigator!;
        navigator.popUntil((r) => identical(r, ownedRoute));
        navigator.removeRoute(ownedRoute);
        await WidgetsBinding.instance.endOfFrame;
      }
      route = null;
      await server?.close(force: true);
      server = null;
      await bridge.store.clearUid();
      if (beforeUid != null) await bridge.store.saveUid(beforeUid!);
      if (beforeToken != null) await bridge.store.saveAuthToken(beforeToken!);
      if (beforeInfo != null) await bridge.store.saveUserInfo(beforeInfo!);
      active = null;
      restored = true;
    }
    final identity =
        await bridge.store.readUid() == beforeUid &&
        await bridge.store.readAuthToken() == beforeToken &&
        jsonEncode(await bridge.store.readUserInfo()) == jsonEncode(beforeInfo);
    return {
      'identityRestored': identity,
      'worldDataRestored': active != this,
      'requestResponseStateRestored': active != this && server == null,
      'resource': bridge.resource,
    };
  }

  static Future<TransportResponse?> respond(TransportRequest request) async {
    final lease = active;
    if (!QaMockResponseOverrides.enabled || lease == null) return null;
    return lease.response(request);
  }

  Future<TransportResponse?> response(TransportRequest request) async {
    final lease = this;
    if (request.method.toUpperCase() != 'GET' ||
        request.uri.path != '/api/v1/world/detail' ||
        request.uri.queryParameters['world_id'] != lease.worldId)
      return null;
    request.cancellationToken?.throwIfCancelled();
    await lease.sameOwner();
    request.cancellationToken?.throwIfCancelled();
    final fails = lease.detailRequests++ == 0;
    if (!fails) lease.successfulResponses++;
    final body = jsonEncode(
      fails
          ? {'err_no': 503, 'err_msg': 'QA first detail failure', 'data': null}
          : {'err_no': 0, 'err_msg': 'success', 'data': lease.data},
    );
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: body,
      bodyBytes: utf8.encode(body),
    );
  }
}

final worldLeases = Expando<WorldRetryLease>();
WorldRetryLease requireWorldLease() {
  final bridge = QaBridge.current;
  final lease = bridge == null ? null : worldLeases[bridge];
  if (lease == null) throw StateError('World preparation is required');
  return lease;
}

Future<Object?> prepareWorld(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!QaMockResponseOverrides.enabled ||
      !started ||
      p.keys.any((k) => k != 'operation')) {
    throw StateError('World preparation requires a ready internal mock App');
  }
  final bridge = QaBridge.current!;
  if (p['operation'] == 'prepare') {
    final old = worldLeases[bridge];
    if (old != null && !old.restored)
      throw StateError('Duplicate world preparation');
    final lease = WorldRetryLease(bridge);
    worldLeases[bridge] = lease;
    return lease.prepare();
  }
  if (p['operation'] == 'read') return requireWorldLease().read();
  if (p['operation'] == 'cleanup') return requireWorldLease().restore();
  throw ArgumentError('Unsupported world preparation operation');
}
