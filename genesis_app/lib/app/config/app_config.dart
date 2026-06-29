import '../../network/genesis_api.dart';

class AppConfig {
  static const defaultPostHogProjectToken =
      'phc_riFTSH7zTTeKCeb38WMYbTHjB2CndxFhaZhN6yUdA7AB';
  static const defaultPostHogHost = 'https://us.i.posthog.com';
  static const defaultAppleWebClientId = 'com.worldo.ai.signin';
  static const defaultAppleWebRedirectUri =
      '${GenesisApi.defaultBaseHost}/callbacks/signinwithapple';

  const AppConfig({
    this.apiBaseUrl = GenesisApi.defaultApiBaseUrl,
    this.gatewayApiBaseUrl = GenesisApi.defaultGatewayApiBaseUrl,
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
    this.postHogProjectToken = const String.fromEnvironment(
      'GENESIS_POSTHOG_PROJECT_TOKEN',
      defaultValue: defaultPostHogProjectToken,
    ),
    this.postHogHost = const String.fromEnvironment(
      'GENESIS_POSTHOG_HOST',
      defaultValue: defaultPostHogHost,
    ),
    this.postHogDebug = const bool.fromEnvironment(
      'GENESIS_POSTHOG_DEBUG',
      defaultValue: false,
    ),
    this.collectEndpoint = const String.fromEnvironment(
      'GENESIS_COLLECT_ENDPOINT',
      defaultValue: 'https://collect.worldo.ai/api/v1/collect',
    ),
    this.collectEnabled = const bool.fromEnvironment(
      'GENESIS_COLLECT_ENABLED',
      defaultValue: true,
    ),
    this.agentControlEnabled = const bool.fromEnvironment(
      'GENESIS_AGENT_CONTROL_ENABLED',
      defaultValue: false,
    ),
    this.agentControlPort = const int.fromEnvironment(
      'GENESIS_AGENT_CONTROL_PORT',
      defaultValue: 17317,
    ),
    this.agentControlToken = const String.fromEnvironment(
      'GENESIS_AGENT_CONTROL_TOKEN',
      defaultValue: '',
    ),
    this.appId = const String.fromEnvironment(
      'GENESIS_APP_ID',
      defaultValue: 'aitown',
    ),
    this.appChannel = const String.fromEnvironment(
      'GENESIS_APP_CHANNEL',
      defaultValue: 'default',
    ),
    this.chatroomHeartbeatInterval = const Duration(seconds: 10),
    this.chatroomAckTimeout = const Duration(seconds: 12),
    bool? useMock,
  }) : _useMockOverride = useMock;

  final String apiBaseUrl;
  final String gatewayApiBaseUrl;
  final String assetBaseUrl;
  final String apiEnvironment;
  final String chatroomWsBaseUrl;
  final String chatroomHttpBaseUrl;
  final String debugProxy;
  final bool debugWsLog;
  final String postHogProjectToken;
  final String postHogHost;
  final bool postHogDebug;
  final String collectEndpoint;
  final bool collectEnabled;
  final bool agentControlEnabled;
  final int agentControlPort;
  final String agentControlToken;
  final String appId;
  final String appChannel;
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
    String? gatewayApiBaseUrl,
    String? assetBaseUrl,
    String? apiEnvironment,
    String? chatroomWsBaseUrl,
    String? chatroomHttpBaseUrl,
    String? debugProxy,
    bool? debugWsLog,
    String? postHogProjectToken,
    String? postHogHost,
    bool? postHogDebug,
    String? collectEndpoint,
    bool? collectEnabled,
    bool? agentControlEnabled,
    int? agentControlPort,
    String? agentControlToken,
    String? appId,
    String? appChannel,
    Duration? chatroomHeartbeatInterval,
    Duration? chatroomAckTimeout,
    bool? useMock,
  }) {
    return AppConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      gatewayApiBaseUrl: gatewayApiBaseUrl ?? this.gatewayApiBaseUrl,
      assetBaseUrl: assetBaseUrl ?? this.assetBaseUrl,
      apiEnvironment: apiEnvironment ?? this.apiEnvironment,
      chatroomWsBaseUrl: chatroomWsBaseUrl ?? this.chatroomWsBaseUrl,
      chatroomHttpBaseUrl: chatroomHttpBaseUrl ?? this.chatroomHttpBaseUrl,
      debugProxy: debugProxy ?? this.debugProxy,
      debugWsLog: debugWsLog ?? this.debugWsLog,
      postHogProjectToken: postHogProjectToken ?? this.postHogProjectToken,
      postHogHost: postHogHost ?? this.postHogHost,
      postHogDebug: postHogDebug ?? this.postHogDebug,
      collectEndpoint: collectEndpoint ?? this.collectEndpoint,
      collectEnabled: collectEnabled ?? this.collectEnabled,
      agentControlEnabled: agentControlEnabled ?? this.agentControlEnabled,
      agentControlPort: agentControlPort ?? this.agentControlPort,
      agentControlToken: agentControlToken ?? this.agentControlToken,
      appId: appId ?? this.appId,
      appChannel: appChannel ?? this.appChannel,
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
