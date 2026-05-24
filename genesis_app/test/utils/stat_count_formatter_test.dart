import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/stat_count_formatter.dart';

void main() {
  test('formatStatCount applies K M B and T suffixes', () {
    expect(formatStatCount(999), '999');
    expect(formatStatCount(1000), '1K');
    expect(formatStatCount(2300), '2.3K');
    expect(formatStatCount(4400000), '4.4M');
    expect(formatStatCount(2500000000), '2.5B');
    expect(formatStatCount(7300000000000), '7.3T');
  });
}
