import 'package:flutter/material.dart';

import '../../ui/components/genesis_page_header.dart';

class PageNotFoundPage extends StatelessWidget {
  const PageNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GenesisBackAppBar(pageName: ''),
      body: const Center(child: Text('Page not found.')),
    );
  }
}
