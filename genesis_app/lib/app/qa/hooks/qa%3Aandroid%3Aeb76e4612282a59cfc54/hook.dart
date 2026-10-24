import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253A1cd4ae5d9b2c78255d2b/hook.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'restore');
  return fault().release();
}
