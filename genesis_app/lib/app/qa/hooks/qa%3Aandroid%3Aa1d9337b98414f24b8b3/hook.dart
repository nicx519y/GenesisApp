import 'package:flutter/widgets.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

/// Insets are physical pixels from the actual Flutter view, not a focus guess.
/// The world remains mounted while its location chat overlay is active.
bool keyboardObstructsWorld({required bool worldPresent, required double bottomInset}) {
  if (!bottomInset.isFinite || bottomInset < 0) {
    throw StateError('Invalid keyboard inset');
  }
  return worldPresent && bottomInset > 0;
}

Future<Object?> invoke(Map<String, dynamic> p, bool prepared, bool started) async {
  validate(p, started, 'read');
  final d = await selection();
  final world = selectedWorld(d.selectedId!);
  return keyboardObstructsWorld(
    worldPresent: world != null,
    bottomInset: world == null ? 0 : View.of(world).viewInsets.bottom,
  );
}
