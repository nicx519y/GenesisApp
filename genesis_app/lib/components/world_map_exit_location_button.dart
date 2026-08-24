import 'package:flutter/material.dart';

import '../ui/theme/genesis_semantic_colors.dart';

class WorldMapExitLocationButton extends StatelessWidget {
  const WorldMapExitLocationButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  // 设计稿 9b 原文:
  //   容器  left:16px; bottom:172px; display:flex; align-items:center; gap:9px
  //   按钮  width:34px; height:34px; border-radius:12px;
  //         background:rgba(21,21,23,.6); border:1px solid rgba(255,255,255,.16)
  //   文案  font:600 11px/1; color:#F4F3F6;
  //         text-shadow:0 1px 5px rgba(0,0,0,.85)
  // 与原实现的区别:文案在按钮**外面**,不再和图标共处一个药丸里。
  static const double buttonSize = 34;
  // 与左上返回按钮(GenesisBackButton)对齐:34 / 圆角 11。
  static const double buttonRadius = 11;
  static const double borderWidth = 0.5;
  static const double labelGap = 9;

  /// 设计稿 9b:`left:16px; bottom:172px`。浮窗高 149,故离浮窗顶边 23。
  static const double mapEdgeGap = 16;
  static const double mapBottomGap = 23;
  static const Color glassBackground = Color(0x99151517);
  // 设计稿:1px solid rgba(255,255,255,.16)。
  static const Color glassBorder = Color(0x29FFFFFF);

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Material(
            color: glassBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
              side: const BorderSide(color: glassBorder, width: borderWidth),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: Icon(
                  Icons.subdirectory_arrow_left,
                  color: context.genesisColors.foregroundStrong,
                  size: 13,
                ),
              ),
            ),
          ),
        ),
        if (displayLabel.isNotEmpty) ...[
          const SizedBox(width: labelGap),
          Flexible(
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 与地图上的地点名同规格:12px / w600 / #F4F3F6
              // (见 worldMapLocationMarkerNameStyle)。
              style: TextStyle(
                color: context.genesisColors.textPrimary,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w600,
                shadows: const <Shadow>[
                  Shadow(
                    color: Color(0xD9000000),
                    offset: Offset(0, 1),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class WorldMapConstrainedMaxWidth extends StatelessWidget {
  const WorldMapConstrainedMaxWidth({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  final double? maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final resolvedMaxWidth = maxWidth;
    if (resolvedMaxWidth == null) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
      child: child,
    );
  }
}
