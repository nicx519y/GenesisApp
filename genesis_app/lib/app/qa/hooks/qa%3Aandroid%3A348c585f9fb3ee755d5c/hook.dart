import 'package:flutter/material.dart';
import '../../../../pages/world/world_page.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart'
    show elements, visible;
export '../android%253Aworld.retry.preparation%253Avalue/view.dart'
    show elements, visible, textElements, actionForText;

void validate(Map<String, dynamic> p, bool started, String operation) {
  if (!started || p.length != 1 || p['operation'] != operation)
    throw ArgumentError('Ready parameterless ' + operation + ' required');
}

bool matchesWorld(Widget widget, String id) =>
    id.isNotEmpty && widget is WorldPage && widget.wid == id;
Element? selectedWorld(String id) {
  final found = elements()
      .where(
        (e) =>
            matchesWorld(e.widget, id) &&
            visible(e) &&
            ModalRoute.of(e)?.isCurrent == true,
      )
      .toList();
  if (found.length > 1) throw StateError('Ambiguous selected world page');
  return found.isEmpty ? null : found.single;
}

Future<WorldDataset> selection() async {
  final d = await worldDatasetResource();
  await d.requireOwner();
  if (!d.active || d.selectedId == null)
    throw StateError('No active world dataset');
  return d;
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final d = await selection();
  return selectedWorld(d.selectedId!) != null;
}
