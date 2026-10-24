import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Abf448f29b28c4fce0618/resource.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
void main() {
 late WorldDataset dataset;
 late WorldMembership subject;
 late Map<String, JsonMap> seed;
 late String owner;
 late bool current;
 setUp(() async {
  owner='qa_test_world_resource'; current=true;
  seed={'detail': {'info': {'world_id':'w1','status':20}, 'relation_status':'none'}, 'info': {'info': {'world_id':'w1','status':20}}, 'map': <String,dynamic>{}};
  dataset=WorldDataset(resource:'r',owner:owner,currentOwner:() async=>owner,currentResource:()=>current,
   list:() async=>{'list':[{'info':{'world_id':'w1'}}]},
   fetch:(endpoint,id) async {
    final response=await dataset.respond(TransportRequest(method:'GET',uri:Uri.parse('https://mock/api/v1/world/$endpoint?world_id=$id&location_id=root'),headers:const {},bodyBytes:null,timeoutMs:1000));
    return response==null?copyWorldJson(seed[endpoint]!):jsonDecode(response.body)['data'] as JsonMap;
   });
  await dataset.prepare(); subject=WorldMembership(dataset);
 });
 test('positive, negative, repeat preparation preserve original snapshot and cleanup',() async {
  final before=await subject.read(); final original=jsonEncode(seed);
  try {
   await expectLater(subject.restore(),throwsStateError);
   expect((await subject.prepare())['joined'],true);
   expect((await subject.negative())['joined'],false);
   await subject.prepare();
   expect((await subject.restore())['matchesSnapshot'],true);
   expect(await subject.read(),before);
   expect((await subject.restore())['restored'],true);
   await expectLater(subject.prepare(),throwsStateError);
   expect(jsonEncode(seed),original);
  } finally { await dataset.restore(); }
 });
 test('dataset may be released first without reacquisition',() async {
  final before=await subject.read(); await subject.prepare(); await dataset.restore();
  expect((await subject.restore())['matchesSnapshot'],true);
  expect(dataset.active,false); expect(await subject.read(),before);
 });
 test('foreign identity and session cannot restore; mismatch retains retryable snapshot',() async {
  await subject.prepare();
  try {
   owner='foreign'; await expectLater(subject.restore(),throwsStateError);
   owner='qa_test_world_resource'; current=false; await expectLater(subject.restore(),throwsStateError);
   current=true; await dataset.restore();
   final saved=copyWorldJson(seed['detail']!);
   seed["detail"]!["relation_status"]="foreign";
   await expectLater(subject.restore(),throwsStateError);
   seed['detail']=saved;
   expect((await subject.restore())['matchesSnapshot'],true);
  } finally {owner='qa_test_world_resource';current=true;await dataset.restore();}
 });
 test('contract and Case protocols remain isolated',() async {
  await expectLater(invoke({'operation':'prepare'},true,true),throwsStateError);
  await expectLater(contract({'operation':'prepare'},false,true),throwsStateError);
  await expectLater(invoke({'operation':'read'},false,false),throwsArgumentError);
  await dataset.restore();
 });
}
