import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/page_header.dart';

enum LegalDocument {
  terms(
    title: 'Terms of Service',
    assetPath: 'assets/legal/terms_of_service.md',
  ),
  privacy(title: 'Privacy Policy', assetPath: 'assets/legal/privacy_policy.md'),
  eula(title: 'EULA', assetPath: 'assets/legal/eula.md');

  const LegalDocument({required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  static LegalDocument fromRouteValue(String value) {
    return LegalDocument.values.firstWhere(
      (item) => item.name == value,
      orElse: () => LegalDocument.terms,
    );
  }
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GenesisBackAppBar(pageName: document.title),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(document.assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final text = snapshot.data;
            if (snapshot.hasError || text == null) {
              return const Center(child: Text('Load failed'));
            }
            return _LegalMarkdownView(markdown: text);
          },
        ),
      ),
    );
  }
}

class _LegalMarkdownView extends StatelessWidget {
  const _LegalMarkdownView({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseMarkdown(markdown);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: blocks.length,
      itemBuilder: (context, index) => blocks[index],
    );
  }
}

List<Widget> _parseMarkdown(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final blocks = <Widget>[];
  final paragraph = <String>[];
  final bullets = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(_LegalParagraph(text: paragraph.join(' ')));
    paragraph.clear();
  }

  void flushBullets() {
    if (bullets.isEmpty) return;
    blocks.add(_LegalBulletList(items: List<String>.from(bullets)));
    bullets.clear();
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushParagraph();
      flushBullets();
      continue;
    }

    if (line.startsWith('# ')) {
      flushParagraph();
      flushBullets();
      blocks.add(_LegalHeading(text: line.substring(2), level: 1));
      continue;
    }
    if (line.startsWith('## ')) {
      flushParagraph();
      flushBullets();
      blocks.add(_LegalHeading(text: line.substring(3), level: 2));
      continue;
    }
    if (line.startsWith('### ')) {
      flushParagraph();
      flushBullets();
      blocks.add(_LegalHeading(text: line.substring(4), level: 3));
      continue;
    }
    if (line.startsWith('- ')) {
      flushParagraph();
      bullets.add(line.substring(2));
      continue;
    }

    flushBullets();
    paragraph.add(line);
  }

  flushParagraph();
  flushBullets();
  return blocks;
}

class _LegalHeading extends StatelessWidget {
  const _LegalHeading({required this.text, required this.level});

  final String text;
  final int level;

  @override
  Widget build(BuildContext context) {
    final style = switch (level) {
      1 => const TextStyle(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111111),
      ),
      2 => const TextStyle(
        fontSize: 17,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
      _ => const TextStyle(
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: Color(0xFF242424),
      ),
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 4 : 18, bottom: 9),
      child: Text(text, style: style),
    );
  }
}

class _LegalParagraph extends StatelessWidget {
  const _LegalParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          style: _legalBodyStyle,
          children: _inlineSpans(text, _legalBodyStyle),
        ),
      ),
    );
  }
}

class _LegalBulletList extends StatelessWidget {
  const _LegalBulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: SizedBox.square(
                      dimension: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF3E3E3E),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: _legalBodyStyle,
                        children: _inlineSpans(item, _legalBodyStyle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

const _legalBodyStyle = TextStyle(
  fontSize: 14,
  height: 1.48,
  color: Color(0xFF333333),
  fontWeight: FontWeight.w400,
);

List<InlineSpan> _inlineSpans(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  var index = 0;
  final boldPattern = RegExp(r'\*\*(.+?)\*\*');
  for (final match in boldPattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(TextSpan(text: text.substring(index, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index)));
  }
  return spans;
}
