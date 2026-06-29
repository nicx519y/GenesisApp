import 'package:flutter/foundation.dart';

class AgentControlStatus {
  const AgentControlStatus({
    required this.enabled,
    required this.running,
    this.host = '127.0.0.1',
    this.port,
    this.tokenConfigured = false,
    this.tokenPreview,
    this.lastError,
    this.recentEvents = const [],
  });

  const AgentControlStatus.disabled()
    : enabled = false,
      running = false,
      host = '127.0.0.1',
      port = null,
      tokenConfigured = false,
      tokenPreview = null,
      lastError = null,
      recentEvents = const [];

  final bool enabled;
  final bool running;
  final String host;
  final int? port;
  final bool tokenConfigured;
  final String? tokenPreview;
  final String? lastError;
  final List<String> recentEvents;

  String get label {
    if (!enabled) return 'disabled';
    if (running) return 'running';
    if (lastError?.isNotEmpty == true) return 'error';
    return 'starting';
  }

  AgentControlStatus copyWith({
    bool? enabled,
    bool? running,
    String? host,
    int? port,
    bool? tokenConfigured,
    String? tokenPreview,
    String? lastError,
    List<String>? recentEvents,
  }) {
    return AgentControlStatus(
      enabled: enabled ?? this.enabled,
      running: running ?? this.running,
      host: host ?? this.host,
      port: port ?? this.port,
      tokenConfigured: tokenConfigured ?? this.tokenConfigured,
      tokenPreview: tokenPreview ?? this.tokenPreview,
      lastError: lastError,
      recentEvents: recentEvents ?? this.recentEvents,
    );
  }
}

final ValueNotifier<AgentControlStatus> agentControlStatus =
    ValueNotifier<AgentControlStatus>(const AgentControlStatus.disabled());
