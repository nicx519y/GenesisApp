import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/chat/shared/chat_ui.dart';
import '../../features/location_chat_reply/edit/edit.dart';
import '../../features/location_chat_reply/go_on/go_on.dart';
import '../../features/location_chat_reply/inspiration/inspiration.dart';
import '../../features/location_chat_reply/regenerate/regenerate.dart';
import '../../features/location_chat_reply/shared/reply_action_state.dart';
import '../../icons/custom_icon_assets.dart';
import '../../components/gems/gem_purchase_bottom_sheet.dart';
import '../../ui/tokens/genesis_colors.dart';
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
    this.actionsExpanded = true,
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
  final bool actionsExpanded;
  final Key? actionToolbarKey;
  final Key? paginationKey;
  final ChatUiStyleConfig style;
  final double? selfMessageBubbleMaxWidthCap;
  final int? inspirationPage;
  final ValueChanged<int>? onInspirationPageChanged;
  final bool? inspirationExpanded;
  final Key? inspirationListKey;
  final Object? inspirationIdentity;
  final ValueChanged<bool>? onInspirationExpandedChanged;

  static const inspirationAnimationDuration = Duration(milliseconds: 220);
  static const inspirationAnimationCurve = Curves.easeOut;

  static const double buttonSize = 32;
  static const double iconSize = 17;
  static const double centerSpacing = 50;
  // Account for the icon's inset inside its button when spacing the row.
  static const double contentBottomGap = 12 - (buttonSize - iconSize) / 2;

  @override
  State<LocationChatReplyActions> createState() =>
      _LocationChatReplyActionsState();
}

class _LocationChatReplyActionsState extends State<LocationChatReplyActions> {
  bool _localEditPromptExpanded = false;
  bool _localInspirationExpanded = false;
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
    _setInspirationExpanded(
      !(_inspirationExpanded && _inspiration.messages.isNotEmpty),
    );
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
    final paginationVisible =
        widget.loadingIndicator == null &&
        widget.cardCount > 1 &&
        !widget.cardsConfirmed;
    final actionButtons = <Widget>[
      if (widget.loadingIndicator case final indicator?) indicator,
      if (widget.loadingIndicator == null) ...[
        if (_regenerate.state != LocationChatReplyActionState.none)
          LocationChatRegenerateButton(
            key: const ValueKey('location-chat-regenerate'),
            feature: _regenerate,
            onBeforeInvoke: () {
              _setEditPromptExpanded(false);
              _setInspirationExpanded(false);
            },
          ),
        if (_goOn.state != LocationChatReplyActionState.none)
          LocationChatGoOnButton(
            key: const ValueKey('location-chat-go-on'),
            feature: _goOn,
            onBeforeInvoke: () {
              _setEditPromptExpanded(false);
              _setInspirationExpanded(false);
            },
          ),
        if (_edit.state != LocationChatReplyActionState.none)
          LocationChatEditButton(
            key: const ValueKey('location-chat-edit'),
            feature: _edit,
            onBeforeInvoke: () {
              _setEditPromptExpanded(true);
              _setInspirationExpanded(false);
            },
          ),
        if (_inspiration.state != LocationChatReplyActionState.none)
          LocationChatInspirationButton(
            key: const ValueKey('location-chat-inspiration'),
            feature: _inspiration,
            expanded: _inspirationExpanded,
            onBeforeInvoke: () => _setEditPromptExpanded(false),
            onToggle: _invokeInspiration,
          ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LocationChatReplyPagination(
          key: widget.paginationKey,
          expanded: widget.actionsExpanded && paginationVisible,
          pagination: paginationVisible ? _buildPagination(context) : null,
        ),
        _LocationChatReplyActionToolbar(
          key: widget.actionToolbarKey,
          expanded: widget.actionsExpanded && actionButtons.isNotEmpty,
          animateChanges: widget.loadingIndicator == null,
          style: style,
          actions: actionButtons,
        ),
        if (widget.actionsExpanded &&
            widget.loadingIndicator == null &&
            (widget.editPromptExpanded ?? _localEditPromptExpanded) &&
            _edit.freeUsesRemaining != null)
          _quotaPrompt(
            feature: 'edit',
            message: 'Free Edition uses left: ',
            remaining: _edit.freeUsesRemaining!,
          ),
        LocationChatInspirationReplies(
          key: widget.inspirationListKey,
          identity: widget.inspirationIdentity,
          expanded:
              widget.actionsExpanded &&
              widget.loadingIndicator == null &&
              _inspiration.state != LocationChatReplyActionState.none &&
              _inspirationExpanded,
          replies: _inspiration.messages,
          footer: _inspiration.freeUsesRemaining != null
              ? _quotaPrompt(
                  feature: 'inspiration',
                  message: 'Free inspiration uses left: ',
                  remaining: _inspiration.freeUsesRemaining!,
                )
              : null,
          onSend: (text) {
            _setInspirationExpanded(false);
            _inspiration.onSend?.call(text);
          },
          onEdit: (text) {
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
      ],
    );
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
            tooltip: 'Previous reply',
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
            tooltip: 'Next reply',
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
    required String message,
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
                semanticsLabel: '$message$remaining. Get more',
                message: TextSpan(
                  children: [
                    TextSpan(text: message),
                    TextSpan(
                      text: '"$remaining"',
                      style: const TextStyle(color: GenesisColors.redSecondary),
                    ),
                  ],
                ),
                actionLabel: 'Get more >',
              ),
            ),
          ),
        );
      },
    ),
  );
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
  });

  final bool expanded;
  final bool animateChanges;
  final ChatUiStyleConfig style;
  final List<Widget> actions;

  @override
  State<_LocationChatReplyActionToolbar> createState() =>
      _LocationChatReplyActionToolbarState();
}

class _LocationChatReplyActionToolbarState
    extends State<_LocationChatReplyActionToolbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expansionController;
  late final CurvedAnimation _expansion;
  List<Widget> _displayedActions = const [];

  bool get _wantsOpen => widget.expanded && widget.actions.isNotEmpty;

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
      _displayedActions = List<Widget>.unmodifiable(widget.actions);
      _expansionController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _LocationChatReplyActionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animateChanges || (!oldWidget.animateChanges && !_wantsOpen)) {
      _expansionController.stop();
      _displayedActions = _wantsOpen
          ? List<Widget>.unmodifiable(widget.actions)
          : const [];
      _expansionController.value = _wantsOpen ? 1 : 0;
      return;
    }
    _syncExpansion();
  }

  void _syncExpansion() {
    if (!_wantsOpen) {
      if (!_expansionController.isDismissed) _expansionController.reverse();
      return;
    }
    _displayedActions = List<Widget>.unmodifiable(widget.actions);
    _expansionController.forward();
  }

  void _onExpansionStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted || _wantsOpen) return;
    setState(() => _displayedActions = const []);
  }

  @override
  void dispose() {
    _expansion.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _displayedActions.isEmpty
      ? const SizedBox.shrink()
      : AnimatedBuilder(
          animation: _expansionController,
          child: IgnorePointer(
            ignoring: !_wantsOpen,
            child: ExcludeSemantics(
              excluding: !_wantsOpen,
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.style.avatarSize + widget.style.avatarBubbleGap,
                ),
                child: SizedBox(
                  height: LocationChatReplyActions.buttonSize,
                  child: Row(
                    key: const ValueKey(
                      'location-chat-reply-actions-four-icons',
                    ),
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (
                        var index = 0;
                        index < _displayedActions.length;
                        index++
                      ) ...[
                        if (index > 0)
                          const SizedBox(
                            width:
                                LocationChatReplyActions.centerSpacing -
                                LocationChatReplyActions.buttonSize,
                          ),
                        _displayedActions[index],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          builder: (context, child) => _expansionController.isDismissed
              ? const SizedBox.shrink()
              : SizeTransition(
                  key: const ValueKey('location-chat-reply-actions-transition'),
                  sizeFactor: _expansion,
                  alignment: Alignment.bottomLeft,
                  child: child,
                ),
        );
}

/// Shared appearance for inline subscription prompts below reply actions.
class LocationChatSubscriptionPrompt extends StatelessWidget {
  const LocationChatSubscriptionPrompt({
    super.key,
    required this.style,
    required this.promptKey,
    required this.semanticsLabel,
    required this.message,
    required this.actionLabel,
    this.singleLine = false,
  });

  final ChatUiStyleConfig style;
  final Key promptKey;
  final String semanticsLabel;
  final InlineSpan message;
  final String actionLabel;
  final bool singleLine;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    child: GestureDetector(
      key: promptKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => showSubscriptionPurchaseBottomSheet(context),
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
          child: Text.rich(
            TextSpan(
              children: [
                message,
                TextSpan(
                  text: '${singleLine ? ' ' : '\n'}$actionLabel',
                  style: const TextStyle(color: GenesisColors.redSecondary),
                ),
              ],
            ),
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
