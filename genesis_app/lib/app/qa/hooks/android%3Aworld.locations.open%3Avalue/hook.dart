import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import '../../../../pages/world/world_page.dart';
import '../../../../pages/world/world_bottom_sheet.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show selection;
import '../qa%253Aandroid%253A8f81866f11bb4803f54c/hook.dart'
    show targetHitTestable;
import '../android%253Aworld.retry.preparation%253Avalue/lease.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart'
    show elements, visible, textElements;

/// Consume the existing resource; never acquire a second snapshot or fall back
/// after an ownership failure. Both supported preparations retain cleanup.
Future<String> preparedWorldId() async {
  final retry = WorldRetryLease.active;
  if (retry != null) {
    await retry.sameOwner();
    return retry.worldId;
  }
  return (await selection()).selectedId!;
}

int _pointer = 97500;

/// Real input, including interception by overlays and disabled controls.
void dispatchLocationsTap(Element root) {
  final targets = <Element>{};
  for (final label in textElements('Locations', root)) {
    label.visitAncestorElements((parent) {
      final widget = parent.widget;
      if (widget is GestureDetector && widget.onTap != null ||
          widget is InkWell && widget.onTap != null ||
          widget is ButtonStyleButton && widget.onPressed != null) {
        if (targetHitTestable(parent)) targets.add(parent);
        return false;
      }
      return parent != root;
    });
  }
  if (targets.length != 1) {
    throw StateError('Locations requires one unblocked touch target');
  }
  final target = targets.single;
  final box = target.findRenderObject()! as RenderBox;
  final point = box.localToGlobal(box.size.center(Offset.zero));
  final view = View.of(target);
  if (!(Offset.zero & (view.physicalSize / view.devicePixelRatio)).contains(point)) {
    throw StateError('Locations is outside the viewport');
  }
  final binding = WidgetsBinding.instance;
  final pointer = _pointer++;
  binding.handlePointerEvent(PointerDownEvent(
    pointer: pointer, position: point, viewId: view.viewId,
    kind: PointerDeviceKind.touch,
  ));
  try {
    binding.handlePointerEvent(PointerUpEvent(
      pointer: pointer, position: point, viewId: view.viewId,
      kind: PointerDeviceKind.touch,
    ));
  } catch (_) {
    binding.handlePointerEvent(PointerCancelEvent(
      pointer: pointer, position: point, viewId: view.viewId,
      kind: PointerDeviceKind.touch,
    ));
    rethrow;
  }
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1 || p['operation'] != 'interact') {
    throw ArgumentError('Expected interact');
  }
  final id = await preparedWorldId();
  final roots = elements().where((e) {
    final widget = e.widget;
    return (widget is WorldPage && widget.wid == id ||
            widget is WorldSingleSectionBottomSheet &&
                widget.initialWorld.worldId == id) &&
        visible(e) && ModalRoute.of(e)?.isCurrent == true;
  }).toList();
  // A sheet can be embedded in the page rather than in a separate route.
  final sheets = roots.where((e) => e.widget is WorldSingleSectionBottomSheet).toList();
  final targets = sheets.isNotEmpty ? sheets : roots;
  if (targets.length != 1) throw StateError('Current prepared world required');
  dispatchLocationsTap(targets.single);
  return {
    'action': 'tap', 'entry': 'Locations', 'dispatched': true,
    'clicked': true, 'targetMatchesPreparedWorld': true,
  };
}
