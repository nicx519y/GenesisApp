part of 'genesis_api.dart';

class CreateOriginResult {
  const CreateOriginResult({required this.worldviewId, required this.oid});

  final String worldviewId;
  final String oid;
}

class WorldProgressResult {
  const WorldProgressResult({required this.message, required this.tickCount});

  final String message;
  final int tickCount;
}

class MyWorldSummary {
  const MyWorldSummary({
    required this.wid,
    required this.name,
    this.definitionVersion = 0,
    this.defaultMapLocationId = '',
    this.deleted = false,
    required this.snapshotCoverUrl,
    required this.updatedAtText,
    required this.ownerName,
    required this.progressCount,
    this.subTickNo = 0,
    required this.interactCount,
    required this.characterCount,
    required this.playerCount,
  });

  final String wid;
  final String name;
  final int definitionVersion;
  final String defaultMapLocationId;
  final bool deleted;
  final String snapshotCoverUrl;
  final String updatedAtText;
  final String ownerName;
  final int progressCount;
  final int subTickNo;
  final int interactCount;
  final int characterCount;
  final int playerCount;
}

class WorldSummaryLatestItem {
  const WorldSummaryLatestItem({
    required this.worldId,
    required this.originId,
    this.deleted = false,
    required this.tickNo,
    this.subTickNo = 0,
    required this.summary,
    required this.tickTime,
    required this.createdAt,
  });

  final String worldId;
  final String originId;
  final bool deleted;
  final int tickNo;
  final int subTickNo;
  final String summary;
  final int tickTime;
  final int createdAt;
}

class SearchResultBundle {
  const SearchResultBundle({
    required this.origins,
    required this.worlds,
    required this.users,
  });

  final List<OriginSummary> origins;
  final List<MyWorldSummary> worlds;
  final List<SearchUserSummary> users;
}

class SearchUserSummary {
  const SearchUserSummary({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.userCode,
    this.deleted = false,
  });

  final String uid;
  final String displayName;
  final String avatarUrl;
  final String userCode;
  final bool deleted;
}
