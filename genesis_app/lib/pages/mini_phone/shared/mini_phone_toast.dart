import 'package:flutter/material.dart';

import '../../../components/common/genesis_center_toast.dart';

/// Suppress the generic transport text only at MiniPhone's presentation edge.
/// Request errors remain available to retry, recovery and diagnostics.
String miniPhoneToastMessage(String message) =>
    message.trim() == 'Request failed' ? '' : message;

void showMiniPhoneToast(
  BuildContext context,
  String message, {
  Brightness? brightness,
}) => showGenesisToast(
  context,
  miniPhoneToastMessage(message),
  brightness: brightness,
);

void showMiniPhoneToastInOverlay(
  OverlayState overlay,
  String message, {
  Brightness brightness = Brightness.light,
}) => showGenesisToastInOverlay(
  overlay,
  miniPhoneToastMessage(message),
  brightness: brightness,
);
