import '../qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart' show selectedWorld;
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
 if(!started||p.length!=1||p['operation']!='read')throw ArgumentError('Expected read');
 final r=resource();await r.requireOwner();
 return {'atPreparedWorld':selectedWorld(r.worldId)!=null&&r.route?.isCurrent==true,'chatConnectionAvailable':r.peer?.connected==true&&r.peer!.errors.isEmpty};
}
