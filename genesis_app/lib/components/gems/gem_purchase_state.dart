import '../../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';

import '../../ui/components/genesis_refresh_indicator.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_purchase_catalog.dart';
import 'memory_membership_style.dart';

/// A committed tab entry refreshes its catalog without recreating purchase state.
class PurchaseCatalogEntry extends InheritedWidget {
  const PurchaseCatalogEntry({
    super.key,
    required this.revision,
    required super.child,
  });

  /// A null revision allows the sheet to show cached content before entry.
  final int? revision;

  static int? of(BuildContext context) {
    final entry = context
        .dependOnInheritedWidgetOfExactType<PurchaseCatalogEntry>();
    return entry == null ? 0 : entry.revision;
  }

  @override
  bool updateShouldNotify(PurchaseCatalogEntry oldWidget) =>
      revision != oldWidget.revision;
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

/// A visual preview for tabs whose purchase content has not been mounted yet.
class GemPurchaseTabPlaceholder extends StatelessWidget {
  const GemPurchaseTabPlaceholder.subscription({
    super.key,
    this.horizontalInset = 16,
    this.topSpacing = purchaseTabContentTopSpacing,
  }) : _subscription = true;

  const GemPurchaseTabPlaceholder.gems({
    super.key,
    this.horizontalInset = 16,
    this.topSpacing = purchaseTabContentTopSpacing,
  }) : _subscription = false;

  final double horizontalInset;
  final double topSpacing;
  final bool _subscription;

  Widget _bone(double height, {double? width, double radius = 4}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: GenesisColors.darkFaintFill,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalInset,
        topSpacing,
        horizontalInset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _subscription
            ? [
                _bone(
                  (constraints.maxHeight * .65).clamp(180, 520),
                  width: memoryMembershipCardWidth(constraints.maxWidth),
                  radius: 18,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _bone(72, radius: 14)),
                    const SizedBox(width: 12),
                    Expanded(child: _bone(72, radius: 14)),
                  ],
                ),
              ]
            : [
                _bone(18, width: 82),
                const SizedBox(height: 8),
                _bone(40, width: 120),
                const SizedBox(height: 24),
                const GemProductGridSkeleton(),
              ],
      ),
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
