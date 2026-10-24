import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';
import '../qa%253Aandroid%253A9ad73fa4984b5264a357/hook.dart' as origin;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  return origin.atOrigin(await selection());
}
