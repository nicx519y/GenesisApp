import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/debug/world_memory_debug_preview.dart';
import '../../app/membership/membership_access_store.dart';
import '../../app/membership/membership_catalog.dart';
import '../../l10n/genesis_localizations.dart';
import '../common/genesis_center_toast.dart';
import 'gem_purchase_state.dart';
import 'memory_membership_carousel.dart';
import 'memory_membership_style.dart';
import 'pro_subscription_content.dart';

/// Production adapter only. Preview galleries use the pure carousel directly.
/// The existing checkout owns all SKU selection, pricing, orders and receipts.
class MemoryMembershipWalletContent extends StatefulWidget {
  const MemoryMembershipWalletContent({
    super.key,
    this.initialTier,
    this.productsLoader,
    this.onTierChanged,
  });
  final MemoryMembershipTier? initialTier;
  final MembershipCatalogLoader? productsLoader;
  final ValueChanged<MemoryMembershipTier>? onTierChanged;

  @override
  State<MemoryMembershipWalletContent> createState() =>
      _MemoryMembershipWalletContentState();
}

class _MemoryMembershipWalletContentState
    extends State<MemoryMembershipWalletContent> {
  bool _checkout = false;
  String _premiumPlanCode = 'pro_yearly';
  AppServices? _services;
  MembershipCatalogData? _loaded;
  int? _entryRevision;
  int _loadGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.maybeOf(context);
    final revision = PurchaseCatalogEntry.of(context);
    final changed = !identical(services, _services);
    if (changed) {
      _services?.sessionRevision.removeListener(_sessionChanged);
      _services = services;
      services?.sessionRevision.addListener(_sessionChanged);
      _loaded = null;
      _checkout = false;
    }
    if (changed || _entryRevision != revision) {
      _entryRevision = revision;
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant MemoryMembershipWalletContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productsLoader != widget.productsLoader) {
      _loaded = null;
      unawaited(_load());
    }
  }

  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _loaded = null;
      _checkout = false;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final loader =
        widget.productsLoader ?? _services?.membershipCatalog.loadForEntry;
    if (loader == null) return;
    try {
      final data = await loader();
      if (mounted && generation == _loadGeneration) {
        setState(() => _loaded = data);
      }
    } catch (_) {
      // No fallback price or product. The original checkout retains its own
      // catalog loading, error/retry UI and purchase eligibility checks.
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _services?.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }

  void _subscribe(bool yearly) => setState(() {
    _premiumPlanCode = yearly ? 'pro_yearly' : 'pro_monthly';
    _checkout = true;
  });

  @override
  Widget build(BuildContext context) {
    Widget checkout() => Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _checkout = false),
            icon: const Icon(Icons.chevron_left),
            label: Text(context.l10n.premiumSubscription),
          ),
        ),
        Expanded(
          child: ProSubscriptionContent(
            refreshMembershipOnOpen: false,
            closeOnPurchaseSuccess: true,
            horizontalInset: 16,
            headingTopSpacing: 10,
            productsLoader: widget.productsLoader,
            initialPlanCode: _premiumPlanCode,
          ),
        ),
      ],
    );
    final services = _services;
    String? catalogPrice(String code) {
      // Reuse the account-scoped display cache. Checkout still refreshes and
      // verifies its own catalog before any real store request.
      for (final offer
          in (widget.productsLoader != null
                      ? _loaded
                      : services?.membershipCatalog.cached)
                  ?.offers ??
              const <MembershipOffer>[]) {
        if (offer.product.planCode == code) return offer.price?.formattedPrice;
      }
      return null;
    }

    Widget cards(MembershipAccessState state) =>
        MemoryMembershipSubscriptionCarousel(
          premiumActive: state.isVip == true,
          deluxeActive: false,
          premiumExpiry: state.membership?.expiresAt,
          premiumYearlyPrice: catalogPrice('pro_yearly'),
          premiumMonthlyPrice: catalogPrice('pro_monthly'),
          initialTier: widget.initialTier,
          onTierChanged: widget.onTierChanged,
          onPremiumSubscribe: () => _subscribe(true),
          onPremiumPlanSubscribe: _subscribe,
          onDeluxeSubscribe: () => showGenesisToast(
            context,
            context.l10n.memoryMembershipDeluxeUnavailable,
          ),
        );
    final carousel = services == null
        ? cards(const MembershipAccessState())
        : ListenableBuilder(
            listenable: services.membershipCatalog.displayRevision,
            builder: (context, _) =>
                ValueListenableBuilder<MembershipAccessState>(
                  valueListenable: services.membership.state,
                  builder: (context, state, _) => cards(state),
                ),
          );
    return ValueListenableBuilder<WorldMemoryDebugPreview>(
      valueListenable: worldMemoryDebugPreview,
      builder: (context, _, _) {
        final preview = activeWorldMemoryDebugPreview;
        // Sample ownership and draft prices never reach the real checkout.
        if (preview != null) {
          void notice() => showGenesisToast(
            context,
            context.l10n.memoryMembershipDraftPreview,
          );
          return MemoryMembershipSubscriptionCarousel(
            key: ValueKey(preview.membership),
            premiumActive: preview.premium,
            deluxeActive: preview.deluxe,
            premiumExpiry: preview.premiumExpiry,
            deluxeExpiry: preview.deluxeExpiry,
            initialTier: widget.initialTier,
            onTierChanged: widget.onTierChanged,
            onPremiumSubscribe: notice,
            onDeluxeSubscribe: notice,
          );
        }
        return Stack(
          children: [
            Offstage(offstage: _checkout, child: carousel),
            if (_checkout) checkout(),
          ],
        );
      },
    );
  }
}
