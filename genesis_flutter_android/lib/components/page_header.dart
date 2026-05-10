import 'package:flutter/material.dart';

import '../routers/app_router.dart';
import 'search_bar.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.pageName,
    this.horizontalPadding = 16,
    this.topPadding = 8,
  });

  final String pageName;
  final double horizontalPadding;
  final double topPadding;

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
            Text(
              pageName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            SearchBarPlaceholder(
              hintText: 'Search origins, worlds, users...',
              onTap: () {
                Navigator.of(context).pushNamed(RouteNames.search);
              },
            ),
          ],
        ),
      ),
    );
  }
}
