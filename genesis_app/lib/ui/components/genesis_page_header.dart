import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_spacing.dart';
import 'genesis_app_bar.dart';
import 'genesis_page_title.dart';
import 'genesis_safe_area.dart';
import 'genesis_search_field.dart';

const double kGenesisTopBarHeight = 50;

class GenesisLargePageHeader extends StatelessWidget {
  const GenesisLargePageHeader({
    super.key,
    required this.title,
    this.titleKey,
    this.trailing,
    this.horizontalPadding = 20,
    this.topPadding = 20,
    this.bottomPadding = 18,
    this.backgroundColor,
  });

  final String title;
  final Key? titleKey;
  final Widget? trailing;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GenesisTopSafeArea(
      backgroundColor: backgroundColor ?? context.genesisColors.pageBackground,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topPadding,
          horizontalPadding,
          bottomPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: GenesisPageTitle(text: title, textKey: titleKey),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class GenesisPageHeader extends StatelessWidget {
  const GenesisPageHeader({
    super.key,
    required this.title,
    this.horizontalPadding = GenesisSpacing.page,
    this.topPadding = 0,
    this.showSearchField = true,
    this.searchHintText = 'Explore',
    this.onSearchTap,
    this.trailing,
  });

  final String title;
  final double horizontalPadding;
  final double topPadding;
  final bool showSearchField;
  final String searchHintText;
  final VoidCallback? onSearchTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GenesisTopSafeArea(
      backgroundColor: context.genesisColors.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topPadding,
          horizontalPadding,
          0,
        ),
        child: Column(
          children: [
            SizedBox(
              height: kGenesisTopBarHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(child: GenesisPageTitle(text: title)),
                  if (trailing != null)
                    Align(alignment: Alignment.centerRight, child: trailing),
                ],
              ),
            ),
            if (showSearchField)
              GenesisSearchField(
                variant: GenesisSearchFieldVariant.compact,
                hintText: searchHintText,
                onTap: onSearchTap,
              ),
          ],
        ),
      ),
    );
  }
}

class GenesisBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GenesisBackAppBar({
    super.key,
    required this.pageName,
    this.onBack,
    this.actions,
    this.titleKey,
    this.onTitleTap,
    this.titleStyle,
    this.systemOverlayStyle,
  });

  final String pageName;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Key? titleKey;
  final VoidCallback? onTitleTap;
  final TextStyle? titleStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return GenesisAppBar(
      title: pageName,
      variant: GenesisAppBarVariant.leadingTitle,
      onBack: onBack,
      actions: actions,
      titleKey: titleKey,
      onTitleTap: onTitleTap,
      titleStyle: titleStyle,
      systemOverlayStyle: systemOverlayStyle,
    );
  }
}
