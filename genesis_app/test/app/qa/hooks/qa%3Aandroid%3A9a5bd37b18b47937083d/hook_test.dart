import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A9a5bd37b18b47937083d/hook.dart';
void main(){
 testWidgets('dispatches the rendered bubble sibling and rejects blocked or duplicate targets',(tester)async {
  final root=GlobalKey();var taps=0;
  Widget bubble()=>SizedBox(width:180,height:50,child:Stack(children:[
   Positioned.fill(child:GestureDetector(onTap:(){taps++;},behavior:HitTestBehavior.opaque,
    child:Container(key:const ValueKey<String>('tile-location-bubble-body-Location A')))),
   const Positioned.fill(child:IgnorePointer(child:Text('Location A'))),
  ]));
  Future<void> mount({bool block=false,bool duplicate=false})async {
   await tester.pumpWidget(MaterialApp(home:Scaffold(body:Stack(key:root,children:[
    Column(children:[bubble(),if(duplicate)bubble()]),
    if(block) const Positioned.fill(child:AbsorbPointer(child:ColoredBox(color:Colors.black))),
   ]))));await tester.pump();
  }
  try {
   await mount();final targets=labelTargets(root.currentContext as Element,'Location A');
   expect(targets.length,1);targets.values.single();expect(taps,1);
   expect(labelTargets(root.currentContext as Element,'Missing'),isEmpty);
   await mount(block:true);expect(labelTargets(root.currentContext as Element,'Location A'),isEmpty);expect(taps,1);
   await mount(duplicate:true);expect(labelTargets(root.currentContext as Element,'Location A').length,2);expect(taps,1);
  }finally{await tester.pumpWidget(const SizedBox());await tester.pump();}
 });
test('missing map cannot dispatch navigation',(){expect(()=>tapLocation(null,'a','Location A'),throwsStateError);});test('rejects read and unknown parameters',()async{await expectLater(invoke({'operation':'read'},false,true),throwsArgumentError);await expectLater(invoke({'operation':'interact','force':true},false,true),throwsArgumentError);});}
