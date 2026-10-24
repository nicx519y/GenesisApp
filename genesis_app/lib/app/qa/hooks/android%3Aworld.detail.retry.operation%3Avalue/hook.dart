import '../android%253Aworld.retry.preparation%253Avalue/lease.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1 || p['operation'] != 'interact')
    throw ArgumentError('Expected interact');
  final lease = requireWorldLease();
  await lease.sameOwner();
  final world = worldElement();
  final action = world == null ? null : actionForText('Retry', world);
  if (action == null) throw StateError('Retry is not actionable');
  final before = lease.detailRequests;
  action();
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (lease.detailRequests <= before && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return {
    'retryClicked': true,
    'requestCompleted': lease.detailRequests > before,
    'responseSucceeded': lease.successfulResponses > 0,
    'responseMatchesPreparedWorld':
        lease.detailRequests > before && lease.successfulResponses > 0,
    'worldId': lease.worldId,
    'detailRequests': lease.detailRequests,
  };
}
