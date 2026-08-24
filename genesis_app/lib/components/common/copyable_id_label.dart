import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../ui/theme/genesis_semantic_colors.dart';
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
    this.copyIconAsset,
    this.copyIconSize,
    this.trailingGap = 6,
  });

  static const TextStyle textStyle = TextStyle(
    fontSize: 13,
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

  /// 传了就用这张 SVG 代替 Material 的 copy 图标,给按设计稿取图的页面用。
  final String? copyIconAsset;
  final double? copyIconSize;
  final double trailingGap;

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
      trailingIcon: enabled && showCopyIcon && copyIconAsset == null
          ? Icons.copy_outlined
          : null,
      trailingIconAsset: enabled && showCopyIcon ? copyIconAsset : null,
      trailingIconColor: customIconColor ?? context.genesisColors.textMuted,
      trailingIconSize: copyIconSize ?? 16,
      trailingGap: trailingGap,
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
    this.trailingIconAsset,
    this.trailingIconColor,
    this.trailingIconSize = 16,
    this.trailingGap = 4,
  });

  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;
  final TextAlign textAlign;
  final IconData? trailingIcon;

  /// SVG 尾图标。与 [trailingIcon] 二选一,同时给时以 SVG 为准。
  final String? trailingIconAsset;
  final Color? trailingIconColor;
  final double trailingIconSize;
  final double trailingGap;

  @override
  Widget build(BuildContext context) {
    final trailingIcon = this.trailingIcon;
    final trailingIconAsset = this.trailingIconAsset;
    final trailingColor = trailingIconColor ?? context.genesisColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        // 用 minHeight 而不是定高:图标比文字矮时(9.5px 正文配 10px 图钉)
        // 定高会把文字行挤出容器。
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: trailingIconSize),
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
              if (trailingIconAsset != null) ...[
                SizedBox(width: trailingGap),
                SvgPicture.asset(
                  trailingIconAsset,
                  width: trailingIconSize,
                  height: trailingIconSize,
                  colorFilter: ColorFilter.mode(trailingColor, BlendMode.srcIn),
                ),
              ] else if (trailingIcon != null) ...[
                SizedBox(width: trailingGap),
                Icon(
                  trailingIcon,
                  size: trailingIconSize,
                  color: trailingColor,
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
