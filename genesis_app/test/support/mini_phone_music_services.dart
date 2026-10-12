import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

/// Use a deterministic API without invoking native request-header providers.
AppServices musicTestServices(GenesisApi api) {
  final base = ServiceRegistry.build(
    config: const AppConfig(useMock: true),
    sessionStoreOverride: MemoryUserSessionStore(),
    chatroomMessagesOverride: MemoryChatroomMessageStorage(),
  );
  base.dispose();
  return AppServices(
    config: base.config,
    platformConfig: base.platformConfig,
    deviceId: base.deviceId,
    sessionStore: base.sessionStore,
    identityAuth: base.identityAuth,
    backendAuth: base.backendAuth,
    api: api,
    chatroom: base.chatroom,
    chatroomMessages: base.chatroomMessages,
    directMessageConversations: base.directMessageConversations,
    directMessageMessages: base.directMessageMessages,
    appVersionCheck: base.appVersionCheck,
    externalUrlOpener: base.externalUrlOpener,
  );
}
