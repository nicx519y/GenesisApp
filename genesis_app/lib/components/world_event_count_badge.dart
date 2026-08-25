import 'package:flutter/material.dart';

import '../ui/theme/genesis_semantic_colors.dart';
import '../ui/tokens/genesis_typography.dart';

/// 事件计数徽标。设计稿 9a 的 #F82B3C 标记:圆角长方形(半径 6 小于高度的
/// 一半,所以是方形圆角而不是胶囊)、无描边。地图 location 右上角和详情页
/// 底 bar 的 Events 共用这一份,免得两边各写一套后又漂开。
class WorldEventCountBadge extends StatelessWidget {
  const WorldEventCountBadge({super.key, required this.count});

  static const double minWidth = 20;
  static const double height = 16;
  static const double borderRadius = 6;
  static const double horizontalPadding = 5;
  static const double fontSize = 9.5;

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return Container(
      constraints: const BoxConstraints(minWidth: minWidth),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: colors.danger,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          // inherit: false —— 徽标会被放进带 DefaultTextStyle 的 tab 行里,
          // 不继承就不会捡到下划线之类的装饰。
          inherit: false,
          fontFamily: GenesisTypography.fontFamily,
          fontFamilyFallback: GenesisTypography.fontFamilyFallback,
          color: colors.onDanger,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
