import 'package:flutter/material.dart';

import '../../app/membership/membership_catalog.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/gems/pro_subscription_content.dart';
import '../../components/onboarding/personalization_sheet.dart';
import '../../ui/theme/genesis_dark_theme.dart';

enum PersonalizationPreviewScenario {
  newUser('新用户填表（未登录）', '直接看初始表单；可填写后 Continue，或点 Sign in 模拟登录后尚未填表。'),
  signedInEmpty('已登录 · 尚未填写资料', '直接看已登录的表单：Gender、Age 都为空，底部没有登录链接。'),
  signInComplete(
    '登录 · 账号资料已完整',
    '直接看登录步骤；点 Google / Apple 模拟登录成功，两项已有值，sheet 关闭。',
  ),
  subscription('订阅 sheet', '直接看填表完成后的订阅样式；可切换套餐，点 Skip 关闭。'),
  close('Close sheet', '关闭当前开发预览，回到底层页面。');

  const PersonalizationPreviewScenario(this.label, this.description);
  final String label;
  final String description;
}

Future<PersonalizationPreviewScenario?> selectPersonalizationPreviewScenario(
  BuildContext context,
) => showDialog<PersonalizationPreviewScenario>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text('Onboarding preview'),
    children: [
      for (final scenario in PersonalizationPreviewScenario.values) ...[
        if (scenario == PersonalizationPreviewScenario.close) const Divider(),
        SimpleDialogOption(
          key: ValueKey('onboarding-scenario-${scenario.name}'),
          onPressed: () => Navigator.of(context).pop(scenario),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenario.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  scenario.description,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  ),
);

ModalRoute<PersonalizationProfile>? _activePersonalizationPreviewRoute;

/// A Developer panel may be above the preview. Close the owned preview route,
/// not whichever route happens to be at the top of the navigator.
void closeDeveloperPersonalizationPreview() {
  final route = _activePersonalizationPreviewRoute;
  final navigator = route?.navigator;
  if (route == null || navigator == null || !route.isActive) return;
  _activePersonalizationPreviewRoute = null;
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}

Future<void> showDeveloperPersonalizationPreview(
  BuildContext context,
  PersonalizationPreviewScenario scenario, {
  MembershipCatalogLoader? productsLoader,
}) async {
  closeDeveloperPersonalizationPreview();
  if (scenario == PersonalizationPreviewScenario.close) return;
  ModalRoute<PersonalizationProfile>? previewRoute;
  try {
    await showGenesisModalBottomSheet<PersonalizationProfile>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        previewRoute = ModalRoute.of<PersonalizationProfile>(context);
        _activePersonalizationPreviewRoute = previewRoute;
        return _DeveloperPersonalizationPreview(
          initialScenario: scenario,
          productsLoader: productsLoader,
        );
      },
    );
  } finally {
    if (identical(_activePersonalizationPreviewRoute, previewRoute)) {
      _activePersonalizationPreviewRoute = null;
    }
  }
}

class _DeveloperPersonalizationPreview extends StatefulWidget {
  const _DeveloperPersonalizationPreview({
    required this.initialScenario,
    required this.productsLoader,
  });
  final PersonalizationPreviewScenario initialScenario;
  final MembershipCatalogLoader? productsLoader;

  @override
  State<_DeveloperPersonalizationPreview> createState() =>
      _DeveloperPersonalizationPreviewState();
}

class _DeveloperPersonalizationPreviewState
    extends State<_DeveloperPersonalizationPreview> {
  late PersonalizationPreviewScenario _scenario = widget.initialScenario;
  int _revision = 0;

  Future<void> _options() async {
    final selection = await selectPersonalizationPreviewScenario(context);
    if (!mounted || selection == null) return;
    if (selection == PersonalizationPreviewScenario.close) {
      closeDeveloperPersonalizationPreview();
      return;
    }
    setState(() {
      _scenario = selection;
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Capture this scenario so an in-flight simulated login cannot change
    // its result when the developer starts another preview.
    final scenario = _scenario;
    const completeProfile = PersonalizationProfile(
      gender: 'Non_binary',
      age: '25-34',
      completed: true,
    );
    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: GenesisDarkTheme(
                child: Material(
                  color: Colors.transparent,
                  child: FilledButton.tonal(
                    key: const ValueKey('onboarding-preview-options'),
                    onPressed: _options,
                    child: const Text('Preview options'),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: PersonalizationSheet(
              useSharedLoginSubmission: false,
              trackFormEvents: false,
              form: personalizationPreviewForm,
              onSubmit: (_) async => PersonalizationNextStep.subscription,
              key: ValueKey(_revision),
              initialStep: switch (scenario) {
                PersonalizationPreviewScenario.signInComplete =>
                  PersonalizationStep.signIn,
                PersonalizationPreviewScenario.subscription =>
                  PersonalizationStep.subscription,
                _ => PersonalizationStep.form,
              },
              initiallySignedIn:
                  scenario == PersonalizationPreviewScenario.signedInEmpty,
              initialProfile:
                  scenario == PersonalizationPreviewScenario.subscription
                  ? completeProfile
                  : const PersonalizationProfile(),
              onSignIn: (_) async {
                await Future<void>.delayed(const Duration(milliseconds: 450));
                return scenario == PersonalizationPreviewScenario.signInComplete
                    ? completeProfile
                    : const PersonalizationProfile();
              },
              subscriptionBuilder: (_) => ProSubscriptionContent.purchaseSheet(
                productsLoader: widget.productsLoader,
                onCloseAfterPurchaseSuccess:
                    closeDeveloperPersonalizationPreview,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Design fixtures only. Production choices come from device/personalization.
final personalizationPreviewForm = [
  PersonalizationField(
    name: 'gender',
    label: 'Gender',
    options: [
      for (final value in ['Male', 'Female', 'Non_binary'])
        PersonalizationOption(value: value, label: value),
    ],
  ),
  PersonalizationField(
    name: 'age',
    label: 'Age',
    options: [
      for (final value in ['18-24', '25-34', '35-44', '45+'])
        PersonalizationOption(value: value, label: value),
    ],
  ),
];
