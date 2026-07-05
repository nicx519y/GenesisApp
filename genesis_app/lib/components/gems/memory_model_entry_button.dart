import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MemoryModelEntryButton extends StatelessWidget {
  const MemoryModelEntryButton({
    super.key,
    required this.modelLabel,
    required this.onTap,
    this.darkHeader = false,
  });

  final String modelLabel;
  final VoidCallback onTap;
  final bool darkHeader;

  @override
  Widget build(BuildContext context) {
    final foreground = darkHeader ? Colors.white : Colors.black;
    final background = darkHeader
        ? Colors.transparent
        : Colors.white.withValues(alpha: 0.9);
    return Material(
      key: const ValueKey('memory-model-entry'),
      color: background,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 82),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/custom-icons/svg/arrow-change-svgrepo-com.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
              ),
              const SizedBox(width: 5),
              Text(
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
            ],
          ),
        ),
      ),
    );
  }
}
