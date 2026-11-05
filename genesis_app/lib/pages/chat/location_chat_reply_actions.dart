import '../../l10n/genesis_l10n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/membership/subscription_analytics.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../features/location_chat_reply/edit/edit.dart';
import '../../features/location_chat_reply/go_on/go_on.dart';
import '../../features/location_chat_reply/inspiration/inspiration.dart';
import '../../features/location_chat_reply/regenerate/regenerate.dart';
import '../../features/location_chat_reply/shared/reply_action_state.dart';
import '../../features/location_chat_reply/shared/reply_feature_button.dart';
import '../../icons/custom_icon_assets.dart';
import '../../components/gems/gem_purchase_bottom_sheet.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/components/genesis_localized_rich_text.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/tokens/genesis_spacing.dart';
import '../../ui/tokens/genesis_typography.dart';

part '../../features/location_chat_reply/inspiration/src/location_chat_inspiration_replies.dart';

/// Reply actions with source-bound inspiration suggestions and host-owned messaging.
class LocationChatReplyActions extends StatefulWidget {
  const LocationChatReplyActions({
    super.key,
    required this.style,
    this.regenerateFeature = const LocationChatRegenerateFeature.disabled(),
    this.goOnFeature = const LocationChatGoOnFeature.disabled(),
    this.editFeature = const LocationChatEditFeature.disabled(),
    this.inspirationFeature = const LocationChatInspirationFeature.disabled(),
    this.selfMessageBubbleMaxWidthCap,
    this.inspirationExpanded,
    this.inspirationListKey,
    this.inspirationIdentity,
    this.inspirationPromptExpanded,
    this.onInspirationPromptExpandedChanged,
    this.onInspirationExpandedChanged,
    this.inspirationPage,
    this.onInspirationPageChanged,
    this.cardIndex = 0,
    this.cardCount = 0,
    this.cardsConfirmed = false,
    this.cardSwitchEnabled = true,
    this.onPreviousCard,
    this.onNextCard,
    this.editPromptExpanded,
    this.onEditPromptExpandedChanged,
    this.loadingIndicator,
    this.reservedLoadingIndicator,
    this.actionsExpanded = true,
    this.paginationExpanded,
    this.onTakePhoto,
    this.cameraState = LocationChatReplyActionState.none,
    this.actionsHidden = false,
    this.actionToolbarKey,
    this.paginationKey,
  });

  final LocationChatRegenerateFeature regenerateFeature;
  final LocationChatGoOnFeature goOnFeature;
  final LocationChatEditFeature editFeature;
  final LocationChatInspirationFeature inspirationFeature;

  /// Zero-based position in the full card list, including in-flight/failed cards.
  final int cardIndex;
  final int cardCount;
  final bool cardsConfirmed;
  final bool cardSwitchEnabled;
  final VoidCallback? onPreviousCard;
  final VoidCallback? onNextCard;
  final bool? editPromptExpanded;
  final ValueChanged<bool>? onEditPromptExpandedChanged;

  /// Replaces the action buttons while a sent message awaits reply content.
  final Widget? loadingIndicator;

  /// Keeps the future loading slot laid out without changing toolbar animation.
  final Widget? reservedLoadingIndicator;
  final bool actionsExpanded;
  final bool? paginationExpanded;
  final VoidCallback? onTakePhoto;
  final LocationChatReplyActionState cameraState;
  final bool actionsHidden;
  final Key? actionToolbarKey;
  final Key? paginationKey;
  final ChatUiStyleConfig style;
  final double? selfMessageBubbleMaxWidthCap;
  final int? inspirationPage;
  final ValueChanged<int>? onInspirationPageChanged;
  final bool? inspirationExpanded;
  final Key? inspirationListKey;
  final Object? inspirationIdentity;
  final bool? inspirationPromptExpanded;
  final ValueChanged<bool>? onInspirationPromptExpandedChanged;
  final ValueChanged<bool>? onInspirationExpandedChanged;

  static const inspirationAnimationDuration = Duration(milliseconds: 220);
  static const inspirationAnimationCurve = Curves.easeOut;

  /// Animate the toolbar's height while keeping its buttons hidden until open.
  static const actionCollapseAnimationEnabled = true;

  static const double buttonSize = LocationChatReplyFeatureButton.layoutSize;
  static const double iconSize = LocationChatReplyFeatureButton.iconSize;
  static const double centerSpacing =
      LocationChatReplyActionButtons.centerSpacing;
  // Keep the external content gap independent of the larger touch targets.
  static const double contentBottomGap = 4.5;

  @override
  State<LocationChatReplyActions> createState() =>
      _LocationChatReplyActionsState();
}

class _LocationChatReplyActionsState extends State<LocationChatReplyActions> {
  bool _localEditPromptExpanded = false;
  bool _localInspirationExpanded = false;
  bool _localInspirationPromptExpanded = false;
  int _localInspirationPage = 0;
  bool get _inspirationExpanded =>
      widget.inspirationExpanded ?? _localInspirationExpanded;

  void _setEditPromptExpanded(bool expanded) {
    if (widget.onEditPromptExpandedChanged case final onChanged?) {
      onChanged(expanded);
    } else {
      setState(() => _localEditPromptExpanded = expanded);
    }
  }

  void _invokeInspiration() {
    _setEditPromptExpanded(false);
    _setInspirationPromptExpanded(true);
    _setInspirationExpanded(
      !(_inspirationExpanded && _inspiration.messages.isNotEmpty),
    );
  }

  void _setInspirationPromptExpanded(bool expanded) {
    if (widget.onInspirationPromptExpandedChanged case final onChanged?) {
      onChanged(expanded);
    } else {
      setState(() => _localInspirationPromptExpanded = expanded);
    }
  }

  void _setInspirationExpanded(bool next) {
    if (widget.inspirationExpanded == null) {
      setState(() => _localInspirationExpanded = next);
    }
    final onChanged =
        widget.onInspirationExpandedChanged ??
        widget.inspirationFeature.onExpandedChanged;
    onChanged?.call(next);
  }

  ChatUiStyleConfig get style => widget.style;

  LocationChatRegenerateFeature get _regenerate => widget.regenerateFeature;
  LocationChatGoOnFeature get _goOn => widget.goOnFeature;
  LocationChatEditFeature get _edit => widget.editFeature;
  LocationChatInspirationFeature get _inspiration => widget.inspirationFeature;

  @override
  Widget build(BuildContext context) {
    final hasWaitingIndicator =
        widget.loadingIndicator != null ||
        widget.reservedLoadingIndicator != null;
    final paginationVisible =
        !hasWaitingIndicator && widget.cardCount > 1 && !widget.cardsConfirmed;
    final prompt = _visibleQuotaPrompt();
    final toolbarState = LocationChatReplyToolbarState({
      LocationChatReplyActionId.regenerate: _regenerate.state,
      LocationChatReplyActionId.goOn: _goOn.state,
      LocationChatReplyActionId.edit: _edit.state,
      LocationChatReplyActionId.inspiration: _inspiration.state,
      LocationChatReplyActionId.camera: widget.cameraState,
    });
    final Widget? actionButtons = hasWaitingIndicator
        ? (widget.reservedLoadingIndicator == null
              ? widget.loadingIndicator
              : null)
        : LocationChatReplyActionButtons(
            state: toolbarState,
            buttons: [
              LocationChatReplyActionButton(
                id: LocationChatReplyActionId.regenerate,
                label: context.l10n.chatRegenerate,
                iconAsset: regenerateIconAsset,
                onTap: _regenerate.onInvoke,
                onDisabledTap: _regenerate.onLimitReached,
                onBeforeInvoke: () {
                  _setEditPromptExpanded(false);
                  _setInspirationExpanded(false);
                },
              ),
              LocationChatReplyActionButton(
                id: LocationChatReplyActionId.goOn,
                label: context.l10n.chatGo,
                iconAsset: goOnIconAsset,
                onTap: _goOn.onInvoke,
                onBeforeInvoke: () {
                  _setEditPromptExpanded(false);
                  _setInspirationExpanded(false);
                },
              ),
              LocationChatReplyActionButton(
                id: LocationChatReplyActionId.edit,
                label: context.l10n.chatEdit,
                iconAsset: editSquareIconAsset,
                onTap: _edit.onInvoke,
                onBeforeInvoke: () {
                  _setEditPromptExpanded(true);
                  _setInspirationPromptExpanded(false);
                  _setInspirationExpanded(false);
                },
              ),
              LocationChatReplyActionButton(
                id: LocationChatReplyActionId.inspiration,
                label: context.l10n.chatInspiration,
                iconAsset: inspirationIconAsset,
                expanded: _inspirationExpanded,
                onTap: _invokeInspiration,
                onBeforeInvoke: () => _setEditPromptExpanded(false),
              ),
              LocationChatReplyActionButton(
                id: LocationChatReplyActionId.camera,
                label: context.l10n.miniPhoneCamera,
                iconAsset: cameraIconAsset,
                onTap: widget.onTakePhoto,
              ),
            ],
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LocationChatReplyPagination(
          key: widget.paginationKey,
          expanded:
              (widget.paginationExpanded ?? widget.actionsExpanded) &&
              paginationVisible,
          pagination: paginationVisible ? _buildPagination(context) : null,
        ),
        Visibility(
          visible: !widget.actionsHidden,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: _LocationChatReplyActionToolbar(
            key: widget.actionToolbarKey,
            expanded: widget.actionsExpanded,
            animateChanges: widget.loadingIndicator == null,
            style: style,
            actions: actionButtons,
            reservedIndicator: widget.reservedLoadingIndicator,
          ),
        ),
        LocationChatInspirationReplies(
          key: widget.inspirationListKey,
          identity: widget.inspirationIdentity,
          expanded:
              widget.actionsExpanded &&
              !hasWaitingIndicator &&
              _inspiration.state != LocationChatReplyActionState.none &&
              _inspirationExpanded,
          replies: _inspiration.messages,
          onSend: (text) {
            _setInspirationExpanded(false);
            _inspiration.onSend?.call(text);
          },
          onEdit: (text) {
            _setInspirationPromptExpanded(false);
            _setInspirationExpanded(false);
            _inspiration.onEdit?.call(text);
          },
          style: style,
          maxWidthCap: widget.selfMessageBubbleMaxWidthCap,
          initialPage: widget.inspirationPage ?? _localInspirationPage,
          onPageChanged: (page) {
            _localInspirationPage = page;
            widget.onInspirationPageChanged?.call(page);
          },
        ),
        _LocationChatReplyQuotaPromptTransition(
          prompt: prompt,
          expanded: prompt != null,
        ),
      ],
    );
  }

  Widget? _visibleQuotaPrompt() {
    if (!widget.actionsExpanded || widget.loadingIndicator != null) return null;
    final inspirationRemaining = _inspiration.freeUsesRemaining;
    if ((widget.inspirationPromptExpanded ?? _localInspirationPromptExpanded) &&
        inspirationRemaining != null) {
      return _quotaPrompt(
        feature: 'inspiration',
        template: context.l10n.freeInspirationUsesLeft(
          remaining: GenesisLocalizedRichText.placeholder('remaining'),
          action: GenesisLocalizedRichText.placeholder('action'),
        ),
        remaining: inspirationRemaining,
      );
    }
    final editRemaining = _edit.freeUsesRemaining;
    if ((widget.editPromptExpanded ?? _localEditPromptExpanded) &&
        editRemaining != null) {
      return _quotaPrompt(
        feature: 'edit',
        template: context.l10n.freeEditionUsesLeft(
          remaining: GenesisLocalizedRichText.placeholder('remaining'),
          action: GenesisLocalizedRichText.placeholder('action'),
        ),
        remaining: editRemaining,
      );
    }
    return null;
  }

  Widget _buildPagination(BuildContext context) {
    // Keep 7.5 above the label and 4.5 below it: together with the
    // preceding 4.5 gap and following icon inset, both visual gaps are 12.
    final paginationTextPainter = TextPainter(
      text: TextSpan(
        text: '${widget.cardIndex + 1} / ${widget.cardCount}',
        style: DefaultTextStyle.of(context).style.merge(
          const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final paginationHeight = paginationTextPainter.height + 9;
    paginationTextPainter.dispose();
    final paginationButtonStyle = IconButton.styleFrom(
      minimumSize: Size(48, paginationHeight),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
    return Padding(
      key: const ValueKey('location-chat-reply-pagination'),
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('location-chat-reply-previous-card'),
            style: paginationButtonStyle,
            tooltip: GenesisL10n.current.chatPreviousReply,
            onPressed: widget.cardSwitchEnabled && widget.cardIndex > 0
                ? widget.onPreviousCard
                : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            color: GenesisColors.darkTextPrimary,
            disabledColor: GenesisColors.darkTextTertiary,
          ),
          Text(
            '${widget.cardIndex + 1} / ${widget.cardCount}',
            key: const ValueKey('location-chat-reply-page-indicator'),
            semanticsLabel:
                'Reply ${widget.cardIndex + 1} of ${widget.cardCount}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GenesisColors.darkTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          IconButton(
            key: const ValueKey('location-chat-reply-next-card'),
            style: paginationButtonStyle,
            tooltip: GenesisL10n.current.chatNextReply,
            onPressed:
                widget.cardSwitchEnabled &&
                    widget.cardIndex < widget.cardCount - 1
                ? widget.onNextCard
                : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            color: GenesisColors.darkTextPrimary,
            disabledColor: GenesisColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }

  Widget _quotaPrompt({
    required String feature,
    required String template,
    required int remaining,
  }) => Padding(
    padding: EdgeInsets.only(
      top: feature == 'inspiration' && _inspiration.messages.isNotEmpty
          ? GenesisSpacing.xl
          : LocationChatReplyActions.contentBottomGap,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth -
              style.avatarSize -
              style.avatarBubbleGap -
              style.avatarSideSpacerWidth,
        );
        final width = math.min(
          availableWidth,
          math.min(
            chatNormalBubbleMaxWidth(context, style),
            widget.selfMessageBubbleMaxWidthCap ?? double.infinity,
          ),
        );
        return Center(
          child: SizedBox(
            width: width,
            child: Center(
              child: LocationChatSubscriptionPrompt(
                style: style,
                promptKey: ValueKey('$feature-subscription-prompt'),
                semanticsLabel: template
                    .replaceAll('{remaining}', '$remaining')
                    .replaceAll('{action}', context.l10n.getMoreAction)
                    .replaceAll('\n', '. '),
                template: template,
                placeholders: {
                  'remaining': TextSpan(
                    text: '"$remaining"',
                    style: const TextStyle(color: GenesisColors.redSecondary),
                  ),
                  'action': TextSpan(
                    text: context.l10n.getMoreAction,
                    style: const TextStyle(color: GenesisColors.redSecondary),
                  ),
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _LocationChatReplyQuotaPromptTransition extends StatefulWidget {
  const _LocationChatReplyQuotaPromptTransition({
    required this.expanded,
    required this.prompt,
  });

  final bool expanded;
  final Widget? prompt;

  @override
  State<_LocationChatReplyQuotaPromptTransition> createState() =>
      _LocationChatReplyQuotaPromptTransitionState();
}

class _LocationChatReplyQuotaPromptTransitionState
    extends State<_LocationChatReplyQuotaPromptTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expansionController;
  late final CurvedAnimation _expansion;
  Widget? _displayedPrompt;

  bool get _wantsOpen => widget.expanded && widget.prompt != null;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: LocationChatReplyActions.inspirationAnimationDuration,
    );
    _expansion = CurvedAnimation(
      parent: _expansionController,
      curve: LocationChatReplyActions.inspirationAnimationCurve,
    );
    _expansionController.addStatusListener(_onExpansionStatus);
    if (_wantsOpen) {
      _displayedPrompt = widget.prompt;
      _expansionController.value = 1;
    }
  }

  @override
  void didUpdateWidget(
    covariant _LocationChatReplyQuotaPromptTransition oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (_wantsOpen) {
      // Edit -> Inspiration is a content replacement inside the same open
      // surface. Do not close and reopen the prompt around that replacement.
      _displayedPrompt = widget.prompt;
      _expansionController.forward();
    } else if (!_expansionController.isDismissed) {
      _expansionController.reverse();
    }
  }

  void _onExpansionStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted || _wantsOpen) return;
    setState(() => _displayedPrompt = null);
  }

  @override
  void dispose() {
    _expansion.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _displayedPrompt;
    if (prompt == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _expansionController,
      child: IgnorePointer(
        ignoring: !_wantsOpen,
        child: ExcludeSemantics(excluding: !_wantsOpen, child: prompt),
      ),
      builder: (context, child) => SizeTransition(
        key: const ValueKey('location-chat-subscription-prompt-transition'),
        sizeFactor: _expansion,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: _expansion, child: child),
      ),
    );
  }
}

class _LocationChatReplyPagination extends StatefulWidget {
  const _LocationChatReplyPagination({
    super.key,
    required this.expanded,
    required this.pagination,
  });

  final bool expanded;
  final Widget? pagination;

  @override
  State<_LocationChatReplyPagination> createState() =>
      _LocationChatReplyPaginationState();
}

class _LocationChatReplyPaginationState
    extends State<_LocationChatReplyPagination>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expansionController;
  late final CurvedAnimation _expansion;
  Widget? _displayedPagination;

  bool get _wantsOpen => widget.expanded && widget.pagination != null;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: LocationChatReplyActions.inspirationAnimationDuration,
    );
    _expansion = CurvedAnimation(
      parent: _expansionController,
      curve: LocationChatReplyActions.inspirationAnimationCurve,
    );
    _expansionController.addStatusListener(_onExpansionStatus);
    if (_wantsOpen) {
      _displayedPagination = widget.pagination;
      _expansionController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _LocationChatReplyPagination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_wantsOpen) {
      _displayedPagination = widget.pagination;
      _expansionController.forward();
    } else if (!_expansionController.isDismissed) {
      _expansionController.reverse();
    }
  }

  void _onExpansionStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted || _wantsOpen) return;
    setState(() => _displayedPagination = null);
  }

  @override
  void dispose() {
    _expansion.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pagination = _displayedPagination;
    if (pagination == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _expansionController,
      child: IgnorePointer(
        ignoring: !_wantsOpen,
        child: ExcludeSemantics(excluding: !_wantsOpen, child: pagination),
      ),
      builder: (context, child) => SizeTransition(
        key: const ValueKey('location-chat-reply-pagination-transition'),
        sizeFactor: _expansion,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}

class _LocationChatReplyActionToolbar extends StatefulWidget {
  const _LocationChatReplyActionToolbar({
    super.key,
    required this.expanded,
    required this.animateChanges,
    required this.style,
    required this.actions,
    this.reservedIndicator,
  });

  final bool expanded;
  final bool animateChanges;
  final ChatUiStyleConfig style;
  final Widget? actions;
  final Widget? reservedIndicator;

  @override
  State<_LocationChatReplyActionToolbar> createState() =>
      _LocationChatReplyActionToolbarState();
}

class _LocationChatReplyActionToolbarState
    extends State<_LocationChatReplyActionToolbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expansionController;
  late final CurvedAnimation _expansion;
  Widget? _displayedActions;

  bool get _wantsOpen => widget.expanded && widget.actions != null;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: LocationChatReplyActions.inspirationAnimationDuration,
    );
    _expansion = CurvedAnimation(
      parent: _expansionController,
      curve: LocationChatReplyActions.inspirationAnimationCurve,
    );
    _expansionController.addStatusListener(_onExpansionStatus);
    if (_wantsOpen) {
      _displayedActions = widget.actions;
      _expansionController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _LocationChatReplyActionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animateChanges || (!oldWidget.animateChanges && !_wantsOpen)) {
      _expansionController.stop();
      _displayedActions = _wantsOpen ? widget.actions : null;
      _expansionController.value = _wantsOpen ? 1 : 0;
      return;
    }
    _syncExpansion();
  }

  void _syncExpansion() {
    if (!_wantsOpen) {
      if (LocationChatReplyActions.actionCollapseAnimationEnabled) {
        if (!_expansionController.isDismissed &&
            _expansionController.status != AnimationStatus.reverse) {
          _expansionController.reverse();
        }
      } else {
        _displayedActions = null;
        _expansionController.value = 0;
      }
      return;
    }
    _displayedActions = widget.actions;
    // Scrolling rebuilds the sliver every frame. Restarting the same direction
    // resets the animation clock instead of preserving the current transition.
    if (!_expansionController.isCompleted &&
        _expansionController.status != AnimationStatus.forward) {
      _expansionController.forward();
    }
  }

  void _onExpansionStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted || _wantsOpen) return;
    setState(() => _displayedActions = null);
  }

  @override
  void dispose() {
    _expansion.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = _displayedActions == null
        ? const SizedBox.shrink()
        : AnimatedBuilder(
            animation: _expansionController,
            child: IgnorePointer(
              ignoring: !_wantsOpen,
              child: ExcludeSemantics(
                excluding: !_wantsOpen,
                child: Padding(
                  padding: EdgeInsets.only(
                    left:
                        widget.style.avatarSize + widget.style.avatarBubbleGap,
                    // Align the camera icon's visible edge with self bubbles,
                    // allowing for the icon's inset inside its layout slot.
                    right:
                        widget.style.avatarSize +
                        widget.style.avatarBubbleGap -
                        (LocationChatReplyActions.buttonSize -
                                LocationChatReplyActions.iconSize) /
                            2,
                  ),
                  child: SizedBox(
                    height: LocationChatReplyActions.buttonSize,
                    child: _displayedActions,
                  ),
                ),
              ),
            ),
            builder: (context, child) => _expansionController.isDismissed
                ? const SizedBox.shrink()
                : _wantsOpen && _expansionController.isCompleted
                ? SizedBox(
                    key: const ValueKey(
                      'location-chat-reply-actions-transition',
                    ),
                    height: LocationChatReplyActions.buttonSize,
                    child: child,
                  )
                : SizeTransition(
                    key: const ValueKey(
                      'location-chat-reply-actions-transition',
                    ),
                    sizeFactor: _expansion,
                    alignment: Alignment.bottomLeft,
                    child: const SizedBox(
                      height: LocationChatReplyActions.buttonSize,
                    ),
                  ),
          );
    final indicator = widget.reservedIndicator;
    if (indicator == null) return toolbar;
    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        toolbar,
        Padding(
          padding: EdgeInsets.only(
            left: widget.style.avatarSize + widget.style.avatarBubbleGap,
          ),
          child: SizedBox(
            height: LocationChatReplyActions.buttonSize,
            child: Align(alignment: Alignment.centerLeft, child: indicator),
          ),
        ),
      ],
    );
  }
}

/// Shared appearance for inline subscription prompts below reply actions.
class LocationChatSubscriptionPrompt extends StatelessWidget {
  const LocationChatSubscriptionPrompt({
    super.key,
    required this.style,
    required this.promptKey,
    required this.semanticsLabel,
    required this.template,
    required this.placeholders,
    this.singleLine = false,
  });

  final ChatUiStyleConfig style;
  final Key promptKey;
  final String semanticsLabel;
  final String template;
  final Map<String, InlineSpan> placeholders;
  final bool singleLine;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    child: GestureDetector(
      key: promptKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => showSubscriptionPurchaseBottomSheet(
        context,
        source: SubscriptionSource.chatFeatureQuota,
      ),
      child: ChatStableBackdropSurface(
        borderRadius: BorderRadius.circular(style.bubbleBorderRadius),
        sigma: style.bubbleBackdropBlurSigma,
        child: Container(
          padding: style.bubblePadding,
          decoration: BoxDecoration(
            color:
                (style.useScenePlateBubbleGeometry &&
                            !style.useConfiguredScenePlateSystemStyle
                        ? GenesisColors.darkBackground
                        : chatNarratorMessageBackgroundColor(style))
                    .withValues(alpha: style.selfBubbleColor.a),
            borderRadius: BorderRadius.circular(style.bubbleBorderRadius),
          ),
          child: GenesisLocalizedRichText(
            template: singleLine ? template.replaceFirst('\n', ' ') : template,
            placeholders: placeholders,
            maxLines: singleLine ? 1 : null,
            softWrap: !singleLine,
            textWidthBasis: TextWidthBasis.longestLine,
            textAlign: TextAlign.center,
            style: GenesisTypography.resolve(
              context,
              style.bubbleTextStyle,
            ).copyWith(fontSize: 13),
          ),
        ),
      ),
    ),
  );
}
