import 'package:flutter/widgets.dart';
import '../../../../pages/world/world_header.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

bool observe(Element? root, Object? expected) {
  if (root == null || expected is! String || expected.trim().isEmpty)
    return false;
  return elements(root).any(
    (e) =>
        e.widget is WorldMapTopBar &&
        visible(e) &&
        (e.widget as WorldMapTopBar).title == expected.trim() &&
        textElements(expected.trim(), e).isNotEmpty,
  );
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final d = await selection();
  final raw = await d.selected('detail');
  return observe(
    selectedWorld(d.selectedId!),
    raw['info'] is Map ? raw['info']['world_name'] : null,
  );
}
