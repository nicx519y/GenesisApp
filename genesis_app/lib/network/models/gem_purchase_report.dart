import '../json_utils.dart';

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

class GemPurchaseReport {
  const GemPurchaseReport({
    required this.reportId,
    required this.orderId,
    required this.reportStatus,
    required this.orderStatus,
    required this.granted,
    required this.grantedGems,
    required this.walletBalance,
  });

  factory GemPurchaseReport.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] is Map
        ? asJsonMap(json['wallet'])
        : const <String, dynamic>{};
    return GemPurchaseReport(
      reportId: asString(json['report_id']),
      orderId: asString(json['order_id']),
      reportStatus: asString(json['report_status']),
      orderStatus: asString(json['order_status']),
      granted: asBool(json['granted']),
      grantedGems: asInt(json['granted_gems']),
      walletBalance: asInt(wallet['balance']),
    );
  }

  final String reportId;
  final String orderId;
  final String reportStatus;
  final String orderStatus;
  final bool granted;
  final int grantedGems;
  final int walletBalance;

  bool get isGranted => granted && orderStatus == 'granted';
}
