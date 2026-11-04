import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/service_registry.dart';
import '../../app/debug/world_memory_debug_preview.dart';
import '../../app/membership/membership_catalog.dart';
import '../../components/gems/memory_membership_style.dart';
import '../../components/world_memory/world_memory.dart';
import '../../l10n/genesis_localizations.dart';
import '../../routers/app_router.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'world_recap_cache.dart';
import 'world_recap_section.dart';

/// Connects the shared presentation to existing, account-scoped Premium and
/// summary sources. Structured memory and Deluxe have no production adapter yet,
/// so debug builds show [activeWorldMemoryDebugPreview] instead when it is set.
class WorldMemoryHost extends StatefulWidget {
  const WorldMemoryHost({
    super.key,
    required this.services,
    required this.worldId,
    required this.section,
    this.cache,
    this.scrollController,
    this.active = true,
    this.phone = false,
    this.summaryUpdates,
    this.phoneHeaderBuilder,
    this.onOpenBonds,
  });

  final AppServices services;
  final String worldId;
  final WorldMemorySection section;
  final WorldRecapCache? cache;
  final ScrollController? scrollController;
  final bool active;
  final bool phone;
  final Listenable? summaryUpdates;
  final Widget Function(BuildContext, VoidCallback?)? phoneHeaderBuilder;
  final VoidCallback? onOpenBonds;

  @override
  State<WorldMemoryHost> createState() => _WorldMemoryHostState();
}

class _WorldMemoryHostState extends State<WorldMemoryHost> {
  late WorldRecapCache _cache;
  bool? _premium;
  int _revision = 0;
  bool _entryRefreshPending = true;
  final _summaryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cache = widget.cache ?? WorldRecapCache();
    _bind();
  }

  void _bind() {
    _cache.bindScope((widget.services, widget.services.sessionRevision.value));
    widget.services.membership.state.addListener(_membershipChanged);
    widget.services.sessionRevision.addListener(_accountChanged);
    widget.summaryUpdates?.addListener(_summaryUpdated);
    _checkMembership();
  }

  void _unbind(AppServices services) {
    services.membership.state.removeListener(_membershipChanged);
    services.sessionRevision.removeListener(_accountChanged);
  }

  void _checkMembership() {
    final revision = ++_revision;
    widget.services.membership.checkVip((value) {
      if (!mounted || revision != _revision) return;
      setState(() => _premium = value);
      _ensureSummary();
    });
  }

  void _accountChanged() {
    _revision++;
    _cache.bindScope((widget.services, widget.services.sessionRevision.value));
    _entryRefreshPending = true;
    setState(() => _premium = null);
    _checkMembership();
  }

  void _membershipChanged() {
    if (!mounted) return;
    final value = widget.services.membership.state.value.isVip;
    if (value == true && _premium != true) _entryRefreshPending = true;
    if (_premium != value) setState(() => _premium = value);
    _ensureSummary();
  }

  void _ensureSummary() {
    if (activeWorldMemoryDebugPreview != null ||
        !widget.active ||
        widget.section != WorldMemorySection.recap ||
        _premium != true ||
        !_entryRefreshPending) {
      return;
    }
    _entryRefreshPending = false;
    final revision = _revision;
    scheduleMicrotask(() {
      if (!mounted ||
          revision != _revision ||
          !widget.active ||
          _premium != true) {
        return;
      }
      unawaited(
        _cache.refresh(
          widget.worldId,
          widget.services.api.getWorldRecentSummary,
        ),
      );
    });
  }

  void _summaryUpdated() {
    if (widget.section != WorldMemorySection.recap) return;
    if (activeWorldMemoryDebugPreview != null ||
        !widget.active ||
        _premium != true) {
      _entryRefreshPending = true;
      return;
    }
    unawaited(
      _cache.refreshOnUpdate(
        widget.worldId,
        widget.services.api.getWorldRecentSummary,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant WorldMemoryHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summaryUpdates != widget.summaryUpdates) {
      oldWidget.summaryUpdates?.removeListener(_summaryUpdated);
      widget.summaryUpdates?.addListener(_summaryUpdated);
    }
    if (!oldWidget.active && widget.active) _entryRefreshPending = true;
    if (oldWidget.services != widget.services ||
        oldWidget.worldId != widget.worldId ||
        oldWidget.cache != widget.cache) {
      _unbind(oldWidget.services);
      _revision++;
      if (oldWidget.cache == null) _cache.dispose();
      _cache = widget.cache ?? WorldRecapCache();
      _premium = null;
      _entryRefreshPending = true;
      // _bind also registers this listener after rebinding services.
      widget.summaryUpdates?.removeListener(_summaryUpdated);
      _bind();
    }
    _ensureSummary();
  }

  @override
  void dispose() {
    _revision++;
    _unbind(widget.services);
    widget.summaryUpdates?.removeListener(_summaryUpdated);
    _summaryScrollController.dispose();
    if (widget.cache == null) _cache.dispose();
    super.dispose();
  }

  String? _catalogPrice(String planCode) {
    final offers = widget.services.membershipCatalog.cached?.offers;
    for (final offer in offers ?? const <MembershipOffer>[]) {
      if (offer.product.planCode == planCode) {
        return offer.price?.formattedPrice;
      }
    }
    return null;
  }

  void _openSubscription(MemoryMembershipTier tier) =>
      Navigator.of(context, rootNavigator: true).pushNamed(
        RouteNames.gemWallet,
        arguments: GemWalletRouteArgs.subscription(
          SubscriptionSource.worldRecap,
          membershipTier: tier,
        ),
      );

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<WorldMemoryDebugPreview>(
        valueListenable: worldMemoryDebugPreview,
        builder: (context, _, _) {
          final preview = activeWorldMemoryDebugPreview;
          if (preview == null) {
            _ensureSummary();
            return _buildAccountMemory(context);
          }
          return WorldMemoryView(
            key: ValueKey((preview.membership, preview.story)),
            section: widget.section,
            snapshot: preview.snapshot,
            premiumActive: preview.premium,
            deluxeActive: preview.deluxe,
            phone: widget.phone,
            phoneHeaderBuilder: widget.phoneHeaderBuilder,
            onOpenBonds: widget.onOpenBonds,
            scrollController: widget.scrollController,
            onSubscribe: _openSubscription,
          );
        },
      );

  Widget _buildAccountMemory(BuildContext context) {
    if (_premium == null) {
      final loading = ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              height: 18,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: GenesisColors.darkFaintFill,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          if (widget.services.membership.state.value.lastError != null)
            TextButton(
              onPressed: _checkMembership,
              child: Text(context.l10n.homeRetry),
            ),
        ],
      );
      return widget.phoneHeaderBuilder == null
          ? loading
          : Column(
              children: [
                widget.phoneHeaderBuilder!(context, null),
                Expanded(child: loading),
              ],
            );
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: widget.services.membershipCatalog.displayRevision,
      builder: (context, _) => WorldMemoryView(
        section: widget.section,
        snapshot: const WorldMemorySnapshot.empty(),
        premiumActive: _premium == true,
        premiumYearlyPrice: _catalogPrice('pro_yearly'),
        premiumMonthlyPrice: _catalogPrice('pro_monthly'),
        deluxeActive: false,
        phone: widget.phone,
        phoneHeaderBuilder: widget.phoneHeaderBuilder,
        onOpenBonds: widget.onOpenBonds,
        scrollController: widget.scrollController,
        // Only built once Summary is unlocked, so nothing loads for non-members.
        summaryContent: WorldRecapSection(
          key: ValueKey(('memory-summary', widget.worldId)),
          cache: _cache,
          load: widget.services.api.getWorldRecentSummary,
          scrollController: widget.scrollController ?? _summaryScrollController,
          expandedContentHeight: 0,
          active: widget.active,
          checkVip: widget.services.membership.checkVip,
          membershipChanges: widget.services.membership.state,
          worldId: widget.worldId,
          padding: EdgeInsets.fromLTRB(
            16,
            widget.phone ? 14 : 16,
            16,
            32 + bottomInset,
          ),
        ),
        onSubscribe: _openSubscription,
      ),
    );
  }
}
