import 'package:flutter/material.dart';

class GenesisUploadProgressOverlay extends StatelessWidget {
  const GenesisUploadProgressOverlay({
    super.key,
    required this.progress,
    this.coverColor = const Color(0x7A000000),
    this.labelColor = const Color(0x85000000),
  });

  final double progress;
  final Color coverColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    final coverFactor = (1 - normalized).clamp(0.0, 1.0).toDouble();
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                '${(normalized * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
