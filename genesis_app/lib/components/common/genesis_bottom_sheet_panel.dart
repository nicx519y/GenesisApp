import 'package:flutter/material.dart';

class GenesisBottomSheetPanel extends StatelessWidget {
  const GenesisBottomSheetPanel({
    super.key,
    required this.title,
    required this.height,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 22, 16, 14),
    this.titleBottomSpacing = 18,
  });

  static const BorderRadius borderRadius = BorderRadius.vertical(
    top: Radius.circular(28),
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 16,
    height: 1.1,
    fontWeight: FontWeight.w700,
    color: Color(0xFF111111),
  );

  final String title;
  final double height;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  final double titleBottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: borderRadius,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: titleStyle)),
                    if (trailing != null) trailing!,
                  ],
                ),
                SizedBox(height: titleBottomSpacing),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
