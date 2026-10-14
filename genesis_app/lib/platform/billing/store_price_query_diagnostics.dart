import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Last raw product-query responses in this process. Diagnostic only: no
/// transactions, account identifiers, or purchase actions are stored here.
final storePriceQueryDiagnostics = StorePriceQueryDiagnostics();

@immutable
class RawStoreProductPrice {
  const RawStoreProductPrice({
    required this.id,
    required this.rawPrice,
    required this.currencyCode,
    required this.formattedPrice,
    required this.currencySymbol,
    this.sdkFields = const {},
  });

  final String id;
  final double rawPrice;
  final String currencyCode;
  final String formattedPrice;
  final String currencySymbol;
  final Map<String, Object?> sdkFields;
}

@immutable
class StorePriceQueryCapture {
  const StorePriceQueryCapture({
    required this.group,
    required this.queriedAt,
    required this.requestedIds,
    required this.returned,
    required this.notFoundIds,
    required this.status,
  });

  final String group;
  final DateTime queriedAt;
  final List<String> requestedIds;
  final List<RawStoreProductPrice> returned;
  final List<String> notFoundIds;
  final String status;
}

class StorePriceQueryDiagnostics extends ChangeNotifier {
  final Map<String, StorePriceQueryCapture> _captures = {};

  List<StorePriceQueryCapture> get captures => List.unmodifiable(
    _captures.values.toList()
      ..sort((a, b) => b.queriedAt.compareTo(a.queriedAt)),
  );

  void recordResponse({
    required String group,
    required Set<String> requestedIds,
    required ProductDetailsResponse response,
  }) {
    _record(
      group: group,
      requestedIds: requestedIds,
      returned: [
        for (final product in response.productDetails)
          RawStoreProductPrice(
            id: product.id,
            rawPrice: product.rawPrice,
            currencyCode: product.currencyCode,
            formattedPrice: product.price,
            currencySymbol: product.currencySymbol,
            sdkFields: _sdkFields(product),
          ),
      ],
      notFoundIds: response.notFoundIDs,
      status: response.error == null
          ? 'ok'
          : 'error source=${response.error!.source} code=${response.error!.code}',
    );
  }

  void recordUnavailable({
    required String group,
    required Set<String> requestedIds,
    required String status,
  }) => _record(
    group: group,
    requestedIds: requestedIds,
    returned: const [],
    notFoundIds: const [],
    status: status,
  );

  void _record({
    required String group,
    required Set<String> requestedIds,
    required List<RawStoreProductPrice> returned,
    required List<String> notFoundIds,
    required String status,
  }) {
    final ids = requestedIds.toList()..sort();
    _captures['$group|${ids.join(',')}'] = StorePriceQueryCapture(
      group: group,
      queriedAt: DateTime.now().toUtc(),
      requestedIds: List.unmodifiable(ids),
      returned: List.unmodifiable(returned),
      notFoundIds: List.unmodifiable(notFoundIds),
      status: status,
    );
    notifyListeners();
  }

  void clear() {
    _captures.clear();
    notifyListeners();
  }

  Map<String, Object?> _sdkFields(ProductDetails product) {
    final fields = <String, Object?>{
      'sdkType': product.runtimeType.toString(),
      'id': product.id,
      'title': product.title,
      'description': product.description,
      'price': product.price,
      'rawPrice': product.rawPrice,
      'currencyCode': product.currencyCode,
      'currencySymbol': product.currencySymbol,
    };
    if (product is AppStoreProduct2Details) {
      final native = product.sk2Product;
      final subscription = native.subscription;
      fields['StoreKit2'] = {
        'id': native.id,
        'displayName': native.displayName,
        'description': native.description,
        'price': native.price,
        'displayPrice': native.displayPrice,
        'type': native.type.name,
        'priceLocale': {
          'currencyCode': native.priceLocale.currencyCode,
          'currencySymbol': native.priceLocale.currencySymbol,
        },
        'subscription': subscription == null
            ? null
            : {
                'subscriptionGroupID': subscription.subscriptionGroupID,
                'subscriptionPeriod': {
                  'value': subscription.subscriptionPeriod.value,
                  'unit': subscription.subscriptionPeriod.unit.name,
                },
                'promotionalOffers': [
                  for (final offer in subscription.promotionalOffers)
                    {
                      'id': offer.id,
                      'price': offer.price,
                      'type': offer.type.name,
                      'periodCount': offer.periodCount,
                      'paymentMode': offer.paymentMode.name,
                      'period': {
                        'value': offer.period.value,
                        'unit': offer.period.unit.name,
                      },
                    },
                ],
              },
      };
    }
    return Map.unmodifiable(fields);
  }
}
