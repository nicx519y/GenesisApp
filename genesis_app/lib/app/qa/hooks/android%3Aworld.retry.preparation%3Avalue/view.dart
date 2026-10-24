import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../pages/world/world_page.dart';
import 'lease.dart';

/// Read the mounted tree; do not mount, navigate or repair readiness here.
List<Element> elements([Element? root]) {
  final result = <Element>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Offstage && w.offstage ||
        w is Visibility && !w.visible ||
        w is Opacity && w.opacity == 0)
      return;
    result.add(e);
    e.visitChildren(visit);
  }

  final start = root ?? WidgetsBinding.instance.rootElement;
  if (start != null) visit(start);
  return result;
}

bool visible(Element e) {
  final render = e.findRenderObject();
  if (render is! RenderBox ||
      !render.attached ||
      !render.hasSize ||
      render.size.isEmpty)
    return false;
  final view = View.of(e);
  final bounds = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  return bounds.overlaps(render.localToGlobal(Offset.zero) & render.size);
}

Element? worldElement() {
  final lease = requireWorldLease();
  for (final e in elements()) {
    if (e.widget is WorldPage &&
        (e.widget as WorldPage).wid == lease.worldId &&
        visible(e))
      return e;
  }
  return null;
}

List<Element> textElements(String text, [Element? root]) => elements(root)
    .where(
      (e) =>
          e.widget is Text &&
          ((e.widget as Text).data ??
                  (e.widget as Text).textSpan?.toPlainText()) ==
              text &&
          visible(e),
    )
    .toList();
VoidCallback? actionForText(String text, [Element? root]) {
  for (final e in textElements(text, root)) {
    VoidCallback? callback;
    e.visitAncestorElements((parent) {
      final w = parent.widget;
      if (w is ButtonStyleButton) {
        callback = w.onPressed;
        return false;
      }
      if (w is InkWell) {
        callback = w.onTap;
        return false;
      }
      if (w is GestureDetector && w.onTap != null) {
        callback = w.onTap;
        return false;
      }
      return parent != root;
    });
    if (callback != null) return callback;
  }
  return null;
}

void validateRead(Map<String, dynamic> p, bool started) {
  if (!started || p['operation'] != 'read' || p.length != 1)
    throw ArgumentError('Ready parameterless read required');
}
