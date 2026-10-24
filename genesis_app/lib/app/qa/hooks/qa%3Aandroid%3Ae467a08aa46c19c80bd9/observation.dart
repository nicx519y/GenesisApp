import 'package:flutter/material.dart';
import '../../../../components/common/genesis_generation_wait_overlay.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart'
    show elements, visible;

/// Match the rendered title inside this world's actual wait overlay. The
/// production widget cycles one through six dots; unrelated text is not proof.
bool progressWaitVisible(Element? world) {
  if (world == null) {
    return false;
  }
  final title = RegExp(r'^Progressing the World\.{0,6}$');
  for (final overlay in elements(world)) {
    final widget = overlay.widget;
    if (widget is! GenesisGenerationWaitOverlay ||
        widget.title != 'Progressing the World' || !visible(overlay)) {
      continue;
    }
    if (elements(overlay).any((e) => e.widget is Text && visible(e) &&
        title.hasMatch((e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText() ?? ''))) {
      return true;
    }
  }
  return false;
}
