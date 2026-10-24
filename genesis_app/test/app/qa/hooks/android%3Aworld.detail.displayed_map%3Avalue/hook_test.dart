import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.detail.displayed_map%253Avalue/hook.dart';

void main() {
  test('matches the map URL with absent, empty and resize query', () {
    const map = 'http://127.0.0.1:33587/map.png';
    // This is the failed comparison: an empty query serializes with a '?'.
    expect(Uri.parse(map).replace(query: '').toString(), '$map?');
    for (final actual in [map, '$map?', '$map?x-oss-process=image/resize,w_720']) {
      expect(sameMapImageUrl(actual, map), isTrue);
      expect(sameMapImageUrl(map, actual), isTrue);
    }
  });
  test('rejects foreign ports, paths, identities and missing map URLs', () {
    const map = 'http://127.0.0.1:33587/map.png';
    for (final actual in [
      '',
      'http://127.0.0.1:33588/map.png',
      'http://127.0.0.1:33587/other.png',
      'https://127.0.0.1:33587/map.png',
      '$map?resource=foreign',
    ]) {
      expect(sameMapImageUrl(actual, map), isFalse);
    }
    expect(sameMapImageUrl('', ''), isFalse);
  });
  test('rejects undeclared operation before accessing App state', () async {
    await expectLater(
      invoke({'operation': 'unknown'}, false, true),
      throwsArgumentError,
    );
  });
  test(
    'rejects missing preparation instead of manufacturing an observation',
    () async {
      await expectLater(
        invoke({'operation': 'read'}, false, true),
        throwsStateError,
      );
    },
  );
}
