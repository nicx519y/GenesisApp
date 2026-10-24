import 'package:flutter/material.dart';
import '../../qa_bridge.dart';

// Dynamic errors are associated with the rendered element in the frame of the
// actual business log, never with a remembered login result or an HTTP payload.
QaBridge? _logOwner;
WeakReference<Element>? _dynamicNotice;
int _generation = 0;

List<Element> renderedToastElements() {
  final result = <Element>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Offstage && widget.offstage) { return; }
    if (widget is Opacity && widget.opacity == 0) { return; }
    if (widget is FadeTransition && widget.opacity.value == 0) { return; }
    if (widget is Text && widget.data != null &&
        widget.textAlign == TextAlign.center && widget.style?.inherit == false &&
        widget.style?.fontSize == 14) {
      var overlay = false, ignore = false, center = false, clip = false;
      element.visitAncestorElements((ancestor) {
        final parent = ancestor.widget;
        if (parent is Overlay) { overlay = true; return false; }
        if (parent is IgnorePointer && parent.ignoring) { ignore = true; }
        if (parent is Center) { center = true; }
        if (parent is ClipRRect) { clip = true; }
        return true;
      });
      final render = element.findRenderObject();
      if (overlay && ignore && center && clip && render is RenderBox &&
          render.attached && render.hasSize && !render.size.isEmpty) {
        final bounds = MatrixUtils.transformRect(render.getTransformTo(null), Offset.zero & render.size);
        final view = View.of(element);
        final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
        if (bounds.overlaps(screen)) { result.add(element); }
      }
    }
    element.visitChildren(visit);
  }
  final root = WidgetsBinding.instance.rootElement;
  if (root != null) { visit(root); }
  return result;
}

Future<Object?> observeLoginFailureLog(
  Map<String, dynamic> parameters, bool prepared, bool started,
) async {
  final message = parameters['message'];
  if (!started || message is! String) { return null; }
  String? text;
  for (final prefix in ['[Auth][LoginSheet] login exception: ', '[Auth][MePage] login failed: ']) {
    if (message.startsWith(prefix)) { text = message.substring(prefix.length).trim(); }
  }
  if (text == null) { return null; }
  final owner = QaBridge.current;
  final generation = ++_generation;
  _logOwner = owner;
  _dynamicNotice = null;
  final expected = text.isEmpty ? 'Sign-in failed' : text;
  // Exclude pre-existing ordinary toasts with the same message.
  final previous = renderedToastElements().toSet();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (generation != _generation || owner == null || !identical(owner, QaBridge.current)) { return; }
    for (final element in renderedToastElements()) {
      if (!previous.contains(element) && (element.widget as Text).data == expected) {
        _dynamicNotice = WeakReference(element);
        break;
      }
    }
  });
  return null;
}

Future<Object?> readLoginFailureNotice(
  Map<String, dynamic> parameters, bool prepared, bool started,
) async {
  if (parameters.isNotEmpty) { throw ArgumentError('Expected read without parameters'); }
  if (!started) { return false; }
  final dynamicElement = identical(_logOwner, QaBridge.current) && QaBridge.current != null
      ? _dynamicNotice?.target : null;
  return renderedToastElements().any((element) =>
      (element.widget as Text).data == 'Sign-in failed' || identical(element, dynamicElement));
}
