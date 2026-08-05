import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_colors.dart';

class OriginRoleSelectionMark extends StatelessWidget {
  const OriginRoleSelectionMark({
    super.key,
    required this.selected,
    this.semanticLabel,
  });

  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      label: semanticLabel,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: selected ? GenesisColors.brand : Colors.white10,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 5,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}
