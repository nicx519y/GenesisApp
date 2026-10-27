import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/privacy/privacy_choices_store.dart';
import '../../app/privacy/privacy_consent_controller.dart';
import '../../l10n/genesis_localizations.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../routers/app_router.dart';
import '../../pages/legal/legal_document_page.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/components/genesis_dark_close_button.dart';

/// Shared consent UI for startup, Settings, and isolated developer previews.
enum PrivacyDialogResult { submitted, closed, failed }

final privacyRouteObserver = RouteObserver<ModalRoute<dynamic>>();
Future<PrivacyDialogResult> showPrivacyChoicesDialog(
  BuildContext context, {
  bool dismissCurrentRoute = false,
  bool openChoicesDirectly = false,
  bool persistChoices = true,
  Future<PrivacyChoices?> Function()? loadChoices,
}) async {
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final target = rootNavigator.overlay?.context ?? rootNavigator.context;
  if (dismissCurrentRoute) {
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route == null || !route.isCurrent) return PrivacyDialogResult.closed;
    if (navigator.canPop()) {
      final dismissed = await navigator.maybePop();
      if (!dismissed || route.isCurrent) return PrivacyDialogResult.closed;
      await route.completed;
    }
  }
  PrivacyChoices? initialChoices;
  try {
    if (persistChoices) {
      initialChoices = await (loadChoices ?? PrivacyChoicesStore.read)()
          .timeout(const Duration(seconds: 2));
    }
  } catch (_) {
    if (target.mounted) {
      showGenesisToast(target, target.l10n.privacyChoicesLoadError);
    }
    return PrivacyDialogResult.failed;
  }
  if (!target.mounted) return PrivacyDialogResult.closed;
  TransitionRoute<dynamic>? presentedRoute;
  final submitted = await showGenesisDialog<PrivacyChoices>(
    context: target,
    barrierColor: const Color(0x52000000),
    barrierDismissible: false,
    builder: (dialogContext) {
      presentedRoute =
          ModalRoute.of(dialogContext) as TransitionRoute<dynamic>?;
      return _DmaPreview(
        openChoicesDirectly: openChoicesDirectly,
        initialChoices: initialChoices,
        persistChoices: persistChoices,
      );
    },
  );
  await presentedRoute?.completed;
  return submitted == null
      ? PrivacyDialogResult.closed
      : PrivacyDialogResult.submitted;
}

class _DmaPreview extends StatefulWidget {
  const _DmaPreview({
    required this.openChoicesDirectly,
    required this.initialChoices,
    required this.persistChoices,
  });

  final bool openChoicesDirectly;
  final PrivacyChoices? initialChoices;
  final bool persistChoices;

  @override
  State<_DmaPreview> createState() => _DmaPreviewState();
}

class _DmaPreviewState extends State<_DmaPreview> {
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _customize = widget.openChoicesDirectly;
    _restoreChoices();
    _privacyTap = TapGestureRecognizer()..onTap = _openPrivacyPolicy;
  }

  @override
  void dispose() {
    _privacyTap.dispose();
    super.dispose();
  }

  void _openPrivacyPolicy() => Navigator.of(context).pushNamed(
    RouteNames.legal,
    arguments: {'document': LegalDocument.privacy.name},
  );

  bool _customize = false;
  bool _adStorage = false;
  bool _shareData = false;
  bool _personalize = false;
  bool _analytics = false;
  bool _saving = false;

  void _restoreChoices() {
    _adStorage = widget.initialChoices?.adStorage ?? false;
    _shareData = widget.initialChoices?.adUserData ?? false;
    _personalize = widget.initialChoices?.adPersonalization ?? false;
    _analytics = widget.initialChoices?.analyticsStorage ?? false;
  }

  Future<void> _submit(String action) async {
    if (_saving) return;
    if (action == 'manage') {
      setState(() => _customize = true);
      return;
    }
    setState(() {
      _saving = true;
      if (action == 'accept' || action == 'reject') {
        _adStorage = _shareData = _personalize = _analytics =
            action == 'accept';
      }
    });
    try {
      if (widget.persistChoices) {
        await privacyConsent.save(
          PrivacyChoices(
            adStorage: _adStorage,
            adUserData: _shareData,
            adPersonalization: _personalize,
            analyticsStorage: _analytics,
          ),
          fromSettings: widget.openChoicesDirectly,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(
          PrivacyChoices(
            adStorage: _adStorage,
            adUserData: _shareData,
            adPersonalization: _personalize,
            analyticsStorage: _analytics,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showGenesisToast(context, context.l10n.privacyChoicesSaveError);
      }
    }
  }

  void _close() => Navigator.of(context).pop();

  void _onClosePressed() {
    if (_saving || !_customize) return;
    if (widget.openChoicesDirectly) {
      _close();
      return;
    }
    setState(() {
      _customize = false;
      _restoreChoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rows = _customize ? 2 : 3;
    final availableHeight = math.max(
      0.0,
      media.size.height -
          media.padding.vertical -
          media.viewInsets.bottom -
          GenesisActionBox.defaultRowHeight * rows -
          48,
    );
    return PopScope(
      canPop: false,
      child: GenesisActionBox<String>(
        title: context.l10n.privacyChoicesTitle,
        titleHeight: 0,
        titleWidget: const SizedBox.shrink(),
        showCancel: false,
        actions: _customize
            ? [
                GenesisActionBoxAction(
                  label: context.l10n.privacyChoicesAcceptAll,
                  value: 'accept',
                ),
                GenesisActionBoxAction(
                  label: context.l10n.privacyChoicesConfirm,
                  value: 'confirm',
                  color: GenesisColors.darkTextPrimary,
                ),
              ]
            : [
                GenesisActionBoxAction(
                  label: context.l10n.privacyChoicesConsent,
                  value: 'accept',
                ),
                GenesisActionBoxAction(
                  label: context.l10n.privacyChoicesReject,
                  value: 'reject',
                  fontWeight: FontWeight.w400,
                  color: GenesisColors.darkTextPrimary,
                ),
                GenesisActionBoxAction(
                  label: context.l10n.privacyChoicesManage,
                  value: 'manage',
                  fontWeight: FontWeight.w400,
                  color: GenesisColors.darkTextPrimary,
                ),
              ],
        onActionSelected: _submit,
        onCancel: _onClosePressed,
        content: Stack(
          children: [
            if (_customize)
              _choicesContent(availableHeight)
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.privacyChoicesTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: GenesisColors.darkTextPrimary,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text.rich(
                        _policyText(
                          context.l10n.privacyChoicesPartnersDescription(
                            privacyPolicy: '{privacyPolicy}',
                          ),
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: GenesisColors.darkTextSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_customize)
              Positioned(
                top: 12,
                right: 12,
                child: GenesisDarkCloseButton(
                  key: const ValueKey('dma-preview-close'),
                  onPressed: _onClosePressed,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choicesContent(double availableHeight) => SizedBox(
    height: math.min(460, availableHeight),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
      child: Column(
        children: [
          Text(
            context.l10n.privacyChoicesTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GenesisColors.darkTextPrimary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('dma-choices-scroll'),
              child: Column(
                children: [
                  _option(
                    title: context.l10n.privacyChoicesAdStorage,
                    description:
                        context.l10n.privacyChoicesAdStorageDescription,
                    value: _adStorage,
                    onChanged: (value) => setState(() => _adStorage = value),
                  ),
                  const GenesisActionBoxDivider(),
                  _option(
                    title: context.l10n.privacyChoicesAdUserData,
                    description:
                        context.l10n.privacyChoicesAdUserDataDescription,
                    value: _shareData,
                    onChanged: (value) => setState(() => _shareData = value),
                  ),
                  const GenesisActionBoxDivider(),
                  _option(
                    title: context.l10n.privacyChoicesPersonalization,
                    description:
                        context.l10n.privacyChoicesPersonalizationDescription,
                    value: _personalize,
                    onChanged: (value) => setState(() => _personalize = value),
                  ),
                  const GenesisActionBoxDivider(),
                  _option(
                    title: context.l10n.privacyChoicesAnalytics,
                    description:
                        context.l10n.privacyChoicesAnalyticsDescription,
                    value: _analytics,
                    onChanged: (value) => setState(() => _analytics = value),
                  ),
                  const GenesisActionBoxDivider(),
                  const SizedBox(height: 16),
                  Text.rich(
                    _policyText(
                      context.l10n.privacyChoicesPartnersDescription(
                        privacyPolicy: '{privacyPolicy}',
                      ),
                    ),
                    style: const TextStyle(
                      color: GenesisColors.darkTextTertiary,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  TextSpan _policyText(String sentence) {
    const marker = '{privacyPolicy}';
    final index = sentence.indexOf(marker);
    if (index < 0) return TextSpan(text: sentence);
    return TextSpan(
      children: [
        TextSpan(text: sentence.substring(0, index)),
        _policySpan(context.l10n.privacyPolicy, _privacyTap),
        TextSpan(text: sentence.substring(index + marker.length)),
      ],
    );
  }

  TextSpan _policySpan(String label, TapGestureRecognizer recognizer) =>
      TextSpan(
        text: label,
        recognizer: recognizer,
        style: const TextStyle(
          color: GenesisColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _option({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => MergeSemantics(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        description,
        style: const TextStyle(
          color: GenesisColors.darkTextSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      onTap: _saving ? null : () => onChanged(!value),
      trailing: SizedBox(
        width: 44,
        height: 32,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Switch(value: value, onChanged: _saving ? null : onChanged),
        ),
      ),
    ),
  );
}
