import '../../network/genesis_api.dart';

class AppConfig {
  const AppConfig({
    this.apiBaseUrl = GenesisApi.defaultApiBaseUrl,
    this.assetBaseUrl = GenesisApi.defaultAssetBaseUrl,
    this.useMock,
  });

  final String apiBaseUrl;
  final String assetBaseUrl;
  final bool? useMock;
}
