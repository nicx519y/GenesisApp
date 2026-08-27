part of 'search_page.dart';

class _SearchTabResults {
  _SearchTabResults();

  final List<_SearchResultItem> items = <_SearchResultItem>[];
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
    total = 0;
    nextPage = 1;
    hasMore = true;
    hasRequested = false;
    isInitialLoading = false;
    isLoadingMore = false;
    requestToken = 0;
    error = null;
  }
}

class _SearchPageResult {
  const _SearchPageResult({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.tabTotals,
  });

  final List<_SearchResultItem> items;
  final int total;
  final bool hasMore;
  final Map<_SearchTab, int> tabTotals;
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
    this.originV2,
    this.worldV2,
    this.userV2,
    this.deleted = false,
  });

  factory _SearchResultItem.fromV2Origin(SearchV2OriginItem origin) {
    final originator = formatUidForDisplay(origin.owner.name, fallback: '-');
    return _SearchResultItem(
      tab: _SearchTab.origin,
      entityId: origin.originId,
      shortCode: origin.originId,
      title: origin.originName,
      subtitle:
          'OID: ${_dashOrValue(origin.originId)}  '
          'Originator: $originator\n'
          'Brief: ${_dashOrValue(origin.brief)}\n'
          'Latest Version: ${_originVersionLabel(origin.originVersion)}',
      coverImage: asImageUrl(origin.cover),
      copyCount: origin.stats.copyCount,
      connectCount: origin.stats.connectCount,
      tickCount: origin.stats.maxTickCount,
      characterCount: origin.stats.characterCount,
      playerCount: 0,
      memberCount: origin.stats.locationCount,
      originV2: origin,
      deleted: false,
    );
  }

  factory _SearchResultItem.fromV2World(SearchV2WorldItem world) {
    final owner = formatUidForDisplay(world.owner.name, fallback: '-');
    return _SearchResultItem(
      tab: _SearchTab.world,
      entityId: world.worldId,
      shortCode: world.worldId,
      title: world.worldName,
      subtitle: 'WID: ${_dashOrValue(world.worldId)}  Owner: $owner',
      coverImage: asImageUrl(world.cover),
      copyCount: 0,
      connectCount: 0,
      tickCount: 0,
      characterCount: 0,
      playerCount: 0,
      memberCount: 0,
      worldV2: world,
      deleted: false,
    );
  }

  factory _SearchResultItem.fromV2User(SearchV2UserItem user) {
    final title = formatUidForDisplay(
      user.name,
      fallback: formatUidForDisplay(user.uid),
    );
    return _SearchResultItem(
      tab: _SearchTab.user,
      entityId: user.uid,
      shortCode: user.uid,
      title: title,
      subtitle: '',
      coverImage: asImageUrl(user.avatar),
      copyCount: 0,
      connectCount: 0,
      tickCount: 0,
      characterCount: 0,
      playerCount: 0,
      memberCount: 0,
      userV2: user,
      deleted: false,
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
  final SearchV2OriginItem? originV2;
  final SearchV2WorldItem? worldV2;
  final SearchV2UserItem? userV2;
  final bool deleted;

  String get displayTitle {
    final trimmed = title.trim();
    if (tab == _SearchTab.origin && trimmed.isNotEmpty) {
      return originDisplayName(trimmed);
    }
    if (trimmed.isNotEmpty) return trimmed;
    return shortCode.trim().isNotEmpty ? shortCode : entityId;
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

String _dashOrValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _originVersionLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '0') return '-';
  final numeric = int.tryParse(trimmed);
  if (numeric != null) return numeric > 0 ? 'V$numeric' : '-';
  final prefixed = RegExp(r'^[vV]\s*(\d+)$').firstMatch(trimmed);
  if (prefixed != null) return 'V${prefixed.group(1)}';
  return trimmed;
}
