import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A4e9bddbcfd11e06f535a/hook.dart';
ChatMessageVm message(String local,int id,String text)=>ChatMessageVm(localId:local,globalMessageId:id,senderId:'sender',senderName:'Sender',text:text,isMe:false,status:'sent');
void main(){testWidgets('counts rendered rows; preserves duplicates and rejects wrong ID or content',(tester)async{
 final key=GlobalKey();
 Future<void> mount(List<ChatMessageVm> rows)async{await tester.pumpWidget(MaterialApp(home:Scaffold(body:Column(key:key,children:[for(final row in rows)ChatMessageRow(message:row,showDateDivider:false)]))));await tester.pump();}
 try{
  await mount([message('one',17,'known')]);expect(countKnown(displayedMessages(key.currentContext as Element),17,'known'),1);
  await mount([message('one',17,'known'),message('two',17,'known')]);expect(countKnown(displayedMessages(key.currentContext as Element),17,'known'),2);
  await mount([message('wrong-id',18,'known'),message('wrong-text',17,'foreign')]);expect(countKnown(displayedMessages(key.currentContext as Element),17,'known'),0);
  expect(displayedMessages(null),isEmpty);
 }finally{await tester.pumpWidget(const SizedBox());await tester.pump();}
});}
