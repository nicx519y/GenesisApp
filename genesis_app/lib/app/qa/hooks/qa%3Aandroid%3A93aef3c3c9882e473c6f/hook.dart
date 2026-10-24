import '../qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';
import '../qa%253Aandroid%253Acde7c29bc0058f1961ed/hook.dart';
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
 if(!started||p.length!=1||p['operation']!='read')throw ArgumentError('Expected read');
 final r=resource();await r.requireOwner();
 return observation().count('join');
}
