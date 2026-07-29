import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/gem_purchase_report.dart';

void main() {
  for (final status in GemPurchaseReportStatus.values) {
    test('parses ${status.name} as a terminal report status', () {
      final report = GemPurchaseReport.fromJson(<String, dynamic>{
        'status': status.name,
        'granted_gems': 550,
        'transaction_id': 'GPA.1234-5678',
        'reason': 'account_mismatch',
      });

      expect(report.status, status);
      expect(report.grantedGems, 550);
      expect(report.transactionId, 'GPA.1234-5678');
      expect(report.reason, 'account_mismatch');
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
