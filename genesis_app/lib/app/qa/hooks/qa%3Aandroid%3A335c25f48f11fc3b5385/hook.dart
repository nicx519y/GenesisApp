import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ae902ad40417a12b1d8e2/hook.dart' show success;
import '../qa%253Aandroid%253A293292093e027b74e41e/hook.dart' show observe;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final s = success();
  await s.owner.requireOwner();
  return s.newRound > 0 && observe(worldElement(), s.newTime);
}
