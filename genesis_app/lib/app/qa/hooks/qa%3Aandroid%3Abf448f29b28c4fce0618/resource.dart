import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import '../../qa_bridge.dart';

/// Owns only this field's snapshot, on the already acquired dataset resource.
class WorldMembership {
  WorldMembership(this.dataset);
  final WorldDataset dataset;
  static const fields = <(String, List<String>)>[
    ('detail', <String>["relation_status"])
  ];
  List<Object?>? _snapshot;
  bool _restored = false;
  Future<List<Object?>> values() async {
    await dataset.requireOwner();
    final result = <Object?>[];
    for (final field in fields) {
      Object? value = await dataset.fetch(field.$1, dataset.selectedId!);
      for (final key in field.$2) {
        if (value is! Map || !value.containsKey(key)) throw StateError('Missing world resource field');
        value = value[key];
      }
      if (value is Map || value is List) throw StateError('Expected scalar world field');
      result.add(value);
    }
    return result;
  }
  Future<JsonMap> read() async {
    final values = await this.values();
    final relation = values[0];
    if (relation is! String) throw StateError('Invalid membership response');
    return {'joined': relation == 'joined' || relation == 'owner', 'relationStatus': relation, 'resource': dataset.resource};
  }
  Future<void> write(List<Object?> values) async {
    for (var i = 0; i < fields.length; i++) {
      await dataset.replace(fields[i].$1, fields[i].$2, values[i]);
    }
  }
  Future<JsonMap> prepare() async {
    await dataset.requireOwner();
    if (!dataset.active || _restored) throw StateError('Active, unrestored world resource required');
    // Validate before acquiring, and preserve the first snapshot on repeated preparation.
    await read();
    _snapshot ??= await values();
    await write(["joined"]);
    return read();
  }
  Future<JsonMap> restore() async {
    await dataset.requireOwner();
    final before = _snapshot;
    if (before == null) throw StateError('No membership snapshot was acquired');
    // Dataset restoration can precede membership restoration in the Case.
    // Once it is released, observe the underlying source, never reacquire it.
    if (dataset.active && !_restored) await write(before);
    final matches = const DeepCollectionEqualityForWorld().equal(await values(), before);
    if (!matches) throw StateError('membership restoration mismatch');
    _restored = true;
    return {'restored': _restored, 'matchesSnapshot': matches, 'resource': dataset.resource};
  }
  Future<JsonMap> negative() async {
    if (_snapshot == null || _restored) throw StateError('Prepared membership required');
    await write(["none"]);
    return read();
  }
}
final _resources = Expando<WorldMembership>();
Future<WorldMembership> resource({bool acquire = false}) async {
  final dataset = await worldDatasetResource();
  if (dataset.selectedId == null) throw StateError('No selected world');
  final existing = _resources[dataset];
  if (existing != null) return existing;
  if (!acquire) throw StateError('No membership snapshot was acquired');
  return _resources[dataset] = WorldMembership(dataset);
}
Future<Object?> invoke(Map<String, dynamic> p, bool prepared, bool started) async {
  if (!started || p.length != 1) throw ArgumentError('Started parameterless operation required');
  final operation = p['operation'];
  if (operation == 'read') return WorldMembership(await worldDatasetResource()).read();
  if (prepared) throw StateError('Case preparation cannot use a contract session');
  return switch (operation) {
    'prepare' => (await resource(acquire: true)).prepare(),
    'restore' || 'cleanup' => (await resource()).restore(),
    _ => throw ArgumentError('Unsupported membership operation'),
  };
}
Future<Object?> contract(Map<String, dynamic> p, bool prepared, bool started) async {
  if (!prepared || !started || p.length != 1) throw StateError('Started isolated contract required');
  return switch (p['operation']) {
    'prepare' => (await resource(acquire: true)).prepare(),
    'read' => WorldMembership(await worldDatasetResource()).read(),
    'negative' => (await resource()).negative(),
    'restore' => (await resource()).restore(),
    _ => throw ArgumentError('Unsupported contract operation'),
  };
}
