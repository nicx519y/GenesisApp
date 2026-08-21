import 'package:flutter/material.dart';

import '../../ui/genesis_ui.dart';

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
