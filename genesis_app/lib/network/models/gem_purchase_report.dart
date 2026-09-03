import '../json_utils.dart';
import '../../utils/gem_amount.dart';

class GemPurchaseReportRequest {
  const GemPurchaseReportRequest({
    required this.provider,
    required this.productId,
    required this.storeProductId,
    this.environment = 'unknown',
    this.transactionId,
    this.originalTransactionId,
    this.purchaseToken,
    this.requestId,
    this.payload = const <String, Object?>{},
  });

  final String provider;
  final String productId;
  final String storeProductId;
  final String environment;
  final String? transactionId;
  final String? originalTransactionId;
  final String? purchaseToken;
  final String? requestId;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'provider': provider,
      'environment': environment,
      'product_id': productId,
      'store_product_id': storeProductId,
      if ((transactionId ?? '').trim().isNotEmpty)
        'transaction_id': transactionId,
      if ((originalTransactionId ?? '').trim().isNotEmpty)
        'original_transaction_id': originalTransactionId,
      if ((purchaseToken ?? '').trim().isNotEmpty)
        'purchase_token': purchaseToken,
      if ((requestId ?? '').trim().isNotEmpty) 'request_id': requestId,
      if (payload.isNotEmpty) 'payload': payload,
    };
  }
}

enum GemPurchaseReportStatus { completed, accepted, rejected }

class GemPurchaseReport {
  const GemPurchaseReport({
    required this.status,
    this.grantedGemsCent,
    this.transactionId = '',
    this.reason = '',
  });

  factory GemPurchaseReport.fromJson(Map<String, dynamic> json) {
    final value = asString(json['status']).trim().toLowerCase();
    final status = switch (value) {
      'completed' => GemPurchaseReportStatus.completed,
      'accepted' => GemPurchaseReportStatus.accepted,
      'rejected' => GemPurchaseReportStatus.rejected,
      _ => throw FormatException('Unsupported purchase report status: $value'),
    };
    final grantedGemsCent = status == GemPurchaseReportStatus.completed
        ? requireGemCent(
            json['granted_gems_cent'],
            fieldName: 'granted_gems_cent',
          )
        : null;
    return GemPurchaseReport(
      status: status,
      grantedGemsCent: grantedGemsCent,
      transactionId: asString(json['transaction_id']).trim(),
      reason: asString(json['reason']).trim(),
    );
  }

  final GemPurchaseReportStatus status;
  final int? grantedGemsCent;
  final String transactionId;
  final String reason;
}
