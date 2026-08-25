import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/genesis_semantic_colors.dart';
import '../theme/genesis_ui_theme.dart';
import '../tokens/genesis_typography.dart';
import '../tokens/genesis_control_metrics.dart';
import '../system/genesis_system_ui.dart';
import 'genesis_control_icons.dart';
import 'genesis_page_title.dart';

enum GenesisAppBarVariant { centered, leadingTitle, largeTitle }

class GenesisAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GenesisAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    this.variant = GenesisAppBarVariant.centered,
    this.onBack,
    this.backButtonKey,
    this.backForegroundColor,
    this.showBackButton = true,
    this.actions,
    this.titleKey,
    this.onTitleTap,
    this.titleStyle,
    this.backgroundColor,
    this.systemOverlayStyle,
    this.height,
    this.leadingWidth,
    this.titleSpacing,
  });

  final String title;

  /// 标题下的一行小字(仅非 centered 变体渲染),如版本号等页面级元信息。
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final GenesisAppBarVariant variant;
  final VoidCallback? onBack;
  final Key? backButtonKey;
  final Color? backForegroundColor;
  final bool showBackButton;
  final List<Widget>? actions;
  final Key? titleKey;
  final VoidCallback? onTitleTap;
  final TextStyle? titleStyle;
  final Color? backgroundColor;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final double? height;
  final double? leadingWidth;
  final double? titleSpacing;

  double get _defaultHeight => switch (variant) {
    GenesisAppBarVariant.centered => 50,
    GenesisAppBarVariant.leadingTitle => 64,
    GenesisAppBarVariant.largeTitle => 64,
  };

  @override
  Size get preferredSize => Size.fromHeight(height ?? _defaultHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final uiTheme = GenesisUiTheme.of(context);
    final effectiveHeight =
        height ??
        switch (variant) {
          GenesisAppBarVariant.centered => uiTheme.centeredAppBarHeight,
          GenesisAppBarVariant.leadingTitle => uiTheme.leadingTitleAppBarHeight,
          GenesisAppBarVariant.largeTitle => uiTheme.leadingTitleAppBarHeight,
        };
    final centered = variant == GenesisAppBarVariant.centered;
    final large = variant == GenesisAppBarVariant.largeTitle;
    // Bar titles are the one place the dark side keeps pure white; content
    // titles elsewhere sit a tier down, on soft white. foregroundStrong is
    // white on dark and ink on light, so both skins stay correct.
    final resolvedTitleStyle =
        titleStyle ??
        (large
            ? GenesisTypography.pageTitle.copyWith(
                color: colors.foregroundStrong,
              )
            : centered
            ? null
            : GenesisTypography.navigationTitle.copyWith(
                color: colors.foregroundStrong,
              ));

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: effectiveHeight,
      backgroundColor: backgroundColor ?? colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle:
          systemOverlayStyle ??
          GenesisSystemUi.forThemeBrightness(Theme.of(context).brightness),
      centerTitle: centered,
      leadingWidth: showBackButton
          ? (leadingWidth ??
                (centered
                    ? 54
                    : GenesisControlMetrics.appBarHorizontalPadding +
                          GenesisControlMetrics.backButtonVisualSize +
                          GenesisControlMetrics.appBarLeadingTitleGap))
          : 0,
      leading: showBackButton
          ? Padding(
              padding: const EdgeInsets.only(
                left: GenesisControlMetrics.appBarHorizontalPadding,
              ),
              child: Align(
                alignment: centered ? Alignment.center : Alignment.centerLeft,
                child: GenesisBackButton(
                  key: backButtonKey,
                  foregroundColor:
                      backForegroundColor ?? colors.navigationSelected,
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ),
            )
          : null,
      titleSpacing:
          titleSpacing ??
          (centered
              ? null
              : large
              ? GenesisControlMetrics.appBarHorizontalPadding
              : 0),
      title: GestureDetector(
        key: titleKey,
        behavior: HitTestBehavior.translucent,
        onTap: onTitleTap,
        child: centered
            ? GenesisPageTitle(text: title, style: resolvedTitleStyle)
            : subtitle == null || subtitle!.trim().isEmpty
            ? Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolvedTitleStyle,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolvedTitleStyle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        subtitleStyle ??
                        TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                          color: colors.textSecondary,
                        ),
                  ),
                ],
              ),
      ),
      actions: actions,
    );
  }
}
