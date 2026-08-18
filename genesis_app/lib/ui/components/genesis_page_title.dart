import 'package:flutter/widgets.dart';

import '../theme/genesis_ui_theme.dart';

class GenesisPageTitle extends StatelessWidget {
  const GenesisPageTitle({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GenesisUiTheme.of(context).pageTitleStyle.merge(style),
    );
  }
}
