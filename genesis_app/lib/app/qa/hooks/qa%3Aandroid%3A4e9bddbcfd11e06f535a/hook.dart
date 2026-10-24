import 'package:flutter/material.dart';
import '../../../../components/chat/shared/chat_ui.dart';
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart' show activePanel;
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart' show elements,visible,validate;
import '../qa%253Aandroid%253A538adf49de88c951fcbe/resource.dart';
List<ChatMessageVm> displayedMessages(Element? panel) => panel==null?[]:elements(panel).where((e)=>e.widget is ChatMessageRow&&visible(e)).map((e)=>(e.widget as ChatMessageRow).message).toList();
int countKnown(Iterable<ChatMessageVm> rows,int id,String content) => rows.where((m)=>m.globalMessageId==id&&m.text==content).length;
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
  validate(p,started,'read');final r=resource();await r.requireOwner();
  return countKnown(displayedMessages(activePanel()),r.knownId,r.knownContent);
}
