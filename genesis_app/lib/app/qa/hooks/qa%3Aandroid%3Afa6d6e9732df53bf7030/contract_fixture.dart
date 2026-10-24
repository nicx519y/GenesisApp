import 'dart:async';
import 'dart:convert';
import '../../../../network/websocket_transport.dart';
import 'package:flutter/material.dart';
import '../../../genesis_navigator.dart';
import '../../../../pages/chat/location_chat_page.dart';
import '../../../../network/chatroom/world_chatroom_service.dart';
import '../../../../network/chatroom/chatroom_message_storage.dart';
import '../../../../ui/navigation/genesis_dark_page_route.dart';
import '../qa%253Aandroid%253A88f61b36d73b39e019fe/view.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show selectedWorld;
import '../qa%253Aandroid%253Acde7c29bc0058f1961ed/hook.dart' show observation;
import 'resource.dart';
import 'list_transition.dart';

/// Contract-only navigation, negative subject and cleanup. Never imported by runtime.
class ParentContractFixture {
  ParentContractFixture(this.owner);
  final ParentResource owner;
  Route<void>? foreign;
  Route<dynamic>? listRoute;
  WorldChatroomService? service;
  Future<void> restoreForeign() async {
    if (foreign != null) {
      if (foreign!.isActive) {
        if (!foreign!.isCurrent)
          throw StateError('Unknown overlay above foreign subject');
        foreign!.navigator!.removeRoute(foreign!);
        await WidgetsBinding.instance.endOfFrame;
      }
      await service?.dispose();
      if (foreign!.isActive || service?.state.connected == true)
        throw StateError('Foreign subject cleanup failed');
      foreign = null;
      service = null;
    }
  }

  Future<void> closeList() async {
    if (listRoute != null && listRoute!.isActive) {
      if (!listRoute!.isCurrent)
        throw StateError('Unknown overlay above fixture list');
      listRoute!.navigator!.removeRoute(listRoute!);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (listRoute?.isActive == true)
      throw StateError('Fixture list not restored');
    listRoute = null;
  }

  Future<Object?> call(String op) async {
    await owner.requireOwner();
    if (op == 'open_list') {
      final w = selectedWorld(owner.worldId);
      if (w == null) throw StateError('Prepared world not visible');
      final target = labelTarget(w, 'Locations');
      if (target == null) throw StateError('Locations action unavailable');
      final list = await openContractLocations(target, locationsList);
      listRoute = ModalRoute.of(list);
      return {'visible': true};
    }
    if (op == 'close_list') {
      await closeList();
      return {'restored': listRoute == null};
    }
    if (op == 'foreign') {
      if (foreign != null) throw StateError('Foreign subject already acquired');
      service = WorldChatroomService(
        api: owner.isolated!.api,
        client: owner.isolated!.chatroom,
        messageStorage: MemoryChatroomMessageStorage(),
      );
      foreign = GenesisDarkPageRoute<void>(
        builder: (_) => Scaffold(
          body: LocationChatPanel(
            worldId: owner.worldId,
            locationId: owner.childIds.first,
            locationName: 'Contract child',
            isLeafLocation: false,
            renderBackgroundImage: false,
            showComposer: false,
            service: service,
            onBack: () {},
          ),
        ),
      );
      unawaited(genesisNavigatorKey.currentState!.push(foreign!));
      await WidgetsBinding.instance.endOfFrame;
      observation().sample();
      return {'mounted': foreign!.isActive};
    }
    if (op == 'restore_foreign') {
      await restoreForeign();
      return {'restored': foreign == null};
    }
    if (op == 'frames') {
      final socket = await IoWebSocketTransport().connect(
        Uri.parse('${owner.peer!.url}?world_id=${owner.worldId}'),
      );
      final messages = StreamIterator(socket.messages);
      try {
        for (final type in ['send_message', 'join', 'leave']) {
          for (final id in [owner.childIds.first, owner.parentId]) {
            await socket.send(
              jsonEncode({
                'type': type,
                'world_id': owner.worldId,
                'location_id': id,
                'user_id': owner.peer!.uid,
                'client_msg_id': 'fixture-$type-$id',
              }),
            );
            if (!await messages.moveNext().timeout(const Duration(seconds: 2)))
              throw StateError('Missing loopback ack');
            final ack = jsonDecode(messages.current as String) as Map;
            if (ack['err_no'] != 0) throw StateError('Loopback ack rejected');
          }
        }
      } finally {
        await messages.cancel();
        await socket.close();
      }
      return {'frames': owner.peer!.frames.length};
    }
    throw ArgumentError('Unsupported fixture operation');
  }
}

final fixtures = Expando<ParentContractFixture>();
Future<Object?> fixture(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  final r = resource();
  var f = fixtures[r];
  if (f == null) {
    f = ParentContractFixture(r);
    fixtures[r] = f;
    final owned = f;
    r.restorers.add(() async {
      await owned.restoreForeign();
      // Locations are released by the common resource restore.
    });
  }
  return f.call(p['operation'] as String);
}
