import 'package:flutter/material.dart';
import '../../qa_bridge.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

class InputBlockerFixture {
  InputBlockerFixture(this.overlay);
  final OverlayState overlay;
  OverlayEntry? entry;
  bool acquired = false;
  bool released = false;
  Future<void> prepare() async {
    if (acquired) throw StateError('Input blocker already acquired');
    acquired = true;
    entry = OverlayEntry(
      builder: (_) => const Positioned.fill(
        child: AbsorbPointer(child: ColoredBox(color: Colors.transparent)),
      ),
    );
    overlay.insert(entry!);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<Map<String, Object?>> restore(String resource) async {
    if (!acquired) throw StateError('No input blocker acquired');
    if (!released) {
      entry!.remove();
      entry!.dispose();
      entry = null;
      released = true;
      await WidgetsBinding.instance.endOfFrame;
    }
    return {
      'restored': released,
      'matchesSnapshot': entry == null,
      'resource': resource,
    };
  }
}

final fixtures = Expando<InputBlockerFixture>();
Future<Object?> fixture(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  final d = await selection(), bridge = QaBridge.current!;
  if (p['operation'] == 'prepare') {
    if (fixtures[bridge] != null)
      throw StateError('Input blocker already acquired');
    final world = selectedWorld(d.selectedId!);
    if (world == null) throw StateError('Selected world missing');
    final f = InputBlockerFixture(Overlay.of(world));
    fixtures[bridge] = f;
    await f.prepare();
    return {'prepared': f.entry?.mounted == true, 'resource': d.resource};
  }
  if (p['operation'] == 'restore') {
    final f = fixtures[bridge];
    if (f == null) throw StateError('No input blocker acquired');
    return f.restore(d.resource);
  }
  throw ArgumentError('Unknown input blocker operation');
}
