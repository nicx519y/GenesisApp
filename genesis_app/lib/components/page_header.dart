import 'package:flutter/material.dart';

import '../routers/app_router.dart';
import '../ui/genesis_ui.dart';
import 'search_bar.dart';

const double kGenesisTopBarHeight = 50;

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.pageName,
    this.horizontalPadding = 16,
    this.topPadding = 0,
    this.showSearchBar = true,
  });

  final String pageName;
  final double horizontalPadding;
  final double topPadding;
  final bool showSearchBar;

  @override
  Widget build(BuildContext context) {
    return GenesisTopSafeArea(
      backgroundColor: Colors.white,
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
              child: Center(child: GenesisPageTitle(text: pageName)),
            ),
            if (showSearchBar) ...[
              SearchBarPlaceholder(
                onTap: () {
                  Navigator.of(context).pushNamed(RouteNames.search);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PageTitleText extends StatelessWidget {
  const PageTitleText({super.key, required this.pageName});

  final String pageName;

  @override
  Widget build(BuildContext context) {
    return GenesisPageTitle(text: pageName);
  }
}

class GenesisBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GenesisBackAppBar({
    super.key,
    required this.pageName,
    this.onBack,
    this.actions,
  });

  final String pageName;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kGenesisTopBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: kGenesisTopBarHeight,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leadingWidth: 37,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            constraints: const BoxConstraints.tightFor(width: 17, height: 17),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black,
              size: 17,
            ),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      title: PageTitleText(pageName: pageName),
      actions: actions,
    );
  }
}
