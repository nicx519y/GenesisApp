import 'package:flutter/widgets.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_typography.dart';

class GenesisPageTitle extends StatelessWidget {
  const GenesisPageTitle({
    super.key,
    required this.text,
    this.style,
    this.textKey,
  });

  final String text;
  final TextStyle? style;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: textKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GenesisTypography.pageTitle
          .copyWith(color: context.genesisColors.textPrimary)
          .merge(style),
    );
  }
}

class GenesisDisplayTitle extends StatelessWidget {
  const GenesisDisplayTitle({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: GenesisTypography.displayTitle
          .copyWith(color: context.genesisColors.textPrimary)
          .merge(style),
    );
  }
}

enum GenesisMetricValueSize { regular, prominent }

class GenesisMetricValueText extends StatelessWidget {
  const GenesisMetricValueText({
    super.key,
    required this.value,
    this.size = GenesisMetricValueSize.regular,
    this.style,
    this.maxLines = 1,
    this.textKey,
  });

  final String value;
  final GenesisMetricValueSize size;
  final TextStyle? style;
  final int maxLines;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final baseStyle = switch (size) {
      GenesisMetricValueSize.regular => GenesisTypography.metricValue,
      GenesisMetricValueSize.prominent =>
        GenesisTypography.prominentMetricValue,
    };
    return Text(
      value,
      key: textKey,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: baseStyle
          .copyWith(color: context.genesisColors.textPrimary)
          .merge(style),
    );
  }
}
