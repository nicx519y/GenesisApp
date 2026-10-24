import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A538adf49de88c951fcbe/history.dart';
void main() {
 test('V2 and legacy history preserve IDs, location, author and content through business parsers', () {
  final wire=historyMessage(worldId:'world-a',locationId:'a',messageId:910001,content:'known');
  for(final actual in [ChatroomHttpMessage.fromV2Json(wire),ChatroomHttpMessage.fromJson(legacyHistoryMessage(wire))]) {
   expect(actual.globalMessageId,910001);expect(actual.locationMessageId,910001);
   expect(actual.locationId,'a');expect(actual.senderId,'qa-history-author');expect(actual.content,'known');
   final rendered=WorldChatroomMessage.fromHttpMessage(actual);
   expect(rendered.globalMessageId,910001);expect(rendered.locationId,'a');
  }
  final foreign=ChatroomHttpMessage.fromV2Json(historyMessage(worldId:'world-a',locationId:'b',messageId:910002,content:'foreign'));
  expect(foreign.locationId,isNot('a'));expect(foreign.globalMessageId,isNot(910001));
  final broken=Map<String,dynamic>.from(wire)..remove('global_message_id');
  expect(ChatroomHttpMessage.fromV2Json(broken).globalMessageId,0);
 });
}
