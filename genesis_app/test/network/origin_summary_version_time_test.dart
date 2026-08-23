import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';

void main() {
  test('9k version line keeps its timestamp from origin_version_time', () {
    final item = OriginSummary.fromJson(const <String, dynamic>{
      'oid': 'o_7F2KQ9',
      'version_num': 1,
      'origin_version_time': '2026-07-02T21:40:00Z',
    });

    expect(item.updatedAt, isNotNull);
    expect(item.updatedAt!.toUtc(), DateTime.utc(2026, 7, 2, 21, 40));
  });

  test('updated_at still wins when the payload carries both', () {
    final item = OriginSummary.fromJson(const <String, dynamic>{
      'oid': 'o_7F2KQ9',
      'updated_at': '2026-08-13T08:15:00Z',
      'origin_version_time': '2026-07-02T21:40:00Z',
    });

    expect(item.updatedAt!.toUtc(), DateTime.utc(2026, 8, 13, 8, 15));
  });

  test('a payload with neither field leaves the timestamp empty', () {
    final item = OriginSummary.fromJson(const <String, dynamic>{'oid': 'o_x'});
    expect(item.updatedAt, isNull);
  });
}
