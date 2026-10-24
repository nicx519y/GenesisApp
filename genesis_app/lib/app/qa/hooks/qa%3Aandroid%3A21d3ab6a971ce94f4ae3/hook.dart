import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import '../qa%253Aandroid%253A049d4a0c0bcd1b89f6c0/hook.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  await resource().requireOwner();
  return canTouch();
}
