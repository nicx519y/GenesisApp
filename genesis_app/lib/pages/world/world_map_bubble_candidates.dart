import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/json_utils.dart';
import 'world_value_helpers.dart';

class WorldMapBubbleCandidate {
  const WorldMapBubbleCandidate({
    required this.characterId,
    required this.characterLocationId,
    required this.message,
    required this.content,
  });

  final String characterId;
  final String characterLocationId;
  final WorldChatroomMessage message;
  final String content;
}

List<WorldMapBubbleCandidate> worldMapBubbleCandidatesFor({
  required int currentTickNo,
  required List<Map<String, dynamic>> characterPositions,
  required Map<String, List<WorldChatroomMessage>> messagesByLocation,
}) {
  if (currentTickNo <= 0 || characterPositions.isEmpty) {
    return const <WorldMapBubbleCandidate>[];
  }

  final aiCharacterLocationById = _aiCharacterLocationById(characterPositions);
  if (aiCharacterLocationById.isEmpty) {
    return const <WorldMapBubbleCandidate>[];
  }

  final candidates = <WorldMapBubbleCandidate>[];
  final relevantLocationIds = aiCharacterLocationById.values.toSet();
  for (final locationId in relevantLocationIds) {
    final messages = messagesByLocation[locationId];
    if (messages == null || messages.isEmpty) continue;

    final currentTickMessages = messages
        .where((message) => message.tickNo == currentTickNo)
        .toList(growable: false);
    if (currentTickMessages.isEmpty) continue;

    final latestRoundId = _latestConversationRoundId(currentTickMessages);
    if (latestRoundId.isEmpty) continue;

    for (final message in currentTickMessages) {
      if (message.conversationRoundId != latestRoundId) continue;
      final characterLocationId = aiCharacterLocationById[message.senderId];
      if (characterLocationId == null) continue;
      if (!_isBubbleMessageSenderType(message.senderType)) continue;
      if (message.streaming) continue;
      final content = worldMapBubbleDisplayContent(message.content);
      if (content.isEmpty) continue;
      candidates.add(
        WorldMapBubbleCandidate(
          characterId: message.senderId,
          characterLocationId: characterLocationId,
          message: message,
          content: content,
        ),
      );
    }
  }

  candidates.sort(_compareBubbleCandidates);
  return List<WorldMapBubbleCandidate>.unmodifiable(candidates);
}

Map<String, String> _aiCharacterLocationById(
  List<Map<String, dynamic>> characterPositions,
) {
  final result = <String, String>{};
  for (final position in characterPositions) {
    final locationId = worldMapString(position, const [
      'location_id',
      'current_location_id',
    ]);
    if (locationId.isEmpty) continue;
    final rawCharacter = position['character'];
    if (rawCharacter is! Map) continue;
    final character = asJsonMap(rawCharacter);
    if (!_isAiControlledCharacter(character)) continue;
    final characterId = worldMapString(character, const [
      'character_id',
      'char_id',
      'id',
    ]);
    if (characterId.isEmpty) continue;
    result[characterId] = locationId;
  }
  return result;
}

bool _isAiControlledCharacter(Map<String, dynamic> character) {
  final type = character['type'];
  final isAiRole = type is num
      ? type == 1
      : {'1', 'ai'}.contains('$type'.trim().toLowerCase());
  final playerUid = worldMapString(character, const [
    'player_uid',
    'user_id',
    'uid',
  ]);
  return isAiRole && playerUid.isEmpty;
}

String _latestConversationRoundId(List<WorldChatroomMessage> messages) {
  WorldChatroomMessage? latest;
  for (final message in messages) {
    if (message.streaming) continue;
    if (latest == null || _compareMessages(message, latest) > 0) {
      latest = message;
    }
  }
  return latest?.conversationRoundId ?? '';
}

bool _isBubbleMessageSenderType(String senderType) {
  final normalized = senderType.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return normalized != 'narrator' &&
      normalized != 'npc' &&
      normalized != 'system' &&
      normalized != 'tick' &&
      normalized != 'user' &&
      normalized != 'player';
}

String worldMapBubbleDisplayContent(String raw) {
  var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = _removeItalicMarkdownSpans(text);
  text = text.replaceAllMapped(
    RegExp(r'\\([\\`*_{}\[\]()#+\-.!|>])'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAll(RegExp(r'[「」]'), '');
  text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
  text = text.replaceAll(RegExp(r' *\n+ *'), ' ');
  text = text.replaceAllMapped(
    RegExp(r'\s+([,.!?;:])'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'([([{])\s+'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAll(RegExp(r'\\r\\n|\\n|\\r'), ' ');
  return text.trim();
}

String _removeItalicMarkdownSpans(String input) {
  return input.replaceAll(RegExp(r'\*[^*\n]+?\*'), ' ');
}

int _compareBubbleCandidates(
  WorldMapBubbleCandidate a,
  WorldMapBubbleCandidate b,
) {
  final byMessage = _compareMessages(a.message, b.message);
  if (byMessage != 0) return byMessage;
  return a.characterId.compareTo(b.characterId);
}

int _compareMessages(WorldChatroomMessage a, WorldChatroomMessage b) {
  final aCreated = a.createdAt;
  final bCreated = b.createdAt;
  if (aCreated != null && bCreated != null) {
    final byCreated = aCreated.compareTo(bCreated);
    if (byCreated != 0) return byCreated;
  } else if (aCreated != null) {
    return 1;
  } else if (bCreated != null) {
    return -1;
  }

  if (a.messageId > 0 && b.messageId > 0) {
    final byMessageId = a.messageId.compareTo(b.messageId);
    if (byMessageId != 0) return byMessageId;
  }

  final byRound = a.conversationRoundNumber.compareTo(
    b.conversationRoundNumber,
  );
  if (byRound != 0) return byRound;

  final byOrder = a.roundOrder.compareTo(b.roundOrder);
  if (byOrder != 0) return byOrder;

  return a.messageId.compareTo(b.messageId);
}
