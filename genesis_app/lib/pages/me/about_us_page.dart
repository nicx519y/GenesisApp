import '../../l10n/genesis_l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/common/genesis_center_toast.dart';
import '../../components/page_header.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../routers/app_router.dart';
import '../../ui/genesis_ui.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/theme/genesis_dark_theme.dart';
import '../legal/legal_document_page.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const _fallbackAppVersion = 'v1.0.0';
  static const _contactEmail = 'worldodeveloper@gmail.com';

  static String versionLabel(String versionName) {
    final trimmed = versionName.trim();
    return trimmed.isEmpty ? _fallbackAppVersion : 'v$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return GenesisDarkTheme(
      child: GenesisBottomSystemBarStyleScope(
        style: const GenesisBottomSystemBarStyle(
          color: GenesisColors.darkBackground,
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: kGenesisLightSystemUiOverlayStyle,
          child: Scaffold(
            backgroundColor: GenesisColors.darkBackground,
            appBar: GenesisBackAppBar(
              backgroundColor: GenesisColors.darkBackground,
              foregroundColor: GenesisColors.darkTextPrimary,
              systemOverlayStyle: kGenesisLightSystemUiOverlayStyle,
              pageName: GenesisL10n.current.meAbout,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                      children: [
                        const _AboutBrandHeader(),
                        const SizedBox(height: 8),
                        const _AboutVersionText(),
                        const SizedBox(height: 34),
                        const _AboutDescription(),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _AboutLegalLinks(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutVersionText extends StatelessWidget {
  const _AboutVersionText();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppVersionInfo>(
      future: AppMetadataService.appVersion(),
      builder: (context, snapshot) {
        final versionName = snapshot.data?.versionName.trim() ?? '';

        return Text(
          AboutUsPage.versionLabel(versionName),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: GenesisColors.darkTextTertiary,
          ),
        );
      },
    );
  }
}

class _AboutDescription extends StatefulWidget {
  const _AboutDescription();

  @override
  State<_AboutDescription> createState() => _AboutDescriptionState();
}

class _AboutDescriptionState extends State<_AboutDescription> {
  late final TapGestureRecognizer _emailRecognizer;

  @override
  void initState() {
    super.initState();
    _emailRecognizer = TapGestureRecognizer()..onTap = _copyEmail;
  }

  @override
  void dispose() {
    _emailRecognizer.dispose();
    super.dispose();
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(
      const ClipboardData(text: AboutUsPage._contactEmail),
    );
    if (mounted)
      showGenesisToast(
        context,
        GenesisL10n
            .current
            .meEmailCopied,
      );
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
      fontSize: 15,
      height: 1.55,
      fontWeight: FontWeight.w400,
      color: GenesisColors.darkTextSecondary,
    );
    final emailStyle = bodyStyle.copyWith(
      color: GenesisColors.darkTextPrimary,
      fontWeight: FontWeight.w600,
    );

    return GenesisLocalizedRichText(
      template: context.l10n.aboutDescription(
        contactEmail: GenesisLocalizedRichText.placeholder('contactEmail'),
      ),
      placeholders: {
        'contactEmail': TextSpan(
          text: AboutUsPage._contactEmail,
          style: emailStyle,
          recognizer: _emailRecognizer,
        ),
      },
      style: bodyStyle,
      textAlign: TextAlign.left,
    );
  }
}

class _AboutBrandHeader extends StatelessWidget {
  const _AboutBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/app_icon.png',
          key: const Key('about_genesis_launch_logo'),
          width: 96,
          height: 96,
          fit: BoxFit.contain,
          semanticLabel: 'Worldo',
        ),
      ),
    );
  }
}

class _AboutLegalLinks extends StatefulWidget {
  const _AboutLegalLinks();

  @override
  State<_AboutLegalLinks> createState() => _AboutLegalLinksState();
}

class _AboutLegalLinksState extends State<_AboutLegalLinks> {
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _eulaRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openDocument(LegalDocument.privacy);
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openDocument(LegalDocument.terms);
    _eulaRecognizer = TapGestureRecognizer()
      ..onTap = () => _openDocument(LegalDocument.eula);
  }

  @override
  void dispose() {
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    _eulaRecognizer.dispose();
    super.dispose();
  }

  void _openDocument(LegalDocument document) {
    Navigator.of(
      context,
    ).pushNamed(RouteNames.legal, arguments: {'document': document.name});
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
      fontSize: 11,
      height: 1.35,
      color: GenesisColors.darkTextTertiary,
      fontWeight: FontWeight.w400,
    );
    const linkStyle = TextStyle(
      fontSize: 11,
      height: 1.35,
      color: GenesisColors.darkTextSecondary,
      fontWeight: FontWeight.w600,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: GenesisLocalizedRichText(
        template: context.l10n.legalLinksSentence(
          privacyPolicy: GenesisLocalizedRichText.placeholder('privacyPolicy'),
          termsOfUse: GenesisLocalizedRichText.placeholder('termsOfUse'),
          endUserLicenseAgreement: GenesisLocalizedRichText.placeholder(
            'endUserLicenseAgreement',
          ),
        ),
        placeholders: {
          'privacyPolicy': TextSpan(
            text: context.l10n.privacyPolicy,
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          'termsOfUse': TextSpan(
            text: context.l10n.termsOfUse,
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          'endUserLicenseAgreement': TextSpan(
            text: context.l10n.endUserLicenseAgreement,
            style: linkStyle,
            recognizer: _eulaRecognizer,
          ),
        },
        style: bodyStyle,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.left,
      ),
    );
  }
}
