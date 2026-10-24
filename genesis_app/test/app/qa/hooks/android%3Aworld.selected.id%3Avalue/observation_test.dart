import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.selected.id%253Avalue/observation.dart';

void main() {
  test(
    'extracts real field and preserves missing or invalid negative observations',
    () {
      expect(
        extractObservation({
          'info': {'world_id': 'sample'},
        }),
        'sample',
      );
      expect(
        extractObservation({
          'info': {'world_id': ''},
        }),
        '',
      );
      expect(extractObservation({}), isNull);
    },
  );
}
