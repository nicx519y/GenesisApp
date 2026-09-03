import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/gem_purchase_report.dart';

void main() {
  for (final status in GemPurchaseReportStatus.values) {
    test('parses ${status.name} as a terminal report status', () {
      final report = GemPurchaseReport.fromJson(<String, dynamic>{
        'status': status.name,
        if (status == GemPurchaseReportStatus.completed)
          'granted_gems_cent': 55000,
        'transaction_id': 'GPA.1234-5678',
        'reason': 'account_mismatch',
      });

      expect(report.status, status);
      expect(
        report.grantedGemsCent,
        status == GemPurchaseReportStatus.completed ? 55000 : isNull,
      );
      expect(report.transactionId, 'GPA.1234-5678');
      expect(report.reason, 'account_mismatch');
    });
  }

  test('completed requires an integer granted_gems_cent', () {
    for (final value in <Object?>[null, 550.0, '55000']) {
      expect(
        () => GemPurchaseReport.fromJson(<String, dynamic>{
          'status': 'completed',
          if (value != null) 'granted_gems_cent': value,
        }),
        throwsFormatException,
      );
    }
  });

  test('rejects an unsupported report status', () {
    expect(
      () => GemPurchaseReport.fromJson(const <String, dynamic>{
        'status': 'processing',
      }),
      throwsFormatException,
    );
  });
}
