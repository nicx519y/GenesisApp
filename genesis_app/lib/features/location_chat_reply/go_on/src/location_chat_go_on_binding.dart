part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatGoOnBinding on _LocationChatPanelState {
  LocationChatGoOnFeature _goOnFeature(
    bool replyBlocked,
    ChatroomReplyRoundState? replyState,
    bool goOnPending,
    bool contentIsRendering,
  ) => LocationChatGoOnFeature(
    state: resolveLocationChatReplyActionState(
      showWhenUnavailable: _usesPreparedEntry,
      busy:
          (goOnPending ||
              (_replyRequestLoading && !_replyLoadingForRegeneration)) &&
          !contentIsRendering,
      supported: replyState?.supportsGoOn ?? false,
      otherReplyOperationActive:
          _regenerateReplyOperationActive ||
          _editReplyOperationActive ||
          _inspirationReplyOperationActive,
      canInvoke: !replyBlocked && (replyState?.canGoOn ?? false),
    ),
    onInvoke: () => unawaited(
      _runReplyAction(
        (controller) => controller.goOn(widget.locationId),
        generating: true,
        continuing: true,
      ),
    ),
  );
}
