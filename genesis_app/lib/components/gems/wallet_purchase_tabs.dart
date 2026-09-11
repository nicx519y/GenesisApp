import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';
import '../../ui/components/secend_tabs.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_assets.dart';

/// Wallet uses the same underline tabs as the other app pages.
class WalletPurchaseTabs extends StatelessWidget {
  const WalletPurchaseTabs({super.key, required this.controller});

  final TabController controller;
  static const double _iconSize = 22;
  static double _iconGap(int index) => index == 0 ? 6 : 3;

  double _indicatorOffset(BuildContext context) {
    final page = (controller.animation?.value ?? controller.index.toDouble())
        .clamp(0.0, controller.length - 1.0);
    // Each label centres icon + gap + text. Shift the underline to the text
    // centre, interpolating the different gaps while switching tabs.
    final gap = _iconGap(0) + (_iconGap(1) - _iconGap(0)) * page;
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return direction * (_iconSize + gap) / 2;
  }

  static const _labelStyle = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

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
              indicatorColor: GenesisColors.redPrimary,
              indicatorHorizontalOffset: _indicatorOffset(context),
              labels: ['Subscription', if (controller.length > 1) 'Buy Gems'],
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          index == 0 ? proCrownIconAsset : gemOutlineIconAsset,
                          key: ValueKey(
                            index == 0
                                ? 'subscription-crown-icon'
                                : 'buy-gems-outline-icon',
                          ),
                          width: _iconSize,
                          height: _iconSize,
                          colorFilter: ColorFilter.mode(
                            _colorForTab(index),
                            BlendMode.srcIn,
                          ),
                        ),
                        // The narrow gem has more whitespace inside its SVG box.
                        SizedBox(width: _iconGap(index)),
                        Flexible(
                          child: Text(
                            index == 0 ? 'Subscription' : 'Buy Gems',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: measureStyle.copyWith(
                              color: _colorForTab(index),
                            ),
                          ),
                        ),
                      ],
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
