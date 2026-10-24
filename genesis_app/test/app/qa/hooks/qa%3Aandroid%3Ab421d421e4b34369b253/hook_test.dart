import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Ab421d421e4b34369b253/hook.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart' show activePanel;
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/subject.dart';
void main(){testWidgets('compares actual panel identity and rendered title independently',(tester)async{
 final f=await mountSubject(tester);
 try{
  final p=activePanel();
  expect(observe(p,'qa-contract-chat-world','qa-contract-chat-location','Contract location'),{
   'locationId':'qa-contract-chat-location','displayedName':'Contract location','locationIdMatches':true,'displayedNameMatches':true});
  expect(observe(p,'wrong-world','qa-contract-chat-location','Contract location')['locationIdMatches'],false);
  expect(observe(p,'qa-contract-chat-world','wrong-location','Contract location')['locationIdMatches'],false);
  expect(observe(p,'qa-contract-chat-world','qa-contract-chat-location','wrong-name')['displayedNameMatches'],false);
  expect(observe(null,'qa-contract-chat-world','qa-contract-chat-location','Contract location')['displayedNameMatches'],false);
 }finally{await closeSubject(tester,f);}
});}
