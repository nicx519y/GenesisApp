import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/theme/genesis_semantic_colors.dart';

OverlayEntry? _currentGenesisToast;
Timer? _currentGenesisToastTimer;

void showGenesisToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final trimmedMessage = message.trim();
  if (trimmedMessage.isEmpty) return;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  showGenesisToastInOverlay(overlay, trimmedMessage, duration: duration);
}

void showGenesisToastInOverlay(
  OverlayState overlay,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final trimmedMessage = message.trim();
  if (trimmedMessage.isEmpty) return;

  _currentGenesisToastTimer?.cancel();
  _currentGenesisToast?.remove();

  final entry = OverlayEntry(
    builder: (context) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.genesisColors.scrim.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Text(
                    trimmedMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      inherit: false,
                      color: context.genesisColors.textInverse,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _currentGenesisToast = entry;
  overlay.insert(entry);
  _currentGenesisToastTimer = Timer(duration, () {
    if (_currentGenesisToast == entry) {
      _currentGenesisToast = null;
      _currentGenesisToastTimer = null;
    }
    entry.remove();
  });
}
