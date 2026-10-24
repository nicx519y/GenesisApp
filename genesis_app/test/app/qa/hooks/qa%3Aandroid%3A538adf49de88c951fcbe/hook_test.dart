import 'dart:io';
import 'dart:convert';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A538adf49de88c951fcbe/socket.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A538adf49de88c951fcbe/resource.dart';
void main(){
 test('real loopback handshake acknowledges the owned world and releases the port',() async {
  final peer=LocationChatPeer('world-a','uid-a');
  expect(await peer.probe(),false);
  await peer.open();final uri=Uri.parse(peer.url);
  try{
   expect(await peer.probe(),true);
   final socket=await WebSocket.connect('${peer.url}?world_id=world-a');
   try {
    socket.add(jsonEncode({'type':'join','world_id':'world-a','location_id':'a','client_msg_id':'join-1'}));
    final frame=ChatroomV2Message.fromJson(jsonDecode(await socket.first.timeout(const Duration(seconds:3)) as String) as Map<String,dynamic>);
    final ack=ChatroomAck.fromV2Message(frame);
    expect(ack.clientMsgId,'join-1');expect(ack.locationId,'a');expect(ack.worldId,'world-a');expect(ack.code,0);
   }finally{await socket.close();}
   await expectLater(WebSocket.connect('${peer.url}?world_id=foreign'),throwsA(isA<WebSocketException>()));
   expect(await peer.probe(),true);
   await expectLater(peer.open(),throwsStateError);
  }finally{await peer.close();}
  expect(peer.closed,true);expect(await peer.probe(),false);
  final rebound=await HttpServer.bind(InternetAddress.loopbackIPv4,uri.port);
  await rebound.close(force:true);
 });
 test('contract and Case mutation protocols stay isolated',()async{
  await expectLater(invoke({'operation':'prepare'},true,true),throwsStateError);
  await expectLater(contract({'operation':'prepare'},false,true),throwsStateError);
  await expectLater(invoke({'operation':'prepare'},false,false),throwsStateError);
  await expectLater(invoke({'operation':'read','navigate':true},false,true),throwsStateError);
 });
}
