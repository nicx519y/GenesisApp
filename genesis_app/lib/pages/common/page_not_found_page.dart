import 'package:flutter/material.dart';

import '../../ui/components/genesis_page_scaffold.dart';

class PageNotFoundPage extends StatelessWidget {
  const PageNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const GenesisPageScaffold.secondary(
      title: '',
      body: Center(child: Text('Page not found.')),
    );
  }
}
