import 'package:genesis_flutter_android/app/telemetry/purchase_event_reporting.dart';

class RecordedPurchaseEvent {
  const RecordedPurchaseEvent({
    required this.provider,
    required this.productId,
    required this.kind,
    required this.purchaseIdentity,
    required this.transactionIdentity,
    required this.priceAmountMicros,
    required this.priceCurrencyCode,
  });

  final String provider;
  final String productId;
  final PurchaseEventKind kind;
  final String purchaseIdentity;
  final String? transactionIdentity;
  final int? priceAmountMicros;
  final String priceCurrencyCode;
}

class RecordingPurchaseEventRecorder implements PurchaseEventRecorder {
  final calls = <RecordedPurchaseEvent>[];

  @override
  Future<void> recordPurchase({
    required String provider,
    required String productId,
    required PurchaseEventKind kind,
    required String purchaseIdentity,
    String? transactionIdentity,
    int? priceAmountMicros,
    String priceCurrencyCode = '',
  }) async {
    calls.add(
      RecordedPurchaseEvent(
        provider: provider,
        productId: productId,
        kind: kind,
        purchaseIdentity: purchaseIdentity,
        transactionIdentity: transactionIdentity,
        priceAmountMicros: priceAmountMicros,
        priceCurrencyCode: priceCurrencyCode,
      ),
    );
  }
}
