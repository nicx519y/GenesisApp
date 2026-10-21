part of 'location_chat_page.dart';

extension _LocationChatPhoneNavigation on _LocationChatPanelState {
  Future<void> _openPhoneFromRoom({
    MiniPhoneSession? session,
    PhonePerson? contact,
    required String source,
  }) async {
    await PagePresentationScope.runCovered(context, () async {
      await showMiniPhone(
        context,
        session: session,
        worldId: _modelWorldId,
        modelCache: _modelRequestCache,
        initialContact: contact,
        entrySource: source,
      );
    });
  }
}
