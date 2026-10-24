import '../android%253Aworld.retry.preparation%253Avalue/lease.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validateRead(p, started);
  final lease = requireWorldLease();
  await lease.sameOwner();
  final world = worldElement();
  final found = world != null && textElements(lease.name, world).isNotEmpty;
  return {
    'visible': found,
    'worldIdMatchesPreparedWorld': world != null,
    'nameMatchesPreparedWorld': found,
    'worldId': world == null ? null : lease.worldId,
  };
}
