part of 'membership_purchase_service.dart';

/// A single-use, page-owned store product. Never prepares a purchase identity.
class MembershipCheckoutPreparation {
  MembershipCheckoutPreparation._(
    this._service,
    this._session,
    this._revision,
    this._onExpired,
  );
  static const _maxAge = Duration(minutes: 2);
  final MembershipPurchaseService _service;
  final int _session;
  final int _revision;
  final VoidCallback? _onExpired;
  final Stopwatch _age = Stopwatch();
  late final Future<_PreparedMembershipProduct?> _future;
  Timer? _expiry;
  bool _invalid = false;
  bool _consumed = false;

  void invalidate() {
    _invalid = true;
    _expiry?.cancel();
  }

  void _markReady() {
    if (!_usable) return;
    _age.start();
    _expiry = Timer(_maxAge, () {
      invalidate();
      _onExpired?.call();
    });
  }

  bool get _usable => !_invalid && !_consumed && _age.elapsed < _maxAge;
}

class _PreparedMembershipProduct {
  const _PreparedMembershipProduct(
    this.owner,
    this.catalog,
    this.product,
    this.nativeProduct,
  );
  final String? owner;
  final MembershipProductList catalog;
  final MembershipProduct product;
  final Object nativeProduct;
}

class _CheckoutIdentity {
  const _CheckoutIdentity(this.uuid, this.guest);
  final String uuid;
  final MembershipGuestIdentity? guest;
}

class _CheckoutPreparationFailure implements Exception {
  const _CheckoutPreparationFailure(this.stage, this.error);
  final String stage;
  final Object error;
}

extension _MembershipCheckoutPreparation on MembershipPurchaseService {
  Future<T> _timedCheckoutPreparation<T>(
    String stage,
    Future<T> Function() run,
  ) async {
    final clock = Stopwatch()..start();
    try {
      return await run();
    } catch (error) {
      throw _CheckoutPreparationFailure(stage, error);
    } finally {
      if (kDebugMode) {
        debugPrint(
          '[Membership][prepare_timing] stage=$stage elapsed_ms=${clock.elapsedMilliseconds}',
        );
      }
    }
  }

  Future<_CheckoutIdentity> _prepareCheckoutIdentity(
    String? uid,
    MembershipProductList products,
  ) async {
    final guest = uid == null
        ? products.lastAccountUuid == null
              ? await _timedCheckoutPreparation('prepare_guest', prepareGuest)
              : MembershipGuestIdentity(accountUuid: products.lastAccountUuid!)
        : null;
    final uuid =
        products.lastAccountUuid ??
        guest?.accountUuid ??
        await _timedCheckoutPreparation<String>(
          'load_account_uuid',
          loadAccountUuid,
        );
    if (!isMembershipAccountUuid(uuid)) {
      throw const _CheckoutPreparationFailure(
        'load_account_uuid',
        FormatException('Invalid membership account UUID'),
      );
    }
    return _CheckoutIdentity(uuid, guest);
  }

  Future<_PreparedMembershipProduct> _prepareStoreProduct(
    String? uid,
    MembershipProductList products,
    MembershipProduct product,
  ) async {
    final nativeProduct = await _timedCheckoutPreparation(
      'query_store_product',
      () => platform.prepare(product),
    );
    return _PreparedMembershipProduct(uid, products, product, nativeProduct);
  }

  Future<_PreparedMembershipProduct?> _takeCheckoutPreparation(
    MembershipCheckoutPreparation? preparation,
    String? uid,
    MembershipProductList products,
    MembershipProduct product,
  ) async {
    if (preparation == null ||
        !identical(preparation._service, this) ||
        !preparation._usable ||
        preparation._session != _session ||
        preparation._revision != catalogRevision.value) {
      return null;
    }
    final ready = await preparation._future;
    if (!preparation._usable ||
        preparation._session != _session ||
        preparation._revision != catalogRevision.value ||
        ready == null ||
        ready.owner != uid ||
        !identical(ready.catalog, products) ||
        ready.product.planCode != product.planCode ||
        ready.product.storeProductId != product.storeProductId ||
        ready.product.basePlanId != product.basePlanId ||
        ready.product.offerId != product.offerId) {
      return null;
    }
    // A refresh may have replaced the catalog while native preparation waited.
    if (!identical(await readCheckoutProducts(), products)) {
      throw const MembershipPurchaseBlocked('eligibility_unavailable');
    }
    if (!preparation._usable ||
        preparation._session != _session ||
        preparation._revision != catalogRevision.value) {
      return null;
    }
    preparation._consumed = true;
    preparation._expiry?.cancel();
    return ready;
  }
}
