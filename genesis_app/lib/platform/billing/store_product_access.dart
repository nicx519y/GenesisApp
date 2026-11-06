import 'dart:async';
import 'billing_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

/// Refresh context and display revision only. No Dart product object cache.
abstract final class StoreProductAccess {
  @visibleForTesting
  static Future<void> Function()? invalidateNativeForTesting;
  static int _revision = 0;
  static int get revision => _revision;
  static final Object _freshKey = Object();
  static final Object _checkoutGuardKey = Object();
  static final Object _attemptKey = Object();
  static bool canLaunch() =>
      (Zone.current[_checkoutGuardKey] as bool Function()?)?.call() ?? true;
  static Future<T> withCheckoutGuard<T>(
    bool Function() guard,
    Future<T> Function() action, {
    String? attemptId,
  }) => runZoned(
    action,
    zoneValues: {_checkoutGuardKey: guard, _attemptKey: attemptId},
  );
  static Future<void> _resetPending = Future.value();
  static bool get forceRefresh => Zone.current[_freshKey] == true;
  static Future<T> refresh<T>(Future<T> Function() action) => runZoned(
    () => SK2Product.withFreshProducts(action),
    zoneValues: {_freshKey: true},
  );
  static Future<T> lookup<T>(String sku, Future<T> Function() action) =>
      action();

  static Future<void> ready() => _resetPending;

  static void reset() {
    _revision++;
    _resetPending = _resetPending.catchError((Object _) {}).then((_) async {
      try {
        if (invalidateNativeForTesting != null) {
          await invalidateNativeForTesting!();
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          await InAppPurchase.instance
              .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
              .invalidateProductDetails();
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          await SK2Product.invalidateProducts();
        }
      } on MissingPluginException {
        // Unit/widget tests without native plugins; real devices register both APIs.
      }
    });
    // Keep reset ordered with lookups and expose failures to the next lookup.
    unawaited(_resetPending.catchError((Object _) {}));
  }

  static Future<bool> retryUnavailable({
    required Future<bool> Function() purchase,
    required Future<void> Function() refresh,
    required bool Function() canContinue,
  }) async {
    return StoreProductRecovery(
      canContinue: canContinue,
    ).run(action: purchase, refresh: refresh);
  }

  static Future<bool> launch(Future<bool> Function() action) async {
    await ready();
    try {
      return await action();
    } on PlatformException catch (error) {
      if (const {
        'NOT_FOUND',
        'product_not_found',
        'product_details_changed',
        'INVALID_OFFER_TOKEN',
        'storekit2_failed_to_fetch_product',
        'product_cache_refresh_failed',
        'product_query_invalidated',
      }.contains(error.code)) {
        reset();
      }
      rethrow;
    }
  }
}

/// One catalog recovery shared by preparation and launch for a single click.
class StoreProductRecovery {
  StoreProductRecovery({required this.canContinue});
  final bool Function() canContinue;
  bool _used = false;
  bool get used => _used;

  static bool isUnavailable(Object error) {
    final code = switch (error) {
      PlatformException(:final code) => code,
      BillingPlatformException(:final code) => code,
      IAPError(:final code) => code,
      _ => '',
    };
    return const {
      'NOT_FOUND',
      'product_not_found',
      'membership_product_not_found',
      'product_details_changed',
      'INVALID_OFFER_TOKEN',
      'storekit2_failed_to_fetch_product',
      'itemUnavailable',
      'purchase_itemUnavailable',
    }.contains(code);
  }

  Future<T> run<T>({
    required Future<T> Function() action,
    required Future<void> Function() refresh,
  }) async {
    try {
      return await action();
    } catch (error) {
      if (_used || !isUnavailable(error) || !canContinue()) rethrow;
      _used = true;
      await refresh();
      if (!canContinue()) {
        throw const BillingPlatformException('checkout_aborted');
      }
      return action();
    }
  }
}
