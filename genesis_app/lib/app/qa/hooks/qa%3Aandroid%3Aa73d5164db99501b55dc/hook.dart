import 'package:flutter/widgets.dart';
import 'touch.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ae902ad40417a12b1d8e2/hook.dart' show success;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'interact');
  final s = success();
  await s.owner.requireOwner();
  if (!s.active || s.submissions != 0) {
    throw StateError('Unsubmitted success attempt required');
  }
  final w = worldElement();
  if (w == null || s.owner.route?.isCurrent != true || eventsPanel() != null) {
    throw StateError('Uncovered target map required');
  }
  final targets = elements(w).where((e) =>
      e.widget.key == const ValueKey<String>('world-header-action-button') &&
      visible(e)).toList();
  if (targets.length != 1) {
    throw StateError('Unique tick button required');
  }
  final attempt = s.owner.attempt;
  final dispatched = dispatchRapidTaps(targets.single);
  return {
    'dispatchedTapCount': dispatched,
    'sameProgressAttempt':
        identical(s, success()) && attempt == s.owner.attempt,
    'attempt': attempt,
  };
}
