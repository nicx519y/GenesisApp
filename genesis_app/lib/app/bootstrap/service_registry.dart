import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/common/genesis_center_toast.dart';
import '../../app/genesis_navigator.dart';
import '../../network/genesis_api.dart';
import '../../network/app_request_headers.dart';
import '../../network/chatroom/chatroom_client.dart';
import '../../network/chatroom/chatroom_message_storage.dart';
import '../../network/chatroom/chatroom_socket_transport.dart';
import '../../network/direct_message_conversation_store.dart';
import '../../network/direct_message_message_store.dart';
import '../../routers/app_router.dart';
import '../../network/io_http_transport.dart';
import '../../platform/platform_services.dart';
import '../config/app_config.dart';
import '../config/platform_config.dart';

class AppServices {
  AppServices({
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
    ValueNotifier<int>? sessionRevision,
  }) : sessionRevision = sessionRevision ?? ValueNotifier<int>(0);

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
  final ValueNotifier<int> sessionRevision;

  void notifySessionChanged() {
    sessionRevision.value += 1;
  }
}

class ServiceRegistry {
  const ServiceRegistry._();

  static AppServices build({AppConfig config = const AppConfig()}) {
    final platformConfig = DefaultPlatformConfig(appConfig: config);
    const deviceId = NativeDeviceIdService();
    final sessionStore = NativeUserSessionStore();
    const identityAuth = FirebaseIdentityAuthService();
    final sessionRevision = ValueNotifier<int>(0);
    var handlingSessionExpired = false;
    Future<void> handleSessionExpired(String _) async {
      if (handlingSessionExpired) return;
      handlingSessionExpired = true;
      try {
        await sessionStore.clearUid();
        sessionRevision.value += 1;
        try {
          await identityAuth.signOutIdentity();
        } catch (error) {
          debugPrint('[Auth][SessionExpired] identity sign out failed: $error');
        }

        final navigator = genesisNavigatorKey.currentState;
        navigator?.pushNamedAndRemoveUntil(RouteNames.origin, (_) => false);
        const toastMessage = 'Your account is logged in on another device.';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final overlay = genesisNavigatorKey.currentState?.overlay;
          if (overlay == null) return;
          showGenesisToastInOverlay(
            overlay,
            toastMessage,
            duration: const Duration(seconds: 4),
          );
        });
      } finally {
        await Future<void>.delayed(const Duration(seconds: 1));
        handlingSessionExpired = false;
      }
    }

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
    final appRequestHeaders = AppRequestHeaderProvider();
    final api = GenesisApi(
      useMock: useMock,
      transport: httpTransport,
      platformConfig: platformConfig,
      chatroomHttpBaseUrl: config.chatroomHttpBaseUrl,
      deviceIdService: deviceId,
      sessionStore: sessionStore,
      identityAuthService: identityAuth,
      appHeaderProvider: appRequestHeaders.headers,
      onSessionExpired: handleSessionExpired,
    );
    final chatroom = ChatroomClient(
      wsBaseUrl: config.chatroomWsBaseUrl,
      sessionStore: sessionStore,
      deviceIdService: deviceId,
      transport: socketTransport,
      heartbeatInterval: config.chatroomHeartbeatInterval,
      ackTimeout: config.chatroomAckTimeout,
      requestHeaderProvider: appRequestHeaders.headers,
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
      sessionRevision: sessionRevision,
    );
  }
}
