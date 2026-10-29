import 'package:flutter/widgets.dart';

/// Complete the login surface's own route, preserving pages opened above it.
void completeLoginRoute<T extends Object?>(BuildContext context, T result) {
  final route = ModalRoute.of<T>(context);
  final navigator = route?.navigator;
  if (route == null || navigator == null || !route.isActive) return;
  if (route.isCurrent) {
    navigator.pop<T>(result);
  } else {
    navigator.removeRoute<T>(route, result);
  }
}
