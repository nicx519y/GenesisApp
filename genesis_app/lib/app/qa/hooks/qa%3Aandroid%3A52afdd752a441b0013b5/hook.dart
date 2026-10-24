import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import '../qa%253Aandroid%253A5b3990fd6789b5efbe42/hook.dart';
import '../qa%253Aandroid%253A1cd4ae5d9b2c78255d2b/hook.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  await resource().requireOwner();
  final f = fault();
  if (f.failure != null)
    throw StateError('Mock completion failed: ${f.failure}');
  final actual = displayedWorld();
  return {
    'completed':
        f.completed &&
        actual.tickCount == f.newRound &&
        actual.currentTime == f.newTime,
    'outcome': f.completed ? 'success' : 'pending',
    'advancedFromBaseline': actual.tickCount > baseline().round,
    'worldId': actual.worldId,
    'requestId': f.retryRequestId ?? '',
    'newRound': actual.tickCount,
  };
}
