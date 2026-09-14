part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatGoOnBinding on _LocationChatPanelState {
  LocationChatGoOnFeature _goOnFeature(LocationChatReplyActionState state) =>
      LocationChatGoOnFeature(
        state: state,
        onInvoke: () => unawaited(
          _runReplyGeneration(
            (controller) => controller.goOn(widget.locationId),
            regenerating: false,
          ),
        ),
      );
}
