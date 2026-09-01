import 'package:flutter/material.dart';

import 'chat_character_mention_tag.dart';
import 'chat_location_mention_tag.dart';

export 'chat_character_mention_tag.dart';
export 'chat_location_mention_tag.dart';

enum ChatMentionType { character, location }

@immutable
class ChatMentionEntry {
  const ChatMentionEntry({
    required this.id,
    required this.name,
    required this.type,
    this.subtitle = '',
    this.imageUrl = '',
    this.isPlayerControlled = false,
    this.isNew = false,
    this.isCurrentLocation = false,
  });

  final String id;
  final String name;
  final ChatMentionType type;
  final String subtitle;
  final String imageUrl;
  final bool isPlayerControlled;
  final bool isNew;
  final bool isCurrentLocation;

  String get serializedText => '@$name<$id>';
}

@immutable
class ChatMentionCatalog {
  ChatMentionCatalog({
    Iterable<ChatMentionEntry> characters = const <ChatMentionEntry>[],
    Iterable<ChatMentionEntry> currentLocationCharacters =
        const <ChatMentionEntry>[],
    Iterable<ChatMentionEntry> locations = const <ChatMentionEntry>[],
  }) : characters = List<ChatMentionEntry>.unmodifiable(characters),
       currentLocationCharacters = List<ChatMentionEntry>.unmodifiable(
         currentLocationCharacters,
       ),
       locations = List<ChatMentionEntry>.unmodifiable(locations),
       newLocations = List<ChatMentionEntry>.unmodifiable(
         locations.where((entry) => entry.isNew),
       ),
       _byId = _buildLookup(characters, locations);

  static final ChatMentionCatalog empty = ChatMentionCatalog();

  final List<ChatMentionEntry> characters;
  final List<ChatMentionEntry> currentLocationCharacters;
  final List<ChatMentionEntry> locations;
  final List<ChatMentionEntry> newLocations;
  final Map<String, ChatMentionEntry> _byId;

  bool get isEmpty => characters.isEmpty && locations.isEmpty;

  ChatMentionEntry? entryForId(String id) => _byId[id.trim()];

  static Map<String, ChatMentionEntry> _buildLookup(
    Iterable<ChatMentionEntry> characters,
    Iterable<ChatMentionEntry> locations,
  ) {
    final result = <String, ChatMentionEntry>{};
    for (final entry in characters) {
      final id = entry.id.trim();
      if (id.isNotEmpty) result.putIfAbsent(id, () => entry);
    }
    for (final entry in locations) {
      final id = entry.id.trim();
      if (id.isNotEmpty) result.putIfAbsent(id, () => entry);
    }
    return Map<String, ChatMentionEntry>.unmodifiable(result);
  }
}

class ChatMentionScope extends InheritedWidget {
  const ChatMentionScope({
    super.key,
    required this.catalog,
    required super.child,
  });

  final ChatMentionCatalog catalog;

  static ChatMentionCatalog? maybeCatalogOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ChatMentionScope>()
        ?.catalog;
  }

  @override
  bool updateShouldNotify(ChatMentionScope oldWidget) {
    return !identical(catalog, oldWidget.catalog);
  }
}

@immutable
class ChatMentionToken {
  const ChatMentionToken({
    required this.start,
    required this.end,
    required this.name,
    required this.id,
    required this.entry,
  });

  final int start;
  final int end;
  final String name;
  final String id;
  final ChatMentionEntry entry;

  String get rawText => '@$name<$id>';
}

final RegExp _chatMentionPattern = RegExp(r'@([^@<>\n]+)<([^<>\s]+)>');

List<ChatMentionToken> parseKnownChatMentions(
  String text,
  ChatMentionCatalog catalog,
) {
  final tokens = <ChatMentionToken>[];
  for (final match in _chatMentionPattern.allMatches(text)) {
    final name = (match.group(1) ?? '').trim();
    final id = (match.group(2) ?? '').trim();
    if (name.isEmpty || id.isEmpty) continue;
    final entry = catalog.entryForId(id);
    if (entry == null) continue;
    tokens.add(
      ChatMentionToken(
        start: match.start,
        end: match.end,
        name: name,
        id: id,
        entry: entry,
      ),
    );
  }
  return tokens;
}

InlineSpan chatMentionWidgetSpan(ChatMentionToken token) {
  final child = token.entry.type == ChatMentionType.character
      ? ChatCharacterMentionTag(name: token.name)
      : ChatLocationMentionTag(name: token.name);
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Semantics(label: '@${token.name}', child: child),
  );
}
