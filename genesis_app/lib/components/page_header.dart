import 'package:flutter/material.dart';

import '../routers/app_router.dart';
import 'search_bar.dart';

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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topPadding,
          horizontalPadding,
          0,
        ),
        child: Column(
          children: [
            PageTitleText(pageName: pageName),
            if (showSearchBar) ...[
              const SizedBox(height: 6),
              SearchBarPlaceholder(
                hintText: 'Search origins, worlds, users...',
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
    return Text(
      pageName,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );
  }
}
