import 'package:flutter/material.dart';
import '../../../../pages/chat/location_chat_page.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show elements, visible, validate;

/// InheritedElement's lookup table includes itself. Calling ModalRoute.of on
/// the route's inherited scope would register it as its own dependent and
/// corrupt the tree on the next navigation. Only query descendant contexts.
ModalRoute<dynamic>? observedRoute(Element element) =>
    element is InheritedElement ? null : ModalRoute.of(element);

/// Cached inactive panels and panels below another route are not visible chat.
Element? activePanel([Element? root]) {
  final panels = elements(root).where((e) {
    final w = e.widget;
    if (w is! LocationChatPanel || !w.active || !visible(e)) return false;
    var current = observedRoute(e)?.isCurrent == true;
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Offstage && w.offstage ||
          w is Visibility && !w.visible ||
          w is Opacity && w.opacity == 0 ||
          observedRoute(a)?.isCurrent == false)
        current = false;
      return current;
    });
    return current;
  }).toList();
  if (panels.length > 1) throw StateError('Ambiguous active location chat');
  return panels.isEmpty ? null : panels.single;
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  return activePanel() != null;
}
