import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/genesis_colors.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_typography.dart';

// GenesisUiTheme 是 UI 组件库专用的 ThemeExtension。
// Material 自带的 ThemeData 不知道 GenesisSearchField / GenesisBottomNavigation 等自定义组件，
// 所以这些组件的颜色、字体、圆角、指示器尺寸都集中放在这里。
class GenesisUiTheme extends ThemeExtension<GenesisUiTheme> {
  const GenesisUiTheme({
    // 页面标题样式，当前由 GenesisPageTitle 使用。
    required this.pageTitleStyle,
    // 通用正文样式，当前由 GenesisTabBar 的未选中标签等组件使用。
    required this.bodyStyle,
    // 强调正文样式，当前由 GenesisTabBar 的选中标签等组件使用。
    required this.bodyStrongStyle,
    // 底部导航标签样式，当前由 GenesisBottomNavigationTile 使用。
    required this.tabLabelStyle,
    // 搜索框背景色，当前由 GenesisSearchField 外层容器使用。
    required this.searchBackgroundColor,
    // 搜索框左侧搜索图标颜色。
    required this.searchIconColor,
    // 搜索框 placeholder 文字样式。
    required this.searchHintStyle,
    // 搜索框输入文字样式。
    required this.searchTextStyle,
    // 搜索框圆角。
    required this.searchBorderRadius,
    // 底部导航栏背景色。
    required this.bottomNavigationBackgroundColor,
    // 底部导航普通 tab 选中颜色。
    required this.bottomNavigationSelectedColor,
    // 底部导航普通 tab 未选中颜色。
    required this.bottomNavigationUnselectedColor,
    // 底部导航强调 tab 颜色，例如 Create 中间按钮。
    required this.bottomNavigationProminentColor,
    // 二级 TabBar 选中标签颜色。
    required this.tabSelectedColor,
    // 二级 TabBar 未选中标签颜色。
    required this.tabUnselectedColor,
    // 二级 TabBar 下划线指示器颜色。
    required this.tabIndicatorColor,
    // 二级 TabBar 下划线指示器宽度。
    required this.tabIndicatorWidth,
    // 二级 TabBar 下划线指示器高度。
    required this.tabIndicatorHeight,
    // 通用面板/按钮圆角，当前由 GenesisPrimaryButton 使用。
    required this.panelBorderRadius,
  });

  // 浅色主题默认值。
  // 这里是“改 UI 组件库整体视觉”的主入口；优先改这里，而不是去组件内部写死颜色。
  factory GenesisUiTheme.light() {
    return GenesisUiTheme(
      // 页面标题使用全局标题 token。
      pageTitleStyle: GenesisTypography.pageTitle,
      // 普通正文使用全局正文 token。
      bodyStyle: GenesisTypography.body,
      // 强调正文使用全局强调 token。
      bodyStrongStyle: GenesisTypography.bodyStrong,
      // 底部 tab 文案使用专门的小字号 token。
      tabLabelStyle: GenesisTypography.tabLabel,
      // 搜索框默认浅灰背景。
      searchBackgroundColor: GenesisColors.surfaceInput,
      // 搜索图标默认弱化灰色。
      searchIconColor: GenesisColors.textDisabled,
      // 搜索提示文案复用正文尺寸，但颜色弱化。
      searchHintStyle: GenesisTypography.body.copyWith(
        color: GenesisColors.textDisabled,
      ),
      // 搜索输入文字复用正文样式。
      searchTextStyle: GenesisTypography.body,
      // 搜索框圆角使用输入框圆角 token。
      searchBorderRadius: GenesisRadii.input,
      // 底部导航背景色。
      bottomNavigationBackgroundColor: GenesisColors.surfaceMuted,
      // 底部导航选中态颜色。
      bottomNavigationSelectedColor: GenesisColors.textPrimary,
      // 底部导航未选中态颜色。
      bottomNavigationUnselectedColor: GenesisColors.textDisabled,
      // 底部导航突出项颜色，例如 Create。
      bottomNavigationProminentColor: GenesisColors.create,
      // 二级 tab 选中颜色。
      tabSelectedColor: GenesisColors.textPrimary,
      // 二级 tab 未选中颜色。
      tabUnselectedColor: GenesisColors.textTertiary,
      // 二级 tab 指示器使用状态红。
      tabIndicatorColor: GenesisColors.danger,
      // 二级 tab 指示器固定宽度，保持和现有视觉一致。
      tabIndicatorWidth: 34,
      // 二级 tab 指示器高度。
      tabIndicatorHeight: 3,
      // 通用面板圆角。
      panelBorderRadius: GenesisRadii.panel,
    );
  }

  // GenesisPageTitle 的文字样式。
  final TextStyle pageTitleStyle;
  // 通用正文样式。
  final TextStyle bodyStyle;
  // 通用强调正文样式。
  final TextStyle bodyStrongStyle;
  // 底部导航标签样式。
  final TextStyle tabLabelStyle;
  // GenesisSearchField 背景色。
  final Color searchBackgroundColor;
  // GenesisSearchField 搜索图标颜色。
  final Color searchIconColor;
  // GenesisSearchField placeholder 样式。
  final TextStyle searchHintStyle;
  // GenesisSearchField 输入文字样式。
  final TextStyle searchTextStyle;
  // GenesisSearchField 外框圆角。
  final BorderRadius searchBorderRadius;
  // GenesisBottomNavigation 背景色。
  final Color bottomNavigationBackgroundColor;
  // GenesisBottomNavigation 普通项选中颜色。
  final Color bottomNavigationSelectedColor;
  // GenesisBottomNavigation 普通项未选中颜色。
  final Color bottomNavigationUnselectedColor;
  // GenesisBottomNavigation prominent 项颜色。
  final Color bottomNavigationProminentColor;
  // GenesisTabBar 选中标签颜色。
  final Color tabSelectedColor;
  // GenesisTabBar 未选中标签颜色。
  final Color tabUnselectedColor;
  // GenesisTabBar 指示器颜色。
  final Color tabIndicatorColor;
  // GenesisTabBar 指示器宽度。
  final double tabIndicatorWidth;
  // GenesisTabBar 指示器高度。
  final double tabIndicatorHeight;
  // GenesisPrimaryButton 等面板型组件圆角。
  final BorderRadius panelBorderRadius;

  // 给组件读取主题的统一方法。
  // 如果外层 MaterialApp 没有挂 GenesisUiTheme，则回退到 light 默认值，避免组件空指针。
  static GenesisUiTheme of(BuildContext context) {
    return Theme.of(context).extension<GenesisUiTheme>() ??
        GenesisUiTheme.light();
  }

  @override
  // 用于局部覆盖部分样式，例如只改搜索框背景而不改其他组件。
  GenesisUiTheme copyWith({
    // 覆盖页面标题样式。
    TextStyle? pageTitleStyle,
    // 覆盖普通正文样式。
    TextStyle? bodyStyle,
    // 覆盖强调正文样式。
    TextStyle? bodyStrongStyle,
    // 覆盖底部导航标签样式。
    TextStyle? tabLabelStyle,
    // 覆盖搜索框背景色。
    Color? searchBackgroundColor,
    // 覆盖搜索图标颜色。
    Color? searchIconColor,
    // 覆盖搜索提示文案样式。
    TextStyle? searchHintStyle,
    // 覆盖搜索输入文字样式。
    TextStyle? searchTextStyle,
    // 覆盖搜索框圆角。
    BorderRadius? searchBorderRadius,
    // 覆盖底部导航背景色。
    Color? bottomNavigationBackgroundColor,
    // 覆盖底部导航选中颜色。
    Color? bottomNavigationSelectedColor,
    // 覆盖底部导航未选中颜色。
    Color? bottomNavigationUnselectedColor,
    // 覆盖底部导航突出项颜色。
    Color? bottomNavigationProminentColor,
    // 覆盖二级 tab 选中颜色。
    Color? tabSelectedColor,
    // 覆盖二级 tab 未选中颜色。
    Color? tabUnselectedColor,
    // 覆盖二级 tab 指示器颜色。
    Color? tabIndicatorColor,
    // 覆盖二级 tab 指示器宽度。
    double? tabIndicatorWidth,
    // 覆盖二级 tab 指示器高度。
    double? tabIndicatorHeight,
    // 覆盖通用面板圆角。
    BorderRadius? panelBorderRadius,
  }) {
    return GenesisUiTheme(
      // 未传入时沿用当前主题值，保证 copyWith 只覆盖指定字段。
      pageTitleStyle: pageTitleStyle ?? this.pageTitleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      bodyStrongStyle: bodyStrongStyle ?? this.bodyStrongStyle,
      tabLabelStyle: tabLabelStyle ?? this.tabLabelStyle,
      searchBackgroundColor:
          searchBackgroundColor ?? this.searchBackgroundColor,
      searchIconColor: searchIconColor ?? this.searchIconColor,
      searchHintStyle: searchHintStyle ?? this.searchHintStyle,
      searchTextStyle: searchTextStyle ?? this.searchTextStyle,
      searchBorderRadius: searchBorderRadius ?? this.searchBorderRadius,
      bottomNavigationBackgroundColor:
          bottomNavigationBackgroundColor ??
          this.bottomNavigationBackgroundColor,
      bottomNavigationSelectedColor:
          bottomNavigationSelectedColor ?? this.bottomNavigationSelectedColor,
      bottomNavigationUnselectedColor:
          bottomNavigationUnselectedColor ??
          this.bottomNavigationUnselectedColor,
      bottomNavigationProminentColor:
          bottomNavigationProminentColor ?? this.bottomNavigationProminentColor,
      tabSelectedColor: tabSelectedColor ?? this.tabSelectedColor,
      tabUnselectedColor: tabUnselectedColor ?? this.tabUnselectedColor,
      tabIndicatorColor: tabIndicatorColor ?? this.tabIndicatorColor,
      tabIndicatorWidth: tabIndicatorWidth ?? this.tabIndicatorWidth,
      tabIndicatorHeight: tabIndicatorHeight ?? this.tabIndicatorHeight,
      panelBorderRadius: panelBorderRadius ?? this.panelBorderRadius,
    );
  }

  @override
  // Flutter 主题切换/动画过渡时会调用 lerp。
  // 所有颜色、字体、圆角、尺寸都要能插值，避免主题切换时突然跳变。
  GenesisUiTheme lerp(ThemeExtension<GenesisUiTheme>? other, double t) {
    // 如果目标主题不是同类型，保持当前主题不变。
    if (other is! GenesisUiTheme) return this;
    return GenesisUiTheme(
      // 标题文字样式插值。
      pageTitleStyle: TextStyle.lerp(pageTitleStyle, other.pageTitleStyle, t)!,
      // 正文文字样式插值。
      bodyStyle: TextStyle.lerp(bodyStyle, other.bodyStyle, t)!,
      // 强调正文样式插值。
      bodyStrongStyle: TextStyle.lerp(
        bodyStrongStyle,
        other.bodyStrongStyle,
        t,
      )!,
      // 底部导航标签文字样式插值。
      tabLabelStyle: TextStyle.lerp(tabLabelStyle, other.tabLabelStyle, t)!,
      // 搜索框背景色插值。
      searchBackgroundColor: Color.lerp(
        searchBackgroundColor,
        other.searchBackgroundColor,
        t,
      )!,
      // 搜索图标颜色插值。
      searchIconColor: Color.lerp(searchIconColor, other.searchIconColor, t)!,
      // 搜索提示文案样式插值。
      searchHintStyle: TextStyle.lerp(
        searchHintStyle,
        other.searchHintStyle,
        t,
      )!,
      // 搜索输入文字样式插值。
      searchTextStyle: TextStyle.lerp(
        searchTextStyle,
        other.searchTextStyle,
        t,
      )!,
      // 搜索框圆角插值。
      searchBorderRadius: BorderRadius.lerp(
        searchBorderRadius,
        other.searchBorderRadius,
        t,
      )!,
      // 底部导航背景色插值。
      bottomNavigationBackgroundColor: Color.lerp(
        bottomNavigationBackgroundColor,
        other.bottomNavigationBackgroundColor,
        t,
      )!,
      // 底部导航选中颜色插值。
      bottomNavigationSelectedColor: Color.lerp(
        bottomNavigationSelectedColor,
        other.bottomNavigationSelectedColor,
        t,
      )!,
      // 底部导航未选中颜色插值。
      bottomNavigationUnselectedColor: Color.lerp(
        bottomNavigationUnselectedColor,
        other.bottomNavigationUnselectedColor,
        t,
      )!,
      // 底部导航突出项颜色插值。
      bottomNavigationProminentColor: Color.lerp(
        bottomNavigationProminentColor,
        other.bottomNavigationProminentColor,
        t,
      )!,
      // 二级 tab 选中颜色插值。
      tabSelectedColor: Color.lerp(
        tabSelectedColor,
        other.tabSelectedColor,
        t,
      )!,
      // 二级 tab 未选中颜色插值。
      tabUnselectedColor: Color.lerp(
        tabUnselectedColor,
        other.tabUnselectedColor,
        t,
      )!,
      // 二级 tab 指示器颜色插值。
      tabIndicatorColor: Color.lerp(
        tabIndicatorColor,
        other.tabIndicatorColor,
        t,
      )!,
      // 二级 tab 指示器宽度插值。
      tabIndicatorWidth: lerpDouble(
        tabIndicatorWidth,
        other.tabIndicatorWidth,
        t,
      )!,
      // 二级 tab 指示器高度插值。
      tabIndicatorHeight: lerpDouble(
        tabIndicatorHeight,
        other.tabIndicatorHeight,
        t,
      )!,
      // 通用面板圆角插值。
      panelBorderRadius: BorderRadius.lerp(
        panelBorderRadius,
        other.panelBorderRadius,
        t,
      )!,
    );
  }
}
