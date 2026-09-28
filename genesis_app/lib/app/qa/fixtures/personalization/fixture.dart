import 'dart:convert';
import '../../../../network/mock_data/mock_personalization_profile.dart';

/// One authenticated Case run owns a snapshot; no identity mutation or UI actions.
class PersonalizationFixture {
  PersonalizationFixture({
    required this.identity,
    required this.owner,
    required this.snapshot,
    required this.write,
    required this.observed,
  });
  final Future<String?> Function() identity;
  final Future<String> Function() owner;
  final Map<String, Object?>? Function(String) snapshot;
  final void Function(String, Map<String, Object?>?) write;
  final Map<String, Object?> Function() observed;
  String? _run, _owner, _identity, _config;
  Map<String, Object?>? _before;
  Map<String, dynamic>? _request;
  bool _restored = false;
  Future<void> _same() async {
    if (_identity != await identity() || _owner != await owner()) {
      throw StateError('Fixture identity changed; refusing another owner');
    }
  }

  Future<Object?> call(
    String operation,
    Map<String, dynamic> p,
    bool started,
  ) async {
    final run = p['runId'];
    if (run is! String || run.isEmpty || run.length > 160) {
      throw ArgumentError('Missing fixture run identity');
    }
    if (operation == 'prepare') {
      if (p['version'] != 1 ||
          !const ['completed', 'first_run', 'preserve'].contains(p['mode']) ||
          p.keys.any(
            (k) => !const [
              'runId',
              'version',
              'mode',
              'gender',
              'age',
            ].contains(k),
          )) {
        throw ArgumentError('Unsupported fixture configuration');
      }
      final config = jsonEncode([
        p['version'],
        p['mode'],
        p['gender'],
        p['age'],
      ]);
      if (_run != null) {
        if (_run != run || _config != config || _restored) {
          throw StateError('Fixture run/config mismatch');
        }
        await _same();
        return _receipt();
      }
      if (started) throw StateError('Fixture must be prepared before startup');
      final gender = p['gender'], age = p['age'];
      final seeded = p['mode'] == 'completed'
          ? completedMockPersonalization(gender as String, age as String)
          : null;
      _identity = await identity();
      _owner = await owner();
      _before = snapshot(_owner!);
      _run = run;
      _config = config;
      _request = Map.of(p);
      await _same();
      if (p['mode'] != 'preserve') write(_owner!, seeded);
      return _receipt();
    }
    if (_run != run || _owner == null) {
      throw StateError('No fixture owned by this run');
    }
    await _same();
    if (operation == 'read') {
      if (_restored) throw StateError('Fixture already restored');
      return {..._receipt(), 'observed': observed()};
    }
    if (operation == 'restore') {
      if (!_restored && _request!['mode'] != 'preserve') {
        write(_owner!, _before);
      }
      final restored = jsonEncode(snapshot(_owner!)) == jsonEncode(_before);
      if (!restored) throw StateError('Fixture snapshot was not restored');
      _restored = true;
      return {
        'runId': run,
        'version': 1,
        'mode': _request!['mode'],
        'restored': true,
        'identityUnchanged': true,
      };
    }
    throw ArgumentError('Unknown fixture operation');
  }

  Map<String, Object?> _receipt() => {
    'runId': _run,
    'version': 1,
    'mode': _request!['mode'],
    'before': _before,
    'profile': snapshot(_owner!),
    'identityUnchanged': true,
  };
}
