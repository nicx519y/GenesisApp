import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import '../qa%253Aandroid%253A5b3990fd6789b5efbe42/hook.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  await resource().requireOwner();
  return displayedWorld().tickCount - baseline().round;
}
