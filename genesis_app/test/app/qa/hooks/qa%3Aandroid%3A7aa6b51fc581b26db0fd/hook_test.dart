import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A7aa6b51fc581b26db0fd/hook.dart';
ChatMessageVm row(int id)=>ChatMessageVm(localId:'$id',globalMessageId:id,senderId:'sender',senderName:'Sender',text:'history-$id',isMe:false,status:'sent');
void main(){test('retains every foreign and unknown origin, excluding only the UI disclaimer',(){
 final origins={1:'a',2:'b'};
 expect(foreignRows([row(1)],origins,'a'),isEmpty);
 expect(foreignRows([row(1),row(2),row(3)],origins,'a'),[
  {'messageId':'2','locationId':'b','content':'history-2'},
  {'messageId':'3','locationId':null,'content':'history-3'}]);
 expect(foreignRows([ChatMessageVm.aiContentDisclaimer()],origins,'a'),isEmpty);
});}
