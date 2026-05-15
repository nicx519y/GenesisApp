import 'package:flutter/material.dart';

import '../tokens/genesis_spacing.dart';
import '../theme/genesis_ui_theme.dart';

class GenesisPrimaryButton extends StatelessWidget {
  const GenesisPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: uiTheme.panelBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: GenesisSpacing.page),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
