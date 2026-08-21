import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

import 'genesis_center_toast.dart';

class CopyableIdLabel extends StatelessWidget {
  const CopyableIdLabel({
    super.key,
    required this.label,
    required this.value,
    this.displayValue,
    this.showCopyIcon = true,
    this.enabled = true,
    this.customTextStyle,
    this.customIconColor,
  });

  static const TextStyle textStyle = TextStyle(
    fontSize: 12,
    height: 1.1,
    fontWeight: FontWeight.w400,
  );

  final String label;
  final String value;
  final String? displayValue;
  final bool showCopyIcon;
  final bool enabled;
  final TextStyle? customTextStyle;
  final Color? customIconColor;

  @override
  Widget build(BuildContext context) {
    final resolvedDisplayValue = displayValue ?? formatCopyableIdValue(value);
    final normalizedLabel = label.trim().toUpperCase();
    return GenesisInlineMetaLabel(
      text: '$normalizedLabel: $resolvedDisplayValue',
      onTap: enabled
          ? () => _copy(context, resolvedDisplayValue, normalizedLabel)
          : null,
      style:
          customTextStyle ??
          CopyableIdLabel.textStyle.copyWith(
            color: context.genesisColors.textMuted,
          ),
      trailingIcon: enabled && showCopyIcon ? Icons.copy_outlined : null,
      trailingIconColor: customIconColor ?? context.genesisColors.textMuted,
      trailingGap: 6,
    );
  }

  Future<void> _copy(
    BuildContext context,
    String displayValue,
    String normalizedLabel,
  ) async {
    await Clipboard.setData(ClipboardData(text: displayValue));
    if (!context.mounted) return;
    showGenesisToast(context, '$normalizedLabel copied');
  }
}

class GenesisInlineMetaLabel extends StatelessWidget {
  const GenesisInlineMetaLabel({
    super.key,
    required this.text,
    this.onTap,
    this.style,
    this.textAlign = TextAlign.left,
    this.trailingIcon,
    this.trailingIconColor,
    this.trailingIconSize = 16,
    this.trailingGap = 4,
  });

  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;
  final TextAlign textAlign;
  final IconData? trailingIcon;
  final Color? trailingIconColor;
  final double trailingIconSize;
  final double trailingGap;

  @override
  Widget build(BuildContext context) {
    final trailingIcon = this.trailingIcon;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: SizedBox(
          height: trailingIconSize,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  text,
                  textAlign: textAlign,
                  style:
                      style ??
                      CopyableIdLabel.textStyle.copyWith(
                        color: context.genesisColors.textMuted,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                SizedBox(width: trailingGap),
                Icon(
                  trailingIcon,
                  size: trailingIconSize,
                  color: trailingIconColor ?? context.genesisColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String formatCopyableIdValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '-';
  return trimmed.substring(0, 1).toLowerCase() + trimmed.substring(1);
}
