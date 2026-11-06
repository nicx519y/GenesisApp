import 'dart:async';

import '../../app/membership/membership_catalog.dart';
import 'memory_membership_style.dart';
import '../../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';

import '../../ui/components/secend_tabs.dart';
import '../../ui/tokens/genesis_colors.dart';

class WalletPurchaseTabView extends StatefulWidget {
  const WalletPurchaseTabView({
    required this.pageKey,
    required this.controller,
    required this.children,
  });

  final Key pageKey;
  final TabController controller;
  final List<Widget> children;

  @override
  State<WalletPurchaseTabView> createState() => _WalletPurchaseTabViewState();
}

class _WalletPurchaseTabViewState extends State<WalletPurchaseTabView> {
  static const _shortSwipeDistance = 48.0;
  int? _pointer;
  double? _dragViewport;

  bool _onScroll(ScrollNotification notification) {
    if (_pointer != null &&
        notification.depth == 0 &&
        notification.metrics.axis == Axis.horizontal &&
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _dragViewport = notification.metrics.viewportDimension;
    }
    return false;
  }

  void _endSwipe(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    final viewport = _dragViewport;
    _clearSwipe(event);
    final controller = widget.controller;
    if (viewport == null || controller.indexIsChanging) return;
    final offset = controller.offset;
    if (offset.abs() >= .5 || offset.abs() * viewport < _shortSwipeDistance) {
      return;
    }
    final origin = controller.index;
    final target = origin + (offset > 0 ? 1 : -1);
    if (target < 0 || target >= controller.length) return;
    // Let PageView finish handling pointer up before redirecting its snap.
    scheduleMicrotask(() {
      if (mounted &&
          _pointer == null &&
          identical(widget.controller, controller) &&
          controller.index == origin &&
          !controller.indexIsChanging) {
        controller.animateTo(target);
      }
    });
  }

  void _clearSwipe(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _dragViewport = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _pointer ??= event.pointer,
    onPointerUp: _endSwipe,
    onPointerCancel: _clearSwipe,
    child: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: TabBarView(
        key: widget.pageKey,
        controller: widget.controller,
        children: widget.children,
      ),
    ),
  );
}

/// Wallet uses the same underline tabs as the other app pages.
class WalletPurchaseTabs extends StatelessWidget {
  const WalletPurchaseTabs({
    super.key,
    required this.controller,
    this.membershipColor,
    this.membershipCatalog,
    this.initialMembershipType,
  });

  final TabController controller;
  final Color? membershipColor;
  final MembershipCatalog? membershipCatalog;
  final MemoryMembershipTier? initialMembershipType;

  static const _labelStyle = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  /// The underline takes the colour of the tab it sits under, and crosses
  /// between them with the swipe rather than snapping at the end of it.
  Color _indicatorColor(Color membershipColor) {
    const gemsIndex = 1;
    if (controller.length <= gemsIndex) return membershipColor;
    final page = (controller.animation?.value ?? controller.index.toDouble())
        .clamp(0.0, controller.length - 1.0);
    return Color.lerp(
      membershipColor,
      GenesisColors.redPrimary,
      (page / gemsIndex).clamp(0.0, 1.0),
    )!;
  }

  Color _colorForTab(int index) {
    const selectedColor = GenesisColors.darkTextPrimary;
    // Taps select immediately; swipes use page progress before the controller
    // commits its new index at scroll end.
    if (controller.indexIsChanging) {
      return controller.index == index
          ? selectedColor
          : GenesisColors.darkTextSecondary;
    }
    final page = controller.animation?.value ?? controller.index.toDouble();
    final selectedness = (1 - (page - index).abs()).clamp(0.0, 1.0);
    return Color.lerp(
      GenesisColors.darkTextSecondary,
      selectedColor,
      selectedness,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = membershipCatalog;
    if (catalog == null) return _buildMembershipTransition(context);
    return ListenableBuilder(
      listenable: catalog.displayRevision,
      builder: (context, _) => _buildMembershipTransition(context),
    );
  }

  Widget _buildMembershipTransition(BuildContext context) {
    // Resolve before the lazy subscription page is mounted. Returning from Gems
    // must never temporarily substitute Premium for a known Deluxe selection.
    final target =
        membershipColor ??
        (initialMembershipType ??
                memoryMembershipInitialTier(
                  hasPurchased:
                      membershipCatalog?.cached?.hasPurchased ?? false,
                ))
            .accent;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: target, end: target),
      // While Gems is selected the membership endpoint is invisible. Settle it
      // immediately so returning cannot interpolate through an obsolete gold.
      duration: controller.index == 1
          ? Duration.zero
          : membershipTierTransitionDuration,
      curve: membershipTierTransitionCurve,
      builder: (context, color, _) => _buildTabs(context, color!),
    );
  }

  Widget _buildTabs(BuildContext context, Color color) {
    return ConstrainedBox(
      key: const ValueKey('wallet-purchase-tabs'),
      constraints: const BoxConstraints(maxWidth: 360),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final measureStyle = Theme.of(
            context,
          ).textTheme.bodyMedium!.merge(_labelStyle);
          return AnimatedBuilder(
            animation: Listenable.merge([controller, controller.animation]),
            builder: (context, _) => SecendTabs(
              controller: controller,
              indicatorColor: _indicatorColor(color),
              indicatorWidth: 24,
              indicatorHeight: 3,
              labels: [
                GenesisL10n.current.premiumSubscription,
                if (controller.length > 1) GenesisL10n.current.gemsBuy,
              ],
              horizontalPadding: 0,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              verticalPadding: 0,
              expanded: true,
              tabAlignment: TabAlignment.fill,
              labelStyle: _labelStyle,
              unselectedLabelStyle: _labelStyle,
              labelColor: GenesisColors.darkTextPrimary,
              unselectedLabelColor: GenesisColors.darkTextSecondary,
              labelWidgets: [
                for (var index = 0; index < controller.length; index++)
                  SizedBox(
                    key: ValueKey(
                      index == 0
                          ? 'wallet-subscription-tab'
                          : 'wallet-buy-gems-tab',
                    ),
                    width: double.infinity,
                    // Label only: the underline centres on the tab itself now
                    // that no icon sits beside the words.
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          index == 0
                              ? GenesisL10n.current.premiumSubscription
                              : GenesisL10n.current.gemsBuy,
                          maxLines: 1,
                          softWrap: false,
                          style: measureStyle.copyWith(
                            color: _colorForTab(index),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
