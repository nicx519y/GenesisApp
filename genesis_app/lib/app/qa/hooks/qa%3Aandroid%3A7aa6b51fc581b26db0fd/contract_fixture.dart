import 'dart:async';
import 'package:flutter/material.dart';
import '../../../genesis_navigator.dart';
import '../../../../pages/chat/location_chat_page.dart';
import '../../../../network/chatroom/chatroom_http_models.dart';
import '../../../../network/chatroom/chatroom_message_storage.dart';
import '../../../../network/chatroom/world_chatroom_service.dart';
import '../../../../ui/navigation/genesis_dark_page_route.dart';
import '../qa%253Aandroid%253A538adf49de88c951fcbe/resource.dart';
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart';

/// A separate real panel at B proves that the read primitives reject B as A.
/// This subject is used only by the contract, never the Case runtime.
class ForeignPanelFixture {
  ForeignPanelFixture(this.resource);
  final LocationChatResource resource;
  Route<void>? route;
  late WorldChatroomService service;
  Route<dynamic>? previous;
  bool released=false;
  Future<Map<String,Object?>> prepare() async {
    if(route!=null) throw StateError('Foreign panel already acquired');
    final current=activePanel();
    if(current==null) throw StateError('Contract requires original chat panel');
    previous=ModalRoute.of(current);
    service=WorldChatroomService(api:resource.services.api,client:resource.services.chatroom,messageStorage:MemoryChatroomMessageStorage());
    final message=WorldChatroomMessage.fromHttpMessage(ChatroomHttpMessage.fromV2Json(resource.message(resource.foreignLocationId)));
    route=GenesisDarkPageRoute<void>(builder:(_)=>Scaffold(body:LocationChatPanel(
      worldId:resource.worldId,locationId:resource.foreignLocationId,locationName:'Foreign contract location',
      service:service,isLeafLocation:false,renderBackgroundImage:false,showComposer:false,
      openingPreviewMessages:[message],retainOpeningPreviewUntilHistory:true,onBack:(){},
    )));
    unawaited(genesisNavigatorKey.currentState!.push(route!));
    await WidgetsBinding.instance.endOfFrame;
    return {'prepared':route!.isActive,'resource':resource.bridge.resource};
  }
  Future<Map<String,Object?>> restore() async {
    if(route==null) throw StateError('Foreign panel not acquired');
    if(!released) {
      if(route!.isActive&&!route!.isCurrent) throw StateError('Foreign route above contract subject');
      if(route!.isActive) route!.navigator!.removeRoute(route!);
      await WidgetsBinding.instance.endOfFrame;
      await service.dispose();released=true;
    }
    final matches=previous?.isCurrent==true&&!route!.isActive&&!service.state.connected;
    if(!matches) throw StateError('Foreign panel restoration mismatch');
    return {'restored':released,'matchesSnapshot':matches,'resource':resource.bridge.resource};
  }
}
final fixtures=Expando<ForeignPanelFixture>();
Future<Object?> fixture(Map<String,dynamic> p,bool prepared,bool started) async {
  if(!prepared||!started||p.length!=1) throw StateError('Started isolated contract required');
  final r=resource();await r.requireOwner();
  if(p['operation']=='prepare') {final f=ForeignPanelFixture(r);if(fixtures[r]!=null) throw StateError('Duplicate foreign fixture');fixtures[r]=f;return f.prepare();}
  if(p['operation']=='restore') {final f=fixtures[r];if(f==null) throw StateError('No foreign fixture');return f.restore();}
  throw ArgumentError('Unsupported contract fixture operation');
}
