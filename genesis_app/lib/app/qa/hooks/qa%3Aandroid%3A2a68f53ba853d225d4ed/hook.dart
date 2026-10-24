import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import '../qa%253Aandroid%253Ae467a08aa46c19c80bd9/observation.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  await resource().requireOwner();
  return resource().route?.isActive == true &&
      progressWaitVisible(worldElement());
}
