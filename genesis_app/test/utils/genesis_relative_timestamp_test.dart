import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/genesis_timestamp_formatter.dart';

void main() {
  final now = DateTime(2026, 8, 22, 12, 0);

  String at(DateTime t) => formatGenesisRelativeTimestamp(t, now: now);

  test('under a minute reads as now', () {
    expect(at(now), 'now');
    expect(at(now.subtract(const Duration(seconds: 40))), 'now');
  });

  test('minutes and hours inside the day', () {
    expect(at(now.subtract(const Duration(minutes: 4))), '4m');
    expect(at(now.subtract(const Duration(minutes: 59))), '59m');
    expect(at(now.subtract(const Duration(hours: 2))), '2h');
    expect(at(now.subtract(const Duration(hours: 23))), '23h');
  });

  test('days up to a week', () {
    expect(at(now.subtract(const Duration(days: 1))), '1d');
    expect(at(now.subtract(const Duration(days: 3))), '3d');
    expect(at(now.subtract(const Duration(days: 6))), '6d');
  });

  test('a week or more falls back to a short date', () {
    expect(at(DateTime(2026, 7, 20, 9, 0)), 'Jul 20');
    expect(at(DateTime(2025, 7, 20, 9, 0)), 'Jul 20, 2025');
  });

  test('missing or unparseable input returns the fallback', () {
    expect(formatGenesisRelativeTimestamp(null, now: now), '');
    expect(
      formatGenesisRelativeTimestamp('', fallback: '-', now: now),
      '-',
    );
  });

  test('a future timestamp does not read as a negative age', () {
    expect(at(now.add(const Duration(hours: 3))), 'now');
  });
}
