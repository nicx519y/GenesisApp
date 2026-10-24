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
        (e.widget as WorldMapTopBar).timeText == expected.trim() &&
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
    raw['info'] is Map ? raw['info']['current_time'] : null,
  );
}

// Contract-only evidence is captured before the scenario restores its route.
Map<String, Object?> timeEvidence(Element? root, Object? expected) {
  final headers = root == null ? <Element>[] : elements(root).where(
    (e) => e.widget is WorldMapTopBar && visible(e),
  ).toList();
  return {
    'selectedTime': expected,
    'headerTimes': headers.map((e) => (e.widget as WorldMapTopBar).timeText).toList(),
    'visibleTexts': headers.expand((e) => elements(e)).where(
      (e) => e.widget is Text && visible(e),
    ).map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText()).toList(),
    'matches': observe(root, expected),
  };
}

Future<Object?> contractEvidence(
  Map<String, dynamic> p, bool prepared, bool started,
) async {
  if (!prepared) throw StateError('Isolated contract session required');
  validate(p, started, 'read');
  final d = await selection();
  final raw = await d.selected('detail');
  return timeEvidence(selectedWorld(d.selectedId!),
    raw['info'] is Map ? raw['info']['current_time'] : null);
}
