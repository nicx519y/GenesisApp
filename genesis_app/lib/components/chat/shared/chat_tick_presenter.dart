import '../../../network/chatroom/chatroom_models.dart';
import '../../../network/chatroom/chatroom_timeline_payload.dart';
import '../../../utils/genesis_ugc_text.dart';
import 'chat_ui.dart';

/// Both chat and World Events resolve the same chapter through this adapter.
/// Null existence means location metadata is still loading, not an unknown ID.
ChatTickPayloadVm presentChatTickChapter(
  ChatroomV2TickPayload payload, {
  required String Function(String) locationName,
  required String Function(String) roleName,
  required String Function(String) roleAvatarUrl,
  required bool? Function(String) roleIsAi,
  bool? Function(String)? locationExists,
  bool Function(String)? isUserId,
  String legacyLocationId = '',
  bool requireLegacyVisibility = false,
  ChatCharactersMovedPayloadVm? charactersMoved,
}) {
  if (payload.isMalformed) return const ChatTickPayloadVm(isMalformed: true);
  String display(String value) => value.length <= chatroomMaxStringCodeUnits
      ? normalizeGenesisUgcTextForDisplay(value)
      : '';
  bool user(String id) => isUserId?.call(id) ?? false;
  ChatTickStatusVm statusVm(
    ChatroomTickStatus status,
    Map<String, String> cast,
  ) {
    final owner = status.owner.trim();
    final isWorld = owner == 'world';
    final resolvedName = isWorld ? '' : roleName(owner).trim();
    return ChatTickStatusVm(
      owner: owner,
      name: display(
        resolvedName.isEmpty || resolvedName == owner
            ? cast[owner] ?? ''
            : resolvedName,
      ),
      avatarUrl: isWorld ? '' : roleAvatarUrl(owner),
      icon: display(status.icon),
      form: display(status.form),
      content: display(status.content),
    );
  }

  final paragraphs = <ChatStoryEventParagraphVm>[];
  for (final (index, event) in payload.storyEvents.indexed) {
    final locationId = event.locationId.trim();
    final modern = payload.hasStatusFields || event.hasStatusFields;
    if (modern && locationExists?.call(locationId) == false) continue;
    if (!modern &&
        legacyLocationId.isNotEmpty &&
        locationId != legacyLocationId) {
      continue;
    }
    final visibility = event.visibility.trim().toLowerCase();
    final visibleTo = event.visibleTo ?? const <String>[];
    if ([
          event.locationId,
          event.timestamp,
          event.visibility,
          event.text,
          event.clue,
          ...visibleTo,
        ].any((value) => value.length > chatroomMaxStringCodeUnits) ||
        visibleTo.length > chatroomMaxCollectionItems) {
      continue;
    }
    if (!modern &&
        requireLegacyVisibility &&
        ((visibility != 'public' && visibility != 'char_only') ||
            (visibility == 'char_only' && visibleTo.isEmpty))) {
      continue;
    }
    final roles = <ChatStoryEventVisibleRoleVm>[];
    if (!modern && visibility != 'public') {
      final seen = <String>{};
      for (final id in visibleTo) {
        final name = display(roleName(id)).trim();
        if (name.isEmpty || !seen.add(name)) continue;
        roles.add(
          ChatStoryEventVisibleRoleVm(
            roleId: id,
            name: name,
            isAi: roleIsAi(id) ?? false,
            avatarUrl: roleAvatarUrl(id),
          ),
        );
      }
    }
    final cast = <String, String>{};
    for (final member in event.cast) {
      final id = member.id.trim();
      if (id.isNotEmpty && !user(id)) cast.putIfAbsent(id, () => member.name);
    }
    final statuses = [
      for (final status in event.status)
        if (status.owner.trim() == 'world' ||
            (!user(status.owner.trim()) &&
                cast.containsKey(status.owner.trim())))
          statusVm(status, cast),
    ];
    paragraphs.add(
      ChatStoryEventParagraphVm(
        timestamp: modern || event.timestamp == payload.currentTime
            ? ''
            : display(event.timestamp),
        text: display(event.text),
        clue: display(event.clue),
        visibilityLabel: modern
            ? ''
            : visibility == 'public'
            ? 'public'
            : roles.map((role) => role.name).join(', '),
        visibleRoles: List.unmodifiable(roles),
        locationId: locationId,
        locationName: display(locationName(locationId)),
        statuses: List.unmodifiable(statuses),
        sourceIndex: index,
      ),
    );
  }
  return ChatTickPayloadVm(
    globalText: display(payload.globalText),
    globalStatuses: List.unmodifiable([
      for (final status in payload.globalStatus)
        if (status.owner.trim() == 'world') statusVm(status, const {}),
    ]),
    storyEvents: paragraphs.isEmpty
        ? null
        : ChatStoryEventsPayloadVm(
            locationId: paragraphs.first.locationId,
            locationName: paragraphs.first.locationName,
            paragraphs: List.unmodifiable(paragraphs),
          ),
    charactersMoved: charactersMoved,
    fallbackContent: display(payload.fallbackContent),
  );
}
