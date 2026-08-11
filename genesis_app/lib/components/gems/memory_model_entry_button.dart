import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const double kMemoryModelEntryMinWidth = 82;
const double kMemoryModelEntryMaxWidth = 96;

class MemoryModelEntryButton extends StatelessWidget {
  const MemoryModelEntryButton({
    super.key,
    required this.modelLabel,
    required this.onTap,
    this.darkHeader = false,
    this.compact = false,
  });

  final String modelLabel;
  final VoidCallback onTap;
  final bool darkHeader;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = darkHeader ? Colors.white : Colors.black;
    final background = darkHeader
        ? Colors.transparent
        : Colors.white.withValues(alpha: 0.9);
    final borderRadius = compact ? 11.5 : 19.0;
    final iconSize = compact ? 16.0 : 18.0;
    return Material(
      key: const ValueKey('memory-model-entry'),
      color: background,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Container(
          height: compact ? 23 : 38,
          constraints: const BoxConstraints(
            minWidth: kMemoryModelEntryMinWidth,
            maxWidth: kMemoryModelEntryMaxWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/custom-icons/svg/arrow-change-svgrepo-com.svg',
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  modelLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w400,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
