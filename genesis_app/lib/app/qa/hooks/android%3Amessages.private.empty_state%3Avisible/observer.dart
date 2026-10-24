import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Select by the existing business key, never by the expected copy.
List<Element> emptyStateElements() {
  final found = <Element>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Offstage && w.offstage ||
        w is Opacity && w.opacity == 0 ||
        w is FadeTransition && w.opacity.value == 0)
      return;
    if (w.key == const ValueKey('direct-messages-empty-state')) {
      final r = e.findRenderObject();
      if (r is RenderBox &&
          r.attached &&
          r.hasSize &&
          !r.size.isEmpty &&
          (ModalRoute.of(e)?.isCurrent ?? true)) {
        final view = View.of(e);
        final screen =
            Offset.zero & (view.physicalSize / view.devicePixelRatio);
        final bounds = MatrixUtils.transformRect(
          r.getTransformTo(null),
          Offset.zero & r.size,
        );
        var painted = true;
        RenderObject child = r;
        for (
          RenderObject? parent = child.parent;
          parent != null;
          parent = child.parent
        ) {
          if (parent is RenderIndexedStack) {
            RenderBox? selected = parent.firstChild;
            for (var i = 0; i < (parent.index ?? -1) && selected != null; i++) {
              selected = parent.childAfter(selected);
            }
            if (parent.index == null || !identical(selected, child))
              painted = false;
          }
          child = parent;
        }
        if (painted && bounds.overlaps(screen)) found.add(e);
      }
    }
    e.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return found;
}

Future<Object?> readEmptyVisible(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (p.isNotEmpty) throw ArgumentError('Expected parameterless read');
  if (!started) return false;
  final elements = emptyStateElements();
  if (elements.length > 1) throw StateError('Ambiguous empty state');
  return elements.length == 1;
}
