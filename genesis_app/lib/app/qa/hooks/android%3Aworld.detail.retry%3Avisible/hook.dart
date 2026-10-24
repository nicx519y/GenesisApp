import '../android%253Aworld.retry.preparation%253Avalue/lease.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validateRead(p, started);
  await requireWorldLease().sameOwner();
  final world = worldElement();
  return world != null && textElements('Retry', world).isNotEmpty;
}
