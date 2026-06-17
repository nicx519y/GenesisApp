import '../../network/genesis_api.dart';

class AppConfig {
  const AppConfig({
    this.apiBaseUrl = GenesisApi.defaultApiBaseUrl,
    this.assetBaseUrl = GenesisApi.defaultAssetBaseUrl,
    this.apiEnvironment = const String.fromEnvironment(
      'GENESIS_API_ENV',
      defaultValue: 'real',
    ),
    this.chatroomWsBaseUrl = const String.fromEnvironment(
      'GENESIS_CHATROOM_WS_URL',
      defaultValue: GenesisApi.defaultChatroomWsBaseUrl,
    ),
    this.chatroomHttpBaseUrl = const String.fromEnvironment(
      'GENESIS_CHATROOM_HTTP_URL',
      defaultValue: GenesisApi.defaultChatroomHttpBaseUrl,
    ),
    this.debugProxy = const String.fromEnvironment(
      'GENESIS_DEBUG_PROXY',
      defaultValue: '',
    ),
    this.debugWsLog = const bool.fromEnvironment(
      'GENESIS_DEBUG_WS_LOG',
      defaultValue: false,
    ),
    this.chatroomHeartbeatInterval = const Duration(seconds: 2),
    this.chatroomAckTimeout = const Duration(seconds: 12),
    bool? useMock,
  }) : _useMockOverride = useMock;

  final String apiBaseUrl;
  final String assetBaseUrl;
  final String apiEnvironment;
  final String chatroomWsBaseUrl;
  final String chatroomHttpBaseUrl;
  final String debugProxy;
  final bool debugWsLog;
  final Duration chatroomHeartbeatInterval;
  final Duration chatroomAckTimeout;
  final bool? _useMockOverride;

  bool? get useMock {
    final override = _useMockOverride;
    if (override != null) return override;
    return mockApiOverrideFromEnvironment(apiEnvironment);
  }

  AppConfig copyWith({
    String? apiBaseUrl,
    String? assetBaseUrl,
    String? apiEnvironment,
    String? chatroomWsBaseUrl,
    String? chatroomHttpBaseUrl,
    String? debugProxy,
    bool? debugWsLog,
    Duration? chatroomHeartbeatInterval,
    Duration? chatroomAckTimeout,
    bool? useMock,
  }) {
    return AppConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      assetBaseUrl: assetBaseUrl ?? this.assetBaseUrl,
      apiEnvironment: apiEnvironment ?? this.apiEnvironment,
      chatroomWsBaseUrl: chatroomWsBaseUrl ?? this.chatroomWsBaseUrl,
      chatroomHttpBaseUrl: chatroomHttpBaseUrl ?? this.chatroomHttpBaseUrl,
      debugProxy: debugProxy ?? this.debugProxy,
      debugWsLog: debugWsLog ?? this.debugWsLog,
      chatroomHeartbeatInterval:
          chatroomHeartbeatInterval ?? this.chatroomHeartbeatInterval,
      chatroomAckTimeout: chatroomAckTimeout ?? this.chatroomAckTimeout,
      useMock: useMock ?? _useMockOverride,
    );
  }
}

bool? mockApiOverrideFromEnvironment(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'auto') return null;
  if (normalized == 'mock' || normalized == 'local' || normalized == 'debug') {
    return true;
  }
  if (normalized == 'production' ||
      normalized == 'prod' ||
      normalized == 'real') {
    return false;
  }
  return null;
}
