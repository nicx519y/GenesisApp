import '../../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';

import '../../ui/components/genesis_refresh_indicator.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_purchase_catalog.dart';
import '../common/genesis_modal_routes.dart';

/// A committed tab entry refreshes its catalog without recreating purchase state.
class PurchaseCatalogEntry extends InheritedWidget {
  const PurchaseCatalogEntry({
    super.key,
    required this.revision,
    required super.child,
  });
  final int revision;

  static int of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PurchaseCatalogEntry>()
          ?.revision ??
      0;

  @override
  bool updateShouldNotify(PurchaseCatalogEntry oldWidget) =>
      revision != oldWidget.revision;
}

/// One root-overlay loading barrier shared by mounted Gems purchase surfaces.
class GemProductRefreshGuard extends StatefulWidget {
  const GemProductRefreshGuard({
    super.key,
    required this.isLoading,
    required this.child,
  });
  final bool isLoading;
  final Widget child;
  @override
  State<GemProductRefreshGuard> createState() => _GemProductRefreshGuardState();
}

class _GemProductRefreshGuardState extends State<GemProductRefreshGuard> {
  static final Map<OverlayState, _GemProductRefreshEntry> _entries = {};
  OverlayState? _overlay;
  bool _syncScheduled = false;

  void _release() {
    final overlay = _overlay;
    _overlay = null;
    if (overlay == null) return;
    final shared = _entries[overlay];
    shared?.owners.remove(this);
    if (shared != null && shared.owners.isEmpty) {
      _entries.remove(overlay);
      shared.entry.remove();
      shared.entry.dispose();
    }
  }

  void _sync() {
    if (!widget.isLoading) {
      _release();
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    if (identical(overlay, _overlay)) return;
    _release();
    final shared = _entries.putIfAbsent(overlay, () {
      final entry = OverlayEntry(
        builder: (_) => const Stack(
          key: ValueKey<String>('gem-products-global-loading'),
          fit: StackFit.expand,
          children: [
            ModalBarrier(dismissible: false, color: kGenesisModalBarrierColor),
            Center(
              child: SizedBox.square(
                dimension: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: GenesisColors.darkRaisedBackground,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: GemPurchaseLoading(),
                ),
              ),
            ),
          ],
        ),
      );
      overlay.insert(entry);
      return _GemProductRefreshEntry(entry);
    });
    shared.owners.add(this);
    _overlay = overlay;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_syncScheduled) {
      _syncScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncScheduled = false;
        if (mounted) _sync();
      });
    }
    return PopScope(
      canPop: !widget.isLoading,
      child: AbsorbPointer(absorbing: widget.isLoading, child: widget.child),
    );
  }
}

class _GemProductRefreshEntry {
  _GemProductRefreshEntry(this.entry);
  final OverlayEntry entry;
  final Set<Object> owners = {};
}

/// Shared loading, placeholder and retry states for purchase pages and sheets.
class GemPurchaseLoading extends StatelessWidget {
  const GemPurchaseLoading({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: size,
      child: const GenesisLoadingIndicator(),
    ),
  );
}

class GemProductGridSkeleton extends StatelessWidget {
  const GemProductGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        mainAxisExtent: kGemProductCardHeight,
      ),
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: GenesisColors.darkFaintFill,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class GemPurchaseState extends StatelessWidget {
  const GemPurchaseState({
    super.key,
    required this.message,
    this.onRetry,
    this.height = 160,
  });

  final String message;
  final VoidCallback? onRetry;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GenesisColors.darkTextTertiary,
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: GenesisColors.darkTextSecondary,
              ),
              child: Text(GenesisL10n.current.homeRetry),
            ),
          ],
        ],
      ),
    );
  }
}
