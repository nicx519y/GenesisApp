import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        BoxParentData,
        RenderProxyBox,
        ScrollCacheExtent,
        ScrollDirection,
        SliverMultiBoxAdaptorParentData,
        SliverConstraints,
        SliverGeometry,
        RenderSliverList;

import '../../components/chat/shared/chat_ui.dart';
import '../../app/debug/location_chat_bubble_layout_settings.dart';
import '../../features/location_chat_reply/edit/edit.dart';
import '../../features/location_chat_reply/go_on/go_on.dart';
import '../../features/location_chat_reply/inspiration/inspiration.dart';
import '../../features/location_chat_reply/regenerate/regenerate.dart';
import '../../features/location_chat_reply/shared/reply_action_state.dart';
import '../../ui/tokens/genesis_spacing.dart';
import 'location_chat_reply_actions.dart';
import 'location_chat_reply_card_switcher.dart';
import 'location_chat_reply_layout_bridge.dart';
import 'location_chat_reply_render_snapshot.dart';

enum LocationChatViewportMode { initializing, followingLatest, detached }

enum LocationChatBottomReason {
  sentMessage,
  replyGeneration,
  unseenMessageNotice,
  composerFocus,
  inspirationExpanded,
  editPromptExpanded,
}

enum LocationChatBottomBehavior { jump, animate }

const locationChatOldestEdgeLoadingAnimationDuration = Duration(
  milliseconds: 220,
);
// Must exceed ScrollPosition's 0.001 dimension tolerance even after rounding.
const _locationChatLayoutCorrectionExtentSignal = 0.01;
const _locationChatAnchorRestoreCacheExtent = 1000000000.0;

@visibleForTesting
int debugLocationChatMessageRowBuildCount = 0;

double locationChatStableReplyViewportHeightForTesting({
  required double currentViewportHeight,
  required double effectiveKeyboardInset,
}) => (currentViewportHeight + effectiveKeyboardInset).clamp(
  currentViewportHeight,
  double.infinity,
);

/// Provides the keyboard inset already applied outside the message viewport.
class LocationChatKeyboardInsetScope extends InheritedWidget {
  const LocationChatKeyboardInsetScope({
    super.key,
    required this.effectiveInset,
    required super.child,
  });

  final double effectiveInset;

  static double read(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<LocationChatKeyboardInsetScope>()
          ?.effectiveInset ??
      0;

  @override
  bool updateShouldNotify(LocationChatKeyboardInsetScope oldWidget) =>
      effectiveInset != oldWidget.effectiveInset;
}

/// Owns every programmatic scroll-position change for location chat.
class LocationChatScrollCoordinator extends ChangeNotifier {
  LocationChatScrollCoordinator({ScrollController? controller})
    : _ownsController = controller == null {
    this.controller =
        controller ??
        _LocationChatScrollController(
          shouldFollowLatest: () => shouldSnapToLatestOnLayout,
        );
  }

  static const double bottomTolerance = 24;
  static const double oldestMessageStopTolerance = 1;
  static const Duration bottomAnimationDuration = Duration(milliseconds: 220);

  late final ScrollController controller;
  final bool _ownsController;

  LocationChatViewportMode _mode = LocationChatViewportMode.initializing;
  int _commandGeneration = 0;
  int? _animatedBottomScrollGeneration;
  bool _entryRevealScheduled = false;
  double? _oldestMessageStopOffset;
  bool _userDragActive = false;
  bool _stopAtOldestMessageForCurrentDrag = false;
  bool _disposed = false;
  bool _holdingReplyPosition = false;
  bool _userScrollIncludesTemporaryTail = false;
  bool _hasMessageContentBelowViewport = false;
  Set<String> _messageLocalIdsBelowViewport = const {};
  Set<String> _messageLocalIdsIntersectingViewport = const {};
  Set<String> get messageLocalIdsBelowViewport => _messageLocalIdsBelowViewport;
  Set<String> get messageLocalIdsIntersectingViewport =>
      _messageLocalIdsIntersectingViewport;

  /// Excludes waiting space, action controls, and message bottom spacing.
  bool get hasMessageContentBelowViewport => _hasMessageContentBelowViewport;

  void reportMessageContentBelowViewport(
    bool value, {
    Set<String> messageLocalIds = const {},
    Set<String> visibleMessageLocalIds = const {},
  }) {
    if (_disposed ||
        (value == _hasMessageContentBelowViewport &&
            setEquals(messageLocalIds, _messageLocalIdsBelowViewport) &&
            setEquals(
              visibleMessageLocalIds,
              _messageLocalIdsIntersectingViewport,
            ))) {
      return;
    }
    _hasMessageContentBelowViewport = value;
    _messageLocalIdsBelowViewport = Set.unmodifiable(messageLocalIds);
    _messageLocalIdsIntersectingViewport = Set.unmodifiable(
      visibleMessageLocalIds,
    );
    notifyListeners();
  }

  LocationChatViewportMode get mode => _mode;
  bool get isDetached => _mode == LocationChatViewportMode.detached;
  bool get isReadingHistory => isDetached && !_holdingReplyPosition;
  bool get shouldFollowLatest => !isDetached;
  bool get canPositionWaitingReply =>
      shouldFollowLatest || _holdingReplyPosition;
  bool get shouldSnapToLatestOnLayout =>
      shouldFollowLatest && _animatedBottomScrollGeneration == null;
  int get commandGeneration => _commandGeneration;
  double? get oldestMessageStopOffset => _oldestMessageStopOffset;
  bool get shouldStopAtOldestMessage =>
      _userDragActive && _stopAtOldestMessageForCurrentDrag;

  bool get isAtBottom {
    if (!controller.hasClients) return true;
    final position = controller.position;
    return position.maxScrollExtent - position.pixels <= bottomTolerance;
  }

  void enter() {
    _holdingReplyPosition = false;
    _cancelPendingCommands();
    _entryRevealScheduled = false;
    _setMode(LocationChatViewportMode.initializing);
    onViewportLaidOut();
  }

  void deactivate() {
    _holdingReplyPosition = false;
    _cancelPendingCommands();
    _entryRevealScheduled = false;
    _setMode(LocationChatViewportMode.detached);
  }

  void onViewportLaidOut() {
    if (_disposed ||
        _mode != LocationChatViewportMode.initializing ||
        _entryRevealScheduled) {
      return;
    }
    _entryRevealScheduled = true;
    final generation = _commandGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryRevealScheduled = false;
      if (!_commandIsCurrent(generation) || !controller.hasClients) return;
      _jumpTo(controller.position.maxScrollExtent);
      _setMode(LocationChatViewportMode.followingLatest);
    });
  }

  void requestBottom({
    required LocationChatBottomReason reason,
    required LocationChatBottomBehavior behavior,
    Duration duration = bottomAnimationDuration,
  }) {
    if (_disposed) return;
    if (_holdingReplyPosition &&
        reason == LocationChatBottomReason.replyGeneration) {
      return;
    }
    _holdingReplyPosition = false;
    final generation = ++_commandGeneration;
    _animatedBottomScrollGeneration =
        behavior == LocationChatBottomBehavior.animate ? generation : null;
    _entryRevealScheduled = false;
    _setMode(LocationChatViewportMode.followingLatest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_commandIsCurrent(generation) || !controller.hasClients) return;
      final target = controller.position.maxScrollExtent;
      switch (behavior) {
        case LocationChatBottomBehavior.jump:
          _jumpTo(target);
        case LocationChatBottomBehavior.animate:
          if (reason == LocationChatBottomReason.inspirationExpanded) {
            _animateToGrowingBottom(duration, generation);
          } else {
            _animateTo(
              target,
              duration,
              generation,
              settleAtLatest:
                  reason == LocationChatBottomReason.replyGeneration ||
                  reason == LocationChatBottomReason.editPromptExpanded,
            );
          }
      }
    });
  }

  /// Move once, then let incoming content fill the space below this viewport.
  void positionWaitingReply(double target) {
    if (_disposed || !controller.hasClients) return;
    _cancelPendingCommands();
    final generation = _commandGeneration;
    _holdingReplyPosition = true;
    _entryRevealScheduled = false;
    _setMode(LocationChatViewportMode.detached);
    _jumpTo(controller.position.pixels); // Stop any earlier bottom animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_commandIsCurrent(generation) || !controller.hasClients) return;
      _animateTo(
        target.clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        ),
        bottomAnimationDuration,
        generation,
        settleAtLatest: false,
      );
    });
  }

  /// Stop a generated-reply hold without pulling a manually detached reader.
  void releaseWaitingReplyPosition() {
    if (_disposed || !_holdingReplyPosition) return;
    _holdingReplyPosition = false;
    _userScrollIncludesTemporaryTail = false;
    requestBottom(
      reason: LocationChatBottomReason.replyGeneration,
      behavior: LocationChatBottomBehavior.jump,
    );
  }

  /// Reveal the entire edited row when it fits, otherwise keep its end visible.
  void revealEditedMessage({
    required BuildContext messageContext,
    required BuildContext viewportContext,
  }) {
    if (_disposed || !controller.hasClients) return;
    final messageBox = messageContext.findRenderObject();
    final viewportBox = viewportContext.findRenderObject();
    if (messageBox is! RenderBox ||
        viewportBox is! RenderBox ||
        !messageBox.hasSize ||
        !viewportBox.hasSize) {
      return;
    }
    final messageTop = messageBox.localToGlobal(Offset.zero).dy;
    final messageBottom = messageTop + messageBox.size.height;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy + 12;
    final viewportBottom = viewportTop + viewportBox.size.height - 24;
    double delta = 0;
    if (messageBottom - messageTop > viewportBottom - viewportTop ||
        messageBottom > viewportBottom) {
      delta = messageBottom - viewportBottom;
    } else if (messageTop < viewportTop) {
      delta = messageTop - viewportTop;
    }
    if (delta.abs() < 0.5) return;
    _cancelPendingCommands();
    _jumpTo(
      (controller.position.pixels + delta).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
  }

  bool handleScrollNotification(ScrollNotification notification) {
    // Nested horizontal carousels must not change conversation anchoring.
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      final stoppedHoldingReplyPosition = _holdingReplyPosition;
      _holdingReplyPosition = false;
      _cancelPendingCommands();
      _userDragActive = true;
      final stopOffset = _oldestMessageStopOffset;
      _stopAtOldestMessageForCurrentDrag =
          stopOffset != null &&
          notification.metrics.pixels > stopOffset + oldestMessageStopTolerance;
      // A held reply and manual history reading share the detached viewport
      // mode. Notify when the hold ends so visible-row anchoring starts only
      // for the user's drag, never for the growing generated reply itself.
      if (stoppedHoldingReplyPosition) notifyListeners();
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _userDragActive = false;
      _stopAtOldestMessageForCurrentDrag = false;
    }

    final userDriven =
        notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle ||
        notification is ScrollUpdateNotification &&
            notification.dragDetails != null;
    if (!userDriven) return false;

    _holdingReplyPosition = false;

    final atBottom =
        !_userScrollIncludesTemporaryTail &&
        notification.metrics.maxScrollExtent - notification.metrics.pixels <=
            bottomTolerance;
    _cancelPendingCommands();
    _entryRevealScheduled = false;
    _setMode(
      atBottom
          ? LocationChatViewportMode.followingLatest
          : LocationChatViewportMode.detached,
    );
    return false;
  }

  void setOldestMessageStopOffset(double? value) {
    if (_disposed) return;
    final normalized = value?.clamp(0.0, double.infinity).toDouble();
    if (normalized == null && _oldestMessageStopOffset == null) return;
    if (normalized != null &&
        _oldestMessageStopOffset != null &&
        (normalized - _oldestMessageStopOffset!).abs() <
            precisionErrorTolerance) {
      return;
    }
    _oldestMessageStopOffset = normalized;
    if (normalized == null) {
      _userDragActive = false;
      _stopAtOldestMessageForCurrentDrag = false;
    }
  }

  void restoreAnchor({
    required double delta,
    required int expectedCommandGeneration,
  }) {
    if (_disposed ||
        !isDetached ||
        expectedCommandGeneration != _commandGeneration ||
        !controller.hasClients ||
        delta.abs() < precisionErrorTolerance) {
      return;
    }
    final position = controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < precisionErrorTolerance) return;
    _jumpTo(target);
  }

  void _cancelPendingCommands() {
    _commandGeneration += 1;
    _animatedBottomScrollGeneration = null;
  }

  bool _commandIsCurrent(int generation) {
    return !_disposed && generation == _commandGeneration;
  }

  void _setMode(LocationChatViewportMode value) {
    if (_mode == value || _disposed) return;
    _mode = value;
    notifyListeners();
  }

  void _jumpTo(double target) {
    controller.jumpTo(target);
  }

  Future<void> _animateTo(
    double target,
    Duration duration,
    int generation, {
    required bool settleAtLatest,
  }) async {
    try {
      await controller.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOut,
      );
    } finally {
      if (_animatedBottomScrollGeneration == generation) {
        _animatedBottomScrollGeneration = null;
      }
    }
    if (settleAtLatest &&
        _commandIsCurrent(generation) &&
        controller.hasClients &&
        shouldFollowLatest) {
      // Content may have grown while the request and scroll ran together.
      _jumpTo(controller.position.maxScrollExtent);
    }
  }

  /// Follows a bottom edge that is itself moving during the expansion.
  ///
  /// A regular [ScrollController.animateTo] captures one target extent. The
  /// inspiration list grows during the same 220ms, so that target is stale on
  /// the next layout and produces a visible catch-up jump at the end. Sampling
  /// the latest extent on every frame keeps the conversation scroll and the
  /// list expansion in one animation while retaining generation cancellation
  /// for user drags.
  void _animateToGrowingBottom(Duration duration, int generation) {
    if (!_commandIsCurrent(generation) || !controller.hasClients) return;
    final startPixels = controller.position.pixels;
    Duration? startTimestamp;

    void tick(Duration timestamp) {
      if (!_commandIsCurrent(generation) || !controller.hasClients) return;
      startTimestamp ??= timestamp;
      final elapsed = timestamp - startTimestamp!;
      final progress = duration == Duration.zero
          ? 1.0
          : (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
      final eased = Curves.easeOut.transform(progress);
      final position = controller.position;
      final target =
          startPixels + (position.maxScrollExtent - startPixels) * eased;
      _jumpTo(target.clamp(position.minScrollExtent, position.maxScrollExtent));
      if (progress < 1) {
        WidgetsBinding.instance.scheduleFrameCallback(tick);
        return;
      }
      if (_animatedBottomScrollGeneration == generation) {
        _animatedBottomScrollGeneration = null;
      }
      if (_commandIsCurrent(generation) &&
          controller.hasClients &&
          shouldFollowLatest) {
        _jumpTo(controller.position.maxScrollExtent);
      }
    }

    WidgetsBinding.instance.scheduleFrameCallback(tick);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _commandGeneration += 1;
    if (_ownsController) controller.dispose();
    super.dispose();
  }
}

class _LocationChatScrollController extends ScrollController {
  _LocationChatScrollController({required this.shouldFollowLatest});

  final bool Function() shouldFollowLatest;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _LocationChatScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    shouldFollowLatest: shouldFollowLatest,
  );
}

class _LocationChatScrollPosition extends ScrollPositionWithSingleContext {
  _LocationChatScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.shouldFollowLatest,
  });

  final bool Function() shouldFollowLatest;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final firstLayout = !haveDimensions;
    final accepted = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    // Flutter skips dimension-correction physics on the first layout. Position
    // the opening before paint instead of revealing the top then jumping down.
    if (firstLayout && shouldFollowLatest() && pixels != maxScrollExtent) {
      correctPixels(maxScrollExtent);
      return false;
    }
    return accepted;
  }
}

class LocationChatAnchoredMessageList extends StatefulWidget {
  const LocationChatAnchoredMessageList({
    super.key,
    required this.coordinator,
    required this.messages,
    required this.topTitle,
    this.loadingAfterMessageLocalId,
    this.loadingIdentity,
    this.preAckWaitingAfterMessageLocalId,
    this.preAckWaitingIdentity,
    this.waitingPositionResetRevision = 0,
    this.goOnAwaitingContentIdentity,
    this.replyWaitingPositioningEnabled = true,
    this.replyViewportReserveFraction =
        LocationChatBubbleLayoutSettings.defaultReplyViewportReserveFraction,
    this.active = true,
    this.onMessageLongPressStart,
    this.onFailedMessageTap,
    this.onCharactersMovedLocationTap,
    this.keyboardDismissBehavior,
    this.oldestEdgeNotice,
    this.oldestEdgeNoticeRequiresSecondScroll = false,
    this.oldestEdgeLoading = false,
    this.onOldestEdgeLoadingCollapsed,
    this.showDateDividers = true,
    this.messageLayoutId,
    this.replyActionsMessageId,
    this.replyActionsIdentity,
    this.replyActionsVisible = true,
    this.replyPresentationRevision = 0,
    this.replyStatus,
    this.replyCards = const [],
    this.replyCurrentCardId = 0,
    this.replyCardBindingIdentity,
    this.replyCardSwitchEnabled = true,
    this.replyRegenerationInProgress = false,
    this.replyRegenerationDispatchRevision = 0,
    this.onReplyCardSelected,
    this.onReplyCardTransitionChanged,
    this.regenerateFeature = const LocationChatRegenerateFeature.disabled(),
    this.goOnFeature = const LocationChatGoOnFeature.disabled(),
    this.editFeature = const LocationChatEditFeature.disabled(),
    this.inspirationFeature = const LocationChatInspirationFeature.disabled(),
    this.replyCardIndex = 0,
    this.replyCardCount = 0,
    this.replyCardsConfirmed = false,
    this.showConfirmedCardPagination = false,
    this.onPreviousReplyCard,
    this.onNextReplyCard,
    this.inspirationIdentity,
    this.inspirationPresentationRevision = 0,
    this.selfMessageBubbleMaxWidthCap,
    this.otherMessageBubbleMaxWidthCap,
    this.style,
  });

  final LocationChatScrollCoordinator coordinator;
  final List<ChatMessageVm> messages;
  final String topTitle;
  final String? loadingAfterMessageLocalId;
  final String? loadingIdentity;
  final String? preAckWaitingAfterMessageLocalId;
  final String? preAckWaitingIdentity;
  final int waitingPositionResetRevision;

  /// Accepted Go On waiting for its first non-empty rendered reply.
  final String? goOnAwaitingContentIdentity;

  /// Whether Send, Go On and Regenerate hold a waiting anchor above the tail.
  final bool replyWaitingPositioningEnabled;

  /// Portion below the reply anchor, shared by Send, Go On and Regenerate.
  final double replyViewportReserveFraction;
  final bool active;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatMessageTap? onFailedMessageTap;
  final ChatCharacterMovementTap? onCharactersMovedLocationTap;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? oldestEdgeNotice;
  final bool oldestEdgeNoticeRequiresSecondScroll;
  final bool oldestEdgeLoading;
  final VoidCallback? onOldestEdgeLoadingCollapsed;
  final bool showDateDividers;
  final String Function(ChatMessageVm message)? messageLayoutId;

  /// Last projected reply message that may use the compact action-row gap.
  /// This marker does not determine round or action eligibility.
  final String? replyActionsMessageId;

  /// Stable world/location/round identity, independent of candidate message IDs.
  final String? replyActionsIdentity;

  /// Shows the controls inside the permanent bottom action slot.
  final bool replyActionsVisible;

  /// Change only for explicit card switches, never for streaming text updates.
  final int replyPresentationRevision;
  final Widget? replyStatus;
  final List<LocationChatReplyCard> replyCards;
  final int replyCurrentCardId;
  final String? replyCardBindingIdentity;
  final bool replyCardSwitchEnabled;
  final bool replyRegenerationInProgress;
  final int replyRegenerationDispatchRevision;
  final bool Function(int cardId)? onReplyCardSelected;
  final ValueChanged<bool>? onReplyCardTransitionChanged;
  final LocationChatRegenerateFeature regenerateFeature;
  final LocationChatGoOnFeature goOnFeature;
  final LocationChatEditFeature editFeature;
  final LocationChatInspirationFeature inspirationFeature;
  final int replyCardIndex;
  final int replyCardCount;
  final bool replyCardsConfirmed;

  /// Keep the locked pager visible during card selection until Go On ACK.
  final bool showConfirmedCardPagination;
  final VoidCallback? onPreviousReplyCard;
  final VoidCallback? onNextReplyCard;
  final String? inspirationIdentity;
  final int inspirationPresentationRevision;
  final double? selfMessageBubbleMaxWidthCap;
  final double? otherMessageBubbleMaxWidthCap;
  final ChatUiStyleConfig? style;

  @override
  State<LocationChatAnchoredMessageList> createState() =>
      _LocationChatAnchoredMessageListState();
}

class _LocationChatAnchoredMessageListState
    extends State<LocationChatAnchoredMessageList>
    with SingleTickerProviderStateMixin {
  final GlobalKey _messageContentKey = GlobalKey();
  final Map<String, GlobalKey> _messageLayoutKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _messageVisibilityKeys = <String, GlobalKey>{};
  final GlobalKey _scrollViewportKey = GlobalKey();
  final GlobalKey _replyControlLayoutKey = GlobalKey();
  final GlobalKey _waitingBubbleLayoutKey = GlobalKey();
  double _waitingMinContentExtent = 0;
  bool _consumingTemporaryTail = false;
  bool _contentVisibilityScheduled = false;

  bool _handleTemporaryTailScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _consumingTemporaryTail = true;
    } else if (notification is UserScrollNotification) {
      _consumingTemporaryTail = notification.direction != ScrollDirection.idle;
    }
    final metrics = notification.metrics;
    // Reaching a reserved tail is not reaching the real conversation bottom.
    widget.coordinator._userScrollIncludesTemporaryTail =
        _waitingMinContentExtent > 0 &&
        _waitingMinContentExtent + _layoutCorrectionExtentSignal >=
            metrics.maxScrollExtent + metrics.viewportDimension - 0.5;
    if (_consumingTemporaryTail &&
        notification is ScrollUpdateNotification &&
        (notification.scrollDelta ?? 0) < 0 &&
        _waitingMinContentExtent > 0) {
      // Pulling messages down consumes the exposed tail. Keep only enough
      // extent for this viewport; reversing the gesture cannot recreate it.
      // The real rows still determine the natural minimum scroll extent.
      final extent =
          (metrics.pixels +
                  metrics.viewportDimension -
                  _layoutCorrectionExtentSignal)
              .clamp(0.0, _waitingMinContentExtent);
      if (extent < _waitingMinContentExtent) {
        setState(() => _waitingMinContentExtent = extent);
      }
    }
    return false;
  }

  void _scheduleContentVisibility() {
    if (_contentVisibilityScheduled) return;
    _contentVisibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentVisibilityScheduled = false;
      if (!mounted || !widget.active) return;
      final viewport = _globalBounds(
        _scrollViewportKey.currentContext?.findRenderObject(),
      );
      if (viewport == null) return;
      final last = _renderedMessages.lastOrNull;
      if (last == null) {
        widget.coordinator.reportMessageContentBelowViewport(false);
        return;
      }
      final style = widget.style ?? ChatUiStyleConfig.standard;
      final compact =
          _currentReplyCard?.messages.lastOrNull?.localId == last.localId
          ? _replyActionsImmediatelyFollowDeck
          : widget.replyActionsVisible &&
                last.localId == widget.replyActionsMessageId;
      final bottomGap = compact
          ? LocationChatReplyActions.contentBottomGap
          : last.isSystem && !last.isImage
          ? style.systemMessageMargin.bottom
          : style.rowBottomPadding;
      final bounds = _messageBounds(_messageLayoutId(last));
      // Past the real tail the lazy list may keep only its footer laid out.
      // When neither is laid out the last message is beyond the history cache
      // below the viewport, not part of the artificial waiting-space sliver.
      final footer = _globalBounds(
        _replyControlLayoutKey.currentContext?.findRenderObject(),
      );
      final bottom = bounds?.bottom ?? footer?.top;
      final hasContentBelow =
          bottom == null || bottom - bottomGap > viewport.bottom + 0.5;
      final below = <String>{};
      final visible = <String>{};
      final rows = <Rect?>[];
      var lastLaidOutIndex = -1;
      for (var index = 0; index < _renderedMessages.length; index++) {
        final message = _renderedMessages[index];
        final layoutId = _messageLayoutId(message);
        final row = _messageBounds(layoutId);
        rows.add(row);
        if (row != null) lastLaidOutIndex = index;
        final messageBounds = _messageVisibilityBounds(layoutId);
        if (messageBounds != null && messageBounds.overlaps(viewport)) {
          visible.add(message.localId);
        }
      }
      if (hasContentBelow) {
        for (var index = 0; index < _renderedMessages.length; index++) {
          final message = _renderedMessages[index];
          final row = rows[index];
          final gap = message.localId == last.localId
              ? bottomGap
              : message.isSystem && !message.isImage
              ? style.systemMessageMargin.bottom
              : style.rowBottomPadding;
          // Only unlaid-out rows after the lazy list's laid-out range are
          // below the viewport. Rows before it are older bubbles above us.
          if ((row == null && index > lastLaidOutIndex) ||
              (row != null && row.bottom - gap > viewport.bottom + 0.5)) {
            below.add(message.localId);
          }
        }
      }
      widget.coordinator.reportMessageContentBelowViewport(
        hasContentBelow,
        messageLocalIds: below,
        visibleMessageLocalIds: visible,
      );
    });
  }

  void _retainExtentOnStreamCompletion() {
    final coordinator = widget.coordinator;
    if (!widget.replyWaitingPositioningEnabled ||
        !widget.active ||
        widget.replyRegenerationInProgress ||
        !coordinator.controller.hasClients ||
        !coordinator.shouldFollowLatest ||
        !coordinator.isAtBottom) {
      return;
    }
    final viewport = _globalBounds(
      _scrollViewportKey.currentContext?.findRenderObject(),
    );
    if (viewport == null) return;
    for (final message in widget.messages) {
      if (message.status != 'sent') continue;
      final layoutId = _messageLayoutId(message);
      final previous =
          _rowChildren[layoutId]?.snapshot ??
          _cardRowChildren[widget.replyCurrentCardId]?[message.localId]
              ?.snapshot;
      if (previous?.status != 'streaming') continue;
      final bounds = _messageBounds(layoutId);
      if (bounds == null || !bounds.overlaps(viewport)) continue;
      final position = coordinator.controller.position;
      // Final text or the compact action-row gap can be shorter than the last
      // stream frame. Keep that lost height in the tail instead of following
      // a smaller maxScrollExtent and moving every visible bubble downward.
      // The next reply consumes the space; growing content still follows normally.
      _waitingMinContentExtent = _waitingMinContentExtent.clamp(
        position.maxScrollExtent +
            position.viewportDimension -
            _layoutCorrectionExtentSignal,
        double.infinity,
      );
      break;
    }
  }

  static String? _waitingIdentity(LocationChatAnchoredMessageList list) =>
      !list.replyWaitingPositioningEnabled
      ? null
      : list.replyRegenerationInProgress
      ? 'regenerate:${list.replyCardBindingIdentity ?? list.replyActionsIdentity}'
      : list.goOnAwaitingContentIdentity ??
            list.preAckWaitingIdentity ??
            (list.loadingAfterMessageLocalId == null
                ? null
                : list.loadingIdentity ?? list.loadingAfterMessageLocalId);

  void _scheduleWaitingPosition() {
    final identity = _waitingIdentity(widget);
    if (identity == null || !widget.active) return;
    final coordinator = widget.coordinator;
    final generation = coordinator.commandGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.active ||
          widget.coordinator != coordinator ||
          _waitingIdentity(widget) != identity ||
          coordinator.commandGeneration != generation ||
          !coordinator.canPositionWaitingReply ||
          !coordinator.controller.hasClients) {
        return;
      }
      final regenerating = widget.replyRegenerationInProgress;
      final anchor = _globalBounds(
        (regenerating
                ? _cardSwitcherKey.currentContext
                : _waitingBubbleLayoutKey.currentContext)
            ?.findRenderObject(),
      );
      final viewport = _globalBounds(
        _scrollViewportKey.currentContext?.findRenderObject(),
      );
      if (anchor == null || viewport == null) return;
      // Regenerate has no loading bubble. Treat the collapsing card as if the
      // shared 32px loading/action slot still followed its top, so its content
      // starts at the same visual position as Send/Go On while the reserve is
      // still measured below that virtual slot's bottom.
      final anchorEdge = regenerating
          ? anchor.top + LocationChatReplyActions.buttonSize
          : anchor.bottom;
      final contentAnchor =
          coordinator.controller.position.pixels + anchorEdge - viewport.top;
      final stableViewportHeight =
          locationChatStableReplyViewportHeightForTesting(
            currentViewportHeight: viewport.height,
            effectiveKeyboardInset: LocationChatKeyboardInsetScope.read(
              context,
            ),
          );
      final reservedHeight =
          stableViewportHeight *
          LocationChatBubbleLayoutSettings.normalizeReplyViewportReserveFraction(
            widget.replyViewportReserveFraction,
          );
      // Keep this minimum extent after loading ends. Reply growth consumes it,
      // so dismissing the bubble never clamps the reader back down the list.
      setState(() {
        _waitingMinContentExtent = (contentAnchor + reservedHeight).clamp(
          stableViewportHeight,
          double.infinity,
        );
      });
      coordinator.positionWaitingReply(
        contentAnchor - (stableViewportHeight - reservedHeight),
      );
    });
  }

  final GlobalKey _replyActionToolbarKey = GlobalKey(
    debugLabel: 'reply-action-toolbar',
  );
  final GlobalKey _replyPaginationKey = GlobalKey(
    debugLabel: 'reply-pagination',
  );
  final _cardSwitcherKey = GlobalKey<LocationChatReplyCardSwitcherState>();
  bool _cardTransitionBusy = false;
  final _replyLayoutBridge = LocationChatReplyLayoutBridge();
  int _replyLayoutFinishGeneration = 0;
  int? _replyLayoutCommandGeneration;
  bool _replyLayoutFinishing = false;
  Object? _layoutEnvironment;
  Object? _timelineIdentity;
  int _timelineMessageCount = 0;
  List<int> _cachedTimelineEntries = const [];
  Map<String, int> _messageIndexByLocalId = const {};
  Map<Key, int> _cachedTimelineIndices = const {};
  late final _LiveMessageList _imageViewerMessages = _LiveMessageList(
    () => _renderedMessages,
  );
  final Map<String, _CachedMessageRow> _rowChildren = {};
  final Map<int, Map<String, _CachedMessageRow>> _cardRowChildren = {};
  bool _rowCleanupScheduled = false;
  ({double contentOffset, double pixels, int commandGeneration})?
  _replySwitchAnchor;
  ({double contentOffset, double pixels, int commandGeneration})?
  _replyActionReplacementAnchor;
  int _deferredHistoryPrefixCount = 0;

  String? get _replyIdentity =>
      widget.replyActionsIdentity ?? widget.replyActionsMessageId;

  LocationChatReplyCard? get _currentReplyCard => widget.replyCards
      .where((card) => card.id == widget.replyCurrentCardId)
      .firstOrNull;

  bool get _replyActionsImmediatelyFollowDeck =>
      widget.replyActionsVisible &&
      !_showLoadingInReplyActionSlot &&
      _renderedMessages.isNotEmpty &&
      _currentReplyCard?.messages.lastOrNull?.localId ==
          _renderedMessages.last.localId;

  bool get _immediateSendWaitingActive =>
      widget.replyWaitingPositioningEnabled &&
      widget.preAckWaitingAfterMessageLocalId != null &&
      widget.preAckWaitingIdentity != null;

  String? get _waitingAfterMessageLocalId => _immediateSendWaitingActive
      ? widget.preAckWaitingAfterMessageLocalId
      : widget.loadingAfterMessageLocalId;

  Object? get _waitingIndicatorIdentity => _immediateSendWaitingActive
      ? widget.preAckWaitingIdentity
      : widget.loadingIdentity;

  bool get _waitingInReplyActionSlot =>
      _waitingAfterMessageLocalId != null &&
      _timelineMessageCount > 0 &&
      _renderedMessages[_timelineMessageCount - 1].localId ==
          _waitingAfterMessageLocalId;

  bool get _loadingInReplyActionSlot =>
      widget.loadingAfterMessageLocalId != null && _waitingInReplyActionSlot;

  bool get _reservingPreAckLoadingInReplyActionSlot =>
      _immediateSendWaitingActive &&
      _waitingInReplyActionSlot &&
      widget.loadingAfterMessageLocalId == null;

  bool get _usesImmediateSendWaitingSlot =>
      _immediateSendWaitingActive && _waitingInReplyActionSlot;

  bool get _showLoadingInReplyActionSlot =>
      _loadingInReplyActionSlot || widget.goOnAwaitingContentIdentity != null;

  Object? get _replyActionSlotLoadingIdentity => _loadingInReplyActionSlot
      ? _waitingIndicatorIdentity
      : widget.goOnAwaitingContentIdentity;

  Object? get _replyControlWaitingIdentity => _showLoadingInReplyActionSlot
      ? _replyActionSlotLoadingIdentity
      : _replyIdentity;

  ChatMessageVm? get _messageBeforeReplyCard {
    final id = _currentReplyCard?.messages.firstOrNull?.localId;
    final index = id == null
        ? _replyInsertionIndex ?? 0
        : (_messageIndexByLocalId[id] ?? -1);
    return index > 0 ? _renderedMessages[index - 1] : null;
  }

  List<int> _timelineEntries(int count) {
    _timelineMessageCount = count;
    final card = _currentReplyCard;
    final firstId = card?.messages.firstOrNull?.localId;
    final start = card == null
        ? -1
        : firstId == null
        ? _replyInsertionIndex ?? count
        : (_messageIndexByLocalId[firstId] ?? -1);
    final length = card?.messages.length ?? 0;
    final identity = (
      _messageLocalIds,
      count,
      start,
      length,
      _replyIdentity,
      _waitingAfterMessageLocalId,
      _waitingIndicatorIdentity,
      widget.loadingAfterMessageLocalId != null,
    );
    if (_timelineIdentity == identity) return _cachedTimelineEntries;
    _timelineIdentity = identity;
    _cachedTimelineEntries = [
      for (var i = 0; i <= count; i++) ...[
        if (i == start) -2,
        if (i == count) -1,
        if (i < count && !(start >= 0 && i >= start && i < start + length)) i,
        if (i < count &&
            _renderedMessages[i].localId == _waitingAfterMessageLocalId &&
            !_waitingInReplyActionSlot &&
            !(start >= 0 && i >= start && i < start + length))
          -3,
      ],
    ];
    _cachedTimelineIndices = {
      for (var i = 0; i < _cachedTimelineEntries.length; i++)
        _entryKey(_cachedTimelineEntries[i]): i,
    };
    return _cachedTimelineEntries;
  }

  Key _entryKey(int entry) => ValueKey<String>(switch (entry) {
    -3 => 'location-chat-ack-loading:$_waitingIndicatorIdentity',
    -2 => 'location-chat-reply-deck:$_replyIdentity',
    -1 => 'location-chat-reply-action-slot',
    _ =>
      'location-chat-message-row:${_messageLayoutId(_renderedMessages[entry])}',
  });

  Widget _buildEntry(int entry, ChatUiStyleConfig style, {bool lazy = true}) =>
      switch (entry) {
        -3 => KeyedSubtree(
          key: _entryKey(entry),
          child: KeyedSubtree(
            key: _waitingBubbleLayoutKey,
            child: ChatReplyWaitingBubble(
              style: style,
              visible: widget.loadingAfterMessageLocalId != null,
            ),
          ),
        ),
        -2 => KeyedSubtree(
          key: _entryKey(entry),
          child: _buildReplyDeck(style),
        ),
        -1 => _ReplyControlsLayoutReporter(
          key: _entryKey(entry),
          bridge: _replyLayoutBridge,
          child: _buildReplyControls(style),
        ),
        _ => _buildMessageRow(entry, style, lazy: lazy),
      };

  void _captureCardLayoutAnchor() {
    // A missing/offscreen toolbar must never expand the history cache just to
    // acquire an anchor. The deck still animates normally in that case.
    if (_contentOffset(_replyControlLayoutKey.currentContext) == null ||
        !widget.coordinator.controller.hasClients) {
      return;
    }
    _replyLayoutFinishGeneration++;
    _replyLayoutCommandGeneration = widget.coordinator.commandGeneration;
    _replyLayoutBridge.begin(
      position: widget.coordinator.controller.position,
      followControlsHeight: widget.coordinator.shouldFollowLatest,
      commandGeneration: widget.coordinator.commandGeneration,
      currentGeneration: () => widget.coordinator.commandGeneration,
    );
  }

  void _setCardTransitionBusy(bool busy) {
    if (!mounted || _cardTransitionBusy == busy) return;
    setState(() {
      _cardTransitionBusy = busy;
      if (busy) _inspirationExpanded = false;
    });
    if (busy) widget.inspirationFeature.onExpandedChanged?.call(false);
    widget.onReplyCardTransitionChanged?.call(busy);
    if (!busy) {
      _replyLayoutFinishing = true;
      final generation = ++_replyLayoutFinishGeneration;
      // Keep the absolute transaction through the committing widget/layout
      // frame. Releasing it earlier lets bottom anchoring move the toolbar.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _replyLayoutFinishGeneration) return;
        final retainedWaitingDelta = _waitingMinContentExtent > 0
            ? _replyLayoutBridge.layoutExtentDelta
            : 0.0;
        setState(() {
          if (retainedWaitingDelta.abs() > precisionErrorTolerance) {
            _waitingMinContentExtent =
                (_waitingMinContentExtent + retainedWaitingDelta).clamp(
                  0.0,
                  double.infinity,
                );
          }
          _replyLayoutBridge.cancel();
          _replyLayoutFinishing = false;
          _replyLayoutCommandGeneration = null;
          _cardRowChildren.removeWhere(
            (id, _) => id != widget.replyCurrentCardId,
          );
        });
        _scheduleDetachedAnchorSnapshot();
      });
    }
  }

  void _switchReplyCard(int delta) {
    if (_cardTransitionBusy ||
        !widget.replyCardSwitchEnabled ||
        widget.replyCardsConfirmed) {
      return;
    }
    if (_currentReplyCard != null) {
      _cardSwitcherKey.currentState?.switchBy(delta);
    } else {
      (delta < 0 ? widget.onPreviousReplyCard : widget.onNextReplyCard)?.call();
    }
  }

  Widget _buildReplyDeck(ChatUiStyleConfig style) =>
      LocationChatReplyCardSwitcher(
        key: _cardSwitcherKey,
        identity: widget.replyCardBindingIdentity ?? _replyIdentity!,
        cards: widget.replyCards,
        currentCardId: widget.replyCurrentCardId,
        regenerationInProgress: widget.replyRegenerationInProgress,
        enabled:
            widget.active &&
            widget.replyCardSwitchEnabled &&
            !widget.replyCardsConfirmed,
        onCommit: (id) => widget.onReplyCardSelected?.call(id) ?? false,
        onBusyChanged: _setCardTransitionBusy,
        onWillChangeLayout: _captureCardLayoutAnchor,
        layoutBridge: _replyLayoutBridge,
        cardBuilderIdentity: (
          style,
          widget.replyCurrentCardId,
          _replyActionsImmediatelyFollowDeck,
          _messageBeforeReplyCard?.createdAt,
          widget.showDateDividers,
          widget.selfMessageBubbleMaxWidthCap,
          widget.otherMessageBubbleMaxWidthCap,
          widget.onMessageLongPressStart,
          widget.onFailedMessageTap,
          widget.onCharactersMovedLocationTap,
        ),
        cardBuilder: (card) => _buildCardBody(card, style),
      );

  Widget _buildCardBody(LocationChatReplyCard card, ChatUiStyleConfig style) {
    _cardRowChildren.removeWhere(
      (id, _) => id != widget.replyCurrentCardId && id != card.id,
    );
    final rows = _cardRowChildren.putIfAbsent(card.id, () => {});
    final messages = card.messages;
    final currentRole = card.id == widget.replyCurrentCardId;
    final validIds = messages.map((message) => message.localId).toSet();
    rows.removeWhere((id, _) => !validIds.contains(id));
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: card.messages.isEmpty && card.status == null ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < messages.length; i++)
            _cachedCardRow(
              rows: rows,
              card: card,
              index: i,
              currentRole: currentRole,
              style: style,
            ),
          if (card.status != null) card.status!,
        ],
      ),
    );
  }

  Widget _cachedCardRow({
    required Map<String, _CachedMessageRow> rows,
    required LocationChatReplyCard card,
    required int index,
    required bool currentRole,
    required ChatUiStyleConfig style,
  }) {
    final messages = card.messages;
    final message = messages[index];
    final divider =
        widget.showDateDividers &&
        shouldShowChatDateDivider(
          index > 0
              ? messages[index - 1].createdAt
              : _messageBeforeReplyCard?.createdAt,
          message.createdAt,
        );
    final compact =
        index == messages.length - 1 && _replyActionsImmediatelyFollowDeck;
    final identity = (
      message,
      currentRole,
      divider,
      compact,
      style,
      widget.selfMessageBubbleMaxWidthCap,
      widget.otherMessageBubbleMaxWidthCap,
      widget.onMessageLongPressStart,
      widget.onFailedMessageTap,
      widget.onCharactersMovedLocationTap,
    );
    final cached = rows[message.localId];
    if (cached != null &&
        cached.identity == identity &&
        locationChatReplyMessagesEqual(cached.snapshot, message)) {
      return cached.child;
    }
    final child = KeyedSubtree(
      key: currentRole
          ? _messageLayoutKeys.putIfAbsent(
              _messageLayoutId(message),
              GlobalKey.new,
            )
          : ValueKey('preview-${message.localId}'),
      child: _messageRow(
        key: ValueKey(message.localId),
        visibilityKey: currentRole
            ? _messageVisibilityKeys.putIfAbsent(
                _messageLayoutId(message),
                GlobalKey.new,
              )
            : null,
        streamIdentity: (
          widget.replyCardBindingIdentity,
          card.id,
          _messageLayoutId(message),
        ),
        streamContinuationNamespace: (widget.replyCardBindingIdentity, card.id),
        message: message,
        imageViewerMessages: currentRole ? _imageViewerMessages : messages,
        style: style,
        compact: compact,
        showDateDivider: divider,
      ),
    );
    rows[message.localId] = (
      identity: identity,
      snapshot: freezeLocationChatReplyMessage(message),
      child: child,
    );
    return child;
  }

  int? get _replyInsertionIndex {
    if (_replyIdentity == null) return null;
    return _renderedMessages.length;
  }

  final BackdropKey _messageBackdropKey = BackdropKey();
  late final AnimationController _oldestEdgeLoadingController;
  late final Animation<double> _oldestEdgeLoadingAnimation;
  late List<ChatMessageVm> _renderedMessages;
  final _inspirationListKey = GlobalKey(debugLabel: 'inspiration-list');
  bool _inspirationExpanded = false;
  bool _inspirationPromptExpanded = false;
  bool _editPromptExpanded = false;
  int _inspirationPage = 0;
  List<ChatMessageVm>? _pendingMessages;
  late List<String> _messageLocalIds;
  int _historyCommitGeneration = 0;
  bool _loadingCollapsePending = false;
  bool _historyCommitScheduled = false;
  bool _oldestMessageStopLayoutScheduled = false;
  bool _detachedAnchorSnapshotScheduled = false;
  bool _anchorRestorePending = false;
  bool _anchorRestoreCleanupScheduled = false;
  int? _anchorRestoreMessageCount;
  double _layoutCorrectionExtentSignal = 0;
  ({String localId, double contentOffset})? _detachedLayoutAnchor;

  @override
  void initState() {
    super.initState();
    _renderedMessages = widget.messages;
    _messageLocalIds = _currentMessageLocalIds(_renderedMessages);
    _rebuildMessageIndex();
    _oldestEdgeLoadingController = AnimationController(
      vsync: this,
      duration: locationChatOldestEdgeLoadingAnimationDuration,
      value: widget.oldestEdgeLoading ? 1 : 0,
    )..addStatusListener(_handleOldestEdgeLoadingStatus);
    _oldestEdgeLoadingAnimation = CurvedAnimation(
      parent: _oldestEdgeLoadingController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    widget.coordinator.addListener(_handleCoordinatorChanged);
    widget.coordinator.controller.addListener(_scheduleContentVisibility);
    _scheduleInitialViewportLayout();
    _scheduleWaitingPosition();
    _scheduleDetachedAnchorSnapshot();
  }

  @override
  void didUpdateWidget(LocationChatAnchoredMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replyRegenerationDispatchRevision !=
        widget.replyRegenerationDispatchRevision) {
      // Collapse belongs to the committed Regenerate request, not its raw tap.
      // A reconnect/join wait therefore shows only button busy state and cannot
      // start a transition that the card switcher would immediately recover.
      _cardSwitcherKey.currentState?.beginRegenerateCollapse(
        deferBusyNotification: true,
      );
    }
    if (oldWidget.waitingPositionResetRevision !=
        widget.waitingPositionResetRevision) {
      _waitingMinContentExtent = 0;
      final resetRevision = widget.waitingPositionResetRevision;
      final coordinator = widget.coordinator;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.coordinator != coordinator ||
            widget.waitingPositionResetRevision != resetRevision) {
          return;
        }
        coordinator.releaseWaitingReplyPosition();
      });
    }
    final disabledWaitingPositioning =
        oldWidget.replyWaitingPositioningEnabled &&
        !widget.replyWaitingPositioningEnabled;
    if (!widget.replyWaitingPositioningEnabled ||
        !widget.active ||
        oldWidget.coordinator != widget.coordinator ||
        widget.coordinator.mode == LocationChatViewportMode.initializing) {
      _waitingMinContentExtent = 0;
    }
    if (disabledWaitingPositioning) {
      oldWidget.coordinator.releaseWaitingReplyPosition();
    }
    _retainExtentOnStreamCompletion();
    if (_waitingIdentity(oldWidget) != _waitingIdentity(widget) ||
        (!oldWidget.active && widget.active)) {
      _scheduleWaitingPosition();
    }
    final oldReplyIdentity =
        oldWidget.replyActionsIdentity ?? oldWidget.replyActionsMessageId;
    final presentationChanged =
        oldWidget.replyPresentationRevision != widget.replyPresentationRevision;
    final appendedSelfMessage =
        !identical(oldWidget.messages, widget.messages) &&
        widget.messages.isNotEmpty &&
        widget.messages.last.isMe &&
        !oldWidget.messages.any(
          (message) => message.localId == widget.messages.last.localId,
        );
    final replacingReplyActionsWithContent =
        oldWidget.replyActionsVisible &&
        !widget.replyActionsVisible &&
        oldReplyIdentity == _replyIdentity &&
        _currentReplyCard != null &&
        // A send already requests the bottom. Preserving the old card first
        // would paint the optimistic bubble at the wrong offset and move the
        // whole list again on the next frame.
        !appendedSelfMessage;
    if (replacingReplyActionsWithContent &&
        widget.coordinator.shouldFollowLatest &&
        widget.coordinator.isAtBottom) {
      final contentOffset = _contentOffset(_cardSwitcherKey.currentContext);
      _replyActionReplacementAnchor = contentOffset == null
          ? null
          : (
              contentOffset: contentOffset,
              pixels: widget.coordinator.controller.position.pixels,
              commandGeneration: widget.coordinator.commandGeneration,
            );
      if (_replyActionReplacementAnchor != null) {
        _layoutCorrectionExtentSignal = _layoutCorrectionExtentSignal == 0
            ? _locationChatLayoutCorrectionExtentSignal
            : 0;
      }
    }
    if (presentationChanged &&
        !_cardTransitionBusy &&
        !_replyLayoutFinishing &&
        !_replyLayoutBridge.isActive &&
        // Detached viewports belong to their visible-message anchor. Anchoring
        // an on-screen reply footer here would move history by stream growth.
        widget.coordinator.shouldFollowLatest &&
        oldReplyIdentity == _replyIdentity &&
        _replyIdentity != null &&
        oldWidget.coordinator == widget.coordinator) {
      final contentOffset = _contentOffset(
        _replyControlLayoutKey.currentContext,
      );
      _replySwitchAnchor = contentOffset == null
          ? null
          : (
              contentOffset: contentOffset,
              pixels: widget.coordinator.controller.position.pixels,
              commandGeneration: widget.coordinator.commandGeneration,
            );
      _layoutCorrectionExtentSignal = _layoutCorrectionExtentSignal == 0
          ? _locationChatLayoutCorrectionExtentSignal
          : 0;
    } else if (oldReplyIdentity != _replyIdentity) {
      _replyLayoutBridge.cancel(clearMeasurements: true);
      _cardRowChildren.clear();
      _replySwitchAnchor = null;
      _replyActionReplacementAnchor = null;
    }
    if (oldWidget.active != widget.active ||
        oldReplyIdentity != _replyIdentity ||
        oldWidget.inspirationIdentity != widget.inspirationIdentity) {
      _inspirationExpanded = false;
      _inspirationPromptExpanded = false;
      _editPromptExpanded = false;
      _inspirationPage = 0;
    }
    if (_usesImmediateSendWaitingSlot ||
        _showLoadingInReplyActionSlot ||
        !widget.replyActionsVisible ||
        widget.inspirationFeature.state == LocationChatReplyActionState.none ||
        (oldWidget.inspirationFeature.messages.isNotEmpty &&
            widget.inspirationFeature.messages.isEmpty)) {
      _inspirationExpanded = false;
    }
    if (oldWidget.inspirationPresentationRevision !=
            widget.inspirationPresentationRevision &&
        widget.inspirationFeature.messages.isNotEmpty) {
      // Reconnect/history refresh may replace the source identity while the
      // user's click is waiting. The committed result owns the expansion.
      _inspirationExpanded = true;
      _inspirationPromptExpanded = true;
    }
    if (oldWidget.coordinator != widget.coordinator) {
      _replyLayoutBridge.cancel(clearMeasurements: true);
      oldWidget.coordinator.removeListener(_handleCoordinatorChanged);
      oldWidget.coordinator.controller.removeListener(
        _scheduleContentVisibility,
      );
      widget.coordinator.addListener(_handleCoordinatorChanged);
      widget.coordinator.controller.addListener(_scheduleContentVisibility);
      _detachedLayoutAnchor = null;
      _scheduleDetachedAnchorSnapshot();
    }
    final loadingStarted =
        !oldWidget.oldestEdgeLoading && widget.oldestEdgeLoading;
    final loadingEnded =
        oldWidget.oldestEdgeLoading && !widget.oldestEdgeLoading;
    if (loadingEnded) _loadingCollapsePending = true;
    if (loadingStarted) {
      _historyCommitGeneration += 1;
      _historyCommitScheduled = false;
    }

    if (_replyLayoutBridge.isActive &&
        !presentationChanged &&
        !identical(oldWidget.messages, widget.messages) &&
        !listEquals(
          _currentMessageLocalIds(oldWidget.messages),
          _currentMessageLocalIds(widget.messages),
        )) {
      _replyLayoutBridge.cancel(clearMeasurements: true);
    }
    if (widget.oldestEdgeLoading || _loadingCollapsePending) {
      _pendingMessages = widget.messages;
      // Hold only prepended history for the loader collapse. Live tail rows,
      // including optimistic sends, must remain visible in every round.
      final firstId = _renderedMessages.isEmpty
          ? null
          : _messageLayoutId(_renderedMessages.first);
      final firstIndex = firstId == null
          ? 0
          : widget.messages.indexWhere(
              (message) => _messageLayoutId(message) == firstId,
            );
      _deferredHistoryPrefixCount = presentationChanged || firstIndex < 0
          ? 0
          : firstIndex;
      _replaceRenderedMessages(
        widget.messages.sublist(_deferredHistoryPrefixCount),
        rebuild: false,
      );
    } else {
      _deferredHistoryPrefixCount = 0;
      _replaceRenderedMessages(widget.messages, rebuild: false);
    }

    if (widget.coordinator.mode == LocationChatViewportMode.initializing) {
      _scheduleInitialViewportLayout();
    }
    if (loadingStarted) {
      _oldestEdgeLoadingController.forward();
    }
    if (loadingEnded &&
        (_oldestEdgeLoadingController.status == AnimationStatus.completed ||
            _oldestEdgeLoadingController.value >= 1)) {
      _oldestEdgeLoadingController.reverse();
    }
  }

  void _handleOldestEdgeLoadingStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _loadingCollapsePending &&
        !widget.oldestEdgeLoading) {
      _oldestEdgeLoadingController.reverse();
      return;
    }
    if (status != AnimationStatus.dismissed || !_loadingCollapsePending) return;

    _scheduleHistoryCommitAfterCollapsedFrame();
  }

  void _scheduleHistoryCommitAfterCollapsedFrame() {
    if (_historyCommitScheduled) return;
    _historyCommitScheduled = true;
    final generation = ++_historyCommitGeneration;
    // Paint the fully collapsed loader once before capturing the old layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _historyCommitGeneration ||
          !_loadingCollapsePending ||
          widget.oldestEdgeLoading) {
        return;
      }

      final nextMessages = _pendingMessages ?? widget.messages;
      _pendingMessages = null;
      _deferredHistoryPrefixCount = 0;
      _loadingCollapsePending = false;
      _historyCommitScheduled = false;
      _replaceRenderedMessages(nextMessages, rebuild: true);
      widget.onOldestEdgeLoadingCollapsed?.call();
    });
  }

  void _replaceRenderedMessages(
    List<ChatMessageVm> nextMessages, {
    required bool rebuild,
  }) {
    if (identical(_renderedMessages, nextMessages)) return;
    final previousLocalIds = _messageLocalIds;
    final nextLocalIds = _currentMessageLocalIds(nextMessages);
    if (listEquals(previousLocalIds, nextLocalIds)) {
      void replace() {
        _renderedMessages = nextMessages;
      }

      if (rebuild) {
        setState(replace);
      } else {
        replace();
      }
      return;
    }

    final shouldPreserveAnchor =
        !_cardTransitionBusy &&
        !_replyLayoutFinishing &&
        !_replyLayoutBridge.isActive &&
        _replySwitchAnchor == null &&
        widget.coordinator.isReadingHistory &&
        _requiresAnchorRestore(previousLocalIds, nextLocalIds);
    final visibleLayoutAnchor = shouldPreserveAnchor
        ? _visibleRetainedAnchor(previousLocalIds, nextLocalIds.toSet())
        : null;
    final previousContentOffset = visibleLayoutAnchor == null
        ? null
        : _messageContentOffset(visibleLayoutAnchor.localId);
    final layoutAnchor =
        visibleLayoutAnchor != null && previousContentOffset != null
        ? (
            localId: visibleLayoutAnchor.localId,
            contentOffset: previousContentOffset,
          )
        : null;
    if (shouldPreserveAnchor) {
      _detachedLayoutAnchor = layoutAnchor;
      _anchorRestorePending = layoutAnchor != null;
      _anchorRestoreMessageCount = layoutAnchor == null
          ? null
          : _anchorRestoreChildCount(
              previousLocalIds: previousLocalIds,
              nextLocalIds: nextLocalIds,
              anchorLocalId: layoutAnchor.localId,
            );
      // A rolling-window replacement can keep the exact same total extent.
      // Toggling a subpixel tail extent still makes ScrollPosition run the
      // layout-phase correction before this frame is painted.
      _layoutCorrectionExtentSignal = _layoutCorrectionExtentSignal == 0
          ? _locationChatLayoutCorrectionExtentSignal
          : 0;
    }

    void replace() {
      _renderedMessages = nextMessages;
      _messageLocalIds = nextLocalIds;
      _rebuildMessageIndex();
      _pruneMessageLayoutKeys();
    }

    if (rebuild) {
      setState(replace);
    } else {
      replace();
    }
    _scheduleDetachedAnchorSnapshot();
  }

  void _handleCoordinatorChanged() {
    if (_replyLayoutCommandGeneration != null &&
        _replyLayoutCommandGeneration != widget.coordinator.commandGeneration) {
      _replyLayoutBridge.cancel();
      _replySwitchAnchor = null;
      _detachedLayoutAnchor = null;
      _replyLayoutCommandGeneration = null;
    }
    if (!widget.coordinator.isReadingHistory) {
      _detachedLayoutAnchor = null;
      _anchorRestorePending = false;
      _anchorRestoreMessageCount = null;
      return;
    }
    _scheduleDetachedAnchorSnapshot();
  }

  void _scheduleDetachedAnchorSnapshot() {
    if (_detachedAnchorSnapshotScheduled) return;
    _detachedAnchorSnapshotScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detachedAnchorSnapshotScheduled = false;
      if (!mounted || !widget.coordinator.isReadingHistory) return;
      final anchor = _visibleRetainedAnchor(
        _messageLocalIds,
        _messageLocalIds.toSet(),
      );
      if (anchor == null) return;
      final contentOffset = _messageContentOffset(anchor.localId);
      if (contentOffset == null) return;
      _detachedLayoutAnchor = (
        localId: anchor.localId,
        contentOffset: contentOffset,
      );
    });
  }

  void _scheduleInitialViewportLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.coordinator.onViewportLaidOut();
    });
  }

  void _rebuildMessageIndex() {
    _messageIndexByLocalId = {
      for (var i = 0; i < _renderedMessages.length; i++)
        _renderedMessages[i].localId: i,
    };
  }

  List<String> _currentMessageLocalIds(List<ChatMessageVm> messages) {
    return messages.map(_messageLayoutId).toList(growable: false);
  }

  String _messageLayoutId(ChatMessageVm message) {
    return widget.messageLayoutId?.call(message) ?? message.localId;
  }

  bool _requiresAnchorRestore(List<String> previous, List<String> next) {
    if (listEquals(previous, next) || previous.isEmpty) return false;
    if (next.length >= previous.length) {
      var pureTailAppend = true;
      for (var index = 0; index < previous.length; index += 1) {
        if (previous[index] == next[index]) continue;
        pureTailAppend = false;
        break;
      }
      if (pureTailAppend) return false;
    }
    return true;
  }

  int _anchorRestoreChildCount({
    required List<String> previousLocalIds,
    required List<String> nextLocalIds,
    required String anchorLocalId,
  }) {
    final nextIndexByLocalId = <String, int>{
      for (var index = 0; index < nextLocalIds.length; index += 1)
        nextLocalIds[index]: index,
    };
    var lastRequiredIndex = nextIndexByLocalId[anchorLocalId] ?? 0;
    for (final localId in previousLocalIds) {
      final nextIndex = nextIndexByLocalId[localId];
      if (nextIndex == null ||
          !_isActive(_messageLayoutKeys[localId]?.currentContext)) {
        continue;
      }
      if (nextIndex > lastRequiredIndex) lastRequiredIndex = nextIndex;
    }
    return (lastRequiredIndex + 1).clamp(0, nextLocalIds.length);
  }

  ({String localId, double top})? _visibleRetainedAnchor(
    List<String> previousLocalIds,
    Set<String> retainedLocalIds,
  ) {
    final viewportBounds = _globalBounds(context.findRenderObject());
    ({String localId, double top})? closestAnchor;
    var closestDistance = double.infinity;
    var closestAnchorIsVisible = false;
    for (final localId in previousLocalIds) {
      if (!retainedLocalIds.contains(localId)) continue;
      final messageBounds = _messageBounds(localId);
      if (messageBounds == null) continue;
      if (viewportBounds == null) {
        return (localId: localId, top: messageBounds.top);
      }
      final isVisible =
          messageBounds.bottom >= viewportBounds.top &&
          messageBounds.top <= viewportBounds.bottom;
      if (closestAnchorIsVisible && !isVisible) continue;
      final distance = isVisible
          ? (messageBounds.center.dy - viewportBounds.center.dy).abs()
          : switch (messageBounds) {
              Rect(:final bottom) when bottom < viewportBounds.top =>
                viewportBounds.top - bottom,
              Rect(:final top) => top - viewportBounds.bottom,
            };
      if (isVisible && !closestAnchorIsVisible) {
        closestDistance = double.infinity;
      }
      if (distance >= closestDistance) continue;
      closestDistance = distance;
      closestAnchorIsVisible = isVisible;
      closestAnchor = (localId: localId, top: messageBounds.top);
    }
    return closestAnchor;
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_handleCoordinatorChanged);
    widget.coordinator.controller.removeListener(_scheduleContentVisibility);
    _replyLayoutBridge.cancel(clearMeasurements: true);
    _rowChildren.clear();
    _cardRowChildren.clear();
    widget.coordinator.setOldestMessageStopOffset(null);
    _historyCommitGeneration += 1;
    _detachedLayoutAnchor = null;
    _oldestEdgeLoadingController
      ..removeStatusListener(_handleOldestEdgeLoadingStatus)
      ..dispose();
    _messageLayoutKeys.clear();
    _messageVisibilityKeys.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleContentVisibility();
    final style = widget.style ?? ChatUiStyleConfig.standard;
    final hasOldestEdgeContent =
        widget.topTitle.trim().isNotEmpty ||
        (widget.oldestEdgeNotice?.trim().isNotEmpty ?? false);
    final requiresSecondScroll =
        widget.oldestEdgeNoticeRequiresSecondScroll &&
        hasOldestEdgeContent &&
        _renderedMessages.isNotEmpty;
    _scheduleOldestMessageStopLayout(
      enabled: requiresSecondScroll,
      topPadding: style.messageListPadding.top,
    );
    return NotificationListener<ChatStreamingLayoutNotification>(
      onNotification: (_) {
        _scheduleContentVisibility();
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final environment = (
            constraints.maxWidth,
            constraints.maxHeight,
            style,
            MediaQuery.textScalerOf(context),
            Directionality.of(context),
          );
          if (_layoutEnvironment != null && _layoutEnvironment != environment) {
            _replyLayoutBridge.cancel(clearMeasurements: true);
          }
          _layoutEnvironment = environment;
          final minHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : 0.0;
          final messageViewportHeight =
              minHeight > style.messageListPadding.vertical
              ? minHeight - style.messageListPadding.vertical
              : 0.0;
          return ScrollConfiguration(
            key: const ValueKey<String>(
              'location-chat-message-scroll-configuration',
            ),
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(overscroll: false),
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleTemporaryTailScroll,
              child: BackdropGroup(
                backdropKey: _messageBackdropKey,
                child: requiresSecondScroll
                    ? _buildSecondScrollMessageView(
                        style: style,
                        minHeight: minHeight,
                        messageViewportHeight: messageViewportHeight,
                        hasOldestEdgeContent: hasOldestEdgeContent,
                      )
                    : _buildLazyMessageView(
                        style: style,
                        hasOldestEdgeContent: hasOldestEdgeContent,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLazyMessageView({
    required ChatUiStyleConfig style,
    required bool hasOldestEdgeContent,
  }) {
    final renderedMessageCount =
        // The waiting row and first reply must survive canonical ID changes in
        // the same frame; the reserved tail already keeps the extent stable.
        _anchorRestorePending &&
            _replySwitchAnchor == null &&
            !widget.coordinator._holdingReplyPosition
        ? (_anchorRestoreMessageCount ?? _renderedMessages.length).clamp(
            0,
            _renderedMessages.length,
          )
        : _renderedMessages.length;
    final entries = _timelineEntries(renderedMessageCount);
    final indices = _cachedTimelineIndices;

    final padding = style.messageListPadding;
    final horizontalPadding = EdgeInsets.only(
      left: padding.left,
      right: padding.right,
    );

    return CustomScrollView(
      key: _scrollViewportKey,
      controller: widget.coordinator.controller,
      physics: _messageScrollPhysics(),
      // Keep the retained anchor in the same sliver layout transaction. Once
      // its exact variable-height offset has been applied, the next frame
      // returns to the normal lazy cache window.
      scrollCacheExtent: _anchorRestorePending
          ? const ScrollCacheExtent.pixels(
              _locationChatAnchorRestoreCacheExtent,
            )
          : null,
      keyboardDismissBehavior:
          widget.keyboardDismissBehavior ??
          ScrollViewKeyboardDismissBehavior.manual,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            padding.top,
            padding.right,
            0,
          ),
          sliver: SliverToBoxAdapter(
            key: const ValueKey<String>('location-chat-oldest-edge-loading'),
            child: _buildOldestEdgeLoading(style),
          ),
        ),
        if (hasOldestEdgeContent)
          SliverPadding(
            padding: horizontalPadding,
            sliver: SliverToBoxAdapter(
              key: const ValueKey<String>('location-chat-oldest-edge-content'),
              child: ChatOldestEdgeContent(
                topTitle: widget.topTitle,
                notice: widget.oldestEdgeNotice,
                loading: false,
                style: style,
              ),
            ),
          ),
        SliverPadding(
          padding: horizontalPadding,
          sliver: _ReplyAnchoredSliverList(
            bridge: _replyLayoutBridge,
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildEntry(entries[index], style),
              childCount: entries.length,
              findChildIndexCallback: (key) => indices[key],
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            0,
            padding.right,
            padding.bottom,
          ),
          sliver: SliverToBoxAdapter(
            key: const ValueKey<String>('location-chat-layout-correction'),
            child: SizedBox(height: _layoutCorrectionExtentSignal),
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final waitingMinContentExtent = _waitingMinContentExtent > 0
                ? _waitingMinContentExtent +
                      _replyLayoutBridge.layoutExtentDelta
                : 0.0;
            return SliverToBoxAdapter(
              child: SizedBox(
                height:
                    (waitingMinContentExtent.clamp(
                              waitingMinContentExtent > 0
                                  ? constraints.viewportMainAxisExtent
                                  : 0,
                              double.infinity,
                            ) +
                            _layoutCorrectionExtentSignal -
                            constraints.precedingScrollExtent)
                        .clamp(0.0, double.infinity),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSecondScrollMessageView({
    required ChatUiStyleConfig style,
    required double minHeight,
    required double messageViewportHeight,
    required bool hasOldestEdgeContent,
  }) {
    return SingleChildScrollView(
      key: _scrollViewportKey,
      controller: widget.coordinator.controller,
      physics: _messageScrollPhysics(),
      keyboardDismissBehavior:
          widget.keyboardDismissBehavior ??
          ScrollViewKeyboardDismissBehavior.manual,
      child: _ReplyLayoutConstrainedBox(
        minHeight: _waitingMinContentExtent > 0
            ? _waitingMinContentExtent.clamp(minHeight, double.infinity) +
                  _layoutCorrectionExtentSignal
            : minHeight,
        preserveWaitingTail: _waitingMinContentExtent > 0,
        bridge: _replyLayoutBridge,
        child: Padding(
          padding: style.messageListPadding,
          child: Column(
            key: _messageContentKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOldestEdgeLoading(style),
              if (hasOldestEdgeContent)
                ChatOldestEdgeContent(
                  topTitle: widget.topTitle,
                  notice: widget.oldestEdgeNotice,
                  loading: false,
                  style: style,
                ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: messageViewportHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in _timelineEntries(
                      _renderedMessages.length,
                    ))
                      _buildEntry(entry, style, lazy: false),
                  ],
                ),
              ),
              SizedBox(height: _layoutCorrectionExtentSignal),
            ],
          ),
        ),
      ),
    );
  }

  ScrollPhysics _messageScrollPhysics() {
    return LocationChatBottomAnchoringScrollPhysics(
      shouldFollowLatest: () => widget.coordinator.shouldSnapToLatestOnLayout,
      oldestMessageStopOffset: () => widget.coordinator.oldestMessageStopOffset,
      shouldStopAtOldestMessage: () =>
          widget.coordinator.shouldStopAtOldestMessage,
      takeDetachedLayoutCorrection: _takeDetachedLayoutCorrection,
      takePresentationLayoutCorrection: _takeReplyPresentationLayoutCorrection,
    );
  }

  Widget _buildOldestEdgeLoading(ChatUiStyleConfig style) {
    return AnimatedBuilder(
      animation: _oldestEdgeLoadingAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox.square(
          dimension: style.sendingBadgeSize,
          child: Padding(
            padding: EdgeInsets.all(style.sendingBadgePadding),
            child: CircularProgressIndicator(
              strokeWidth: style.sendingBadgeStrokeWidth,
              color: style.sendingBadgeColor,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final factor = _oldestEdgeLoadingAnimation.value;
        if (factor <= 0 &&
            !widget.oldestEdgeLoading &&
            !_loadingCollapsePending) {
          return const SizedBox.shrink();
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: factor,
            child: Opacity(opacity: factor, child: child),
          ),
        );
      },
    );
  }

  void _scheduleOldestMessageStopLayout({
    required bool enabled,
    required double topPadding,
  }) {
    if (!enabled) {
      widget.coordinator.setOldestMessageStopOffset(null);
      return;
    }
    if (_oldestMessageStopLayoutScheduled) return;
    _oldestMessageStopLayoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _oldestMessageStopLayoutScheduled = false;
      if (!mounted || _renderedMessages.isEmpty) return;
      final viewportBounds = _globalBounds(
        _scrollViewportKey.currentContext?.findRenderObject(),
      );
      final firstMessageBounds = _messageBounds(
        _messageLayoutId(_renderedMessages.first),
      );
      if (viewportBounds == null || firstMessageBounds == null) return;
      final controller = widget.coordinator.controller;
      if (!controller.hasClients) return;
      final stopOffset =
          controller.position.pixels +
          firstMessageBounds.top -
          viewportBounds.top -
          topPadding;
      widget.coordinator.setOldestMessageStopOffset(stopOffset);
    });
  }

  void _pruneMessageLayoutKeys() {
    final retainedLocalIds = _renderedMessages.map(_messageLayoutId).toSet();
    _messageLayoutKeys.removeWhere(
      (localId, _) => !retainedLocalIds.contains(localId),
    );
    _messageVisibilityKeys.removeWhere(
      (localId, _) => !retainedLocalIds.contains(localId),
    );
  }

  double? _takeReplySwitchLayoutCorrection() {
    final anchor = _replySwitchAnchor;
    if (anchor == null) return null;
    if (anchor.commandGeneration != widget.coordinator.commandGeneration) {
      _replySwitchAnchor = null;
      return null;
    }
    final nextOffset = _contentOffset(_replyControlLayoutKey.currentContext);
    if (nextOffset == null) return null;
    _replySwitchAnchor = null;
    _detachedLayoutAnchor = null;
    _anchorRestorePending = false;
    _anchorRestoreMessageCount = null;
    _scheduleDetachedAnchorSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    // SingleChildScrollView can clamp pixels before calling scroll physics.
    // Use the position captured before layout so shrinking is corrected once.
    return anchor.pixels +
        nextOffset -
        anchor.contentOffset -
        widget.coordinator.controller.position.pixels;
  }

  double? _takeReplyPresentationLayoutCorrection() {
    final bridgeCorrection = _replyLayoutBridge.correction;
    if (bridgeCorrection != null) return bridgeCorrection;
    final replacement = _replyActionReplacementAnchor;
    if (replacement != null) {
      if (replacement.commandGeneration !=
          widget.coordinator.commandGeneration) {
        _replyActionReplacementAnchor = null;
      } else {
        final nextOffset = _contentOffset(_cardSwitcherKey.currentContext);
        if (nextOffset != null) {
          _replyActionReplacementAnchor = null;
          _replySwitchAnchor = null;
          _detachedLayoutAnchor = null;
          _anchorRestorePending = false;
          _anchorRestoreMessageCount = null;
          final generation = replacement.commandGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                generation != widget.coordinator.commandGeneration ||
                !widget.coordinator.shouldFollowLatest) {
              return;
            }
            widget.coordinator.requestBottom(
              reason: LocationChatBottomReason.replyGeneration,
              behavior: LocationChatBottomBehavior.animate,
            );
          });
          return replacement.pixels +
              nextOffset -
              replacement.contentOffset -
              widget.coordinator.controller.position.pixels;
        }
      }
    }
    return _takeReplySwitchLayoutCorrection();
  }

  double? _takeDetachedLayoutCorrection() {
    if (!widget.coordinator.isReadingHistory) {
      _detachedLayoutAnchor = null;
      _anchorRestorePending = false;
      _anchorRestoreMessageCount = null;
      return null;
    }
    final anchor = _detachedLayoutAnchor;
    if (anchor == null) return null;
    final nextContentOffset = _messageContentOffset(anchor.localId);
    if (nextContentOffset == null) return null;
    _detachedLayoutAnchor = (
      localId: anchor.localId,
      contentOffset: nextContentOffset,
    );
    if (widget.oldestEdgeLoading || _loadingCollapsePending) return null;
    final correction = nextContentOffset - anchor.contentOffset;
    _finishAnchorRestoreAfterLayout();
    return correction.abs() > precisionErrorTolerance ? correction : null;
  }

  void _finishAnchorRestoreAfterLayout() {
    if (!_anchorRestorePending || _anchorRestoreCleanupScheduled) return;
    _anchorRestorePending = false;
    _anchorRestoreMessageCount = null;
    _anchorRestoreCleanupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorRestoreCleanupScheduled = false;
      if (!mounted || _anchorRestorePending) return;
      setState(() {});
    });
  }

  double? _messageContentOffset(String localId) {
    return _contentOffset(_messageLayoutKeys[localId]?.currentContext);
  }

  double? _contentOffset(BuildContext? messageContext) {
    if (!_isActive(messageContext)) return null;
    final messageRenderObject = messageContext!.findRenderObject();
    if (messageRenderObject == null || !messageRenderObject.attached) {
      return null;
    }

    // This runs from ScrollPhysics while the sliver is laying out. Reading a
    // RenderBox size (including through getOffsetToReveal) is not legal there.
    // The sliver child parent data already contains the exact variable-height
    // layout offset, so use it without forcing another geometry read.
    var boxOffset = 0.0;
    RenderObject? current = messageRenderObject;
    final contentContext = _messageContentKey.currentContext;
    final contentRenderObject = _isActive(contentContext)
        ? contentContext!.findRenderObject()
        : null;
    while (current != null) {
      if (current == contentRenderObject) {
        return boxOffset.isFinite ? boxOffset : null;
      }
      final parentData = current.parentData;
      if (parentData is SliverMultiBoxAdaptorParentData) {
        final layoutOffset = parentData.layoutOffset;
        if (layoutOffset == null) return null;
        final offset = layoutOffset + boxOffset;
        return offset.isFinite ? offset : null;
      }
      if (parentData is BoxParentData) {
        boxOffset += parentData.offset.dy;
      }
      current = current.parent;
    }
    return null;
  }

  Rect? _messageBounds(String localId) {
    if (localId.isEmpty) return null;
    final messageContext = _messageLayoutKeys[localId]?.currentContext;
    if (!_isActive(messageContext)) return null;
    final renderObject = messageContext!.findRenderObject();
    if (renderObject is! RenderBox || !_hasLaidOutRenderPath(renderObject)) {
      return null;
    }
    return _globalBounds(renderObject);
  }

  Rect? _messageVisibilityBounds(String localId) {
    if (localId.isEmpty) return null;
    final messageContext = _messageVisibilityKeys[localId]?.currentContext;
    if (!_isActive(messageContext)) return null;
    final renderObject = messageContext!.findRenderObject();
    if (renderObject is! RenderBox || !_hasLaidOutRenderPath(renderObject)) {
      return null;
    }
    return _globalBounds(renderObject);
  }

  bool _isActive(BuildContext? context) {
    if (context == null || !context.mounted) return false;
    var active = true;
    assert(() {
      active = (context as Element).debugIsActive;
      return true;
    }());
    return active;
  }

  Rect? _globalBounds(RenderObject? renderObject) {
    if (renderObject is! RenderBox || !_hasLaidOutRenderPath(renderObject)) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bounds = topLeft & renderObject.size;
    return topLeft.dx.isFinite &&
            topLeft.dy.isFinite &&
            bounds.width.isFinite &&
            bounds.height.isFinite
        ? bounds
        : null;
  }

  bool _hasLaidOutRenderPath(RenderObject renderObject) {
    RenderObject? current = renderObject;
    while (current != null) {
      if (!current.attached) return false;
      if (current is RenderBox && !current.hasSize) return false;
      current = current.parent;
    }
    return true;
  }

  Widget _buildMessageRow(
    int messageIndex,
    ChatUiStyleConfig style, {
    bool lazy = true,
  }) {
    final current = _renderedMessages[messageIndex];
    final previous = messageIndex == 0
        ? null
        : _renderedMessages[messageIndex - 1];
    final layoutId = _messageLayoutId(current);
    final layoutKey = _messageLayoutKeys.putIfAbsent(layoutId, GlobalKey.new);
    // An empty pending card can put the pager directly after the prior row.
    final showsPagerAfterEmptyCard =
        widget.replyCardCount > 1 &&
        !widget.replyCardsConfirmed &&
        _currentReplyCard?.messages.isEmpty == true &&
        _currentReplyCard?.status == null;
    final showReplyActions =
        widget.replyActionsVisible &&
        messageIndex + 1 == _replyInsertionIndex &&
        (current.localId == widget.replyActionsMessageId ||
            showsPagerAfterEmptyCard);
    final divider =
        widget.showDateDividers &&
        shouldShowChatDateDivider(previous?.createdAt, current.createdAt);
    final identity = (
      current,
      divider,
      showReplyActions,
      style,
      lazy,
      widget.selfMessageBubbleMaxWidthCap,
      widget.otherMessageBubbleMaxWidthCap,
      widget.onMessageLongPressStart,
      widget.onFailedMessageTap,
      widget.onCharactersMovedLocationTap,
    );
    final cached = _rowChildren[layoutId];
    if (cached != null &&
        cached.identity == identity &&
        locationChatReplyMessagesEqual(cached.snapshot, current)) {
      return cached.child;
    }
    assert(() {
      debugLocationChatMessageRowBuildCount++;
      return true;
    }());
    _scheduleRowCacheCleanup();
    final row = KeyedSubtree(
      key: layoutKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _messageRow(
            key: ValueKey(layoutId),
            visibilityKey: _messageVisibilityKeys.putIfAbsent(
              layoutId,
              GlobalKey.new,
            ),
            streamIdentity: ('timeline', layoutId),
            message: current,
            imageViewerMessages: _imageViewerMessages,
            style: style,
            compact: showReplyActions,
            showDateDivider: divider,
          ),
        ],
      ),
    );
    final child = lazy
        ? KeyedSubtree(
            key: ValueKey<String>('location-chat-message-row:$layoutId'),
            child: row,
          )
        : row;
    _rowChildren[layoutId] = (
      identity: identity,
      snapshot: freezeLocationChatReplyMessage(current),
      child: child,
    );
    return child;
  }

  // Both timeline and card rows share presentation; their callers retain
  // ownership of layout keys, preview identity and cache lifetimes.
  Widget _messageRow({
    required Key key,
    required Key? visibilityKey,
    required Object streamIdentity,
    Object streamContinuationNamespace = 'timeline',
    required ChatMessageVm message,
    required List<ChatMessageVm> imageViewerMessages,
    required ChatUiStyleConfig style,
    required bool compact,
    required bool showDateDivider,
  }) => ChatStreamingMessage(
    key: ValueKey(('stream-effects', key)),
    identity: streamIdentity,
    continuationIdentity: message.roundId.isEmpty
        ? null
        : (
            streamContinuationNamespace,
            message.roundId,
            message.senderId,
            message.senderType,
          ),
    streaming: message.status == 'streaming',
    child: ChatMessageRow(
      key: key,
      visibilityKey: visibilityKey,
      message: message,
      imageViewerMessages: imageViewerMessages,
      style: compact
          ? style.copyWith(
              rowBottomPadding: LocationChatReplyActions.contentBottomGap,
              systemMessageMargin: style.systemMessageMargin.copyWith(
                bottom: LocationChatReplyActions.contentBottomGap,
              ),
            )
          : style,
      selfMessageBubbleMaxWidthCap: widget.selfMessageBubbleMaxWidthCap,
      otherMessageBubbleMaxWidthCap: widget.otherMessageBubbleMaxWidthCap,
      onMessageLongPressStart: widget.onMessageLongPressStart,
      onFailedMessageTap: widget.onFailedMessageTap,
      onCharactersMovedLocationTap: widget.onCharactersMovedLocationTap,
      showDateDivider: showDateDivider,
    ),
  );

  void _scheduleRowCacheCleanup() {
    if (_rowCleanupScheduled) return;
    _rowCleanupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rowCleanupScheduled = false;
      if (!mounted) return;
      _rowChildren.removeWhere(
        (id, _) => _messageLayoutKeys[id]?.currentContext == null,
      );
    });
  }

  Widget _buildReplyControls(ChatUiStyleConfig style) => KeyedSubtree(
    key: ValueKey<String>(
      'location-chat-reply-control:$_replyControlWaitingIdentity',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_showLoadingInReplyActionSlot && _currentReplyCard == null)
          if (widget.replyStatus case final status?) status,
        Padding(
          key: _replyControlLayoutKey,
          padding: const EdgeInsets.only(bottom: GenesisSpacing.xl),
          child: IgnorePointer(
            key: ValueKey(
              'reply-actions-input-blocker-$_replyControlWaitingIdentity',
            ),
            ignoring: _cardTransitionBusy,
            child: LocationChatReplyActions(
              key: ValueKey('reply-actions-$_replyControlWaitingIdentity'),
              loadingIndicator:
                  _showLoadingInReplyActionSlot &&
                      !_usesImmediateSendWaitingSlot
                  ? KeyedSubtree(
                      key: _waitingBubbleLayoutKey,
                      child: ChatReplyWaitingBubble(
                        key: ValueKey<String>(
                          'location-chat-ack-loading:$_replyActionSlotLoadingIdentity',
                        ),
                        style: style,
                        inActionSlot: true,
                      ),
                    )
                  : null,
              reservedLoadingIndicator: _usesImmediateSendWaitingSlot
                  ? KeyedSubtree(
                      key: _waitingBubbleLayoutKey,
                      child: ChatReplyWaitingBubble(
                        key: ValueKey<String>(
                          'location-chat-ack-loading:${widget.preAckWaitingIdentity}',
                        ),
                        style: style,
                        inActionSlot: true,
                        visible: !_reservingPreAckLoadingInReplyActionSlot,
                      ),
                    )
                  : null,
              actionsExpanded:
                  _usesImmediateSendWaitingSlot ||
                  _showLoadingInReplyActionSlot ||
                  (widget.replyActionsVisible && _replyIdentity != null),
              actionToolbarKey: _replyActionToolbarKey,
              paginationKey: _replyPaginationKey,
              inspirationFeature: widget.inspirationFeature,
              editFeature: widget.editFeature,
              regenerateFeature: widget.regenerateFeature,
              goOnFeature: widget.goOnFeature,
              cardIndex: widget.replyCardIndex,
              cardCount: widget.replyCardCount,
              cardsConfirmed:
                  widget.replyCardsConfirmed &&
                  !widget.showConfirmedCardPagination,
              cardSwitchEnabled:
                  widget.active &&
                  widget.replyCardSwitchEnabled &&
                  !widget.replyCardsConfirmed,
              onPreviousCard: () => _switchReplyCard(-1),
              onNextCard: () => _switchReplyCard(1),
              editPromptExpanded: _editPromptExpanded,
              onEditPromptExpandedChanged: (expanded) {
                setState(() => _editPromptExpanded = expanded);
                if (expanded) {
                  final wasFollowingLatest =
                      widget.coordinator.shouldFollowLatest ||
                      widget.coordinator.isAtBottom;
                  widget.coordinator.requestBottom(
                    reason: LocationChatBottomReason.editPromptExpanded,
                    // With no ScrollActivity in flight, scroll physics follows
                    // every frame of the prompt's height animation.
                    behavior: wasFollowingLatest
                        ? LocationChatBottomBehavior.jump
                        : LocationChatBottomBehavior.animate,
                  );
                }
              },
              inspirationListKey: _inspirationListKey,
              inspirationIdentity: widget.inspirationIdentity ?? _replyIdentity,
              inspirationExpanded: _inspirationExpanded,
              inspirationPromptExpanded: _inspirationPromptExpanded,
              onInspirationPromptExpandedChanged: (expanded) {
                setState(() => _inspirationPromptExpanded = expanded);
              },
              inspirationPage: _inspirationPage,
              onInspirationPageChanged: (page) => _inspirationPage = page,
              onInspirationExpandedChanged: (expanded) {
                setState(() => _inspirationExpanded = expanded);
                widget.inspirationFeature.onExpandedChanged?.call(expanded);
                if (expanded) {
                  final wasFollowingLatest =
                      widget.coordinator.shouldFollowLatest ||
                      widget.coordinator.isAtBottom;
                  widget.coordinator.requestBottom(
                    reason: LocationChatBottomReason.inspirationExpanded,
                    // The replies and quota prompt can both grow after this
                    // tap. Keep a bottom-following viewport tied to their
                    // measured extent instead of a stale early target.
                    behavior: wasFollowingLatest
                        ? LocationChatBottomBehavior.jump
                        : LocationChatBottomBehavior.animate,
                  );
                }
              },
              style: style,
              selfMessageBubbleMaxWidthCap: widget.selfMessageBubbleMaxWidthCap,
            ),
          ),
        ),
      ],
    ),
  );
}

class LocationChatBottomAnchoringScrollPhysics extends ClampingScrollPhysics {
  const LocationChatBottomAnchoringScrollPhysics({
    super.parent,
    required this.shouldFollowLatest,
    this.shouldPreservePrependAnchor,
    this.oldestMessageStopOffset,
    this.shouldStopAtOldestMessage,
    this.takeDetachedLayoutCorrection,
    this.takePresentationLayoutCorrection,
  });

  final ValueGetter<bool> shouldFollowLatest;
  final ValueGetter<bool>? shouldPreservePrependAnchor;
  final ValueGetter<double?>? oldestMessageStopOffset;
  final ValueGetter<bool>? shouldStopAtOldestMessage;
  final ValueGetter<double?>? takeDetachedLayoutCorrection;
  final ValueGetter<double?>? takePresentationLayoutCorrection;

  @override
  LocationChatBottomAnchoringScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LocationChatBottomAnchoringScrollPhysics(
      parent: buildParent(ancestor),
      shouldFollowLatest: shouldFollowLatest,
      shouldPreservePrependAnchor: shouldPreservePrependAnchor,
      oldestMessageStopOffset: oldestMessageStopOffset,
      shouldStopAtOldestMessage: shouldStopAtOldestMessage,
      takeDetachedLayoutCorrection: takeDetachedLayoutCorrection,
      takePresentationLayoutCorrection: takePresentationLayoutCorrection,
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.minScrollExtent == position.maxScrollExtent) return 0;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final stopOffset = oldestMessageStopOffset?.call();
    if (stopOffset != null &&
        (shouldStopAtOldestMessage?.call() ?? false) &&
        value < stopOffset &&
        position.pixels >=
            stopOffset -
                LocationChatScrollCoordinator.oldestMessageStopTolerance) {
      return value - stopOffset;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final presentationCorrection = takePresentationLayoutCorrection?.call();
    if (presentationCorrection != null && presentationCorrection.isFinite) {
      return (newPosition.pixels + presentationCorrection).clamp(
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
    }
    if (!shouldFollowLatest()) {
      final currentPixels = newPosition.pixels.clamp(
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
      final layoutCorrection = takeDetachedLayoutCorrection?.call();
      if (layoutCorrection != null && layoutCorrection.isFinite) {
        return (currentPixels + layoutCorrection).clamp(
          newPosition.minScrollExtent,
          newPosition.maxScrollExtent,
        );
      }
      if (shouldPreservePrependAnchor?.call() ?? false) {
        final extentDelta =
            newPosition.maxScrollExtent - oldPosition.maxScrollExtent;
        return (oldPosition.pixels + extentDelta).clamp(
          newPosition.minScrollExtent,
          newPosition.maxScrollExtent,
        );
      }
      return currentPixels;
    }
    if (isScrolling) {
      // Preserve an in-progress animated scroll or drag. A reply-generation
      // animation settles at the latest extent when it completes.
      return super.adjustPositionForNewDimensions(
        oldPosition: oldPosition,
        newPosition: newPosition,
        isScrolling: isScrolling,
        velocity: velocity,
      );
    }
    // Layout can correct pixels while history, streaming content or the keyboard
    // changes the extent. Only a user scroll should leave following-latest mode;
    // comparing the corrected pixels with the old extent can lose the bottom.
    return newPosition.maxScrollExtent;
  }
}

/// Exposes the latest gallery membership to stable message rows.
class _LiveMessageList extends ListBase<ChatMessageVm> {
  _LiveMessageList(this.source);
  final List<ChatMessageVm> Function() source;
  @override
  int get length => source().length;
  @override
  ChatMessageVm operator [](int index) => source()[index];
  @override
  set length(int value) => throw UnsupportedError('Read-only message view');
  @override
  void operator []=(int index, ChatMessageVm value) =>
      throw UnsupportedError('Read-only message view');
}

/// Measures the footer in the same layout pass as the deck. In particular,
/// collapsing inspiration must shrink both the scroll extent and bottom anchor.
class _ReplyControlsLayoutReporter extends SingleChildRenderObjectWidget {
  const _ReplyControlsLayoutReporter({
    super.key,
    required this.bridge,
    required super.child,
  });

  final LocationChatReplyLayoutBridge bridge;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReplyControlsLayoutReporter(bridge);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderReplyControlsLayoutReporter renderObject,
  ) => renderObject.bridge = bridge;
}

/// Keeps the retained waiting tail at a constant physical height while a
/// variable-height reply card is switching in the second-scroll layout.
///
/// The card reports its new height while laying out the child. Relaying out
/// once with the updated transaction delta lets the viewport receive the final
/// extent in this same frame, rather than painting one jumping frame first.
class _ReplyLayoutConstrainedBox extends SingleChildRenderObjectWidget {
  const _ReplyLayoutConstrainedBox({
    required this.minHeight,
    required this.preserveWaitingTail,
    required this.bridge,
    required super.child,
  });

  final double minHeight;
  final bool preserveWaitingTail;
  final LocationChatReplyLayoutBridge bridge;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReplyLayoutConstrainedBox(
        minHeight: minHeight,
        preserveWaitingTail: preserveWaitingTail,
        bridge: bridge,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderReplyLayoutConstrainedBox renderObject,
  ) {
    renderObject
      ..minHeight = minHeight
      ..preserveWaitingTail = preserveWaitingTail
      ..bridge = bridge;
  }
}

class _RenderReplyLayoutConstrainedBox extends RenderProxyBox {
  _RenderReplyLayoutConstrainedBox({
    required double minHeight,
    required bool preserveWaitingTail,
    required LocationChatReplyLayoutBridge bridge,
  }) : _minHeight = minHeight,
       _preserveWaitingTail = preserveWaitingTail,
       _bridge = bridge;

  double _minHeight;
  bool _preserveWaitingTail;
  LocationChatReplyLayoutBridge _bridge;

  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  set preserveWaitingTail(bool value) {
    if (_preserveWaitingTail == value) return;
    _preserveWaitingTail = value;
    markNeedsLayout();
  }

  set bridge(LocationChatReplyLayoutBridge value) {
    if (identical(_bridge, value)) return;
    _bridge = value;
    markNeedsLayout();
  }

  double get _layoutDelta =>
      _preserveWaitingTail ? _bridge.layoutExtentDelta : 0;

  BoxConstraints _childConstraints(double delta) => BoxConstraints(
    minHeight: (_minHeight + delta).clamp(0.0, double.infinity),
  ).enforce(constraints);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }
    final initialDelta = _layoutDelta;
    child.layout(_childConstraints(initialDelta), parentUsesSize: true);
    final reportedDelta = _layoutDelta;
    if ((reportedDelta - initialDelta).abs() > precisionErrorTolerance) {
      child.layout(_childConstraints(reportedDelta), parentUsesSize: true);
    }
    size = child.size;
  }
}

class _RenderReplyControlsLayoutReporter extends RenderProxyBox {
  _RenderReplyControlsLayoutReporter(this.bridge);
  LocationChatReplyLayoutBridge bridge;

  @override
  void performLayout() {
    super.performLayout();
    bridge.reportControlsHeight(size.height);
  }
}

class _ReplyAnchoredSliverList extends SliverList {
  const _ReplyAnchoredSliverList({
    required super.delegate,
    required this.bridge,
  });
  final LocationChatReplyLayoutBridge bridge;

  @override
  double? estimateMaxScrollOffset(
    SliverConstraints? constraints,
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) =>
      bridge.estimatedSliverExtent ??
      super.estimateMaxScrollOffset(
        constraints,
        firstIndex,
        lastIndex,
        leadingScrollOffset,
        trailingScrollOffset,
      );

  @override
  RenderSliverList createRenderObject(BuildContext context) =>
      _RenderReplyAnchoredSliverList(
        childManager: context as SliverMultiBoxAdaptorElement,
        bridge: bridge,
      );
}

class _RenderReplyAnchoredSliverList extends RenderSliverList {
  _RenderReplyAnchoredSliverList({
    required super.childManager,
    required this.bridge,
  });
  final LocationChatReplyLayoutBridge bridge;

  @override
  void performLayout() {
    super.performLayout();
    if (geometry?.scrollOffsetCorrection != null) return;
    final tail = lastChild;
    if (tail != null && indexOf(tail) == childManager.childCount - 1) {
      bridge.reportSliverExtent(childScrollOffset(tail)! + paintExtentOf(tail));
    }
    if (bridge.beganWithoutScrollExtent) return;
    final correction = bridge.correction;
    if (correction != null && correction.abs() > precisionErrorTolerance) {
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
    }
  }
}

typedef _CachedMessageRow = ({
  Object identity,
  ChatMessageVm snapshot,
  Widget child,
});
