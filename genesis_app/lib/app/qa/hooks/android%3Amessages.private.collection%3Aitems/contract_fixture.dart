import 'runtime.dart';

/// Contract-only probe of the original endpoint, independent of the cache read.
Future<Object?> collectionSource(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared ||
      !started ||
      p.keys.any((key) => key != 'seed') ||
      (p.containsKey('seed') && p['seed'] != true))
    throw StateError('Prepared started contract required');
  if (p['seed'] == true)
    await actualServices().directMessageConversations.syncConversations();
  final data = await actualServices().api.v1.dm.conversations(pn: 1, rn: 100);
  final items = data['list'];
  if (items is! List)
    throw StateError('Missing actual conversation source list');
  return items;
}
