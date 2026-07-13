import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/gem_purchase_report.dart';

void main() {
  for (final status in GemPurchaseReportStatus.values) {
    test('parses ${status.name} as a terminal report status', () {
      final report = GemPurchaseReport.fromJson(<String, dynamic>{
        'status': status.name,
      });

      expect(report.status, status);
    });
  }

  test('rejects an unsupported report status', () {
    expect(
      () => GemPurchaseReport.fromJson(const <String, dynamic>{
        'status': 'processing',
      }),
      throwsFormatException,
    );
  });
}
