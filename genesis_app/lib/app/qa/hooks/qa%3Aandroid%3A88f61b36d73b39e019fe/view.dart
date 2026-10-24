import 'package:flutter/material.dart';
import '../../../../pages/chat/location_chat_page.dart';
import '../../../../pages/world/world_bottom_sheet.dart';
import '../../../../components/world_location_list.dart';
import '../qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show elements, visible;
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart' show activePanel;
export '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show elements, visible;

Element? parentPanel() {
  final e = activePanel(), r = resource();
  final w = e?.widget;
  return w is LocationChatPanel &&
          w.worldId == r.worldId &&
          w.locationId == r.parentId
      ? e
      : null;
}

Element? locationsList() {
  final r = resource();
  final sheets = elements().where(
    (e) =>
        e.widget is WorldSingleSectionBottomSheet &&
        (e.widget as WorldSingleSectionBottomSheet).initialWorld.worldId ==
            r.worldId &&
        visible(e),
  );
  final lists = sheets
      .expand(elements)
      .where((e) => e.widget is WorldLocationList && visible(e))
      .toList();
  if (lists.length > 1) throw StateError('Ambiguous location lists');
  return lists.isEmpty ? null : lists.single;
}

Element? labelTarget(Element root, String text) {
  final targets = <Element>{};
  for (final label in elements(root).where(
    (e) => e.widget is Text && (e.widget as Text).data == text && visible(e),
  )) {
    label.visitAncestorElements((e) {
      final w = e.widget;
      if (w is GestureDetector && w.onTap != null ||
          w is InkWell && w.onTap != null ||
          w is ButtonStyleButton && w.onPressed != null) {
        targets.add(e);
        return false;
      }
      return e != root;
    });
  }
  if (targets.length > 1) throw StateError('Ambiguous touch target');
  return targets.isEmpty ? null : targets.single;
}

/// Non-leaf rows render a decorated header, unlike leaf location cards.
/// Find the row even when disabled so missing business wiring is not reported
/// as a missing label or as an intercepted touch. Never borrow an outer action.
Element? parentRowTarget(Element root, String name) {
  final targets = <Element>{};
  for (final label in elements(root).where(
    (e) =>
        e.widget is Text && (e.widget as Text).data == '- $name' && visible(e),
  )) {
    label.visitAncestorElements((e) {
      if (identical(e, root)) return false;
      if (e.widget is InkWell) {
        targets.add(e);
        return false;
      }
      return true;
    });
  }
  if (targets.length > 1) throw StateError('Ambiguous parent rows');
  return targets.isEmpty ? null : targets.single;
}

void requireParentRowAction(Element target) {
  final widget = target.widget;
  if (widget is! InkWell || widget.onTap == null) {
    throw StateError('Parent row has no enabled tap action');
  }
}
