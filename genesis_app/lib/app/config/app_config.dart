import '../../network/genesis_api.dart';

class AppConfig {
  const AppConfig({
    this.apiBaseUrl = GenesisApi.defaultApiBaseUrl,
    this.assetBaseUrl = GenesisApi.defaultAssetBaseUrl,
    this.chatroomWsBaseUrl = const String.fromEnvironment(
      'GENESIS_CHATROOM_WS_URL',
      defaultValue: GenesisApi.defaultChatroomWsBaseUrl,
    ),
    this.chatroomHeartbeatInterval = const Duration(seconds: 30),
    this.chatroomAckTimeout = const Duration(seconds: 12),
    this.useMock,
  });

  final String apiBaseUrl;
  final String assetBaseUrl;
  final String chatroomWsBaseUrl;
  final Duration chatroomHeartbeatInterval;
  final Duration chatroomAckTimeout;
  final bool? useMock;
}
