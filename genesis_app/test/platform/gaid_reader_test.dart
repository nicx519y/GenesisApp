import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/device/gaid_reader.dart';

void main() {
  test('Adjust takes priority without reading system API', () async {
    final result = await readGaid(
      adjustReader: () async => ' adjust-id ',
      systemReader: () async => throw StateError('must not be called'),
    );
    expect(result.id, 'adjust-id');
    expect(result.source, 'adjust');
  });

  for (final value in [null, '', '00000000-0000-0000-0000-000000000000']) {
    test('invalid Adjust value $value falls back to system', () async {
      final result = await readGaid(
        adjustReader: () async => value,
        systemReader: () async => ' system-id ',
      );
      expect(result.id, 'system-id');
      expect(result.source, 'system_api');
    });
  }

  test(
    'Adjust exception falls back and invalid system value has no source',
    () async {
      final result = await readGaid(
        adjustReader: () async => throw StateError('unavailable'),
        systemReader: () async => '00000000-0000-0000-0000-000000000000',
      );
      expect(result.id, isEmpty);
      expect(result.source, isNull);
    },
  );
}
