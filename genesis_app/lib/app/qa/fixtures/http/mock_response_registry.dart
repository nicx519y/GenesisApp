import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../network/http_transport.dart';

typedef QaMockResponder = Future<TransportResponse?> Function(TransportRequest);

class _Responder {
  _Responder(this.respond, Set<String> methods)
    : methods = Set.unmodifiable(methods);
  final QaMockResponder respond;
  final Set<String> methods;
}

final _responders = <String, _Responder>{};
bool get _enabled =>
    kDebugMode &&
    appFlavor == 'internal' &&
    const bool.fromEnvironment('GENESIS_QA_BRIDGE') &&
    const String.fromEnvironment('GENESIS_API_ENV') == 'mock';

/// Dispatch registration only: implementations own identity and resource checks.
QaMockResponderRegistration registerQaHook(
  String id,
  QaMockResponder respond, {
  Set<String> methods = const {'GET'},
}) {
  const allowedMethods = {
    'GET',
    'HEAD',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'OPTIONS',
  };
  if (methods.isEmpty ||
      methods.any((method) => !allowedMethods.contains(method))) {
    throw ArgumentError('Explicit supported HTTP methods required');
  }
  final responder = _Responder(respond, methods);
  if (!RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(id)) {
    throw ArgumentError('Stable responder ID required');
  }
  // Shared QA startup also runs with real data. Keep this wiring inert there;
  // neither retain the callback nor intercept any request outside mock builds.
  if (!_enabled) {
    return QaMockResponderRegistration._(id, responder).._closed = true;
  }
  if (_responders.containsKey(id)) {
    throw StateError('Duplicate QA mock responder');
  }
  _responders[id] = responder;
  return QaMockResponderRegistration._(id, responder);
}

class QaMockResponderRegistration {
  QaMockResponderRegistration._(this.id, this._respond);
  final String id;
  final _Responder _respond;
  bool _closed = false;
  void close() {
    if (_closed) return;
    if (!identical(_responders[id], _respond)) {
      throw StateError('Responder registration ownership changed');
    }
    _responders.remove(id);
    _closed = true;
  }
}

Future<TransportResponse?> dispatchQaMockResponders(
  TransportRequest request,
) async {
  if (!_enabled) return null;
  final method = request.method.toUpperCase();
  request.cancellationToken?.throwIfCancelled();
  TransportResponse? response;
  for (final entry in _responders.entries.toList(growable: false)) {
    if (!identical(_responders[entry.key], entry.value) ||
        !entry.value.methods.contains(method)) {
      continue;
    }
    final next = await entry.value.respond(request);
    request.cancellationToken?.throwIfCancelled();
    if (!identical(_responders[entry.key], entry.value)) {
      throw StateError('Responder released during request');
    }
    if (response != null && next != null) {
      throw StateError('Conflicting QA mock responders');
    }
    response = next ?? response;
  }
  return response;
}
