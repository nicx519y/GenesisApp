import '../../../network/models/world_history.dart';

/// A page keeps these tiny summaries after its message bodies are evicted.
/// Newest-first order means users encountered before a Tick belong to it.
typedef HistoryTickActivity = ({String? tickId, Set<String> locations});

List<HistoryTickActivity> summarizeHistoryTickActivity(
  Iterable<WorldHistoryMessage> newestFirst,
) {
  final result = <HistoryTickActivity>[];
  var locations = <String>{};
  for (final message in newestFirst) {
    if (message.type == 'tick') {
      result.add((tickId: message.id, locations: Set.unmodifiable(locations)));
      locations = <String>{};
    } else if (message.type == 'user') {
      locations.addAll(message.locationRefs.where((id) => id.isNotEmpty));
    }
  }
  result.add((tickId: null, locations: Set.unmodifiable(locations)));
  return List.unmodifiable(result);
}

Map<String, Set<String>> historyTickUserLocations(
  Iterable<HistoryTickActivity> activities,
) {
  final result = <String, Set<String>>{};
  final pending = <String>{};
  for (final activity in activities) {
    pending.addAll(activity.locations);
    final tickId = activity.tickId;
    if (tickId == null) continue;
    result[tickId] = Set.unmodifiable({...?result[tickId], ...pending});
    pending.clear();
  }
  return Map.unmodifiable(result);
}
