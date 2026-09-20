part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatGoOnBinding on _LocationChatPanelState {
  LocationChatGoOnFeature _goOnFeature(LocationChatReplyActionState state) =>
      LocationChatGoOnFeature(
        state: state,
        onInvoke: () {
          final attempt = _beginGoOnAnalytics();
          unawaited(
            _submitReplyAction(
              _LocationChatReplyActionTransaction(
                action: _LocationChatReplyConnectionAction.goOn,
                commit: () => _runReplyGeneration(
                  (controller) => controller.goOn(widget.locationId),
                  regenerating: false,
                  onError: (error) =>
                      _finishGoOnAnalyticsFromError(attempt, error),
                ),
                onFailure: (error) =>
                    _finishGoOnAnalyticsFromError(attempt, error),
              ),
            ),
          );
        },
      );
}
