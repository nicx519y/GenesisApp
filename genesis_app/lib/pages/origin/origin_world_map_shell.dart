part of 'origin_world_page.dart';

extension _OriginWorldPageMapShell on _OriginWorldPageState {
  Widget _buildPersistentMapOverlay(double top, {int locationCount = 0}) {
    return Positioned(
      left: 12,
      right: 12,
      top: top + 8,
      child: WorldTopOverlayBar(
        pointsCount: locationCount,
        controller: _tabController,
        onTabTap: _handleMapModeTabTap,
      ),
    );
  }

  Widget _buildMapOnlyScaffold({
    required double topPadding,
    required double panelCollapsedHeightOffset,
    required Widget mapOverlay,
    required Widget map,
    Widget Function(double minChildSize)? bottomSheetOverlayBuilder,
    Widget? bottomOverlay,
    Widget? topOverlay,
  }) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _baseStatusBarStyle,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final mediaQuery = MediaQuery.of(context);
            final bottomSafeArea =
                mediaQuery.padding.bottom > mediaQuery.viewPadding.bottom
                ? mediaQuery.padding.bottom
                : mediaQuery.viewPadding.bottom;
            final maxMapHeight =
                (viewportHeight -
                        _OriginWorldPageState._mapPanelTopGap -
                        bottomSafeArea)
                    .clamp(0.0, viewportHeight)
                    .toDouble();
            final mapHeight =
                (viewportHeight *
                            (1 -
                                _OriginWorldPageState
                                    ._mapDefaultExposedChildSize) +
                        panelCollapsedHeightOffset -
                        bottomSafeArea)
                    .clamp(0.0, maxMapHeight)
                    .toDouble();
            final bottomOverlayHeight = bottomOverlay == null
                ? 0.0
                : _OriginBottomLaunchBar.heightFor(context);
            final sheetHostHeight = (viewportHeight - bottomOverlayHeight)
                .clamp(0.0, viewportHeight)
                .toDouble();
            final sheetMinChildSize = sheetHostHeight <= 0
                ? _OriginDetailDraggableSheet.defaultInitialChildSize
                : ((sheetHostHeight - mapHeight) / sheetHostHeight)
                      .clamp(0.08, 0.42)
                      .toDouble();
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(height: mapHeight, child: map),
                ),
                mapOverlay,
                if (bottomSheetOverlayBuilder != null)
                  Positioned.fill(
                    bottom: bottomOverlayHeight,
                    child: bottomSheetOverlayBuilder(sheetMinChildSize),
                  ),
                if (bottomOverlay != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: bottomOverlay,
                  ),
                if (topOverlay != null) topOverlay,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OriginBottomLaunchBar extends StatelessWidget {
  const _OriginBottomLaunchBar({
    required this.origin,
    required this.launching,
    required this.onLaunch,
  });

  static double heightFor(BuildContext context) {
    return 49 + GenesisSafeAreaInsets.bottom(context);
  }

  final OriginDetail origin;
  final bool launching;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF9F9F9)),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(13, 0, 13, 0),
        child: SizedBox(
          height: 49,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _LaunchBarStat(
                          iconAsset: copyStatIconAsset,
                          value: origin.copyCount,
                        ),
                        const SizedBox(width: 20),
                        _LaunchBarStat(
                          iconAsset: connectStatIconAsset,
                          value: origin.interactCount,
                        ),
                        const SizedBox(width: 20),
                        _LaunchBarStat(
                          iconAsset: characterStatIconAsset,
                          preserveIconAssetColor: true,
                          value: origin.characterCount,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              GenesisPrimaryButton(
                label: 'Launch',
                leadingIcon: SvgPicture.asset(
                  launchIconAsset,
                  key: const ValueKey<String>('origin-bottom-launch-icon'),
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                iconGap: 6,
                onPressed: launching ? null : onLaunch,
                width: 140,
                height: 35,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                isLoading: launching,
                loadingSize: 22,
                loadingStrokeWidth: 2.4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchBarStat extends StatelessWidget {
  const _LaunchBarStat({
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    return StatItem(
      icon: icon,
      iconAsset: iconAsset,
      preserveIconAssetColor: preserveIconAssetColor,
      iconSize: 14,
      iconAssetScale: 1,
      iconVerticalOffset: 0,
      iconColor: const Color(0xFF111111),
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w400,
        color: Color(0xFF111111),
      ),
    );
  }
}
