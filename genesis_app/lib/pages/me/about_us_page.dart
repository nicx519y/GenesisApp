import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/common/genesis_center_toast.dart';
import '../../components/page_header.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../routers/app_router.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../legal/legal_document_page.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const _appVersion = 'v1.0.0';
  static const _descriptionBeforeEmail =
      'Worldo lets you create, discover, and enter AI-powered worlds filled '
      'with characters, stories, and evolving events. Chat with AI characters, '
      'play with friends, and progress each world through immersive scenes and '
      'choices.\n\n'
      'Our app offers a new way to experience interactive stories — not just '
      'as a reader, but as someone inside the world. If you have any questions, '
      'please contact us at ';
  static const _contactEmail = 'worldodeveloper@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'About'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
                children: [
                  FutureBuilder<String>(
                    future: AppMetadataService.appName(),
                    builder: (context, snapshot) {
                      return _AboutBrandHeader(appName: snapshot.data ?? 'App');
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    _appVersion,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 34),
                  const _AboutDescription(),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _AboutLegalLinks(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
    if (mounted) showGenesisToast(context, 'Email copied');
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
      fontSize: 15,
      height: 1.55,
      fontWeight: FontWeight.w400,
      color: Color(0xFF333333),
    );
    final emailStyle = bodyStyle.copyWith(
      color: const Color(0xFF3E5B8A),
      fontWeight: FontWeight.w500,
    );

    return Text.rich(
      TextSpan(
        style: bodyStyle,
        children: [
          const TextSpan(text: AboutUsPage._descriptionBeforeEmail),
          TextSpan(
            text: AboutUsPage._contactEmail,
            style: emailStyle,
            recognizer: _emailRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.left,
    );
  }
}

class _AboutBrandHeader extends StatelessWidget {
  const _AboutBrandHeader({required this.appName});

  final String appName;

  static const _nameStyle = TextStyle(
    fontSize: 28,
    height: 1.18,
    fontWeight: FontWeight.w700,
    color: Color(0xFF111111),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const iconSize = 42.0;
        const iconGap = 12.0;
        final textPainter = TextPainter(
          text: TextSpan(text: appName, style: _nameStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final textLeft = (constraints.maxWidth - textPainter.width) / 2;
        final maxIconLeft = constraints.maxWidth - iconSize;
        final iconLeft = (textLeft - iconGap - iconSize).clamp(
          0.0,
          maxIconLeft,
        );

        return SizedBox(
          height: iconSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(appName, style: _nameStyle),
              Positioned(
                left: iconLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/images/genesis_app_icon_source_1024.png',
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      color: Color(0xFF6F6F6F),
      fontWeight: FontWeight.w400,
    );
    const linkStyle = TextStyle(
      fontSize: 11,
      height: 1.35,
      color: GenesisColors.brand,
      fontWeight: FontWeight.w500,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          style: bodyStyle,
          children: [
            TextSpan(
              text: 'Privacy Policy',
              style: linkStyle,
              recognizer: _privacyRecognizer,
            ),
            const TextSpan(text: ' , '),
            TextSpan(
              text: 'Terms of Use',
              style: linkStyle,
              recognizer: _termsRecognizer,
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'End User License Agreement',
              style: linkStyle,
              recognizer: _eulaRecognizer,
            ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.left,
      ),
    );
  }
}
