import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../app/telemetry/genesis_telemetry.dart';
import '../../../network/api_exception.dart';

/// Business events only. Transport, identity snapshots and retries belong to Collect.
class MiniPhoneAnalytics {
  MiniPhoneAnalytics({
    required this.worldId,
    required this.enabled,
    required this.generation,
  });

  final String worldId;
  final bool Function() enabled;
  final int Function() generation;
  String? _openId;
  String? get openId => _openId;

  String beginOpen() => _openId = const Uuid().v4();
  void endOpen(String? id) {
    if (_openId == id) _openId = null;
  }

  Map<String, Object?> context(String source) => {
    if (_openId != null) 'open_id': _openId,
    'source': source,
  };

  void event(
    String action, {
    String type = 'event',
    String target = '',
    String stage = '',
    String attemptId = '',
    Map<String, Object?> data = const {},
  }) {
    // Telemetry must never interrupt the user operation, even with an injected sink.
    try {
      if (worldId.trim().isEmpty || !enabled()) return;
      GenesisTelemetry.collectLog(
        actionType: type,
        action: 'mini_phone_$action',
        object1: worldId,
        object2: target,
        object3: stage,
        object4: attemptId,
        extData: data.isEmpty ? '' : jsonEncode(data),
      );
    } catch (_) {}
  }

  void Function(int) photoViewer() {
    final owner = generation();
    return (_) {
      if (owner == generation()) event('photo_view');
    };
  }

  MiniPhoneAnalyticsAttempt beginAttempt(
    String action, {
    required String target,
    required String source,
    Map<String, Object?> data = const {},
  }) => MiniPhoneAnalyticsAttempt._(this, action, target, {
    ...context(source),
    ...data,
  });
}

class MiniPhoneAnalyticsAttempt {
  MiniPhoneAnalyticsAttempt._(
    this.analytics,
    this.action,
    this.target,
    this.data,
  ) : id = const Uuid().v4(),
      _generation = analytics.generation() {
    _record('submit');
  }

  final MiniPhoneAnalytics analytics;
  final String action, target, id;
  final int _generation;
  final Map<String, Object?> data;
  bool _finished = false;

  void _record(String stage) {
    if (_generation != analytics.generation()) return;
    analytics.event(
      action,
      target: target,
      stage: stage,
      attemptId: id,
      data: data,
    );
  }

  void finish(String stage) {
    if (_finished) return;
    _finished = true;
    _record(stage);
  }

  void fail(Object error, {required bool sent, required String errorStage}) {
    if (_finished) return;
    data['error_stage'] = errorStage;
    data['error_kind'] = error is ApiException ? error.kind.name : 'local';
    if (error is ApiException && error.code != null) {
      data['error_code'] = error.code.toString();
    }
    finish(
      !sent
          ? 'local_failed'
          : error is ApiException && error.kind == ApiExceptionKind.business
          ? 'rejected'
          : 'uncertain',
    );
  }
}
