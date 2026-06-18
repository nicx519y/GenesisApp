import 'package:flutter/material.dart';

import '../tokens/genesis_colors.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_ui_theme.dart';

// GenesisTheme 是 App 级 ThemeData 的唯一入口。
// 这里负责把 Flutter Material 主题和自定义 Genesis UI 组件主题挂到一起。
abstract final class GenesisTheme {
  // 当前只定义 light 主题；以后如果支持暗色模式，可以新增 dark() 并复用同一套 token/extension 结构。
  static ThemeData light() {
    // Material 组件使用的基础色板；seedColor 决定默认按钮、状态色等 Material 派生色。
    final colorScheme = ColorScheme.fromSeed(
      // 使用品牌亮绿色作为 Material ColorScheme 的种子色。
      seedColor: GenesisColors.brandBright,
      // 当前产品视觉是浅色背景，所以固定为 Brightness.light。
      brightness: Brightness.light,
    );

    return ThemeData(
      // 交给 Flutter Material 组件读取的标准色彩体系。
      colorScheme: colorScheme,
      // 页面默认背景色；Scaffold 未单独设置时会使用这里。
      scaffoldBackgroundColor: GenesisColors.surface,
      // App 标准 TextTheme；普通 Text 可以通过 Theme.of(context).textTheme 读取。
      textTheme: GenesisTypography.textTheme,
      // 保持 Material 3，避免新旧 Material 默认样式混用。
      useMaterial3: true,
      // FilledButton 的全局默认样式；GenesisPrimaryButton 也会继承这套按钮风格。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 主按钮可点击状态背景色。
          backgroundColor: GenesisColors.brand,
          // 主按钮 disabled 状态背景色。
          disabledBackgroundColor: GenesisColors.brandSoft,
          // 主按钮文字/图标前景色。
          foregroundColor: GenesisColors.surface,
          // 按钮统一使用 8dp 圆角；局部按钮如有特殊尺寸也应保持这个圆角规则。
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
          // 主按钮默认文字样式。
          textStyle: GenesisTypography.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
        ),
      ),
      // TextField/InputDecorator 的默认输入框样式；GenesisSearchField 的可编辑模式会复用其中一部分。
      inputDecorationTheme: const InputDecorationTheme(
        // 输入框默认不画 Material 边框，外层容器负责背景和圆角。
        border: InputBorder.none,
        // 压缩 TextField 内部默认高度，避免搜索框被 Material 默认 padding 撑高。
        isCollapsed: true,
        // 输入框 placeholder 默认样式。
        hintStyle: TextStyle(
          color: GenesisColors.textDisabled,
          fontSize: 14,
          letterSpacing: 0,
        ),
      ),
      // 自定义 Genesis UI 组件的主题扩展。
      // SearchField、PageTitle、BottomNavigation、TabBar 等会优先从这里读取样式。
      extensions: <ThemeExtension<dynamic>>[GenesisUiTheme.light()],
    );
  }
}
