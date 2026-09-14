part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatRegenerateBinding on _LocationChatPanelState {
  LocationChatRegenerateFeature _regenerateFeature(
    LocationChatReplyControlsSnapshot controls,
  ) {
    return LocationChatRegenerateFeature(
      state: controls.regenerate,
      onLimitReached: controls.canExplainRegenerateLimit
          ? () =>
                showGenesisToast(context, 'You can generate up to 10 replies.')
          : null,
      onInvoke: () => unawaited(
        _runReplyGeneration(
          (controller) => controller.regenerate(widget.locationId),
          regenerating: true,
        ),
      ),
    );
  }
}
