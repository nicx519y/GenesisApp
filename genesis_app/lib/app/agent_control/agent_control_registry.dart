import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_http_cache_manager.dart';
import '../../network/models/world.dart';
import '../../pages/world/world_navigation.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../platform/session/user_session_store.dart';
import '../../routers/app_router.dart';
import '../bootstrap/app_services_scope.dart';
import '../bootstrap/service_registry.dart';
import '../config/app_config.dart';
import '../config/app_endpoint_overrides.dart';
import '../debug/location_chat_debug_hub.dart';
import '../debug_page_tracker.dart';
import '../genesis_navigator.dart';
import 'agent_control_models.dart';

part 'agent_control_app_handlers.dart';
part 'agent_control_world_chat_jobs.dart';
part 'agent_control_navigation.dart';
part 'agent_control_reply.dart';
part 'agent_control_params.dart';

typedef AgentControlHandler =
    FutureOr<Object?> Function(
      AgentControlContext context,
      AgentControlRequest request,
    );
typedef _AgentProgress =
    void Function(String goal, Map<String, Object?> details);
typedef _AgentCancelled = bool Function();

class AgentControlContext {
  const AgentControlContext({required this.services});

  final AppServices services;

  NavigatorState? get navigator => genesisNavigatorKey.currentState;

  Map<String, Object?> appState() {
    return {
      'route': genesisCurrentRouteName.value,
      'page': genesisCurrentPageClassName.value,
      'buildMode': _buildModeLabel,
      'agentControlEnabled': services.config.agentControlEnabled,
      'agentControlPort': services.config.agentControlPort,
      'apiBaseUrl': services.config.apiBaseUrl,
      'gatewayApiBaseUrl': services.config.gatewayApiBaseUrl,
      'chatroomHttpBaseUrl': services.config.chatroomHttpBaseUrl,
      'chatroomWsBaseUrl': services.config.chatroomWsBaseUrl,
    };
  }
}

class AgentControlRegistry {
  AgentControlRegistry({Map<String, AgentControlHandler>? handlers})
    : _handlers = {..._defaultHandlers, ...?handlers};

  final Map<String, AgentControlHandler> _handlers;

  Future<AgentControlResponse> execute(
    AgentControlRequest request,
    AgentControlContext context,
  ) async {
    final handler = _handlers[request.method];
    if (handler == null) {
      return _failure(
        request,
        context,
        const AgentControlException(
          code: 'unknown_method',
          message: 'Unknown agent control method.',
        ),
      );
    }
    try {
      final result = await Future<Object?>.sync(
        () => handler(context, request),
      ).timeout(Duration(milliseconds: request.timeoutMs));
      return AgentControlResponse(
        id: request.id,
        ok: true,
        result: result,
        appState: context.appState(),
      );
    } on TimeoutException {
      return _failure(
        request,
        context,
        AgentControlException(
          code: 'timeout',
          message: 'Command timed out after ${request.timeoutMs}ms.',
        ),
      );
    } on AgentControlException catch (error) {
      return _failure(request, context, error);
    } catch (error) {
      return _failure(
        request,
        context,
        AgentControlException(
          code: 'command_failed',
          message: error.toString(),
        ),
      );
    }
  }

  AgentControlResponse _failure(
    AgentControlRequest request,
    AgentControlContext context,
    AgentControlException error,
  ) {
    return AgentControlResponse(
      id: request.id,
      ok: false,
      error: error.toJson(),
      appState: context.appState(),
    );
  }
}

final Map<String, AgentControlHandler> _defaultHandlers = {
  'app.ping': _ping,
  'app.state': _state,
  'app.navigate': _navigate,
  'app.back': _back,
  'auth.state': _authState,
  'auth.clear': _authClear,
  'world.locations': _worldLocations,
  'agent.world_chat': _agentWorldChat,
  'agent.world_chat.open': _agentWorldChatOpen,
  'agent.world_chat.send': _agentWorldChatSend,
  'agent.world_chat.start': _agentWorldChatStart,
  'agent.world_chat.status': _agentWorldChatStatus,
  'agent.world_chat.cancel': _agentWorldChatCancel,
  'config.endpoint.set': _setEndpoint,
  'config.endpoint.clear': _clearEndpoint,
  'cache.clear': _clearCache,
  'diagnostics.snapshot': _diagnosticsSnapshot,
  if (LocationChatDebugHub.available) ...{
    'debug.locationChat.snapshot': _locationChatDebugSnapshot,
    'debug.locationChat.events': _locationChatDebugEvents,
    'debug.locationChat.clear': _locationChatDebugClear,
  },
};

final Map<String, _AgentJob> _agentJobs = <String, _AgentJob>{};
