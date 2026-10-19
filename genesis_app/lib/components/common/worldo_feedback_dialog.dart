import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../l10n/genesis_localizations.dart';
import 'genesis_content_submission_dialog.dart';

/// Shared Settings/rating feedback flow, including submission and existing toasts.
Future<bool> showWorldoFeedbackDialog(BuildContext context) {
  final api = AppServicesScope.read(context).api;
  return showGenesisContentSubmissionDialog(
    context: context,
    title: context.l10n.settingsFeedback,
    inputLines: 5,
    contentInputKey: const ValueKey<String>('genesis-feedback-content-input'),
    successMessage: context.l10n.feedbackSubmitted,
    brightness: Brightness.dark,
    failureMessage: context.l10n.feedbackFailed,
    onSubmit: (content) => api.v1.feedback.create(content: content),
  );
}
