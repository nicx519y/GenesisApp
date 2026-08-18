import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_spacing.dart';
import 'genesis_page_title.dart';
import 'genesis_safe_area.dart';
import 'genesis_search_field.dart';

const double kGenesisTopBarHeight = 50;

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
  Size get preferredSize => const Size.fromHeight(kGenesisTopBarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return AppBar(
      toolbarHeight: kGenesisTopBarHeight,
      backgroundColor: colors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: systemOverlayStyle,
      centerTitle: true,
      leadingWidth: 37,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            constraints: const BoxConstraints.tightFor(width: 17, height: 17),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: colors.navigationSelected,
              size: 17,
            ),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      title: GestureDetector(
        key: titleKey,
        behavior: HitTestBehavior.translucent,
        onTap: onTitleTap,
        child: GenesisPageTitle(text: pageName, style: titleStyle),
      ),
      actions: actions,
    );
  }
}
