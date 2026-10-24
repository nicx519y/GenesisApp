import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/genesis_navigator.dart';
import '../../../../app/bootstrap/app_services_scope.dart';
import '../../../../app/bootstrap/service_registry.dart';
import '../../../../network/chatroom/chatroom_message_storage.dart';
import '../../../../network/chatroom/world_chatroom_service.dart';
import '../../../../pages/chat/location_chat_page.dart';
import '../../../../ui/navigation/genesis_dark_page_route.dart';
import '../../qa_bridge.dart';
import 'hook.dart' show observedRoute;
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart' show elements;

/// Contract-only UI subject: owns its disconnected service and memory storage.
/// Never imported by a Case/runtime primitive and never changes App services.
class ChatPanelFixture {
  ChatPanelFixture(this.navigator, this.previous, AppServices services)
    : service = WorldChatroomService(
        api: services.api,
        client: services.chatroom,
        messageStorage: MemoryChatroomMessageStorage(),
      );
  final NavigatorState navigator;
  final Route<dynamic> previous;
  final WorldChatroomService service;
  final blocked = ValueNotifier(false);
  final shown = ValueNotifier(true);
  late final Route<void> route;
  bool acquired = false, released = false;
  Future<void> prepare() async {
    if (acquired) throw StateError('Chat panel already acquired');
    route = GenesisDarkPageRoute<void>(
      builder: (_) => Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: blocked,
          builder: (_, block, child) =>
              AbsorbPointer(absorbing: block, child: child),
          child: ValueListenableBuilder<bool>(
            valueListenable: shown,
            builder: (_, show, __) => show
                ? LocationChatPanel(
                    worldId: 'qa-contract-chat-world',
                    locationId: 'qa-contract-chat-location',
                    locationName: 'Contract location',
                    isLeafLocation: false,
                    service: service,
                    renderBackgroundImage: false,
                    showComposer: false,
                    onBack: () => shown.value = false,
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
    acquired = true;
    unawaited(navigator.push(route));
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<Map<String, Object?>> restore(String resource) async {
    if (!acquired) throw StateError('No chat panel resource acquired');
    if (!released) {
      if (route.isActive && !route.isCurrent)
        throw StateError('Foreign route above chat fixture');
      if (route.isActive) navigator.removeRoute(route);
      await WidgetsBinding.instance.endOfFrame;
      await service.dispose();
      blocked.dispose();
      shown.dispose();
      released = true;
    }
    final matches =
        previous.isCurrent && !route.isActive && !service.state.connected;
    if (!matches) throw StateError('Chat contract restoration mismatch');
    return {
      'restored': released,
      'matchesSnapshot': matches,
      'serviceDisconnected': !service.state.connected,
      'resource': resource,
    };
  }
}

final fixtures = Expando<ChatPanelFixture>();
Future<Object?> fixture(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  final bridge = QaBridge.current;
  if (bridge == null ||
      const String.fromEnvironment('GENESIS_API_ENV') != 'mock')
    throw StateError('Authenticated mock bridge required');
  final operation = p['operation'];
  if (operation == 'prepare') {
    if (fixtures[bridge] != null)
      throw StateError('Chat contract already acquired');
    final nav = genesisNavigatorKey.currentState;
    if (nav == null) throw StateError('App navigator is not ready');
    final routes = elements()
        .map(observedRoute)
        .whereType<Route<dynamic>>()
        .where((r) => r.navigator == nav && r.isCurrent)
        .toSet();
    if (routes.length != 1) throw StateError('Ambiguous original App route');
    final services = AppServicesScope.maybeRead(nav.context);
    if (services == null) throw StateError('App services are not ready');
    final f = ChatPanelFixture(nav, routes.single, services);
    fixtures[bridge] = f;
    await f.prepare();
    return {'prepared': f.route.isActive, 'resource': bridge.resource};
  }
  final f = fixtures[bridge];
  if (f == null) throw StateError('No chat contract resource acquired');
  if (operation == 'restore') return f.restore(bridge.resource);
  if (f.released || !f.route.isCurrent)
    throw StateError('Chat fixture is not current');
  if (operation == 'block' || operation == 'unblock') {
    f.blocked.value = operation == 'block';
    await WidgetsBinding.instance.endOfFrame;
    return {'blocked': f.blocked.value, 'resource': bridge.resource};
  }
  throw ArgumentError('Unsupported chat fixture operation');
}
