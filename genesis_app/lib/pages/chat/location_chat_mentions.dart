part of 'location_chat_page.dart';

const String _locationChatMentionPlaceholder = '\uFFFC';

@visibleForTesting
ChatMentionCatalog locationChatMentionCatalogForState(
  WorldChatroomState state,
) {
  final world = state.world;
  if (world == null) return ChatMentionCatalog.empty;

  final characterIds = <String>{};
  final characters = <ChatMentionEntry>[];
  for (final character in world.characters) {
    final id = _firstMapString(character, const [
      'char_id',
      'character_id',
      'id',
    ]).trim();
    if (id.isEmpty || characterIds.contains(id)) continue;
    final name = _firstMapString(character, const [
      'name',
      'role_nickname',
      'role_name',
      'character_name',
    ]).trim();
    if (name.isEmpty) continue;
    characterIds.add(id);
    characters.add(
      ChatMentionEntry(
        id: id,
        name: normalizeGenesisUgcTextForDisplay(name),
        type: ChatMentionType.character,
        imageUrl: _firstMapImageUrl(character, const ['avatar', 'avatar_url']),
      ),
    );
  }

  final locationValues = <({String nodeId, Map<String, dynamic> value})>[
    for (final node in world.processedLocationTree.flattened)
      if (node.children.isEmpty) (nodeId: node.id, value: node.value),
  ];
  final locationIds = <String>{};
  final locations = <ChatMentionEntry>[];
  for (final item in locationValues) {
    final id = firstNonEmpty([
      item.nodeId,
      _firstMapString(item.value, const ['location_id', 'id']),
    ]);
    if (id.isEmpty || locationIds.contains(id)) continue;
    final name = _firstMapString(item.value, const [
      'location_name',
      'name',
    ]).trim();
    if (name.isEmpty) continue;
    locationIds.add(id);
    locations.add(
      ChatMentionEntry(
        id: id,
        name: normalizeGenesisUgcTextForDisplay(name),
        type: ChatMentionType.location,
        imageUrl: _firstMapImageUrl(item.value, const [
          'image',
          'icon',
          'map_url',
          'mapUrl',
        ]),
      ),
    );
  }

  return ChatMentionCatalog(characters: characters, locations: locations);
}

class LocationChatMentionEditingController extends TextEditingController {
  LocationChatMentionEditingController({ChatMentionCatalog? catalog})
    : _catalog = catalog ?? ChatMentionCatalog.empty;

  ChatMentionCatalog _catalog;
  final List<_LocationChatComposerMention> _mentions =
      <_LocationChatComposerMention>[];
  int? _insertedAtOffset;
  bool _applyingValue = false;

  ChatMentionCatalog get catalog => _catalog;

  String get serializedText {
    final buffer = StringBuffer();
    var mentionIndex = 0;
    for (var index = 0; index < text.length; index += 1) {
      if (text[index] != _locationChatMentionPlaceholder) {
        buffer.write(text[index]);
        continue;
      }
      if (mentionIndex < _mentions.length) {
        buffer.write(_mentions[mentionIndex].serializedText);
      }
      mentionIndex += 1;
    }
    return buffer.toString();
  }

  int? takeInsertedAtOffset() {
    final result = _insertedAtOffset;
    _insertedAtOffset = null;
    return result;
  }

  bool updateCatalog(ChatMentionCatalog nextCatalog) {
    if (_catalogSignature(_catalog) == _catalogSignature(nextCatalog)) {
      return false;
    }
    final rawText = serializedText;
    final serializedBase = _internalOffsetToSerialized(selection.baseOffset);
    final serializedExtent = _internalOffsetToSerialized(
      selection.extentOffset,
    );
    _catalog = nextCatalog;
    _setSerializedValue(
      rawText,
      serializedSelection: TextSelection(
        baseOffset: serializedBase,
        extentOffset: serializedExtent,
      ),
    );
    return true;
  }

  void setSerializedText(String rawText) {
    _setSerializedValue(
      rawText,
      serializedSelection: TextSelection.collapsed(offset: rawText.length),
    );
  }

  void insertMention(
    ChatMentionEntry entry, {
    required int replaceStart,
    required int replaceEnd,
  }) {
    final safeStart = replaceStart.clamp(0, text.length);
    final safeEnd = replaceEnd.clamp(safeStart, text.length);
    final mentionIndex = _placeholderCount(text.substring(0, safeStart));
    final removedCount = _placeholderCount(text.substring(safeStart, safeEnd));
    if (removedCount > 0) {
      _mentions.removeRange(mentionIndex, mentionIndex + removedCount);
    }
    _mentions.insert(
      mentionIndex,
      _LocationChatComposerMention(
        id: entry.id,
        name: entry.name,
        entry: entry,
      ),
    );
    final nextText = text.replaceRange(
      safeStart,
      safeEnd,
      _locationChatMentionPlaceholder,
    );
    _setInternalValue(
      TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: safeStart + 1),
      ),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    if (_applyingValue) {
      super.value = newValue;
      return;
    }
    final oldValue = super.value;
    if (oldValue.text == newValue.text) {
      super.value = newValue;
      return;
    }

    final difference = _singleTextDifference(oldValue.text, newValue.text);
    final mentionIndex = _placeholderCount(
      oldValue.text.substring(0, difference.oldStart),
    );
    final removedMentions = _placeholderCount(
      oldValue.text.substring(difference.oldStart, difference.oldEnd),
    );
    if (removedMentions > 0) {
      _mentions.removeRange(mentionIndex, mentionIndex + removedMentions);
    }

    final inserted = newValue.text.substring(
      difference.newStart,
      difference.newEnd,
    );
    final sanitizedInserted = inserted.replaceAll(
      _locationChatMentionPlaceholder,
      '',
    );
    final sanitizedText = newValue.text.replaceRange(
      difference.newStart,
      difference.newEnd,
      sanitizedInserted,
    );
    final strippedPlaceholders = inserted.length - sanitizedInserted.length;
    final nextSelection = _shiftSelectionAfterRemovedCharacters(
      newValue.selection,
      difference.newStart,
      strippedPlaceholders,
      sanitizedText.length,
    );
    final nextComposing = strippedPlaceholders == 0
        ? newValue.composing
        : TextRange.empty;

    final caret = nextSelection.extentOffset;
    final insertedStart = difference.newStart;
    final insertedEnd = insertedStart + sanitizedInserted.length;
    int? atOffset;
    for (var index = insertedEnd - 1; index >= insertedStart; index -= 1) {
      if (sanitizedText[index] == '@' && index < caret) {
        atOffset = index;
        break;
      }
    }
    _insertedAtOffset = atOffset;
    super.value = TextEditingValue(
      text: sanitizedText,
      selection: nextSelection,
      composing: nextComposing,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <InlineSpan>[];
    final composing = withComposing && value.composing.isValid
        ? value.composing
        : TextRange.empty;
    var mentionIndex = 0;
    var index = 0;
    while (index < text.length) {
      if (text[index] == _locationChatMentionPlaceholder) {
        if (mentionIndex < _mentions.length) {
          final mention = _mentions[mentionIndex];
          spans.add(
            chatMentionWidgetSpan(
              ChatMentionToken(
                start: index,
                end: index + 1,
                name: mention.name,
                id: mention.id,
                entry: mention.entry,
              ),
            ),
          );
        }
        mentionIndex += 1;
        index += 1;
        continue;
      }

      final composingText =
          composing.isValid &&
          index >= composing.start &&
          index < composing.end;
      final start = index;
      while (index < text.length &&
          text[index] != _locationChatMentionPlaceholder &&
          (composing.isValid &&
                  index >= composing.start &&
                  index < composing.end) ==
              composingText) {
        index += 1;
      }
      spans.add(
        TextSpan(
          text: text.substring(start, index),
          style: composingText
              ? const TextStyle(decoration: TextDecoration.underline)
              : null,
        ),
      );
    }
    return TextSpan(style: style, children: spans);
  }

  void _setSerializedValue(
    String rawText, {
    required TextSelection serializedSelection,
  }) {
    final tokens = parseKnownChatMentions(rawText, _catalog);
    final buffer = StringBuffer();
    final mentions = <_LocationChatComposerMention>[];
    var offset = 0;
    for (final token in tokens) {
      buffer.write(rawText.substring(offset, token.start));
      buffer.write(_locationChatMentionPlaceholder);
      mentions.add(
        _LocationChatComposerMention(
          id: token.id,
          name: token.name,
          entry: token.entry,
        ),
      );
      offset = token.end;
    }
    buffer.write(rawText.substring(offset));
    final internalText = buffer.toString();
    _mentions
      ..clear()
      ..addAll(mentions);
    _insertedAtOffset = null;
    _setInternalValue(
      TextEditingValue(
        text: internalText,
        selection: TextSelection(
          baseOffset: _serializedOffsetToInternal(
            rawText,
            tokens,
            serializedSelection.baseOffset,
          ),
          extentOffset: _serializedOffsetToInternal(
            rawText,
            tokens,
            serializedSelection.extentOffset,
          ),
        ),
      ),
    );
  }

  void _setInternalValue(TextEditingValue nextValue) {
    _applyingValue = true;
    try {
      super.value = nextValue;
    } finally {
      _applyingValue = false;
    }
  }

  int _internalOffsetToSerialized(int internalOffset) {
    final safeOffset = internalOffset.clamp(0, text.length);
    var serializedOffset = 0;
    var mentionIndex = 0;
    for (var index = 0; index < safeOffset; index += 1) {
      if (text[index] == _locationChatMentionPlaceholder &&
          mentionIndex < _mentions.length) {
        serializedOffset += _mentions[mentionIndex].serializedText.length;
        mentionIndex += 1;
      } else {
        serializedOffset += 1;
      }
    }
    return serializedOffset;
  }
}

class _LocationChatComposerMention {
  const _LocationChatComposerMention({
    required this.id,
    required this.name,
    required this.entry,
  });

  final String id;
  final String name;
  final ChatMentionEntry entry;

  String get serializedText => '@$name<$id>';
}

({int oldStart, int oldEnd, int newStart, int newEnd}) _singleTextDifference(
  String oldText,
  String newText,
) {
  var prefix = 0;
  final shortestLength = math.min(oldText.length, newText.length);
  while (prefix < shortestLength && oldText[prefix] == newText[prefix]) {
    prefix += 1;
  }
  var suffix = 0;
  while (suffix < oldText.length - prefix &&
      suffix < newText.length - prefix &&
      oldText[oldText.length - 1 - suffix] ==
          newText[newText.length - 1 - suffix]) {
    suffix += 1;
  }
  return (
    oldStart: prefix,
    oldEnd: oldText.length - suffix,
    newStart: prefix,
    newEnd: newText.length - suffix,
  );
}

int _placeholderCount(String text) {
  return _locationChatMentionPlaceholder.allMatches(text).length;
}

TextSelection _shiftSelectionAfterRemovedCharacters(
  TextSelection selection,
  int removalStart,
  int removedCount,
  int textLength,
) {
  if (!selection.isValid || removedCount == 0) {
    return selection.isValid
        ? TextSelection(
            baseOffset: selection.baseOffset.clamp(0, textLength),
            extentOffset: selection.extentOffset.clamp(0, textLength),
          )
        : TextSelection.collapsed(offset: textLength);
  }
  int shift(int offset) {
    if (offset <= removalStart) return offset.clamp(0, textLength);
    return (offset - removedCount).clamp(0, textLength);
  }

  return TextSelection(
    baseOffset: shift(selection.baseOffset),
    extentOffset: shift(selection.extentOffset),
    affinity: selection.affinity,
    isDirectional: selection.isDirectional,
  );
}

int _serializedOffsetToInternal(
  String rawText,
  List<ChatMentionToken> tokens,
  int serializedOffset,
) {
  final target = serializedOffset.clamp(0, rawText.length);
  var sourceOffset = 0;
  var internalOffset = 0;
  for (final token in tokens) {
    if (target <= token.start) {
      return internalOffset + target - sourceOffset;
    }
    internalOffset += token.start - sourceOffset;
    if (target < token.end) return internalOffset + 1;
    internalOffset += 1;
    sourceOffset = token.end;
  }
  return internalOffset + target - sourceOffset;
}

int _catalogSignature(ChatMentionCatalog catalog) {
  return Object.hashAll(<Object?>[
    for (final entry in <ChatMentionEntry>[
      ...catalog.characters,
      ...catalog.locations,
    ]) ...[entry.id, entry.name, entry.type, entry.imageUrl],
  ]);
}

extension _LocationChatMentionActions on _LocationChatPanelState {
  void _scheduleMentionSheet(int triggerOffset) {
    if (_mentionSheetOpen || _mentionSheetSchedulePending || !widget.active) {
      return;
    }
    _mentionSheetSchedulePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mentionSheetSchedulePending = false;
      if (!mounted || _mentionSheetOpen || !widget.active) return;
      unawaited(_showMentionSheet(triggerOffset));
    });
  }

  Future<void> _showMentionSheet(int triggerOffset) async {
    if (_mentionSheetOpen ||
        triggerOffset < 0 ||
        triggerOffset >= _textController.text.length ||
        _textController.text[triggerOffset] != '@') {
      return;
    }
    _mentionSheetOpen = true;
    _composerFocusNode.unfocus();
    final selected = await showGenesisModalBottomSheet<ChatMentionEntry>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (sheetContext) =>
          LocationChatMentionSheet(catalog: _textController.catalog),
    );
    if (!mounted) return;
    _mentionSheetOpen = false;
    if (selected != null) {
      final triggerStillExists =
          triggerOffset < _textController.text.length &&
          _textController.text[triggerOffset] == '@';
      final selection = _textController.selection;
      final fallbackStart = selection.isValid
          ? selection.start
          : _textController.text.length;
      final fallbackEnd = selection.isValid ? selection.end : fallbackStart;
      _textController.insertMention(
        selected,
        replaceStart: triggerStillExists ? triggerOffset : fallbackStart,
        replaceEnd: triggerStillExists ? triggerOffset + 1 : fallbackEnd,
      );
    }
    _composerFocusNode.requestFocus();
  }
}

class LocationChatMentionSheet extends StatefulWidget {
  const LocationChatMentionSheet({super.key, required this.catalog});

  final ChatMentionCatalog catalog;

  @override
  State<LocationChatMentionSheet> createState() =>
      _LocationChatMentionSheetState();
}

class _LocationChatMentionSheetState extends State<LocationChatMentionSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.6;
    return Material(
      key: const ValueKey<String>('location-chat-mention-sheet'),
      color: const Color(0xFF151517),
      borderRadius: GenesisBottomSheetPanel.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 10, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mention',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 24 / 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'location-chat-mention-close',
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              GenesisTabBar(
                controller: _tabController,
                labels: const <String>['Characters', 'Locations'],
                horizontalPadding: 8,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                labelFontSize: 14,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0x99FFFFFF),
                indicatorColor: Colors.white,
                expanded: true,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  key: const ValueKey<String>('location-chat-mention-tab-view'),
                  controller: _tabController,
                  children: [
                    _LocationChatMentionList(
                      key: const PageStorageKey<String>(
                        'location-chat-character-mentions',
                      ),
                      entries: widget.catalog.characters,
                      emptyLabel: 'No characters',
                    ),
                    _LocationChatMentionList(
                      key: const PageStorageKey<String>(
                        'location-chat-location-mentions',
                      ),
                      entries: widget.catalog.locations,
                      emptyLabel: 'No locations',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationChatMentionList extends StatelessWidget {
  const _LocationChatMentionList({
    super.key,
    required this.entries,
    required this.emptyLabel,
  });

  final List<ChatMentionEntry> entries;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: entries.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 52, color: Color(0x1FFFFFFF)),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          key: ValueKey<String>(
            'location-chat-mention-${entry.type.name}-${entry.id}',
          ),
          onTap: () => Navigator.of(context).pop(entry),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _LocationChatMentionThumbnail(entry: entry),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocationChatMentionThumbnail extends StatelessWidget {
  const _LocationChatMentionThumbnail({required this.entry});

  final ChatMentionEntry entry;

  @override
  Widget build(BuildContext context) {
    final sourceUrl = entry.imageUrl.trim();
    final cdnLogicalWidth = entry.type == ChatMentionType.character
        ? worldCharacterAvatarLogicalSize
        : worldLocationCoverLogicalSize;
    final resizedUrl = resizeGenesisImageUrl(
      sourceUrl,
      logicalWidth: cdnLogicalWidth,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final imageUrl = resizedUrl.isNotEmpty ? resizedUrl : sourceUrl;
    if (entry.type == ChatMentionType.character) {
      return GenesisCharacterAvatar(
        url: imageUrl,
        name: entry.name,
        size: _locationChatAvatarLogicalSize,
        borderRadius: 8,
      );
    }
    return GenesisListImage(
      imageUrl: imageUrl,
      width: _locationChatAvatarLogicalSize,
      height: _locationChatAvatarLogicalSize,
      borderRadius: BorderRadius.circular(8),
    );
  }
}
