import 'package:flutter/widgets.dart';
import '../qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';
import '../qa%253Aandroid%253A049d4a0c0bcd1b89f6c0/hook.dart'
    show dispatchSingleTap;
import 'view.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1 || p['operation'] != 'interact')
    throw ArgumentError('Expected interact');
  final r = resource();
  await r.requireOwner();
  final list = locationsList();
  if (list == null) throw StateError('Locations list not open');
  final target = parentRowTarget(list, r.parentName);
  if (target == null) throw StateError('Parent row not visible');
  requireParentRowAction(target);
  dispatchSingleTap(target);
  await WidgetsBinding.instance.endOfFrame;
  return {
    'clicked': parentPanel() != null,
    'targetMatchesPreparedParent': parentPanel() != null,
  };
}
