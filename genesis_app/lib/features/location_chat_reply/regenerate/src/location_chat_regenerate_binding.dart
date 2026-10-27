part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatRegenerateBinding on _LocationChatPanelState {
  LocationChatRegenerateFeature _regenerateFeature(
    LocationChatReplyControlsSnapshot controls,
  ) {
    return LocationChatRegenerateFeature(
      state: controls.regenerate,
      onLimitReached: controls.canExplainRegenerateLimit
          ? () {
              _recordRegenerateLimit();
              showGenesisToast(
                context,
                GenesisL10n.current.chatGenerate10Replies,
              );
            }
          : null,
      onInvoke: () {
        final attempt = _beginRegenerateAnalytics();
        unawaited(
          _submitReplyAction(
            _LocationChatReplyActionTransaction(
              action: _LocationChatReplyConnectionAction.regenerate,
              commit: () => _runReplyGeneration(
                (controller) => controller.regenerate(
                  widget.locationId,
                  preparation: _replyPreparationWait,
                ),
                regenerating: true,
                failureAction: _LocationChatReplyConnectionAction.regenerate,
                onError: (error) =>
                    _finishRegenerateAnalyticsFromError(attempt, error),
              ),
              onFailure: (error) =>
                  _finishRegenerateAnalyticsFromError(attempt, error),
            ),
          ),
        );
      },
    );
  }
}
