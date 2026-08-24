import 'package:flutter/material.dart';

import '../ui/components/genesis_safe_area.dart';
import '../ui/components/genesis_search_field.dart';
import '../ui/components/genesis_modal_border.dart';
import '../ui/theme/genesis_semantic_colors.dart';

const double mapDetailSheetTopOverlayOffset = 8;
const double mapDetailSheetExpandedTopGap = 20;

double mapDetailSheetExpandedTop(BuildContext context) {
  return GenesisSafeAreaInsets.top(context) +
      mapDetailSheetTopOverlayOffset +
      genesisSearchFieldHeight +
      mapDetailSheetExpandedTopGap;
}

const BorderRadius mapDetailSheetBorderRadius = BorderRadius.vertical(
  top: Radius.circular(24),
);

BoxDecoration mapDetailSheetDecoration(
  BuildContext context, {
  bool connectsToBottom = false,
}) {
  final colors = context.genesisColors;
  return BoxDecoration(
    color: colors.pageBackground,
    borderRadius: mapDetailSheetBorderRadius,
    boxShadow: connectsToBottom
        ? null
        : [
            BoxShadow(
              color: colors.scrim.withValues(alpha: 0.6),
              blurRadius: 44,
              offset: const Offset(0, -14),
            ),
          ],
  );
}

BoxDecoration mapDetailSheetOutlineDecoration(
  BuildContext context, {
  bool connectsToBottom = false,
}) {
  final borderSide = genesisModalBorderSide(context);
  return BoxDecoration(
    borderRadius: mapDetailSheetBorderRadius,
    border: connectsToBottom
        ? Border(
            top: borderSide,
            left: borderSide,
            right: borderSide,
            bottom: borderSide,
          )
        : genesisModalBorder(context),
  );
}

class MapDetailSheetSurface extends StatelessWidget {
  const MapDetailSheetSurface({
    super.key,
    required this.child,
    this.surfaceKey,
    this.connectsToBottom = false,
    this.showOutline = true,
  });

  final Widget child;
  final Key? surfaceKey;
  final bool connectsToBottom;

  /// 浮窗四周那圈 14% 描边。world 详情浮窗不要它(它拉起后几乎贴满屏,
  /// 描边看着像给整个页面加了个框),其余场景仍按设计稿保留。
  final bool showOutline;

  @override
  Widget build(BuildContext context) {
    final clippedChild = ClipRRect(
      borderRadius: mapDetailSheetBorderRadius,
      child: child,
    );
    return DecoratedBox(
      key: surfaceKey,
      decoration: mapDetailSheetDecoration(
        context,
        connectsToBottom: connectsToBottom,
      ),
      child: showOutline
          ? DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: mapDetailSheetOutlineDecoration(
                context,
                connectsToBottom: connectsToBottom,
              ),
              child: clippedChild,
            )
          : clippedChild,
    );
  }
}
