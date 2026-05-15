import 'package:flutter/material.dart';

import '../routers/app_router.dart';
import '../ui/genesis_ui.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.pageName,
    this.horizontalPadding = 16,
    this.topPadding = 8,
    this.showSearchBar = true,
  });

  final String pageName;
  final double horizontalPadding;
  final double topPadding;
  final bool showSearchBar;

  @override
  Widget build(BuildContext context) {
    return GenesisPageHeader(
      title: pageName,
      horizontalPadding: horizontalPadding,
      topPadding: topPadding,
      showSearchField: showSearchBar,
      onSearchTap: () {
        Navigator.of(context).pushNamed(RouteNames.search);
      },
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
