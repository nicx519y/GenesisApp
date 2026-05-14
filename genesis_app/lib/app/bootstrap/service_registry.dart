import '../../network/genesis_api.dart';
import '../../platform/platform_services.dart';
import '../config/app_config.dart';
import '../config/platform_config.dart';

class AppServices {
  const AppServices({
    required this.config,
    required this.platformConfig,
    required this.deviceId,
    required this.sessionStore,
    required this.identityAuth,
    required this.backendAuth,
    required this.api,
  });

  final AppConfig config;
  final PlatformConfig platformConfig;
  final DeviceIdService deviceId;
  final UserSessionStore sessionStore;
  final IdentityAuthService identityAuth;
  final BackendAuthCoordinator backendAuth;
  final GenesisApi api;
}

class ServiceRegistry {
  const ServiceRegistry._();

  static AppServices build({AppConfig config = const AppConfig()}) {
    final platformConfig = DefaultPlatformConfig(appConfig: config);
    const deviceId = NativeDeviceIdService();
    final sessionStore = NativeUserSessionStore();
    const identityAuth = FirebaseIdentityAuthService();
    final api = GenesisApi(
      useMock: config.useMock,
      platformConfig: platformConfig,
      deviceIdService: deviceId,
      sessionStore: sessionStore,
      identityAuthService: identityAuth,
    );
    final backendAuth = GenesisBackendAuthCoordinator(
      api: api,
      identityAuth: identityAuth,
      sessionStore: sessionStore,
    );
    return AppServices(
      config: config,
      platformConfig: platformConfig,
      deviceId: deviceId,
      sessionStore: sessionStore,
      identityAuth: identityAuth,
      backendAuth: backendAuth,
      api: api,
    );
  }
}
