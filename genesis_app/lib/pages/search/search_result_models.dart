part of 'search_page.dart';

class _SearchTabResults {
  _SearchTabResults(this.tab);

  final _SearchTab tab;
  final List<_SearchResultItem> items = <_SearchResultItem>[];
  final Map<_SearchTab, int> sectionTotals = <_SearchTab, int>{};
  int total = 0;
  int nextPage = 1;
  bool hasMore = true;
  bool hasRequested = false;
  bool isInitialLoading = false;
  bool isLoadingMore = false;
  int requestToken = 0;
  Object? error;

  void reset() {
    items.clear();
    sectionTotals.clear();
    total = 0;
    nextPage = 1;
    hasMore = true;
    hasRequested = false;
    isInitialLoading = false;
    isLoadingMore = false;
    requestToken = 0;
    error = null;
  }

  int sectionTotalFor(_SearchTab section) {
    return sectionTotals[section] ??
        items.where((item) => item.tab == section).length;
  }

  void replaceSectionTotals(Map<_SearchTab, int> totals) {
    sectionTotals
      ..clear()
      ..addAll(totals);
  }
}

class _SearchPageResult {
  const _SearchPageResult({
    required this.items,
    required this.total,
    required this.sectionTotals,
    required this.hasMore,
  });

  final List<_SearchResultItem> items;
  final int total;
  final Map<_SearchTab, int> sectionTotals;
  final bool hasMore;
}

class _SearchResultItem {
  const _SearchResultItem({
    required this.tab,
    required this.entityId,
    required this.shortCode,
    required this.title,
    required this.subtitle,
    required this.coverImage,
    required this.copyCount,
    required this.connectCount,
    required this.tickCount,
    required this.characterCount,
    required this.playerCount,
    required this.memberCount,
    this.creator = '',
    this.brief = '',
    this.tickNo = 0,
    this.subTickNo = 0,
    this.characterName = '',
    this.deleted = false,
  });

  factory _SearchResultItem.fromJson(
    Map<String, dynamic> json, {
    required _SearchTab fallbackTab,
  }) {
    final type = asString(json['type']);
    final tab = switch (type) {
      'origin' => _SearchTab.origin,
      'world' => _SearchTab.world,
      'user' => _SearchTab.user,
      _ => fallbackTab,
    };
    final title = asString(json['title']);
    final shortCode = asString(json['short_code']);
    final entityId = asString(json['entity_id'], fallback: shortCode);
    return _SearchResultItem(
      tab: tab,
      entityId: entityId,
      shortCode: shortCode,
      title: title,
      subtitle: switch (tab) {
        _SearchTab.origin => _originSearchSubtitle(json, fallbackId: entityId),
        _SearchTab.world => _worldSearchSubtitle(json, fallbackId: entityId),
        _ => asString(json['subtitle']),
      },
      coverImage: asImageUrl(json['cover_image']),
      copyCount: asInt(json['copy_cnt']),
      connectCount: asInt(json['connect_cnt']),
      tickCount: asInt(json['tick_cnt']),
      characterCount: asInt(json['character_cnt']),
      playerCount: asInt(json['player_cnt']),
      memberCount: asInt(json['member_cnt'], fallback: asInt(json['user_cnt'])),
      creator: _searchCreatorName(json),
      brief: _searchBrief(json, fallback: asString(json['subtitle'])),
      deleted: switch (tab) {
        _SearchTab.origin => entityDeleted(
          json['deleted'],
          fallback: json['origin_deleted'],
        ),
        _SearchTab.world => entityDeleted(
          json['world_deleted'],
          fallback: json['deleted'],
        ),
        _SearchTab.user => entityDeleted(json['deleted']),
        _SearchTab.all => entityDeleted(json['deleted']),
      },
    );
  }

  factory _SearchResultItem.fromContractJson(
    Map<String, dynamic> json, {
    required _SearchTab fallbackTab,
  }) {
    final user = json['user'] is Map ? asJsonMap(json['user']) : null;
    if (fallbackTab == _SearchTab.user || user != null) {
      final raw = user ?? json;
      final uid = asString(raw['uid']);
      final title = formatUidForDisplay(
        asString(raw['name']),
        fallback: formatUidForDisplay(uid),
      );
      return _SearchResultItem(
        tab: _SearchTab.user,
        entityId: uid,
        shortCode: uid,
        title: title,
        subtitle: asString(raw['bio']),
        coverImage: asImageUrl(raw['avatar']),
        copyCount: 0,
        connectCount: 0,
        tickCount: 0,
        characterCount: 0,
        playerCount: 0,
        memberCount: 0,
        deleted: entityDeleted(raw['deleted']),
      );
    }

    final info = json['info'] is Map
        ? asJsonMap(json['info'])
        : const <String, dynamic>{};
    final stats = json['stats'] is Map
        ? asJsonMap(json['stats'])
        : const <String, dynamic>{};
    if (fallbackTab == _SearchTab.world ||
        info.containsKey('world_id') ||
        info.containsKey('wid')) {
      final lastTick = json['last_tick'] is Map
          ? asJsonMap(json['last_tick'])
          : const <String, dynamic>{};
      final worldId = asString(
        info['world_id'],
        fallback: asString(info['wid']),
      );
      return _SearchResultItem(
        tab: _SearchTab.world,
        entityId: worldId,
        shortCode: worldId,
        title: asString(
          info['world_name'],
          fallback: asString(info['name'], fallback: worldId),
        ),
        subtitle: _worldSearchSubtitle(info, fallbackId: worldId),
        coverImage: asImageUrl(info['cover']),
        copyCount: 0,
        connectCount: asInt(stats['connect_cnt']),
        tickCount: asInt(stats['tick_cnt']),
        characterCount: asInt(stats['character_cnt']),
        playerCount: asInt(stats['player_cnt']),
        memberCount: asInt(stats['location_cnt']),
        creator: _searchCreatorName(info),
        brief: _searchBrief(info),
        tickNo: asInt(lastTick['tick_no']),
        subTickNo: asInt(lastTick['sub_tick_no']),
        characterName: _searchCharacterName(json['my_character']),
        deleted: entityDeleted(
          json['world_deleted'],
          fallback: entityDeleted(
            info['world_deleted'],
            fallback: info['deleted'],
          ),
        ),
      );
    }

    final originId = asString(
      info['origin_id'],
      fallback: asString(info['oid']),
    );
    return _SearchResultItem(
      tab: _SearchTab.origin,
      entityId: originId,
      shortCode: originId,
      title: asString(
        info['origin_name'],
        fallback: asString(info['name'], fallback: originId),
      ),
      subtitle: _originSearchSubtitle(info, fallbackId: originId),
      coverImage: asImageUrl(info['cover']),
      copyCount: asInt(stats['copy_cnt']),
      connectCount: asInt(stats['connect_cnt']),
      tickCount: asInt(stats['tick_cnt']),
      characterCount: asInt(stats['character_cnt']),
      playerCount: 0,
      memberCount: asInt(stats['location_cnt']),
      creator: _searchCreatorName(info),
      brief: _searchBrief(info),
      deleted: entityDeleted(info['deleted'], fallback: info['origin_deleted']),
    );
  }

  final _SearchTab tab;
  final String entityId;
  final String shortCode;
  final String title;
  final String subtitle;
  final String coverImage;
  final int copyCount;
  final int connectCount;
  final int tickCount;
  final int characterCount;
  final int playerCount;
  final int memberCount;

  /// Who made it, and the pitch, for the search row's body lines.
  final String creator;
  final String brief;

  /// World rows only: last completed tick and the viewer's bound character.
  final int tickNo;
  final int subTickNo;
  final String characterName;
  final bool deleted;

  String get displayTitle {
    final trimmed = title.trim();
    if (tab == _SearchTab.origin && trimmed.isNotEmpty) {
      return originDisplayName(trimmed);
    }
    if (trimmed.isNotEmpty) return trimmed;
    return shortCode.trim().isNotEmpty ? shortCode : entityId;
  }

  /// Creator handle for the search row. Blank when the payload carries no
  /// owner at all, so the row can drop the line instead of printing `@-`.
  String get displayCreator {
    final value = creator.trim();
    return value == '-' ? '' : value;
  }

  String get displayBrief => brief.trim();

  /// Same shape as the Home row: `Tick 2-3` / `Not started`.
  String get tickStateLabel {
    if (tickNo <= 0) return 'Not started';
    final sub = subTickNo > 0 ? '-$subTickNo' : '';
    return 'Tick $tickNo$sub';
  }

  /// Home's accent line: the tick state plus the viewer's character.
  String get statusLine {
    final name = characterName.trim();
    if (name.isEmpty) return tickStateLabel;
    return '$tickStateLabel · $name';
  }

  /// Only worlds carry a tick line, and only when the payload actually said
  /// something. Search cannot tell "not started" from "not queried", so a
  /// zero tick with no character stays off the row instead of claiming
  /// `Not started`.
  bool get showStatusLine {
    return tab == _SearchTab.world &&
        !deleted &&
        (tickNo > 0 || characterName.trim().isNotEmpty);
  }

  String get displaySubtitle {
    if (deleted &&
        (tab == _SearchTab.origin ||
            tab == _SearchTab.world ||
            tab == _SearchTab.user)) {
      return deletedEntityDisplayText;
    }
    if (tab == _SearchTab.user) {
      return shortCode.trim().isNotEmpty ? shortCode : entityId;
    }
    return subtitle.trim().isNotEmpty ? subtitle : shortCode;
  }
}

/// The viewer's bound character in a world row, when the payload has one.
String _searchCharacterName(Object? raw) {
  if (raw is! Map) return '';
  return _firstSearchString(asJsonMap(raw), const ['name', 'char_name']);
}

/// Owner / creator display name, shared by every search payload shape.
String _searchCreatorName(Map<dynamic, dynamic> raw) {
  return _searchOwnerDisplayName(
    raw,
    ownerKeys: const [
      'owner_name',
      'created_user_name',
      'originator',
      'owner_uid',
      'created_uid',
    ],
  );
}

/// The world/origin one-line pitch. `display_subtitle` is the curated copy and
/// `brief` the raw one; `setting` is the world mapper's own fallback.
String _searchBrief(Map<dynamic, dynamic> raw, {String fallback = ''}) {
  final brief = _firstSearchString(raw, const [
    'display_subtitle',
    'brief',
    'setting',
  ]);
  if (brief.isNotEmpty) return brief;
  final trimmed = fallback.trim();
  return _isBlankSearchValue(trimmed) ? '' : trimmed;
}

String _originSearchSubtitle(
  Map<dynamic, dynamic> raw, {
  required String fallbackId,
}) {
  final oid = _firstSearchString(raw, const ['oid', 'origin_id']);
  final displayOid = oid.trim().isEmpty ? _dashOrValue(fallbackId) : oid;
  final originator = _searchOwnerDisplayName(
    raw,
    ownerKeys: const [
      'owner_name',
      'created_user_name',
      'originator',
      'owner_uid',
      'created_uid',
    ],
  );
  final versionNum = _firstSearchInt(raw, const [
    'version_num',
    'origin_version',
    'origin_version_num',
    'latest_version',
    'latest_version_num',
    'latest_origin_version',
    'latest_origin_version_num',
    'latestVersion',
    'latestVersionNum',
    'latestOriginVersion',
    'latestOriginVersionNum',
    'version',
    'version_no',
    'versionNo',
  ]);
  final version = _originVersionLabel(raw, fallbackVersionNum: versionNum);
  return 'OID: $displayOid  Originator: $originator\n'
      'Latest Version: $version';
}

String _originVersionLabel(
  Map<dynamic, dynamic> raw, {
  required int fallbackVersionNum,
}) {
  if (fallbackVersionNum > 0) return 'V$fallbackVersionNum';
  final directValue = _firstSearchVersionLabel(raw, const [
    'version_num',
    'origin_version',
    'origin_version_num',
    'latest_version',
    'latest_version_num',
    'latest_origin_version',
    'latest_origin_version_num',
    'latestVersion',
    'latestVersionNum',
    'latestOriginVersion',
    'latestOriginVersionNum',
    'version',
    'version_no',
    'versionNo',
  ]);
  if (directValue.isNotEmpty) return directValue;

  for (final key in const [
    'latest_version',
    'latestVersion',
    'latest_origin_version',
    'latestOriginVersion',
    'origin_version_info',
    'originVersionInfo',
    'version_info',
    'versionInfo',
  ]) {
    final value = raw[key];
    if (value is Map) {
      final nestedLabel = _firstSearchVersionLabel(value, const [
        'version_num',
        'versionNum',
        'origin_version',
        'originVersion',
        'origin_version_num',
        'originVersionNum',
        'latest_version',
        'latestVersion',
        'num',
        'version',
        'version_no',
        'versionNo',
        'label',
        'name',
      ]);
      if (nestedLabel.isNotEmpty) return nestedLabel;
    }
  }

  return '-';
}

String _firstSearchVersionLabel(Map<dynamic, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final label = _searchVersionLabelFromValue(raw[key]);
    if (label.isNotEmpty) return label;
  }
  return '';
}

String _searchVersionLabelFromValue(Object? raw) {
  if (raw is Map || raw is List) return '';
  final value = asString(raw).trim();
  if (_isBlankSearchValue(value) || value == '0') return '';
  final numeric = int.tryParse(value);
  if (numeric != null) return numeric <= 0 ? '' : 'V$numeric';
  final prefixedVersion = RegExp(r'^[vV]\s*(\d+)$').firstMatch(value);
  if (prefixedVersion != null) return 'V${prefixedVersion.group(1)}';
  return value;
}

String _worldSearchSubtitle(
  Map<dynamic, dynamic> raw, {
  required String fallbackId,
}) {
  final wid = _firstSearchString(raw, const ['wid', 'world_id']);
  final displayWid = wid.trim().isEmpty ? _dashOrValue(fallbackId) : wid;
  final owner = _searchOwnerDisplayName(
    raw,
    ownerKeys: const [
      'owner_name',
      'created_user_name',
      'owner_uid',
      'created_uid',
    ],
  );
  return 'WID: $displayWid  Owner: $owner';
}

String _searchOwnerDisplayName(
  Map<dynamic, dynamic> raw, {
  required List<String> ownerKeys,
}) {
  final ownerUser = raw['owner_user'] is Map
      ? asJsonMap(raw['owner_user'])
      : const <String, dynamic>{};
  if (entityDeleted(ownerUser['deleted'])) return deletedEntityDisplayText;

  final owner = _firstSearchString(raw, ownerKeys);
  if (owner.isNotEmpty) return formatUidForDisplay(owner, fallback: '-');

  final ownerUserName = _firstSearchString(ownerUser, const [
    'name',
    'user_name',
    'username',
    'uid',
  ]);
  return formatUidForDisplay(ownerUserName, fallback: '-');
}

String _firstSearchString(Map<dynamic, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = asString(raw[key]).trim();
    if (!_isBlankSearchValue(value)) return value;
  }
  return '';
}

int _firstSearchInt(Map<dynamic, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = asInt(raw[key], fallback: -1);
    if (value > 0) return value;
  }
  return 0;
}

String _dashOrValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

bool _isBlankSearchValue(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == '-' ||
      normalized == '--' ||
      normalized == 'null' ||
      normalized == 'none' ||
      normalized == 'n/a';
}
