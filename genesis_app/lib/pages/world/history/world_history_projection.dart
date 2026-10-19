import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/models/world.dart';
import '../../../network/models/world_history.dart';
import '../../../network/json_utils.dart';
import '../../../utils/genesis_ugc_text.dart';

/// Metadata has a separate lifetime from archive bodies. World clock, loading
/// and Tick count changes reuse these maps without walking characters per row.
class HistoryMetadata {
  Object? _inputs;
  List<Object?> _values = const [];
  int revision = 0;
  int buildCount = 0;
  Map<String, ChatMentionEntry> characters = {};
  Map<String, ChatMentionEntry> locations = {};
  Map<String, List<String>> paths = {};
  ChatMentionCatalog catalog = ChatMentionCatalog.empty;

  void update(WorldDetail world, String currentUid) {
    final inputs = (
      world.characters,
      world.characterPositions,
      world.locations,
      world.processedLocationTree,
      currentUid,
    );
    if (_inputs == inputs) return;
    _inputs = inputs;
    final chars = <String, ChatMentionEntry>{};
    String field(Map row, List<String> keys) {
      for (final key in keys) {
        final value = row[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
      return '';
    }

    for (final row in [...world.characters, ...world.characterPositions]) {
      final character = row['character'] is Map ? row['character'] as Map : row;
      final id = field(character, ['char_id', 'character_id', 'id']);
      if (id.isEmpty || chars.containsKey(id)) continue;
      final uid = field(character, ['player_uid', 'user_id', 'uid']);
      final rawName = field(character, [
        'name',
        'role_nickname',
        'role_name',
        'character_name',
      ]);
      chars[id] = ChatMentionEntry(
        id: id,
        name: normalizeGenesisUgcTextForDisplay(rawName.isEmpty ? id : rawName),
        type: ChatMentionType.character,
        imageUrl: asImageUrl(character['avatar'] ?? character['avatar_url']),
        isPlayerControlled: uid.isNotEmpty,
      );
    }
    final locs = <String, ChatMentionEntry>{};
    final nextPaths = <String, List<String>>{};
    final tree = world.processedLocationTree;
    for (final row in [
      ...world.locations,
      ...tree.flattened.map((n) => {...n.value, 'location_id': n.id}),
    ]) {
      final id = field(row, ['location_id', 'id']);
      if (id.isEmpty) continue;
      final rawName = field(row, ['location_name', 'name']);
      var node = tree.nodeById(id);
      final path = <String>[];
      final visited = <String>{};
      while (node != null && visited.add(node.id)) {
        final name = field(node.value, ['location_name', 'name']);
        if (name.isNotEmpty) {
          path.insert(0, normalizeGenesisUgcTextForDisplay(name));
        }
        node = tree.nodeById(node.parentId);
      }
      nextPaths[id] = path.isNotEmpty
          ? path
          : [rawName.isEmpty ? id : normalizeGenesisUgcTextForDisplay(rawName)];
      locs[id] = ChatMentionEntry(
        id: id,
        name: nextPaths[id]!.last,
        type: ChatMentionType.location,
        subtitle: nextPaths[id]!.take(nextPaths[id]!.length - 1).join(' > '),
        imageUrl: asImageUrl(
          row['image'] ?? row['image_url'] ?? row['background'] ?? row['icon'],
        ),
      );
    }
    final values = <Object?>[
      currentUid,
      for (final e in chars.values)
        (e.id, e.name, e.imageUrl, e.isPlayerControlled),
      for (final e in locs.values) (e.id, e.name, e.subtitle, e.imageUrl),
    ];
    if (listEquals(values, _values)) return;
    _values = values;
    characters = chars;
    locations = locs;
    paths = nextPaths;
    catalog = ChatMentionCatalog(
      characters: chars.values,
      locations: locs.values,
    );
    revision++;
    buildCount++;
  }
}

class HistoryDisplayRow {
  HistoryDisplayRow(this.message, this.locationId);
  final WorldHistoryMessage message;
  final String locationId;
  // Length-prefixed IDs avoid collisions without converting numeric strings.
  String get id =>
      'world-history:${message.id.length}:${message.id}:$locationId';
}

class WorldHistoryProjection {
  WorldHistoryProjection({this.cacheLimit = 300});
  final int cacheLimit;
  final metadata = HistoryMetadata();
  final _cache = <String, (WorldHistoryMessage, int, String, ChatMessageVm)>{};
  // Reuse VMs still owned by the shared viewport without retaining their
  // bodies beyond the LRU budget ourselves.
  final _rendered =
      <
        String,
        (WorldHistoryMessage, int, String, WeakReference<ChatMessageVm>)
      >{};
  final Set<String> _pinned = {};
  List<HistoryDisplayRow> rows = const [];
  Map<String, HistoryDisplayRow> byId = const {};
  int _dataRevision = -1, _metadataRevision = -1, _appVersion = -1;
  String _uid = '';
  List<ChatMessageVm> _messages = const [];
  int get cacheSize => _cache.length;
  int parsedMessageCount = 0;

  List<ChatMessageVm> project({
    required Iterable<WorldHistoryMessage> newestFirst,
    required int dataRevision,
    required WorldDetail world,
    required String uid,
    required int appVersion,
  }) {
    metadata.update(world, uid);
    if (_dataRevision == dataRevision &&
        _metadataRevision == metadata.revision &&
        _appVersion == appVersion &&
        _uid == uid) {
      return _messages;
    }
    _dataRevision = dataRevision;
    _metadataRevision = metadata.revision;
    _appVersion = appVersion;
    _uid = uid;
    // Reverse messages only. Each message's location_refs keep server order.
    final unique = <String, WorldHistoryMessage>{};
    for (final row in newestFirst) {
      unique.putIfAbsent(row.id, () => row);
    }
    rows = [
      for (final row in unique.values.toList().reversed)
        if (row.minAppVersion <= appVersion || row.minAppVersion == 0)
          for (final location
              in row.locationRefs.isEmpty ? [''] : row.locationRefs.toSet())
            HistoryDisplayRow(row, location),
    ];
    byId = {for (final row in rows) row.id: row};
    _cache.removeWhere((id, _) => !byId.containsKey(id));
    _rendered.removeWhere((id, _) => !byId.containsKey(id));
    _pinned.removeWhere((id) => !byId.containsKey(id));
    _messages = _HistoryVmList(this);
    return _messages;
  }

  void pin(Iterable<String> ids) {
    _pinned
      ..clear()
      ..addAll(ids);
    _trim();
  }

  void _trim() {
    while (_cache.length > cacheLimit) {
      final victim = _cache.keys.where((k) => !_pinned.contains(k)).firstOrNull;
      if (victim == null) break;
      _cache.remove(victim);
    }
  }

  void clear() {
    _cache.clear();
    _rendered.clear();
    _pinned.clear();
    rows = const [];
    byId = const {};
    _messages = const [];
    _dataRevision = -1;
  }

  ChatMessageVm messageFor(HistoryDisplayRow display) {
    final row = display.message;
    final retained = _rendered[display.id];
    final existing = retained?.$4.target;
    final cached =
        _cache.remove(display.id) ??
        (retained != null && existing != null
            ? (retained.$1, retained.$2, retained.$3, existing)
            : null);
    final current = identical(byId[display.id]?.message, row);
    if (cached != null &&
        identical(cached.$1, row) &&
        cached.$2 == metadata.revision &&
        cached.$3 == _uid) {
      if (current) {
        _cache[display.id] = cached;
        _trim();
      }
      return cached.$4;
    }
    parsedMessageCount++;
    final character = metadata.characters[row.senderId];
    final tick = row.tick;
    final mine = row.type == 'user' && _uid.isNotEmpty && row.userId == _uid;
    final vm = ChatMessageVm(
      localId: display.id,
      // Existing shared-renderer sentinel means an unnumbered Tick. This is
      // presentation only; the history DTO never invents a protocol Tick ID.
      tickNo: row.type == 'tick' ? -1 : 0,
      senderId: row.senderId,
      senderName:
          character?.name ?? normalizeGenesisUgcTextForDisplay(row.senderName),
      avatarUrl: character?.imageUrl ?? '',
      isPlayerControlledRole: mine || (character?.isPlayerControlled ?? false),
      text: row.content,
      currentTime: tick?.currentTime ?? row.currentTime,
      isMe: mine,
      status: 'sent',
      senderType: row.type,
      messageType: row.messageType,
      createdAt: row.createdAt,
      imageUrl: row.messageType == 'image' ? row.content.trim() : '',
      timelinePayload: row.type != 'tick'
          ? null
          : tick == null
          ? ChatTickPayloadVm(fallbackContent: row.content)
          : _tick(tick, display.locationId),
    );
    if (current) {
      _cache[display.id] = (row, metadata.revision, _uid, vm);
      _rendered[display.id] = (row, metadata.revision, _uid, WeakReference(vm));
      _trim();
    }
    return vm;
  }

  ChatTickStatusVm _status(
    HistoryStatus status, {
    Map<String, String> cast = const {},
  }) {
    final character = metadata.characters[status.owner];
    return ChatTickStatusVm(
      owner: status.owner,
      icon: status.icon,
      form: status.form,
      content: status.content,
      name: cast[status.owner] ?? character?.name ?? status.owner,
      avatarUrl: character?.imageUrl ?? '',
    );
  }

  ChatTickPayloadVm _tick(WorldHistoryTick tick, String locationId) =>
      ChatTickPayloadVm(
        globalText: tick.global,
        globalStatuses: tick.globalStatus.map(_status).toList(growable: false),
        storyEvents: ChatStoryEventsPayloadVm(
          locationId: locationId,
          locationName: metadata.locations[locationId]?.name ?? locationId,
          paragraphs: [
            for (var i = 0; i < tick.events.length; i++)
              if (tick.events[i].locationId == locationId)
                _event(tick.events[i], i),
          ],
        ),
        charactersMoved: ChatCharactersMovedPayloadVm(
          movements: [
            for (final move in tick.movements)
              if (locationId.isNotEmpty &&
                  (move.oldLocationId == locationId ||
                      move.toLocationId == locationId))
                ChatCharacterMovementVm(
                  characterId: move.characterId,
                  characterName:
                      metadata.characters[move.characterId]?.name ??
                      move.characterId,
                  oldLocationId: move.oldLocationId,
                  toLocationId: move.toLocationId,
                  toLocationName:
                      metadata.locations[move.toLocationId]?.name ??
                      move.toLocationId,
                  isDestinationCurrentLocation: move.toLocationId == locationId,
                ),
          ],
        ),
      );
  ChatStoryEventParagraphVm _event(HistoryStoryEvent event, int sourceIndex) {
    final cast = {for (final role in event.cast) role.id: role.name};
    return ChatStoryEventParagraphVm(
      timestamp: event.timestamp,
      text: event.text,
      clue: event.clue,
      visibilityLabel: event.visibility,
      visibleRoles: [
        for (final id in event.visibleTo)
          ChatStoryEventVisibleRoleVm(
            roleId: id,
            name: cast[id] ?? metadata.characters[id]?.name ?? id,
            isAi: !(metadata.characters[id]?.isPlayerControlled ?? false),
            avatarUrl: metadata.characters[id]?.imageUrl ?? '',
          ),
      ],
      locationId: event.locationId,
      locationName:
          metadata.locations[event.locationId]?.name ?? event.locationId,
      statuses: event.statuses
          .map((s) => _status(s, cast: cast))
          .toList(growable: false),
      sourceIndex: sourceIndex,
    );
  }
}

/// The projection keeps descriptors, not another unbounded collection of VMs.
/// Shared chat owns its current render window; this adapter bounds reuse to LRU.
class _HistoryVmList extends ListBase<ChatMessageVm> {
  _HistoryVmList(this.projection) : _rows = projection.rows;
  final WorldHistoryProjection projection;
  final List<HistoryDisplayRow> _rows;
  @override
  int get length => _rows.length;
  @override
  set length(int value) => throw UnsupportedError('Immutable history');
  @override
  ChatMessageVm operator [](int index) => projection.messageFor(_rows[index]);
  @override
  void operator []=(int index, ChatMessageVm value) =>
      throw UnsupportedError('Immutable history');
}
