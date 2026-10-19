import '../../platform/session/user_session_store.dart';
import '../../app/review/app_review_service.dart';
import 'pending_rating_reward_host.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/genesis_localizations.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'genesis_action_box.dart';
import 'genesis_content_submission_dialog.dart';
import '../../app/bootstrap/app_services_scope.dart';
import 'genesis_modal_routes.dart';
import '../../utils/api_error_message.dart';
import 'genesis_center_toast.dart';

final _appReviewService = AppReviewService();
bool _ratingFlowOpen = false;

/// Login required for both automatic and manual entries; no login UI is opened.
Future<int?> showWorldoRatingDialog(
  BuildContext context, {
  AppReviewService? reviewService,
}) async {
  if (_ratingFlowOpen) return null;
  _ratingFlowOpen = true;
  PendingRatingReward.flowActive = true;
  final services = AppServicesScope.read(context);
  final revision = services.sessionRevision.value;
  final parentRoute = ModalRoute.of(context);
  bool current() =>
      context.mounted &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      services.sessionRevision.value == revision &&
      (parentRoute?.isCurrent ?? true);
  TransitionRoute<dynamic>? ratingRoute;
  try {
    final loginUid = await services.sessionStore.readLoginUid();
    if (loginUid == null || !context.mounted || !current()) return null;
    final rating = await showGenesisDialog<int>(
      context: context,
      barrierColor: const Color(0x52000000),
      builder: (dialogContext) {
        ratingRoute = ModalRoute.of(dialogContext) as TransitionRoute<dynamic>?;
        return const WorldoRatingContent();
      },
    );
    // Native UI must not be launched under a dialog's reverse transition.
    await ratingRoute?.completed;
    if (rating == null || !context.mounted || !current()) return rating;
    final owner = await services.sessionStore.readLoginUid();
    if (owner == null || owner != loginUid || !current()) return rating;
    await PendingRatingReward.save(owner, rating);
    PendingRatingReward.flowActive = true;
    AppReviewOutcome? outcome;
    if (rating >= 4) {
      try {
        outcome = await (reviewService ?? _appReviewService).requestFor(
          owner,
          isCurrent: current,
        );
      } catch (_) {
        // In-app review failures never open a store or block the feedback reward.
      }
    }
    if (outcome != AppReviewOutcome.deferred && context.mounted && current()) {
      await PendingRatingReward.show(context, owner, rating);
    }
    return rating;
  } finally {
    PendingRatingReward.flowActive = false;
    _ratingFlowOpen = false;
  }
}

class WorldoRatingContent extends StatefulWidget {
  const WorldoRatingContent({super.key});

  @override
  State<WorldoRatingContent> createState() => _WorldoRatingContentState();
}

class _WorldoRatingContentState extends State<WorldoRatingContent> {
  int _rating = 0;
  bool _feedback = false;
  bool _submitting = false;
  bool _ratingFailed = false;
  final _controller = TextEditingController();
  final _feedbackFocus = FocusNode();
  bool _focusRequested = false;

  @override
  void dispose() {
    _feedbackFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (_rating == 0 || _submitting) return;
    final api = AppServicesScope.read(context).api;
    final failure = context.l10n.feedbackFailed;
    final services = AppServicesScope.read(context);
    final revision = services.sessionRevision.value;
    setState(() {
      _submitting = true;
      _ratingFailed = false;
    });
    try {
      final uid = await services.sessionStore.readLoginUid();
      if (uid == null || services.sessionRevision.value != revision) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
      await api.v1.feedback.create(
        rating: _rating,
        content: content.isEmpty ? null : content,
      );
      if (!mounted) return;
      if (services.sessionRevision.value != revision) {
        setState(() => _submitting = false);
        return;
      }
      Navigator.of(context).pop(_rating);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _ratingFailed = _rating >= 4;
      });
      showGenesisToast(
        context,
        apiErrorMessage(error, fallback: failure),
        brightness: Brightness.dark,
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _feedback ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      onEnd: () {
        if (_feedback && !_focusRequested && mounted) {
          _focusRequested = true;
          _feedbackFocus.requestFocus();
        }
      },
      builder: (context, progress, _) => GenesisActionBox<int>(
        title: context.l10n.rateWorldoTitle,
        titleWidget: const SizedBox.shrink(),
        titleHeight: 0,
        showCancel: _feedback || _ratingFailed,
        actions: [
          if (_feedback || _ratingFailed)
            GenesisActionBoxAction<int>(
              label: _ratingFailed
                  ? context.l10n.homeRetry
                  : context.l10n.createSubmit,
              value: _rating,
              enabled: !_submitting,
            ),
        ],
        onActionSelected: (_) => _submit(),
        onCancel: () {
          if (!_submitting) Navigator.of(context).pop();
        },
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20 - 6 * progress,
              32 - 8 * progress,
              20 - 6 * progress,
              24 - 10 * progress,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.rateWorldoTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GenesisColors.darkTextPrimary,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ClipRect(
                  child: Align(
                    heightFactor: 1 - progress,
                    child: AnimatedOpacity(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 360),
                      curve: Curves.easeInOut,
                      opacity: _feedback ? 0 : 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 26),
                          Text(
                            context.l10n.rateWorldoMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: GenesisColors.darkTextSecondary,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 18 - 6 * progress),
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      for (var star = 1; star <= 5; star++)
                        SizedBox(
                          width:
                              constraints.maxWidth / 5 * (1 - progress) +
                              math.min(32.0, constraints.maxWidth / 5) *
                                  progress,
                          child: Semantics(
                            label: context.l10n.rateWorldoStars(count: star),
                            button: true,
                            selected: _rating == star,
                            child: ExcludeSemantics(
                              child: IconButton(
                                key: ValueKey('worldo-rating-star-$star'),
                                constraints: BoxConstraints(
                                  minHeight: 48 - 16 * progress,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: _submitting || _rating != 0
                                    ? null
                                    : () {
                                        setState(() {
                                          _rating = star;
                                          if (star <= 3) _feedback = true;
                                        });
                                        if (star >= 4) _submit();
                                      },
                                icon: SizedBox.square(
                                  dimension: 32 - 6 * progress,
                                  child: CustomPaint(
                                    painter: _RatingStarPainter(
                                      selected: star <= _rating,
                                      color: _rating >= star
                                          ? GenesisColors.redSecondary
                                          : GenesisColors.darkTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_feedback)
                  ClipRect(
                    child: Align(
                      heightFactor: progress,
                      child: Opacity(
                        opacity: progress,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 4),
                            GenesisFeedbackInput(
                              inputKey: const ValueKey(
                                'genesis-feedback-content-input',
                              ),
                              controller: _controller,
                              focusNode: _feedbackFocus,
                              autofocus: false,
                              hintText: context.l10n.rateWorldoFeedbackHint,
                              enabled: !_submitting,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A consistent thin outline instead of the heavier Material star glyph.
class _RatingStarPainter extends CustomPainter {
  const _RatingStarPainter({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final path = Path();
    for (var point = 0; point < 10; point++) {
      final angle = -math.pi / 2 + point * math.pi / 5;
      final distance = point.isEven ? radius : radius * 0.46;
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      if (point == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    if (selected) canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RatingStarPainter oldDelegate) =>
      selected != oldDelegate.selected || color != oldDelegate.color;
}
