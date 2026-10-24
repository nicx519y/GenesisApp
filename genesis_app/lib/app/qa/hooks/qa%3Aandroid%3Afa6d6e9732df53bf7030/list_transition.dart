import 'package:flutter/material.dart';
import '../qa%253Aandroid%253A049d4a0c0bcd1b89f6c0/hook.dart'
    show dispatchSingleTap;

/// Contract-only synchronization after one real touch. The first modal frame
/// can still be outside the viewport; it is not proof that opening failed.
Future<Element> openContractLocations(
  Element target,
  Element? Function() visibleList, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  if (visibleList() != null) throw StateError('Locations already open');
  final previousRoute = ModalRoute.of(target);
  dispatchSingleTap(target);
  final elapsed = Stopwatch()..start();
  while (elapsed.elapsed < timeout) {
    await WidgetsBinding.instance.endOfFrame.timeout(timeout - elapsed.elapsed);
    final list = visibleList();
    if (list != null) {
      final route = ModalRoute.of(list);
      if (route != null &&
          !identical(route, previousRoute) &&
          route.isCurrent &&
          route.animation?.status == AnimationStatus.completed) {
        return list;
      }
    }
    // Yield to the animation clock; never repeat the touch or force scrolling.
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  throw StateError('Locations did not open after one touch');
}
