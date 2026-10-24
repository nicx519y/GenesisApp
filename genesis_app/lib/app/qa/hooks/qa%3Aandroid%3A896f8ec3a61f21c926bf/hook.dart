import 'package:flutter/material.dart';
import '../../../../ui/components/genesis_dark_close_button.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart' show resource;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'interact');
  await resource().requireOwner();
  final panel = eventsPanel();
  if (panel == null) throw StateError('Events panel required');
  final route = ModalRoute.of(panel);
  final buttons = elements()
      .where(
        (e) =>
            e.widget is GenesisDarkCloseButton &&
            visible(e) &&
            ModalRoute.of(e) == route,
      )
      .map((e) => e.widget as GenesisDarkCloseButton)
      .where((w) => w.onPressed != null)
      .toList();
  if (buttons.length != 1) throw StateError('Ambiguous event close action');
  buttons.single.onPressed!();
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (eventsPanel() != null && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return {'closed': eventsPanel() == null};
}
