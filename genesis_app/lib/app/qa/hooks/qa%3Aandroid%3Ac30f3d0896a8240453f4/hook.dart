import '../qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';
import '../qa%253Aandroid%253A88f61b36d73b39e019fe/view.dart';
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
 if(!started||p.length!=1||p['operation']!='read')throw ArgumentError('Expected read');
 final r=resource();await r.requireOwner();
 return parentPanel()!=null;
}
