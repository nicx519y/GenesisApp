import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../common/genesis_action_box.dart';
import 'gem_assets.dart';
import 'gem_colors.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/components/genesis_modal_border.dart';

enum GemBillingPurchaseDialogPhase { processing, success }

class GemBillingPurchaseDialogState {
  const GemBillingPurchaseDialogState({
    required this.phase,
    required this.attemptId,
    this.grantedText = '',
  });

  factory GemBillingPurchaseDialogState.processing({
    required String attemptId,
  }) {
    return GemBillingPurchaseDialogState(
      phase: GemBillingPurchaseDialogPhase.processing,
      attemptId: attemptId,
    );
  }

  factory GemBillingPurchaseDialogState.success({
    required String attemptId,
    required String grantedText,
  }) {
    return GemBillingPurchaseDialogState(
      phase: GemBillingPurchaseDialogPhase.success,
      attemptId: attemptId,
      grantedText: grantedText,
    );
  }

  final GemBillingPurchaseDialogPhase phase;
  final String attemptId;
  final String grantedText;
}

class GemBillingPurchaseDialog extends StatelessWidget {
  const GemBillingPurchaseDialog({
    super.key,
    required this.state,
    required this.onConfirm,
  });

  final ValueListenable<GemBillingPurchaseDialogState> state;
  final VoidCallback onConfirm;
  static const double _processingHeight = 202;
  static const double _titleHorizontalPadding = 24;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GemBillingPurchaseDialogState>(
      valueListenable: state,
      builder: (context, value, _) {
        final isSuccess = value.phase == GemBillingPurchaseDialogPhase.success;
        return PopScope(
          // The purchase result must be acknowledged explicitly with OK.
          canPop: false,
          child: isSuccess
              ? _GemBillingPurchaseSuccessDialog(
                  grantedText: value.grantedText,
                  onConfirm: onConfirm,
                )
              : GenesisActionBox<bool>(
                  title: '',
                  titleHeight: _processingHeight,
                  titleHorizontalPadding: _titleHorizontalPadding,
                  titleWidget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: context.genesisGemColors.accent,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _ProcessingPaymentText(),
                    ],
                  ),
                  actions: const [],
                  showCancel: false,
                  borderColor: context.genesisColors.textPrimary.withValues(
                    alpha: 0.14,
                  ),
                  onActionSelected: (_) => onConfirm(),
                  onCancel: onConfirm,
                ),
        );
      },
    );
  }
}

class _GemBillingPurchaseSuccessDialog extends StatelessWidget {
  const _GemBillingPurchaseSuccessDialog({
    required this.grantedText,
    required this.onConfirm,
  });

  final String grantedText;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final amountText = grantedText.isEmpty ? '' : '+$grantedText';
    const borderRadius = BorderRadius.all(Radius.circular(20));
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints.tightFor(width: 250),
      backgroundColor: Colors.transparent,
      child: Container(
        key: const ValueKey<String>('billing-purchase-success-dialog'),
        width: 250,
        decoration: BoxDecoration(
          color: context.genesisColors.surfaceRaised,
          borderRadius: borderRadius,
          border: genesisModalBorder(context),
          boxShadow: [
            BoxShadow(
              color: context.genesisColors.shadow.withValues(alpha: 0.55),
              blurRadius: 44,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    gemIconAsset,
                    key: const ValueKey<String>(
                      'billing-purchase-granted-icon',
                    ),
                    width: 38,
                    height: 59,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Purchase successful!',
                    key: const ValueKey<String>(
                      'billing-purchase-success-title',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: context.genesisColors.textPrimary,
                    ),
                  ),
                  const SizedBox(
                    key: ValueKey<String>('billing-purchase-success-line-gap'),
                    height: 14,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      key: const ValueKey<String>(
                        'billing-purchase-granted-fit',
                      ),
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        key: const ValueKey<String>(
                          'billing-purchase-granted-line',
                        ),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            amountText,
                            key: const ValueKey<String>(
                              'billing-purchase-granted-amount',
                            ),
                            style: TextStyle(
                              fontSize: 30,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: context.genesisColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Gems',
                            key: const ValueKey<String>(
                              'billing-purchase-granted-unit',
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w500,
                              color: context.genesisColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Added to your balance',
                    key: const ValueKey<String>(
                      'billing-purchase-granted-subtitle',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                      color: context.genesisColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              key: const ValueKey<String>('billing-purchase-success-divider'),
              width: double.infinity,
              height: 1,
              color: context.genesisColors.dividerAction,
            ),
            Semantics(
              button: true,
              child: InkWell(
                key: const ValueKey<String>('billing-purchase-success-confirm'),
                onTap: onConfirm,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 51,
                  child: Center(
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: context.genesisGemColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingPaymentText extends StatefulWidget {
  const _ProcessingPaymentText();

  @override
  State<_ProcessingPaymentText> createState() => _ProcessingPaymentTextState();
}

class _ProcessingPaymentTextState extends State<_ProcessingPaymentText> {
  late final Timer _timer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _dotCount = _dotCount == 3 ? 1 : _dotCount + 1);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 15,
      height: 20 / 15,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      color: context.genesisColors.textPrimary,
    );
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Purchasing Gems',
                textAlign: TextAlign.center,
                style: style,
              ),
              SizedBox(
                width: 18,
                child: Text(
                  '.' * _dotCount,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  softWrap: false,
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
