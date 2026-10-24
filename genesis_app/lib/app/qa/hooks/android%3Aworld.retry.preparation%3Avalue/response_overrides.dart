import 'lease.dart';
import '../../fixtures/http/mock_response_registry.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../network/http_transport.dart';

/// Process-local QA responses. The normal mock seed is never modified.
class QaMockResponseOverrides {
  static QaMockResponseLease? _active;
  static bool get enabled =>
      kDebugMode &&
      appFlavor == 'internal' &&
      const bool.fromEnvironment('GENESIS_QA_BRIDGE') &&
      const String.fromEnvironment('GENESIS_API_ENV') == 'mock';

  static QaMockResponseLease install({
    required String resource,
    required String ownerUid,
    required Future<String?> Function() currentOwner,
    required bool Function() currentResource,
    required Map<String, Object?> responses,
  }) {
    if (!enabled) {
      throw StateError('QA response override requires internal mock QA build');
    }
    if (resource.isEmpty ||
        !ownerUid.startsWith('qa_test_') ||
        responses.isEmpty ||
        responses.keys.any((key) => !RegExp(r'^GET /[^?#]*$').hasMatch(key))) {
      throw ArgumentError(
        'Explicit resource, QA owner and read-only endpoint required',
      );
    }
    if (_active != null) {
      throw StateError('Another Case owns the response override');
    }
    final lease = QaMockResponseLease._(
      resource,
      ownerUid,
      currentOwner,
      currentResource,
      responses.map((key, value) => MapEntry(key, jsonEncode(value))),
    );
    _active = lease;
    return lease;
  }

  static Future<TransportResponse?> respond(TransportRequest request) async {
    final lease = _active;
    final registered = await dispatchQaMockResponders(request);
    if (registered != null) return registered;
    for (final responder in [WorldRetryLease.respond]) {
      final response = await responder(request);
      if (response != null) return response;
    }
    if (!identical(_active, lease) || lease?._restored == true) {
      throw StateError('QA response owner or Case resource changed');
    }
    if (!enabled || lease == null) return null;
    final body =
        lease._responses['${request.method.toUpperCase()} ${request.uri.path}'];
    if (body == null) return null;
    request.cancellationToken?.throwIfCancelled();
    final owner = await lease._currentOwner();
    if (!identical(_active, lease) ||
        lease._restored ||
        !lease._currentResource() ||
        owner != lease.ownerUid) {
      throw StateError('QA response owner or Case resource changed');
    }
    request.cancellationToken?.throwIfCancelled();
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: body,
      bodyBytes: utf8.encode(body),
    );
  }
}

class QaMockResponseLease {
  QaMockResponseLease._(
    this.resource,
    this.ownerUid,
    this._currentOwner,
    this._currentResource,
    this._responses,
  );
  final String resource;
  final String ownerUid;
  final Future<String?> Function() _currentOwner;
  final bool Function() _currentResource;
  final Map<String, String> _responses;
  bool _restored = false;
  void restore() {
    if (_restored) return;
    if (!identical(QaMockResponseOverrides._active, this)) {
      throw StateError('Cannot restore another Case response override');
    }
    QaMockResponseOverrides._active = null;
    _restored = true;
  }
}
