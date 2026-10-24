import 'package:flutter/material.dart';
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart';
import '../qa%253Aandroid%253A9a3c28dfef1b22d82b51/hook.dart' show backButton;
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart' show validate;
import '../qa%253Aandroid%253A8f81866f11bb4803f54c/hook.dart'
    show targetHitTestable;

Future<Map<String, Object?>> observeOperation() async {
  await WidgetsBinding.instance.endOfFrame.timeout(const Duration(seconds: 3));
  final panel = activePanel();
  final back = panel == null ? null : backButton(panel);
  final reachable = back != null && targetHitTestable(back);
  return {
    'responsive': panel != null && reachable,
    'frameObserved': true,
    'chatVisible': panel != null,
    'backHitTestable': reachable,
  };
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  return observeOperation();
}
