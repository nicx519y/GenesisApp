import '../../network/genesis_api.dart';

class AppConfig {
  static const defaultAlibabaRumServiceId = 'bui9rvr4ow@ee4a8ef0e23567a0da8a4';
  static const defaultAlibabaRumWorkspace =
      'default-cms-1203224652491648-us-west-1';
  static const defaultAlibabaRumEndpoint =
      'https://proj-xtrace-787e287963ab8594ca6655fb346740-us-west-1'
      '.us-west-1.log.aliyuncs.com';

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
    this.alibabaRumServiceId = const String.fromEnvironment(
      'GENESIS_ALIBABA_RUM_SERVICE_ID',
      defaultValue: defaultAlibabaRumServiceId,
    ),
    this.alibabaRumWorkspace = const String.fromEnvironment(
      'GENESIS_ALIBABA_RUM_WORKSPACE',
      defaultValue: defaultAlibabaRumWorkspace,
    ),
    this.alibabaRumEndpoint = const String.fromEnvironment(
      'GENESIS_ALIBABA_RUM_ENDPOINT',
      defaultValue: defaultAlibabaRumEndpoint,
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
  final String alibabaRumServiceId;
  final String alibabaRumWorkspace;
  final String alibabaRumEndpoint;
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
    String? alibabaRumServiceId,
    String? alibabaRumWorkspace,
    String? alibabaRumEndpoint,
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
      alibabaRumServiceId: alibabaRumServiceId ?? this.alibabaRumServiceId,
      alibabaRumWorkspace: alibabaRumWorkspace ?? this.alibabaRumWorkspace,
      alibabaRumEndpoint: alibabaRumEndpoint ?? this.alibabaRumEndpoint,
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
