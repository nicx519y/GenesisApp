import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';

import '../../platform/auth/auth_session.dart';
import '../../ui/genesis_ui.dart';
import '../../ui/theme/genesis_dark_theme.dart';
import '../common/genesis_bottom_sheet_panel.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_modal_routes.dart';
import '../login_provider_button.dart';

enum PersonalizationGender {
  male('Male'),
  female('Female'),
  nonBinary('Non_binary');

  const PersonalizationGender(this.label);
  final String label;
}

enum PersonalizationAge {
  age18to24('18-24'),
  age25to34('25-34'),
  age35to44('35-44'),
  age45plus('45+');

  const PersonalizationAge(this.label);
  final String label;
}

/// Presentation values only; these are not API field encodings.
class PersonalizationProfile {
  const PersonalizationProfile({this.gender, this.age});
  final PersonalizationGender? gender;
  final PersonalizationAge? age;
  bool get isComplete => gender != null && age != null;
}

/// The caller owns authentication, persistence and list refresh. Preview callers
/// inject local callbacks only. A null login result means cancellation.
Future<PersonalizationProfile?> showPersonalizationSheet({
  required BuildContext context,
  required Future<PersonalizationProfile?> Function(IdentityProvider) onSignIn,
  required WidgetBuilder subscriptionBuilder,
}) => showGenesisModalBottomSheet<PersonalizationProfile>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: Colors.transparent,
  builder: (_) => PersonalizationSheet(
    onSignIn: onSignIn,
    subscriptionBuilder: subscriptionBuilder,
  ),
);

enum PersonalizationStep { form, signIn, subscription }

class PersonalizationSheet extends StatefulWidget {
  const PersonalizationSheet({
    super.key,
    required this.onSignIn,
    required this.subscriptionBuilder,
    this.initialStep = PersonalizationStep.form,
    this.initialProfile = const PersonalizationProfile(),
    this.initiallySignedIn = false,
  });

  final Future<PersonalizationProfile?> Function(IdentityProvider) onSignIn;
  final WidgetBuilder subscriptionBuilder;
  static const double sheetHeight = 600;

  final PersonalizationStep initialStep;
  final PersonalizationProfile initialProfile;
  final bool initiallySignedIn;

  @override
  State<PersonalizationSheet> createState() => _PersonalizationSheetState();
}

class _PersonalizationSheetState extends State<PersonalizationSheet> {
  late PersonalizationStep _step;
  PersonalizationGender? _gender;
  PersonalizationAge? _age;
  IdentityProvider? _signingIn;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    _gender = widget.initialProfile.gender;
    _age = widget.initialProfile.age;
    _signedIn = widget.initiallySignedIn;
  }

  PersonalizationProfile get _profile =>
      PersonalizationProfile(gender: _gender, age: _age);

  Future<void> _signIn(IdentityProvider provider) async {
    if (_signingIn != null) return;
    setState(() => _signingIn = provider);
    try {
      final profile = await widget.onSignIn(provider);
      if (!mounted || profile == null) return;
      if (profile.isComplete) {
        Navigator.of(context).pop(profile);
        return;
      }
      setState(() {
        _signedIn = true;
        // An unfilled account has neither field. Keep the local form draft.
        _step = PersonalizationStep.form;
      });
    } catch (_) {
      if (mounted) {
        showGenesisToast(
          context,
          'Sign-in failed. Please try again.',
          brightness: Brightness.dark,
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = null);
    }
  }

  void _backToForm() {
    if (_signingIn == null) setState(() => _step = PersonalizationStep.form);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Modal routes remove top MediaQuery padding. Read the window safe inset
    // so this offset also includes the status bar / camera area on each device.
    final view = View.of(context);
    final safeTop = view.viewPadding.top / view.devicePixelRatio;
    final totalHeight = math.min(
      PersonalizationSheet.sheetHeight,
      math.max(0.0, media.size.height - safeTop - 18),
    );
    final height = math.max(0.0, totalHeight - media.padding.bottom);

    return PopScope(
      canPop: _step == PersonalizationStep.subscription,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _step == PersonalizationStep.signIn) _backToForm();
      },
      child: GenesisDarkTheme(
        child: GenesisBottomSystemBarStyleScope(
          style: const GenesisBottomSystemBarStyle(
            color: GenesisColors.darkRaisedBackground,
          ),
          child: SizedBox(
            height: height + media.padding.bottom,
            child: GenesisBottomSheetPanel(
              title: '',
              height: height,
              padding: EdgeInsets.zero,
              insetBody: false,
              header: _PersonalizationHeader(
                step: _step,
                onBack: _signingIn == null ? _backToForm : null,
                onSkip: () => Navigator.of(context).pop(_profile),
              ),
              child: SizedBox(
                key: const ValueKey('personalization-body'),
                child: GenesisActionSheetBody(
                  bottom: _step == PersonalizationStep.form ? 14 : 0,
                  child: _step == PersonalizationStep.subscription
                      ? _subscription()
                      : _step == PersonalizationStep.form
                      ? _form()
                      : _login(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _subscription() => LayoutBuilder(
    builder: (context, constraints) {
      final minimumHeight =
          520 * MediaQuery.textScalerOf(context).scale(16) / 16;
      return SingleChildScrollView(
        key: const ValueKey('personalization-subscription-scroll'),
        child: SizedBox(
          height: math.max(constraints.maxHeight, minimumHeight),
          child: widget.subscriptionBuilder(context),
        ),
      );
    },
  );

  Widget _form() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const ValueKey('personalization-form-scroll'),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_signedIn) ...[
                const Text(
                  'Complete your profile to continue.',
                  style: TextStyle(
                    fontSize: 14,
                    color: GenesisColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _choices<PersonalizationGender>(
                'Gender',
                PersonalizationGender.values,
                _gender,
                (v) => v.label,
                (v) => setState(() => _gender = v),
                columns: 3,
                maxWidth: constraints.maxWidth,
              ),
              const SizedBox(height: 24),
              _choices<PersonalizationAge>(
                'Age',
                PersonalizationAge.values,
                _age,
                (v) => v.label,
                (v) => setState(() => _age = v),
                columns: 2,
                maxWidth: constraints.maxWidth,
              ),
              const SizedBox(height: 40),
              GenesisPrimaryButton(
                key: const ValueKey('personalization-continue'),
                label: 'Continue',
                height: 48,
                onDisabledPressed: () => showGenesisToast(
                  context,
                  _gender == null && _age == null
                      ? 'Please select your gender and age.'
                      : _gender == null
                      ? 'Please select your gender.'
                      : 'Please select your age.',
                  brightness: Brightness.dark,
                ),
                onPressed: _profile.isComplete
                    ? () => setState(
                        () => _step = PersonalizationStep.subscription,
                      )
                    : null,
              ),
              if (!_signedIn)
                Center(
                  child: TextButton(
                    key: const ValueKey('personalization-sign-in'),
                    onPressed: () =>
                        setState(() => _step = PersonalizationStep.signIn),
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'I have an account to ',
                            style: TextStyle(
                              color: GenesisColors.darkTextSecondary,
                            ),
                          ),
                          TextSpan(
                            text: 'Sign in.',
                            style: TextStyle(
                              color: GenesisColors.redSecondary,
                              decoration: TextDecoration.underline,
                              decorationColor: GenesisColors.redSecondary,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _login() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const ValueKey('personalization-login-scroll'),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/app_icon.png',
                key: const ValueKey('personalization-login-app-icon'),
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                semanticLabel: 'Worldo',
              ),
            ),
            const SizedBox(height: 40),
            const LoginSignupRewardText(),
            const SizedBox(height: 12),
            LoginProviderButtons(
              loggingInProvider: _signingIn,
              onLogin: _signIn,
              spacing: 12,
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LoginLegalText(),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _choices<T>(
    String title,
    List<T> values,
    T? selected,
    String Function(T) label,
    ValueChanged<T> onChanged, {
    required int columns,
    required double maxWidth,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: GenesisColors.darkTextPrimary,
            ),
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Required',
              style: TextStyle(
                fontSize: 12,
                color: GenesisColors.darkTextTertiary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Builder(
        builder: (context) {
          final count = MediaQuery.textScalerOf(context).scale(16) > 21
              ? 2
              : columns;
          final width = (maxWidth - (count - 1) * 8) / count;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                SizedBox(
                  width: width,
                  child: Semantics(
                    selected: value == selected,
                    inMutuallyExclusiveGroup: true,
                    child: OutlinedButton(
                      key: ValueKey('personalization-${label(value)}'),
                      onPressed: () => onChanged(value),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: value == selected
                            ? GenesisColors.darkTextPrimary
                            : GenesisColors.darkTextSecondary,
                        backgroundColor: value == selected
                            ? GenesisColors.redPrimary.withValues(alpha: .12)
                            : GenesisColors.darkPurchaseCardBackground,
                        side: BorderSide(
                          color: value == selected
                              ? GenesisColors.redPrimary
                              : GenesisColors.darkCardBorder,
                        ),
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        label(value),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.3),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

/// All steps share the standard fixed-height action header.
class _PersonalizationHeader extends StatelessWidget {
  const _PersonalizationHeader({
    required this.step,
    required this.onBack,
    required this.onSkip,
  });

  final PersonalizationStep step;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  static const formTitle = 'Personalize Your Worldo Experience';

  @override
  Widget build(BuildContext context) => GenesisActionSheetHeader(
    key: const ValueKey('personalization-header'),
    titleKey: const ValueKey('personalization-header-title'),
    title: switch (step) {
      PersonalizationStep.form => formTitle,
      PersonalizationStep.signIn => 'Sign in',
      PersonalizationStep.subscription => 'Subscription',
    },
    leading: switch (step) {
      PersonalizationStep.form => null,
      PersonalizationStep.signIn => IconButton(
        key: const ValueKey('personalization-back'),
        tooltip: 'Back',
        onPressed: onBack,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 24),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      PersonalizationStep.subscription => SvgPicture.asset(
        proCrownIconAsset,
        key: const ValueKey('personalization-subscription-icon'),
        width: 22,
        height: 22,
        colorFilter: const ColorFilter.mode(
          GenesisColors.darkTextPrimary,
          BlendMode.srcIn,
        ),
      ),
    },
    trailing: step == PersonalizationStep.subscription
        ? TextButton(
            key: const ValueKey('personalization-skip'),
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: GenesisColors.darkTextSecondary,
              minimumSize: const Size(44, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Skip'),
          )
        : null,
  );
}
