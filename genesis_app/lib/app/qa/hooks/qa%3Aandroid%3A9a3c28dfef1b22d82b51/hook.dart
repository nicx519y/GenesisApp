import 'package:flutter/material.dart';
import '../../../../components/chat/shared/chat_ui.dart';
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show elements, visible, validate;
import '../qa%253Aandroid%253A8f81866f11bb4803f54c/hook.dart'
    show targetHitTestable;

Element? backButton(Element panel) {
  final headers = elements(
    panel,
  ).where((e) => e.widget is ChatHeader && visible(e)).toList();
  if (headers.length != 1) return null;
  final header = headers.single.widget as ChatHeader;
  final buttons = elements(headers.single)
      .where(
        (e) =>
            e.widget is IconButton &&
            (e.widget as IconButton).onPressed == header.onBack &&
            visible(e),
      )
      .toList();
  return buttons.length == 1 ? buttons.single : null;
}

Map<String, Object?> dispatchBack(Element? panel) {
  if (panel == null) throw StateError('No active location chat');
  final button = backButton(panel);
  if (button == null || !targetHitTestable(button))
    throw StateError('Location chat back is not reachable');
  (button.widget as IconButton).onPressed!();
  return {'action': 'back', 'dispatched': true};
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'interact');
  return dispatchBack(activePanel());
}
