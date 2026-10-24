import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A7c38b118fb428868d83a/hook.dart';
void main(){test('visibility follows actual row count without hiding duplicates',(){expect(knownVisible(0),false);expect(knownVisible(1),true);expect(knownVisible(2),true);expect(()=>knownVisible(-1),throwsArgumentError);});}
