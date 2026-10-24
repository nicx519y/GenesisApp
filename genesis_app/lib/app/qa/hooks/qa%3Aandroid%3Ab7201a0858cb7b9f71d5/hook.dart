import 'package:flutter/widgets.dart';
import '../qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';
import '../qa%253Aandroid%253A88f61b36d73b39e019fe/view.dart';
import '../qa%253Aandroid%253A049d4a0c0bcd1b89f6c0/hook.dart' show dispatchSingleTap;
import '../qa%253Aandroid%253A9a3c28dfef1b22d82b51/hook.dart' show backButton;
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
 if(!started||p.length!=1||p['operation']!='interact')throw ArgumentError('Expected interact');
 await resource().requireOwner();
 final panel=parentPanel();if(panel==null)throw StateError('Parent panel required');
 final target=backButton(panel);if(target==null)throw StateError('Parent back target absent');
 dispatchSingleTap(target);await WidgetsBinding.instance.endOfFrame;
 return {'backDispatched':parentPanel()==null};
}
