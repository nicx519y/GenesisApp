import '../../network/genesis_api.dart';
import '../../network/chatroom/chatroom_client.dart';
import '../../network/chatroom/chatroom_message_storage.dart';
import '../../network/chatroom/chatroom_socket_transport.dart';
import '../../network/direct_message_conversation_store.dart';
import '../../network/direct_message_message_store.dart';
import '../../network/io_http_transport.dart';
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
    required this.chatroom,
    required this.chatroomMessages,
    required this.directMessageConversations,
    required this.directMessageMessages,
  });

  final AppConfig config;
  final PlatformConfig platformConfig;
  final DeviceIdService deviceId;
  final UserSessionStore sessionStore;
  final IdentityAuthService identityAuth;
  final BackendAuthCoordinator backendAuth;
  final GenesisApi api;
  final ChatroomClient chatroom;
  final ChatroomMessageStorage chatroomMessages;
  final DirectMessageConversationStore directMessageConversations;
  final DirectMessageMessageStore directMessageMessages;
}

class ServiceRegistry {
  const ServiceRegistry._();

  static AppServices build({AppConfig config = const AppConfig()}) {
    final platformConfig = DefaultPlatformConfig(appConfig: config);
    const deviceId = NativeDeviceIdService();
    final sessionStore = NativeUserSessionStore();
    const identityAuth = FirebaseIdentityAuthService();
    final debugProxy = config.debugProxy.trim();
    final useMock = config.useMock;
    final httpTransport = debugProxy.isEmpty || useMock == true
        ? null
        : IoHttpTransport(proxy: debugProxy);
    final socketTransport = debugProxy.isEmpty && !config.debugWsLog
        ? null
        : IoChatroomSocketTransport(
            proxy: debugProxy.isEmpty ? null : debugProxy,
            logFrames:
                config.debugWsLog ||
                !const bool.fromEnvironment('dart.vm.product'),
          );
    final api = GenesisApi(
      useMock: useMock,
      transport: httpTransport,
      platformConfig: platformConfig,
      chatroomHttpBaseUrl: config.chatroomHttpBaseUrl,
      deviceIdService: deviceId,
      sessionStore: sessionStore,
      identityAuthService: identityAuth,
    );
    final chatroom = ChatroomClient(
      wsBaseUrl: config.chatroomWsBaseUrl,
      sessionStore: sessionStore,
      deviceIdService: deviceId,
      transport: socketTransport,
      heartbeatInterval: config.chatroomHeartbeatInterval,
      ackTimeout: config.chatroomAckTimeout,
    );
    final backendAuth = GenesisBackendAuthCoordinator(
      api: api,
      identityAuth: identityAuth,
      sessionStore: sessionStore,
    );
    final directMessageConversations = DirectMessageConversationStore(
      api: api,
      sessionStore: sessionStore,
      storage: SqfliteDirectMessageConversationStorage(),
    );
    final directMessageMessages = DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: SqfliteDirectMessageMessageStorage(),
    );
    final chatroomMessages = SqfliteChatroomMessageStorage();
    return AppServices(
      config: config,
      platformConfig: platformConfig,
      deviceId: deviceId,
      sessionStore: sessionStore,
      identityAuth: identityAuth,
      backendAuth: backendAuth,
      api: api,
      chatroom: chatroom,
      chatroomMessages: chatroomMessages,
      directMessageConversations: directMessageConversations,
      directMessageMessages: directMessageMessages,
    );
  }
}
