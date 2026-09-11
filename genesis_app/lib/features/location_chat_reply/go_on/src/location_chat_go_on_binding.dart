part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatGoOnBinding on _LocationChatPanelState {
  LocationChatGoOnFeature _goOnFeature(
    bool replyBlocked,
    ChatroomReplyRoundState? replyState,
    bool goOnPending,
    bool contentIsRendering,
  ) => LocationChatGoOnFeature(
    enabled: !replyBlocked && (replyState?.canGoOn ?? false),
    busy:
        (goOnPending ||
            (_replyRequestLoading && !_replyLoadingForRegeneration)) &&
        !contentIsRendering,
    onInvoke: () => unawaited(
      _runReplyAction(
        (controller) => controller.goOn(widget.locationId),
        generating: true,
      ),
    ),
  );
}
