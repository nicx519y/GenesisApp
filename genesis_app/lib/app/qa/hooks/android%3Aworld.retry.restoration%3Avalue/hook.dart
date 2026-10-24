import '../android%253Aworld.retry.preparation%253Avalue/lease.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (p.length != 1 || p['operation'] != 'restore')
    throw ArgumentError('Expected restore');
  return requireWorldLease().restore();
}
