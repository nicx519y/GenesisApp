import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A5de4919e028c054f9aba/hook.dart';
void main(){test('restoration cannot invent a snapshot or replace preparation',()async{await expectLater(invoke({'operation':'restore'},false,true),throwsStateError);await expectLater(invoke({'operation':'prepare'},false,true),throwsArgumentError);await expectLater(invoke({'operation':'restore'},true,true),throwsArgumentError);});}
