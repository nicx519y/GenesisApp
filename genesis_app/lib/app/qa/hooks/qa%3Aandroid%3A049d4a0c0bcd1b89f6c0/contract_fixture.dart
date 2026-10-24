import 'package:flutter/material.dart';
import '../../../genesis_navigator.dart';
import '../../qa_bridge.dart';

final blockers = Expando<OverlayEntry>();
Future<Object?> fixture(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  final b = QaBridge.current!;
  if (p['operation'] == 'block') {
    if (blockers[b] != null) throw StateError('Blocker already owned');
    final entry = OverlayEntry(
      builder: (_) => const Positioned.fill(
        child: AbsorbPointer(child: ColoredBox(color: Colors.transparent)),
      ),
    );
    blockers[b] = entry;
    genesisNavigatorKey.currentState!.overlay!.insert(entry);
    await WidgetsBinding.instance.endOfFrame;
    return {'blocked': entry.mounted};
  }
  if (p['operation'] == 'unblock') {
    final entry = blockers[b];
    if (entry == null) return {'restored': true, 'acquired': false};
    entry.remove();
    await WidgetsBinding.instance.endOfFrame;
    final removed = !entry.mounted;
    entry.dispose();
    blockers[b] = null;
    return {'restored': removed, 'acquired': true};
  }
  throw ArgumentError('Unsupported fixture operation');
}
