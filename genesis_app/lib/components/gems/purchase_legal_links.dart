import 'package:flutter/material.dart';

import '../../l10n/genesis_localizations.dart';
import '../../routers/app_router.dart' show RouteNames;
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';

class PurchaseLegalLinks extends StatelessWidget {
  const PurchaseLegalLinks({super.key});

  static const double bottomSpacing = 10;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = GenesisTypography.resolve(
      context,
      const TextStyle(
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w400,
        color: GenesisColors.darkTextTertiary,
      ),
    );

    Widget link(String document, String label) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).pushNamed(RouteNames.legal, arguments: {'document': document}),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x33FFFFFF))),
        ),
        child: Text(label, style: style),
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        link('privacy', l10n.privacyPolicy),
        Text('&', style: style),
        link('terms', l10n.termsOfService),
        Text('&', style: style),
        link('eula', l10n.eulaShort),
      ],
    );
  }
}
