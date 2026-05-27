import 'package:flutter/material.dart';

import '../../components/page_header.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GenesisBackAppBar(pageName: 'About us'),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Text(
            'Thanks for using Genesis Beta. More about us will appear here.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF3E3E3E),
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}
