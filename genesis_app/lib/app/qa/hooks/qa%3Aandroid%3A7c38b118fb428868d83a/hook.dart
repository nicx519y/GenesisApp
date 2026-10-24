import '../qa%253Aandroid%253A4e9bddbcfd11e06f535a/hook.dart' as count;
bool knownVisible(int count) {if(count<0) throw ArgumentError('Negative rendered count');return count>0;}
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async => knownVisible(await count.invoke(p,prepared,started) as int);
