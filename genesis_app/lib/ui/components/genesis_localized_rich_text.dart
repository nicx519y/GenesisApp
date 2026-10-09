import 'package:flutter/material.dart';

/// Builds rich text from one localizable sentence template.
///
/// Placeholders use `{placeholderName}` syntax. Callers provide the matching
/// [InlineSpan], which can be a styled [TextSpan], a clickable [TextSpan], or a
/// [WidgetSpan]. Keeping the surrounding sentence in one template lets each
/// locale move placeholders without changing the widget implementation.
class GenesisLocalizedRichText extends StatelessWidget {
  const GenesisLocalizedRichText({
    super.key,
    required this.template,
    required this.placeholders,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String template;
  final Map<String, InlineSpan> placeholders;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// Marker passed into a generated localization method for a styled value.
  ///
  /// Example:
  /// `l10n.title(GenesisLocalizedRichText.placeholder('worldo'))`.
  static String placeholder(String name) => '{$name}';

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      buildGenesisLocalizedTextSpan(
        template: template,
        placeholders: placeholders,
      ),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

final RegExp _genesisRichTextPlaceholderPattern = RegExp(
  r'\{([A-Za-z_][A-Za-z0-9_]*)\}',
);

/// Parses a localized template into a [TextSpan] while preserving the order
/// chosen by that locale.
TextSpan buildGenesisLocalizedTextSpan({
  required String template,
  required Map<String, InlineSpan> placeholders,
  TextStyle? style,
}) {
  final children = <InlineSpan>[];
  final usedPlaceholders = <String>{};
  var offset = 0;

  for (final match in _genesisRichTextPlaceholderPattern.allMatches(template)) {
    if (match.start > offset) {
      children.add(TextSpan(text: template.substring(offset, match.start)));
    }

    final name = match.group(1)!;
    final replacement = placeholders[name];
    assert(() {
      if (replacement == null) {
        throw FlutterError(
          'Missing rich-text placeholder "$name" for template "$template".',
        );
      }
      return true;
    }());
    children.add(replacement ?? TextSpan(text: match.group(0)));
    usedPlaceholders.add(name);
    offset = match.end;
  }

  if (offset < template.length) {
    children.add(TextSpan(text: template.substring(offset)));
  }

  assert(() {
    final unused = placeholders.keys
        .where((name) => !usedPlaceholders.contains(name))
        .toList(growable: false);
    if (unused.isNotEmpty) {
      throw FlutterError(
        'Unused rich-text placeholders ${unused.join(', ')} for template '
        '"$template".',
      );
    }
    return true;
  }());

  return TextSpan(style: style, children: children);
}
