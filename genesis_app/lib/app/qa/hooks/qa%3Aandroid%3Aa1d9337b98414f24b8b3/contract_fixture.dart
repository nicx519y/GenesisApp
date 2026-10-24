import 'dart:async';
import 'package:flutter/material.dart';
import '../../qa_bridge.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

class KeyboardFixture {
  KeyboardFixture(this.world, this.previousFocus);
  final Element world;
  final FocusNode? previousFocus;
  final focus = FocusNode();
  final controller = TextEditingController();
  OverlayEntry? entry;
  bool released = false;

  Future<void> prepare() async {
    if (View.of(world).viewInsets.bottom != 0) {
      throw StateError('Keyboard fixture requires an initially unobstructed world');
    }
    entry = OverlayEntry(builder: (_) => Positioned(
      left: 16, right: 16, top: 80,
      child: Material(child: TextField(focusNode: focus, controller: controller)),
    ));
    Overlay.of(world).insert(entry!);
    await WidgetsBinding.instance.endOfFrame;
    focus.requestFocus();
  }

  Future<Map<String, Object?>> restore(String resource) async {
    if (!released) {
      focus.unfocus();
      entry?.remove();
      entry?.dispose();
      entry = null;
      focus.dispose();
      controller.dispose();
      if (previousFocus?.context != null && previousFocus!.canRequestFocus) {
        previousFocus!.requestFocus();
      }
      released = true;
    }
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (world.mounted && View.of(world).viewInsets.bottom != 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final matches = world.mounted && View.of(world).viewInsets.bottom == 0 &&
        (previousFocus == null || identical(FocusManager.instance.primaryFocus, previousFocus));
    if (!matches) throw StateError('Keyboard/focus restoration mismatch');
    return {'restored': released && entry == null, 'matchesSnapshot': matches, 'resource': resource};
  }
}
final fixtures = Expando<KeyboardFixture>();
Future<Object?> fixture(Map<String, dynamic> p, bool prepared, bool started) async {
  if (!prepared || !started || p.length != 1) throw StateError('Started isolated contract required');
  final d = await selection();
  final bridge = QaBridge.current!;
  switch (p['operation']) {
    case 'prepare':
      if (fixtures[bridge] != null) throw StateError('Keyboard fixture already acquired');
      final world = selectedWorld(d.selectedId!);
      if (world == null) throw StateError('World must be visible before keyboard preparation');
      final f = KeyboardFixture(world, FocusManager.instance.primaryFocus);
      fixtures[bridge] = f;
      await f.prepare();
      return {'resource': d.resource, 'prepared': f.entry?.mounted == true};
    case 'restore':
      final f = fixtures[bridge];
      if (f == null) throw StateError('No keyboard fixture acquired');
      return f.restore(d.resource);
    default:
      throw ArgumentError('Unknown keyboard fixture operation');
  }
}
