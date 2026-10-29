import 'package:flutter/widgets.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../platform/auth/auth_session.dart';
import '../../platform/auth/login_submission_controller.dart';

/// Binds login pages and sheets to their app's shared submission state.
mixin LoginSubmissionState<T extends StatefulWidget> on State<T> {
  LoginSubmissionController? _loginSubmission;
  LoginSubmissionController? _standaloneLoginSubmission;

  IdentityProvider? get loginSubmittingProvider => _loginSubmission?.value;
  bool get loginSubmissionSucceeded =>
      (_loginSubmission?.isActive ?? false) &&
      (_loginSubmission?.succeeded ?? false);

  @protected
  bool get usesSharedLoginSubmission => true;

  Future<void> submitLogin(
    IdentityProvider provider,
    Future<void> Function(LoginSubmissionController submission) work,
  ) {
    final submission = _loginSubmission!;
    return submission.submit(provider, () => work(submission));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next =
        (usesSharedLoginSubmission
            ? AppServicesScope.maybeOf(context)?.loginSubmission
            : null) ??
        (_standaloneLoginSubmission ??= LoginSubmissionController());
    if (identical(next, _loginSubmission)) return;
    _loginSubmission?.removeListener(_loginSubmissionChanged);
    _loginSubmission = next;
    next.addListener(_loginSubmissionChanged);
    onLoginSubmissionChanged();
  }

  void _loginSubmissionChanged() {
    if (mounted) setState(onLoginSubmissionChanged);
  }

  @protected
  void onLoginSubmissionChanged() {}

  @override
  void dispose() {
    _loginSubmission?.removeListener(_loginSubmissionChanged);
    _standaloneLoginSubmission?.dispose();
    super.dispose();
  }
}
