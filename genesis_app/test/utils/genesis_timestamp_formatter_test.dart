import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/genesis_timestamp_formatter.dart';

void main() {
  test('formats same-day timestamps as HH:mm', () {
    expect(
      formatGenesisDateTime(
        DateTime(2026, 6, 1, 17, 30),
        now: DateTime(2026, 6, 1, 20),
      ),
      '17:30',
    );
  });

  test('formats same-year non-today timestamps as M-D HH:mm', () {
    expect(
      formatGenesisDateTime(
        DateTime(2026, 6, 1, 5, 30),
        now: DateTime(2026, 6, 2),
      ),
      '6-1 05:30',
    );
  });

  test('formats cross-year timestamps as YYYY-M-D', () {
    expect(
      formatGenesisDateTime(
        DateTime(2025, 2, 28, 5, 30),
        now: DateTime(2026, 6, 1),
      ),
      '2025-2-28',
    );
  });

  test('parses seconds and milliseconds timestamps with the same rules', () {
    final value = DateTime(2026, 6, 1, 17, 30);
    expect(
      formatGenesisTimestamp(
        value.millisecondsSinceEpoch ~/ 1000,
        now: DateTime(2026, 6, 1, 20),
      ),
      '17:30',
    );
    expect(
      formatGenesisTimestamp(
        value.millisecondsSinceEpoch,
        now: DateTime(2026, 6, 2),
      ),
      '6-1 17:30',
    );
  });
}
