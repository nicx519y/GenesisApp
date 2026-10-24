import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../components/world_map.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';
import '../qa%253Aandroid%253Aa2066fb18358fd39923e/hook.dart' as map_view;

/// Hit testing is observational: no gesture/callback is dispatched.
bool targetHitTestable(Element target) {
  if (!target.mounted || !visible(target)) return false;
  final render = target.findRenderObject();
  if (render is! RenderBox || !render.hasSize) return false;
  final point = render.localToGlobal(render.size.center(Offset.zero));
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, point, View.of(target).viewId);
  // Only an actual pointer listener proves input reaches the gesture target.
  // An absorbing render box can itself be hit while blocking all child input.
  final descendants = elements(target)
      .map((e) => e.findRenderObject())
      .whereType<RenderPointerListener>()
      .where((r) => r.onPointerDown != null)
      .toSet();
  return result.path.any((entry) => descendants.contains(entry.target));
}

/// Observe only the mounted map's pan/scale surface, never header controls.
List<Element> mapGestureTargets(Element root) {
  final maps = elements(
    root,
  ).where((e) => e.widget is WorldMap && visible(e)).toList();
  if (maps.length != 1) return <Element>[];
  return elements(maps.single).where((e) {
    final widget = e.widget;
    if (widget is! GestureDetector ||
        !visible(e) ||
        (widget.onScaleUpdate == null && widget.onPanUpdate == null))
      return false;
    var enabled = true;
    e.visitAncestorElements((ancestor) {
      final parent = ancestor.widget;
      if (parent is InteractiveViewer && !parent.panEnabled) enabled = false;
      return !identical(ancestor, maps.single);
    });
    return enabled;
  }).toList();
}

Future<Map<String, Object?>> observeMapOperation(
  Element? world,
  String worldId,
) async {
  // Schedule a frame, without changing business state, to observe the UI loop.
  var frameObserved = false;
  await WidgetsBinding.instance.endOfFrame.timeout(const Duration(seconds: 3));
  frameObserved = true;
  final current =
      world != null && world.mounted && ModalRoute.of(world)?.isCurrent == true;
  final mapVisible = current && map_view.observe(world, worldId);
  final controls = current ? mapGestureTargets(world!) : <Element>[];
  final hit = controls.length == 1 && targetHitTestable(controls.single);
  return {
    'responsive': frameObserved && mapVisible && hit,
    'frameObserved': frameObserved,
    'mapVisible': mapVisible,
    'controlCount': controls.length,
    'controlHitTestable': hit,
    'worldId': worldId,
  };
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final d = await selection();
  return observeMapOperation(selectedWorld(d.selectedId!), d.selectedId!);
}
