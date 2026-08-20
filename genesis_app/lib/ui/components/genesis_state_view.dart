import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_primary_button.dart';

enum GenesisLoadingIndicatorVariant { page, section, inline, loadMore }

class GenesisLoadingIndicator extends StatelessWidget {
  const GenesisLoadingIndicator({
    super.key,
    this.variant = GenesisLoadingIndicatorVariant.page,
    this.color,
    this.indicatorKey,
  });

  final GenesisLoadingIndicatorVariant variant;
  final Color? color;
  final Key? indicatorKey;

  @override
  Widget build(BuildContext context) {
    final (size, strokeWidth) = switch (variant) {
      GenesisLoadingIndicatorVariant.page => (24.0, 2.5),
      GenesisLoadingIndicatorVariant.section => (20.0, 2.0),
      GenesisLoadingIndicatorVariant.inline => (16.0, 2.0),
      GenesisLoadingIndicatorVariant.loadMore => (18.0, 2.0),
    };
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        key: indicatorKey,
        strokeWidth: strokeWidth,
        color: color ?? context.genesisColors.primary,
      ),
    );
  }
}

enum _GenesisStateViewKind { loading, error, empty }

class GenesisStateView extends StatelessWidget {
  const GenesisStateView.loading({
    super.key,
    this.height,
    this.progressColor,
    this.loadingVariant = GenesisLoadingIndicatorVariant.page,
  }) : _kind = _GenesisStateViewKind.loading,
       message = null,
       actionLabel = null,
       onAction = null,
       compact = false,
       textStyle = null,
       actionSpacing = 12,
       horizontalPadding = 0;

  const GenesisStateView.error({
    super.key,
    required this.message,
    required this.onAction,
    this.actionLabel = 'Retry',
    this.height,
    this.compact = false,
    this.textStyle,
    this.actionSpacing = 12,
    this.horizontalPadding = 0,
  }) : _kind = _GenesisStateViewKind.error,
       progressColor = null,
       loadingVariant = GenesisLoadingIndicatorVariant.page;

  const GenesisStateView.empty({
    super.key,
    required this.message,
    this.height,
    this.compact = false,
    this.textStyle,
    this.horizontalPadding = 0,
  }) : _kind = _GenesisStateViewKind.empty,
       actionLabel = null,
       onAction = null,
       progressColor = null,
       loadingVariant = GenesisLoadingIndicatorVariant.page,
       actionSpacing = 12;

  final _GenesisStateViewKind _kind;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double? height;
  final bool compact;
  final TextStyle? textStyle;
  final Color? progressColor;
  final GenesisLoadingIndicatorVariant loadingVariant;
  final double actionSpacing;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_kind == _GenesisStateViewKind.loading) {
      content = GenesisLoadingIndicator(
        variant: loadingVariant,
        color: progressColor,
      );
    } else {
      final effectiveStyle =
          textStyle ??
          (compact
                  ? GenesisTypography.supporting
                  : GenesisTypography.bodyStrong)
              .copyWith(color: context.genesisColors.textBody);
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message!, textAlign: TextAlign.center, style: effectiveStyle),
          if (_kind == _GenesisStateViewKind.error) ...[
            SizedBox(height: compact ? 8 : actionSpacing),
            GenesisButton(
              label: actionLabel!,
              onPressed: onAction,
              size: GenesisButtonSize.compact,
              fullWidth: false,
            ),
          ],
        ],
      );
    }
    final centered = Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: content,
      ),
    );
    return height == null
        ? centered
        : SizedBox(height: height, child: centered);
  }
}
