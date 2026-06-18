import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'genesis_center_toast.dart';

class CopyableIdLabel extends StatelessWidget {
  const CopyableIdLabel({
    super.key,
    required this.label,
    required this.value,
    this.displayValue,
    this.showCopyIcon = true,
    this.enabled = true,
  });

  static const TextStyle textStyle = TextStyle(
    fontSize: 12,
    height: 1.1,
    fontWeight: FontWeight.w400,
    color: Color(0xFF8A8A8A),
  );

  static const Color iconColor = Color(0xFF8A8A8A);

  final String label;
  final String value;
  final String? displayValue;
  final bool showCopyIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final resolvedDisplayValue = displayValue ?? formatCopyableIdValue(value);
    final normalizedLabel = label.trim().toUpperCase();
    return InkWell(
      onTap: enabled
          ? () => _copy(context, resolvedDisplayValue, normalizedLabel)
          : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '$normalizedLabel: $resolvedDisplayValue',
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (enabled && showCopyIcon) ...[
              const SizedBox(width: 6),
              const Icon(Icons.copy_outlined, size: 16, color: iconColor),
            ],
          ],
        ),
      ),
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

String formatCopyableIdValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '-';
  return trimmed.substring(0, 1).toLowerCase() + trimmed.substring(1);
}
