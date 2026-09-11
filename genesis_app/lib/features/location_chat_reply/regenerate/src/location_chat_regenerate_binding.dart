part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatRegenerateBinding on _LocationChatPanelState {
  LocationChatRegenerateFeature _regenerateFeature(
    bool replyBlocked,
    ChatroomReplyRoundState? replyState,
    bool contentHasStartedRendering,
  ) => LocationChatRegenerateFeature(
    enabled: !replyBlocked && (replyState?.canRegenerate ?? false),
    busy:
        ((replyState?.generating ?? false) ||
            (_replyRequestLoading && _replyLoadingForRegeneration)) &&
        !contentHasStartedRendering,
    onInvoke: () => unawaited(
      _runReplyAction(
        (controller) => controller.regenerate(widget.locationId),
        generating: true,
        regenerating: true,
      ),
    ),
  );
}
