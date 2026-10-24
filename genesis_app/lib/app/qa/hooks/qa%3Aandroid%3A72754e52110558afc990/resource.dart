import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import '../../qa_bridge.dart';

/// Owns only this field's snapshot, on the already acquired dataset resource.
class WorldProgression {
  WorldProgression(this.dataset);
  final WorldDataset dataset;
  static const fields = <(String, List<String>)>[
    ('detail', <String>["info", "status"]),
    ('info', <String>["info", "status"])
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
    if (values.any((value) => value is! num)) throw StateError('Invalid progression response');
    if (values[0] != values[1]) throw StateError('World status endpoints disagree');
    return {'advancing': values[0] == 20, 'status': values[0], 'resource': dataset.resource};
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
    await write([10, 10]);
    return read();
  }
  Future<JsonMap> restore() async {
    await dataset.requireOwner();
    final before = _snapshot;
    if (before == null) throw StateError('No progression snapshot was acquired');
    // Dataset restoration can precede membership restoration in the Case.
    // Once it is released, observe the underlying source, never reacquire it.
    if (dataset.active && !_restored) await write(before);
    final matches = const DeepCollectionEqualityForWorld().equal(await values(), before);
    if (!matches) throw StateError('progression restoration mismatch');
    _restored = true;
    return {'restored': _restored, 'matchesSnapshot': matches, 'resource': dataset.resource};
  }
  Future<JsonMap> negative() async {
    if (_snapshot == null || _restored) throw StateError('Prepared progression required');
    await write([20, 20]);
    return read();
  }
}
final _resources = Expando<WorldProgression>();
Future<WorldProgression> resource({bool acquire = false}) async {
  final dataset = await worldDatasetResource();
  if (dataset.selectedId == null) throw StateError('No selected world');
  final existing = _resources[dataset];
  if (existing != null) return existing;
  if (!acquire) throw StateError('No progression snapshot was acquired');
  return _resources[dataset] = WorldProgression(dataset);
}
Future<Object?> invoke(Map<String, dynamic> p, bool prepared, bool started) async {
  if (!started || p.length != 1) throw ArgumentError('Started parameterless operation required');
  final operation = p['operation'];
  if (operation == 'read') return WorldProgression(await worldDatasetResource()).read();
  if (prepared) throw StateError('Case preparation cannot use a contract session');
  return switch (operation) {
    'prepare' => (await resource(acquire: true)).prepare(),
    'restore' || 'cleanup' => (await resource()).restore(),
    _ => throw ArgumentError('Unsupported progression operation'),
  };
}
Future<Object?> contract(Map<String, dynamic> p, bool prepared, bool started) async {
  if (!prepared || !started || p.length != 1) throw StateError('Started isolated contract required');
  return switch (p['operation']) {
    'prepare' => (await resource(acquire: true)).prepare(),
    'read' => WorldProgression(await worldDatasetResource()).read(),
    'negative' => (await resource()).negative(),
    'restore' => (await resource()).restore(),
    _ => throw ArgumentError('Unsupported contract operation'),
  };
}
