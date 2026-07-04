import 'package:flutter/material.dart';

class GenesisUploadProgressOverlay extends StatelessWidget {
  const GenesisUploadProgressOverlay({
    super.key,
    required this.progress,
    this.processing = false,
    this.label,
    this.coverColor = const Color(0x7A000000),
    this.labelColor = const Color(0x85000000),
  });

  final double progress;
  final bool processing;
  final String? label;
  final Color coverColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    final coverFactor = (1 - normalized).clamp(0.0, 1.0).toDouble();
    final displayLabel = label ?? '${(normalized * 100).round()}%';
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLabelWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth - 8
            : double.infinity;
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: coverFactor,
                child: ColoredBox(color: coverColor),
              ),
            ),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: labelColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: processing
                      ? const EdgeInsets.all(7)
                      : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxLabelWidth < 1 ? 1 : maxLabelWidth,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              displayLabel,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
