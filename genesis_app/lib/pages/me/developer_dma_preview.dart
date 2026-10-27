import 'package:flutter/widgets.dart';
import '../../components/privacy/privacy_choices_dialog.dart';

/// Compatibility entry for the developer preview. Callers explicitly disable persistence.
Future<void> showDeveloperDmaPreview(
  BuildContext context, {
  bool dismissCurrentRoute = false,
  bool openChoicesDirectly = false,
  bool persistChoices = true,
}) => showPrivacyChoicesDialog(
  context,
  dismissCurrentRoute: dismissCurrentRoute,
  openChoicesDirectly: openChoicesDirectly,
  persistChoices: persistChoices,
);
