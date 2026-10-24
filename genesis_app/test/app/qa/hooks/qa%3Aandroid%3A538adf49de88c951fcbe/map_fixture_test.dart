import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A538adf49de88c951fcbe/map_fixture.dart';
void main(){
 test('leaf entry changes only the isolated map copy and preserves original geometry',(){
  final raw=<String,dynamic>{'map_json':{'width':1,'height':1,'tiles':[{'x':0,'y':0,'type':'mock','location_id':'parent'}]}};
  final map=leafMapJson(raw,'leaf');
  expect((map['tiles'] as List).single,{'x':0,'y':0,'type':'mock','location_id':'leaf'});
  expect(((raw['map_json'] as Map)['tiles'] as List).single['location_id'],'parent');
  expect(map['width'],1);expect(map['height'],1);
  expect(()=>leafMapJson(raw,''),throwsArgumentError);
  expect(()=>leafMapJson({'map_json':{'tiles':[]}},'leaf'),throwsStateError);
 });
}
