import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.selected.name%253Atext/observation.dart';

void main() {
  test(
    'extracts real field and preserves missing or invalid negative observations',
    () {
      expect(
        extractObservation({
          'info': {'world_name': 'sample'},
        }),
        'sample',
      );
      expect(
        extractObservation({
          'info': {'world_name': ''},
        }),
        '',
      );
      expect(extractObservation({}), isNull);
    },
  );
}
