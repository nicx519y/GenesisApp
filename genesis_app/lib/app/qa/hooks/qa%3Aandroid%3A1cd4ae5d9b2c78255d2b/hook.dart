import 'dart:convert';
import '../../../../network/http_transport.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import '../qa%253Aandroid%253Ae902ad40417a12b1d8e2/hook.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';

/// Reuses the successful completion resource and its event/response cleanup.
/// Only the first matching transport submission is replaced by an explicit error.
class RetryFault extends TickSuccess {
  RetryFault(super.owner);
  int requests = 0;
  String? retryRequestId;
  Map<String, Object?>? firstResponse;
  String get handle => 'failure:${owner.attempt}';
  String requestId(int n) => '$handle:$n';
  @override
  Future<Map<String, Object?>> read() async {
    final actual = await super.read();
    return {
      'worldId': owner.worldId,
      'faultHandle': handle,
      'snapshotId': owner.attempt,
      'resource': owner.bridge.resource,
      'firstSubmission': active ? 'explicit_failure' : 'unconfigured',
      'firstSubmissionAdvancesWorld': false,
      'insufficientBalance': false,
      'retryOutcome': actual['outcome'],
      'reversible': beforeEvents != null,
      'appDataPathConfigured': actual['appDataPathConfigured'],
    };
  }

  @override
  Future<TransportResponse?> respond(TransportRequest q) async {
    if (!active) return null;
    if (q.method.toUpperCase() == 'POST' && q.uri.path != '/api/v1/world/tick')
      return null;
    final body = q.method.toUpperCase() == 'POST' && q.bodyBytes != null
        ? jsonDecode(utf8.decode(q.bodyBytes!))
        : null;
    if (q.method.toUpperCase() == 'POST' &&
        q.uri.path == '/api/v1/world/tick' &&
        body is Map &&
        body['world_id'] == owner.worldId) {
      await owner.requireOwner();
      q.cancellationToken?.throwIfCancelled();
      requests++;
      if (requests == 1) {
        final before = await owner.dataset!.selected('detail');
        final response = jsonEncode({
          'err_no': 50001,
          'err_msg': 'QA explicit tick failure',
          'data': null,
        });
        final after = await owner.dataset!.selected('detail');
        firstResponse = {
          'completed': true,
          'outcome': 'explicit_failure',
          'insufficientBalance':
              (jsonDecode(response) as Map)['err_no'] == 21001,
          'worldAdvanced': !const DeepCollectionEqualityForWorld().equal(
            before,
            after,
          ),
          'requestId': requestId(requests),
          'worldId': owner.worldId,
          'errorCode': 50001,
        };
        return TransportResponse(
          statusCode: 200,
          headers: const {'content-type': 'application/json'},
          body: response,
          bodyBytes: utf8.encode(response),
        );
      }
    }
    final response = await super.respond(q);
    if (response != null &&
        q.method.toUpperCase() == 'POST' &&
        q.uri.path == '/api/v1/world/tick' &&
        body is Map &&
        body['world_id'] == owner.worldId) {
      retryRequestId ??= requestId(requests);
    }
    return response;
  }

  Future<Map<String, Object?>> release() async {
    await super.restore();
    return {
      'faultHandle': handle,
      'snapshotId': owner.attempt,
      'resource': owner.bridge.resource,
      'faultRemoved': !active && responseRegistration == null,
      'matchesOriginalConfiguration':
          owner.eventsRestored && !active && responseRegistration == null,
      'actualConfiguration': {
        'active': active,
        'registered': responseRegistration != null,
        'events': await owner.services.api.v1.world.tickList(
          worldId: owner.worldId,
        ),
      },
    };
  }
}

RetryFault fault({bool acquire = false}) {
  final r = resource();
  final old = configurations[r];
  if (old is RetryFault) return old;
  if (old != null)
    throw StateError('Incompatible tick configuration already acquired');
  if (!acquire) throw StateError('Tick failure configuration required');
  final next = RetryFault(r);
  configurations[r] = next;
  return next;
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1)
    throw ArgumentError('Ready parameterless operation required');
  if (p['operation'] == 'read') return fault().read();
  if (prepared)
    throw StateError('Case preparation cannot use contract session');
  return switch (p['operation']) {
    'prepare' => fault(acquire: true).prepare(),
    'cleanup' => fault().release(),
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
    'prepare' => fault(acquire: true).prepare(),
    'restore' => fault().release(),
    _ => throw ArgumentError('Unsupported contract operation'),
  };
}
