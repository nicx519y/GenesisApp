import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../components/chat/shared/chat_ui.dart';

enum LocationChatViewportMode { initializing, followingLatest, detached }

enum LocationChatBottomReason {
  sentMessage,
  unseenMessageNotice,
  composerFocus,
}

enum LocationChatBottomBehavior { jump, animate }

/// Owns every programmatic scroll-position change for location chat.
class LocationChatScrollCoordinator extends ChangeNotifier {
  LocationChatScrollCoordinator({ScrollController? controller})
    : controller = controller ?? ScrollController(),
      _ownsController = controller == null;

  static const double bottomTolerance = 24;
  static const double oldestMessageStopTolerance = 1;
  static const Duration bottomAnimationDuration = Duration(milliseconds: 220);

  final ScrollController controller;
  final bool _ownsController;

  LocationChatViewportMode _mode = LocationChatViewportMode.initializing;
  int _commandGeneration = 0;
  bool _entryRevealScheduled = false;
  double? _oldestMessageStopOffset;
  bool _userDragActive = false;
  bool _stopAtOldestMessageForCurrentDrag = false;
  bool _disposed = false;

  LocationChatViewportMode get mode => _mode;
  bool get isDetached => _mode == LocationChatViewportMode.detached;
  bool get shouldFollowLatest => !isDetached;
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
    _cancelPendingCommands();
    _entryRevealScheduled = false;
    _setMode(LocationChatViewportMode.initializing);
    onViewportLaidOut();
  }

  void deactivate() {
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
  }) {
    if (_disposed) return;
    final generation = ++_commandGeneration;
    _entryRevealScheduled = false;
    _setMode(LocationChatViewportMode.followingLatest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_commandIsCurrent(generation) || !controller.hasClients) return;
      final target = controller.position.maxScrollExtent;
      switch (behavior) {
        case LocationChatBottomBehavior.jump:
          _jumpTo(target);
        case LocationChatBottomBehavior.animate:
          _animateTo(target);
      }
    });
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userDragActive = true;
      final stopOffset = _oldestMessageStopOffset;
      _stopAtOldestMessageForCurrentDrag =
          stopOffset != null &&
          notification.metrics.pixels > stopOffset + oldestMessageStopTolerance;
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

    final atBottom =
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

  void _animateTo(double target) {
    controller.animateTo(
      target,
      duration: bottomAnimationDuration,
      curve: Curves.easeOut,
    );
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

class LocationChatAnchoredMessageList extends StatefulWidget {
  const LocationChatAnchoredMessageList({
    super.key,
    required this.coordinator,
    required this.messages,
    required this.topTitle,
    this.onMessageLongPressStart,
    this.onFailedMessageTap,
    this.onCharactersMovedLocationTap,
    this.keyboardDismissBehavior,
    this.oldestEdgeNotice,
    this.oldestEdgeNoticeRequiresSecondScroll = false,
    this.oldestEdgeLoading = false,
    this.showDateDividers = true,
    this.messageLayoutId,
    this.style,
  });

  final LocationChatScrollCoordinator coordinator;
  final List<ChatMessageVm> messages;
  final String topTitle;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatMessageTap? onFailedMessageTap;
  final ChatCharacterMovementTap? onCharactersMovedLocationTap;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? oldestEdgeNotice;
  final bool oldestEdgeNoticeRequiresSecondScroll;
  final bool oldestEdgeLoading;
  final bool showDateDividers;
  final String Function(ChatMessageVm message)? messageLayoutId;
  final ChatUiStyleConfig? style;

  @override
  State<LocationChatAnchoredMessageList> createState() =>
      _LocationChatAnchoredMessageListState();
}

class _LocationChatAnchoredMessageListState
    extends State<LocationChatAnchoredMessageList> {
  final Map<String, GlobalKey> _messageLayoutKeys = <String, GlobalKey>{};
  final GlobalKey _scrollViewportKey = GlobalKey();
  late List<String> _messageLocalIds;
  int _anchorRestoreGeneration = 0;
  int _prependAnchorGeneration = 0;
  bool _preservePrependAnchor = false;
  bool _oldestMessageStopLayoutScheduled = false;

  @override
  void initState() {
    super.initState();
    _messageLocalIds = _currentMessageLocalIds();
    _scheduleInitialViewportLayout();
  }

  @override
  void didUpdateWidget(LocationChatAnchoredMessageList oldWidget) {
    final previousLocalIds = _messageLocalIds;
    final nextLocalIds = _currentMessageLocalIds();
    final preservePrependAnchor =
        widget.coordinator.isDetached &&
        _isPureHeadPrepend(previousLocalIds, nextLocalIds);
    final shouldRestoreAnchor =
        widget.coordinator.isDetached &&
        !preservePrependAnchor &&
        _requiresAnchorRestore(previousLocalIds, nextLocalIds);
    final anchor = shouldRestoreAnchor
        ? _visibleRetainedAnchor(previousLocalIds, nextLocalIds.toSet())
        : null;
    final commandGeneration = widget.coordinator.commandGeneration;
    _preservePrependAnchor = preservePrependAnchor;
    _messageLocalIds = nextLocalIds;
    super.didUpdateWidget(oldWidget);
    _pruneMessageLayoutKeys();

    _anchorRestoreGeneration += 1;
    final anchorGeneration = _anchorRestoreGeneration;
    if (widget.coordinator.mode == LocationChatViewportMode.initializing) {
      _scheduleInitialViewportLayout();
    }
    _prependAnchorGeneration += 1;
    final prependGeneration = _prependAnchorGeneration;
    if (preservePrependAnchor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || prependGeneration != _prependAnchorGeneration) return;
        _preservePrependAnchor = false;
      });
    }
    if (anchor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || anchorGeneration != _anchorRestoreGeneration) return;
      final nextAnchorTop = _messageTop(anchor.localId);
      if (nextAnchorTop == null) return;
      widget.coordinator.restoreAnchor(
        delta: nextAnchorTop - anchor.top,
        expectedCommandGeneration: commandGeneration,
      );
    });
  }

  void _scheduleInitialViewportLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.coordinator.onViewportLaidOut();
    });
  }

  List<String> _currentMessageLocalIds() {
    return widget.messages.map(_messageLayoutId).toList(growable: false);
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

  bool _isPureHeadPrepend(List<String> previous, List<String> next) {
    if (previous.isEmpty || next.length <= previous.length) return false;
    final addedCount = next.length - previous.length;
    for (var index = 0; index < previous.length; index += 1) {
      if (previous[index] != next[index + addedCount]) return false;
    }
    return true;
  }

  ({String localId, double top})? _visibleRetainedAnchor(
    List<String> previousLocalIds,
    Set<String> retainedLocalIds,
  ) {
    final viewportBounds = _globalBounds(context.findRenderObject());
    ({String localId, double top})? closestAnchor;
    var closestDistance = double.infinity;
    for (final localId in previousLocalIds) {
      if (!retainedLocalIds.contains(localId)) continue;
      final messageBounds = _messageBounds(localId);
      if (messageBounds == null) continue;
      if (viewportBounds == null) {
        return (localId: localId, top: messageBounds.top);
      }
      final distance = switch (messageBounds) {
        Rect(:final bottom) when bottom < viewportBounds.top =>
          viewportBounds.top - bottom,
        Rect(:final top) when top > viewportBounds.bottom =>
          top - viewportBounds.bottom,
        _ => 0.0,
      };
      if (distance >= closestDistance) continue;
      closestDistance = distance;
      closestAnchor = (localId: localId, top: messageBounds.top);
      if (distance == 0) break;
    }
    return closestAnchor;
  }

  @override
  void dispose() {
    _anchorRestoreGeneration += 1;
    _prependAnchorGeneration += 1;
    widget.coordinator.setOldestMessageStopOffset(null);
    _messageLayoutKeys.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? ChatUiStyleConfig.standard;
    final hasOldestEdgeContent =
        widget.topTitle.trim().isNotEmpty ||
        (widget.oldestEdgeNotice?.trim().isNotEmpty ?? false) ||
        widget.oldestEdgeLoading;
    final requiresSecondScroll =
        widget.oldestEdgeNoticeRequiresSecondScroll &&
        hasOldestEdgeContent &&
        widget.messages.isNotEmpty;
    _scheduleOldestMessageStopLayout(
      enabled: requiresSecondScroll,
      topPadding: style.messageListPadding.top,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 0.0;
        final messageViewportHeight =
            minHeight > style.messageListPadding.vertical
            ? minHeight - style.messageListPadding.vertical
            : 0.0;
        return SingleChildScrollView(
          key: _scrollViewportKey,
          controller: widget.coordinator.controller,
          physics: LocationChatBottomAnchoringScrollPhysics(
            shouldFollowLatest: () => widget.coordinator.shouldFollowLatest,
            shouldPreservePrependAnchor: () => _preservePrependAnchor,
            oldestMessageStopOffset: () =>
                widget.coordinator.oldestMessageStopOffset,
            shouldStopAtOldestMessage: () =>
                widget.coordinator.shouldStopAtOldestMessage,
          ),
          keyboardDismissBehavior:
              widget.keyboardDismissBehavior ??
              ScrollViewKeyboardDismissBehavior.manual,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: style.messageListPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasOldestEdgeContent)
                    ChatOldestEdgeContent(
                      topTitle: widget.topTitle,
                      notice: widget.oldestEdgeNotice,
                      loading: widget.oldestEdgeLoading,
                      style: style,
                    ),
                  if (requiresSecondScroll)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: messageViewportHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var index = 0;
                            index < widget.messages.length;
                            index += 1
                          )
                            _buildMessageRow(index, style),
                        ],
                      ),
                    )
                  else
                    for (
                      var index = 0;
                      index < widget.messages.length;
                      index += 1
                    )
                      _buildMessageRow(index, style),
                ],
              ),
            ),
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
      if (!mounted || widget.messages.isEmpty) return;
      final viewportBounds = _globalBounds(
        _scrollViewportKey.currentContext?.findRenderObject(),
      );
      final firstMessageBounds = _messageBounds(
        _messageLayoutId(widget.messages.first),
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
    final retainedLocalIds = widget.messages.map(_messageLayoutId).toSet();
    _messageLayoutKeys.removeWhere(
      (localId, _) => !retainedLocalIds.contains(localId),
    );
  }

  double? _messageTop(String localId) => _messageBounds(localId)?.top;

  Rect? _messageBounds(String localId) {
    if (localId.isEmpty) return null;
    final messageContext = _messageLayoutKeys[localId]?.currentContext;
    final renderObject = messageContext?.findRenderObject();
    if (renderObject is! RenderBox || !_hasLaidOutRenderPath(renderObject)) {
      return null;
    }
    return _globalBounds(renderObject);
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

  Widget _buildMessageRow(int messageIndex, ChatUiStyleConfig style) {
    final current = widget.messages[messageIndex];
    final previous = messageIndex == 0
        ? null
        : widget.messages[messageIndex - 1];
    final layoutId = _messageLayoutId(current);
    final layoutKey = _messageLayoutKeys.putIfAbsent(layoutId, GlobalKey.new);
    return KeyedSubtree(
      key: layoutKey,
      child: ChatMessageRow(
        key: ValueKey(layoutId),
        message: current,
        imageViewerMessages: widget.messages,
        style: style,
        onMessageLongPressStart: widget.onMessageLongPressStart,
        onFailedMessageTap: widget.onFailedMessageTap,
        onCharactersMovedLocationTap: widget.onCharactersMovedLocationTap,
        showDateDivider:
            widget.showDateDividers &&
            shouldShowChatDateDivider(previous?.createdAt, current.createdAt),
      ),
    );
  }
}

class LocationChatBottomAnchoringScrollPhysics extends ClampingScrollPhysics {
  const LocationChatBottomAnchoringScrollPhysics({
    super.parent,
    required this.shouldFollowLatest,
    this.shouldPreservePrependAnchor,
    this.oldestMessageStopOffset,
    this.shouldStopAtOldestMessage,
  });

  final ValueGetter<bool> shouldFollowLatest;
  final ValueGetter<bool>? shouldPreservePrependAnchor;
  final ValueGetter<double?>? oldestMessageStopOffset;
  final ValueGetter<bool>? shouldStopAtOldestMessage;

  @override
  LocationChatBottomAnchoringScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LocationChatBottomAnchoringScrollPhysics(
      parent: buildParent(ancestor),
      shouldFollowLatest: shouldFollowLatest,
      shouldPreservePrependAnchor: shouldPreservePrependAnchor,
      oldestMessageStopOffset: oldestMessageStopOffset,
      shouldStopAtOldestMessage: shouldStopAtOldestMessage,
    );
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
    if (!shouldFollowLatest()) {
      if (shouldPreservePrependAnchor?.call() ?? false) {
        final extentDelta =
            newPosition.maxScrollExtent - oldPosition.maxScrollExtent;
        return (oldPosition.pixels + extentDelta).clamp(
          newPosition.minScrollExtent,
          newPosition.maxScrollExtent,
        );
      }
      return newPosition.pixels.clamp(
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
    }
    final wasNearBottom =
        oldPosition.maxScrollExtent - newPosition.pixels <=
        LocationChatScrollCoordinator.bottomTolerance;
    if (wasNearBottom) return newPosition.maxScrollExtent;
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}
