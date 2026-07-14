import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/gems/gem_records_page.dart';

void main() {
  test('formats today record time', () {
    expect(
      formatGemRecordTimestamp(
        _epochSeconds(DateTime(2026, 6, 30, 9, 2)),
        now: DateTime(2026, 6, 30, 18),
      ),
      'Today 09:02',
    );
  });

  test('formats yesterday record time', () {
    expect(
      formatGemRecordTimestamp(
        _epochSeconds(DateTime(2026, 6, 29, 19, 20)),
        now: DateTime(2026, 6, 30, 8),
      ),
      'Yesterday 19:20',
    );
  });

  test('formats older record date', () {
    expect(
      formatGemRecordTimestamp(
        _epochSeconds(DateTime(2026, 6, 30, 9, 2)),
        now: DateTime(2026, 7, 2),
      ),
      'Jun 30, 2026',
    );
  });
}

int _epochSeconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;
