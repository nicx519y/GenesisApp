import 'package:flutter/material.dart';
import '../../../../pages/chat/location_chat_page.dart';
import '../../../../components/chat/shared/chat_ui.dart';
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart' show activePanel;
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart' show elements,visible,validate;
import '../qa%253Aandroid%253A538adf49de88c951fcbe/resource.dart';
Map<String,Object?> observe(Element? panel,String worldId,String locationId,String name) {
  final widget=panel?.widget;
  final headers=panel==null?<Element>[]:elements(panel).where((e)=>e.widget is ChatHeader&&visible(e)).toList();
  final title=headers.length==1?(headers.single.widget as ChatHeader).title:null;
  final rendered=headers.length==1&&elements(headers.single).any((e)=>e.widget is Text&&(e.widget as Text).data==name&&visible(e));
  return {'locationId':widget is LocationChatPanel?widget.locationId:null,'displayedName':title,
    'locationIdMatches':widget is LocationChatPanel&&widget.worldId==worldId&&widget.locationId==locationId,
    'displayedNameMatches':title==name&&rendered};
}
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
  validate(p,started,'read');final r=resource();await r.requireOwner();
  return observe(activePanel(),r.worldId,r.locationId,r.locationName);
}
