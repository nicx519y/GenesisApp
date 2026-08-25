import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_bottom_sheet.dart';
import 'genesis_modal_border.dart';
import 'genesis_primary_button.dart';

enum GenesisDialogVariant { confirmation, destructive, content, actionList }

class GenesisDialogAction {
  const GenesisDialogAction({
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.variant = GenesisButtonVariant.primary,
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final GenesisButtonVariant variant;
  final bool enabled;
  final bool isLoading;
}

class GenesisDialog extends StatelessWidget {
  const GenesisDialog({
    super.key,
    required this.title,
    required this.content,
    this.variant = GenesisDialogVariant.content,
    this.actions = const <GenesisDialogAction>[],
    this.onClose,
    this.showCloseButton = false,
    this.padding = const EdgeInsets.all(GenesisSpacing.pageWide),
    this.maxWidth = 420,
    this.titleStyle,
    this.showBorder = true,
  }) : assert(
         actions.length <= 3,
         'Use GenesisBottomSheetPanel when there are more than three actions.',
       );

  final String title;
  final Widget content;
  final GenesisDialogVariant variant;
  final List<GenesisDialogAction> actions;
  final VoidCallback? onClose;
  final bool showCloseButton;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  /// Overrides the default navigation-title tier (17/w800) for dialogs whose
  /// heading should sit lighter.
  final TextStyle? titleStyle;

  /// The 14% modal hairline. Passive wait surfaces drop it - they present no
  /// actions, so the outline only adds chrome.
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.all(GenesisSpacing.pageWide),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: showBorder ? genesisModalBorder(context) : null,
          ),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style:
                            titleStyle ??
                            GenesisTypography.navigationTitle.copyWith(
                              color: colors.textPrimary,
                            ),
                      ),
                    ),
                    if (showCloseButton)
                      GenesisBottomSheetCloseButton(onPressed: onClose),
                  ],
                ),
                const SizedBox(height: GenesisSpacing.xl),
                content,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: GenesisSpacing.pageWide),
                  _buildActions(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (variant == GenesisDialogVariant.actionList) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            SizedBox(
              height: 51,
              width: double.infinity,
              child: TextButton(
                key: actions[index].buttonKey,
                onPressed: actions[index].enabled
                    ? actions[index].onPressed
                    : null,
                child: Text(actions[index].label),
              ),
            ),
            if (index != actions.length - 1)
              Divider(height: 1, color: context.genesisColors.dividerAction),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          GenesisButton(
            key: actions[index].buttonKey,
            label: actions[index].label,
            variant: variant == GenesisDialogVariant.destructive && index == 0
                ? GenesisButtonVariant.destructive
                : actions[index].variant,
            onPressed: actions[index].enabled ? actions[index].onPressed : null,
            isLoading: actions[index].isLoading,
          ),
          if (index != actions.length - 1)
            const SizedBox(height: GenesisSpacing.md),
        ],
      ],
    );
  }
}
