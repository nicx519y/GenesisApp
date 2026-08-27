import 'package:flutter/foundation.dart';

import '../../utils/genesis_image_resource.dart';
import '../json_utils.dart';

/// The `data` object in a successful `/api/v2/search` envelope.
@immutable
class SearchV2Response {
  const SearchV2Response({
    required this.keyword,
    required this.type,
    required this.origins,
    required this.worlds,
    required this.users,
  });

  factory SearchV2Response.fromJson(Map<String, dynamic> json) {
    return SearchV2Response(
      keyword: _rawString(json['keyword']),
      type: _rawString(json['type']),
      origins: SearchV2OriginResult.fromJson(asJsonMap(json['origins'])),
      worlds: SearchV2WorldResult.fromJson(asJsonMap(json['worlds'])),
      users: SearchV2UserResult.fromJson(asJsonMap(json['users'])),
    );
  }

  final String keyword;
  final String type;
  final SearchV2OriginResult origins;
  final SearchV2WorldResult worlds;
  final SearchV2UserResult users;
}

@immutable
class SearchV2OriginResult {
  const SearchV2OriginResult({
    required this.items,
    required this.total,
    required this.pageNumber,
    required this.pageSize,
  });

  factory SearchV2OriginResult.fromJson(Map<String, dynamic> json) {
    return SearchV2OriginResult(
      items: _mapList(json['list'], SearchV2OriginItem.fromJson),
      total: asInt(json['total']),
      pageNumber: asInt(json['pn']),
      pageSize: asInt(json['rn']),
    );
  }

  final List<SearchV2OriginItem> items;
  final int total;
  final int pageNumber;
  final int pageSize;

  bool get hasMore => items.isNotEmpty && pageNumber * pageSize < total;
}

@immutable
class SearchV2WorldResult {
  const SearchV2WorldResult({
    required this.items,
    required this.total,
    required this.pageNumber,
    required this.pageSize,
  });

  factory SearchV2WorldResult.fromJson(Map<String, dynamic> json) {
    return SearchV2WorldResult(
      items: _mapList(json['list'], SearchV2WorldItem.fromJson),
      total: asInt(json['total']),
      pageNumber: asInt(json['pn']),
      pageSize: asInt(json['rn']),
    );
  }

  final List<SearchV2WorldItem> items;
  final int total;
  final int pageNumber;
  final int pageSize;

  bool get hasMore => items.isNotEmpty && pageNumber * pageSize < total;
}

@immutable
class SearchV2UserResult {
  const SearchV2UserResult({
    required this.items,
    required this.total,
    required this.pageNumber,
    required this.pageSize,
  });

  factory SearchV2UserResult.fromJson(Map<String, dynamic> json) {
    return SearchV2UserResult(
      items: _mapList(json['list'], SearchV2UserItem.fromJson),
      total: asInt(json['total']),
      pageNumber: asInt(json['pn']),
      pageSize: asInt(json['rn']),
    );
  }

  final List<SearchV2UserItem> items;
  final int total;
  final int pageNumber;
  final int pageSize;

  bool get hasMore => items.isNotEmpty && pageNumber * pageSize < total;
}

@immutable
class SearchV2OriginItem {
  const SearchV2OriginItem({
    required this.originId,
    required this.originName,
    required this.originVersion,
    required this.brief,
    required this.language,
    required this.cover,
    required this.tags,
    required this.characters,
    required this.owner,
    required this.stats,
    required this.matches,
    required this.matchesTruncated,
  });

  factory SearchV2OriginItem.fromJson(Map<String, dynamic> json) {
    return SearchV2OriginItem(
      originId: _rawString(json['origin_id']),
      originName: _rawString(json['origin_name']),
      originVersion: _rawString(json['origin_version']),
      brief: _rawString(json['brief']),
      language: _rawString(json['language']),
      cover: GenesisImageResource.fromJson(json['cover']),
      tags: _stringList(json['tags']),
      characters: _mapList(
        json['characters'],
        SearchV2OriginCharacter.fromJson,
      ),
      owner: SearchV2Owner.fromJson(asJsonMap(json['owner'])),
      stats: SearchV2OriginStats.fromJson(asJsonMap(json['stats'])),
      matches: _mapList(json['matches'], SearchV2Match.fromJson),
      matchesTruncated: asBool(json['matches_truncated']),
    );
  }

  final String originId;
  final String originName;
  final String originVersion;
  final String brief;
  final String language;
  final GenesisImageResource cover;
  final List<String> tags;
  final List<SearchV2OriginCharacter> characters;
  final SearchV2Owner owner;
  final SearchV2OriginStats stats;
  final List<SearchV2Match> matches;
  final bool matchesTruncated;
}

@immutable
class SearchV2WorldItem {
  const SearchV2WorldItem({
    required this.worldId,
    required this.worldName,
    required this.originId,
    required this.language,
    required this.cover,
    required this.owner,
    required this.createdAt,
    required this.matches,
  });

  factory SearchV2WorldItem.fromJson(Map<String, dynamic> json) {
    return SearchV2WorldItem(
      worldId: _rawString(json['world_id']),
      worldName: _rawString(json['world_name']),
      originId: _rawString(json['origin_id']),
      language: _rawString(json['language']),
      cover: GenesisImageResource.fromJson(json['cover']),
      owner: SearchV2Owner.fromJson(asJsonMap(json['owner'])),
      createdAt: asInt(json['created_at']),
      matches: _mapList(json['matches'], SearchV2WorldNameMatch.fromJson),
    );
  }

  final String worldId;
  final String worldName;
  final String originId;
  final String language;
  final GenesisImageResource cover;
  final SearchV2Owner owner;
  final int createdAt;
  final List<SearchV2WorldNameMatch> matches;
}

@immutable
class SearchV2UserItem {
  const SearchV2UserItem({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.matches,
  });

  factory SearchV2UserItem.fromJson(Map<String, dynamic> json) {
    return SearchV2UserItem(
      uid: _rawString(json['uid']),
      name: _rawString(json['name']),
      avatar: GenesisImageResource.fromJson(json['avatar']),
      matches: _mapList(json['matches'], SearchV2UserNameMatch.fromJson),
    );
  }

  final String uid;
  final String name;
  final GenesisImageResource avatar;
  final List<SearchV2UserNameMatch> matches;
}

@immutable
class SearchV2Owner {
  const SearchV2Owner({
    required this.uid,
    required this.name,
    required this.avatar,
  });

  factory SearchV2Owner.fromJson(Map<String, dynamic> json) {
    return SearchV2Owner(
      uid: _rawString(json['uid']),
      name: _rawString(json['name']),
      avatar: GenesisImageResource.fromJson(json['avatar']),
    );
  }

  final String uid;
  final String name;
  final GenesisImageResource avatar;
}

@immutable
class SearchV2OriginStats {
  const SearchV2OriginStats({
    required this.copyCount,
    required this.discussCount,
    required this.characterCount,
    required this.connectCount,
    required this.locationCount,
    required this.maxTickCount,
  });

  factory SearchV2OriginStats.fromJson(Map<String, dynamic> json) {
    return SearchV2OriginStats(
      copyCount: asInt(json['copy_cnt']),
      discussCount: asInt(json['discuss_cnt']),
      characterCount: asInt(json['character_cnt']),
      connectCount: asInt(json['connect_cnt']),
      locationCount: asInt(json['location_cnt']),
      maxTickCount: asInt(json['max_tick_cnt']),
    );
  }

  final int copyCount;
  final int discussCount;
  final int characterCount;
  final int connectCount;
  final int locationCount;
  final int maxTickCount;
}

@immutable
class SearchV2OriginCharacter {
  const SearchV2OriginCharacter({
    required this.characterId,
    required this.name,
  });

  factory SearchV2OriginCharacter.fromJson(Map<String, dynamic> json) {
    return SearchV2OriginCharacter(
      characterId: _rawString(json['character_id']),
      name: _rawString(json['name']),
    );
  }

  final String characterId;
  final String name;
}

/// The `oneOf` match model used only by Origin search items.
@immutable
sealed class SearchV2Match {
  const SearchV2Match({required this.field, required this.highlightRanges});

  factory SearchV2Match.fromJson(Map<String, dynamic> json) {
    if (_rawString(json['field']) == 'character_name') {
      return SearchV2CharacterMatch.fromJson(json);
    }
    return SearchV2TextMatch.fromJson(json);
  }

  final String field;
  final List<SearchV2HighlightRange> highlightRanges;
}

/// Origin name or brief match. It never contains `character_id`.
@immutable
final class SearchV2TextMatch extends SearchV2Match {
  const SearchV2TextMatch({
    required super.field,
    required super.highlightRanges,
  });

  factory SearchV2TextMatch.fromJson(Map<String, dynamic> json) {
    return SearchV2TextMatch(
      field: _rawString(json['field']),
      highlightRanges: _mapList(
        json['highlight_ranges'],
        SearchV2HighlightRange.fromJson,
      ),
    );
  }
}

/// Origin character-name match. This is the only match with `character_id`.
@immutable
final class SearchV2CharacterMatch extends SearchV2Match {
  const SearchV2CharacterMatch({
    required super.field,
    required this.characterId,
    required super.highlightRanges,
  });

  factory SearchV2CharacterMatch.fromJson(Map<String, dynamic> json) {
    return SearchV2CharacterMatch(
      field: _rawString(json['field']),
      characterId: _rawString(json['character_id']),
      highlightRanges: _mapList(
        json['highlight_ranges'],
        SearchV2HighlightRange.fromJson,
      ),
    );
  }

  final String characterId;
}

@immutable
class SearchV2WorldNameMatch {
  const SearchV2WorldNameMatch({
    required this.field,
    required this.highlightRanges,
  });

  factory SearchV2WorldNameMatch.fromJson(Map<String, dynamic> json) {
    return SearchV2WorldNameMatch(
      field: _rawString(json['field']),
      highlightRanges: _mapList(
        json['highlight_ranges'],
        SearchV2HighlightRange.fromJson,
      ),
    );
  }

  final String field;
  final List<SearchV2HighlightRange> highlightRanges;
}

@immutable
class SearchV2UserNameMatch {
  const SearchV2UserNameMatch({
    required this.field,
    required this.highlightRanges,
  });

  factory SearchV2UserNameMatch.fromJson(Map<String, dynamic> json) {
    return SearchV2UserNameMatch(
      field: _rawString(json['field']),
      highlightRanges: _mapList(
        json['highlight_ranges'],
        SearchV2HighlightRange.fromJson,
      ),
    );
  }

  final String field;
  final List<SearchV2HighlightRange> highlightRanges;
}

@immutable
class SearchV2HighlightRange {
  const SearchV2HighlightRange({required this.start, required this.length});

  factory SearchV2HighlightRange.fromJson(Map<String, dynamic> json) {
    return SearchV2HighlightRange(
      start: asInt(json['start']),
      length: asInt(json['length']),
    );
  }

  final int start;
  final int length;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map(_rawString).toList(growable: false);
}

String _rawString(Object? value) => value?.toString() ?? '';

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return <T>[];
  return value.map((item) => fromJson(asJsonMap(item))).toList(growable: false);
}
