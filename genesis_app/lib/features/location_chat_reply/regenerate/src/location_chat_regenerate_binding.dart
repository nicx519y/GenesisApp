part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatRegenerateBinding on _LocationChatPanelState {
  LocationChatRegenerateFeature _regenerateFeature(
    bool replyBlocked,
    ChatroomReplyRoundState? replyState,
    bool regenerationContentRendering, {
    bool? supportedOverride,
  }) {
    final generating =
        (replyState?.generating ?? false) || _regenerateReplyOperationActive;
    final limitReached =
        !generating && (replyState?.regenerateLimitReached ?? false);
    final otherReplyOperationActive =
        _goOnReplyOperationActive ||
        _editReplyOperationActive ||
        _inspirationReplyOperationActive;
    return LocationChatRegenerateFeature(
      state: regenerationContentRendering || limitReached
          ? LocationChatReplyActionState.disabled
          : resolveLocationChatReplyActionState(
              showWhenUnavailable: _usesPreparedEntry,
              busy: generating,
              supported:
                  supportedOverride ?? replyState?.supportsRegenerate ?? false,
              otherReplyOperationActive: otherReplyOperationActive,
              canInvoke: !replyBlocked && (replyState?.canRegenerate ?? false),
            ),
      onLimitReached:
          limitReached && !replyBlocked && !otherReplyOperationActive
          ? () =>
                showGenesisToast(context, 'You can generate up to 10 replies.')
          : null,
      onInvoke: () => unawaited(
        _runReplyAction(
          (controller) => controller.regenerate(widget.locationId),
          generating: true,
          regenerating: true,
        ),
      ),
    );
  }
}
