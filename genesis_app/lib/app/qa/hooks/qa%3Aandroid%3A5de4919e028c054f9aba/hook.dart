import '../qa%253Aandroid%253A538adf49de88c951fcbe/resource.dart';
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
  if(p.length!=1||p['operation']!='restore'||prepared) throw ArgumentError('Parameterless Case restore required');
  return resource().restore();
}
