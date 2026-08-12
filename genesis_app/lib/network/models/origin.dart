import 'package:flutter/foundation.dart';

import '../json_utils.dart';
import 'location_tree.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/genesis_ugc_text.dart';

@immutable
class OriginListResponse {
  const OriginListResponse({
    required this.data,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<OriginSummary> data;
  final int total;
  final int limit;
  final int offset;

  factory OriginListResponse.fromJson(
    Map<String, dynamic> json, {
    int limitFallback = 20,
    int offsetFallback = 0,
  }) {
    final items = (json['data'] is List)
        ? asJsonList(json['data'])
              .map((e) => OriginSummary.fromJson(asJsonMap(e)))
              .toList(growable: false)
        : const <OriginSummary>[];

    return OriginListResponse(
      data: items,
      total: asInt(json['total']),
      limit: asInt(json['limit'], fallback: limitFallback),
      offset: asInt(json['offset'], fallback: offsetFallback),
    );
  }
}

@immutable
class OriginSummary {
  const OriginSummary({
    required this.id,
    required this.oid,
    required this.name,
    required this.description,
    required this.mapImage,
    required this.worldMap,
    required this.worldView,
    this.deleted = false,
    this.originator = '',
    this.versionNum = 0,
    required this.copyCount,
    required this.interactCount,
    this.characterCount = 0,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.characters,
    required this.locations,
  });

  final int id;
  final String oid;
  final String name;
  final String description;
  final String mapImage;
  final String worldMap;
  final String worldView;
  final bool deleted;
  final String originator;
  final int versionNum;
  final int copyCount;
  final int interactCount;
  final int characterCount;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OriginCharacter> characters;
  final List<OriginLocation> locations;

  factory OriginSummary.fromJson(Map<String, dynamic> json) {
    final mapImage = asImageUrl(json['map_image']);
    return OriginSummary(
      id: asInt(json['id']),
      oid: asString(json['oid']),
      name: decodeGenesisUgcTextForDisplay(asString(json['name'])),
      description: decodeGenesisUgcTextForDisplay(
        asString(json['description']),
      ),
      mapImage: mapImage,
      worldMap: asImageUrl(json['world_map'], fallback: mapImage),
      worldView: decodeGenesisUgcTextForDisplay(asString(json['world_view'])),
      deleted: entityDeleted(json['deleted'], fallback: json['origin_deleted']),
      originator: asString(
        json['owner_name'],
        fallback: asString(
          json['created_user_name'],
          fallback: asString(json['originator']),
        ),
      ),
      versionNum: asInt(json['version_num']),
      copyCount: asInt(json['copy_count']),
      interactCount: asInt(json['interact_count']),
      characterCount: asInt(json['character_count']),
      tags: _splitTags(asString(json['tags'])),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      characters: (json['characters'] is List)
          ? asJsonList(json['characters'])
                .map((e) => OriginCharacter.fromJson(asJsonMap(e)))
                .toList(growable: false)
          : const [],
      locations: (json['locations'] is List)
          ? asJsonList(json['locations'])
                .map((e) => OriginLocation.fromJson(asJsonMap(e)))
                .toList(growable: false)
          : const [],
    );
  }
}

@immutable
class OriginDetail {
  OriginDetail({
    required this.id,
    required this.oid,
    required this.name,
    required this.description,
    required this.mapImage,
    required this.worldMap,
    required this.worldView,
    this.deleted = false,
    this.ownerDeleted = false,
    this.ownerUid = '',
    this.originator = '',
    this.ownerUser = const OriginUserInfo(),
    this.originVersion = '',
    this.originVersionTime,
    this.versionNum = 0,
    this.definitionVersion = 1,
    this.language = '',
    this.currentTime = '',
    this.status = 0,
    this.startTime = '',
    this.showOpeningSheet = false,
    required this.copyCount,
    required this.interactCount,
    this.discussCount = 0,
    this.characterCount = 0,
    this.locationCount = 0,
    this.maxTickCount = 0,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.characters,
    required this.locations,
    List<OriginLocation>? allLocations,
    this.events = const <OriginEvent>[],
    this.ticks = const <Map<String, dynamic>>[],
    this.metric = const <String, dynamic>{},
    this.coverResource = const GenesisImageResource(),
    this.initLocationGroup,
    this.locationTree = const <LocationTreeNode<OriginLocation>>[],
    ProcessedLocationTree<OriginLocation>? processedLocationTree,
  }) : allLocations = allLocations ?? locations,
       processedLocationTree =
           processedLocationTree ??
           ProcessedLocationTree<OriginLocation>(locationTree);

  final int id;
  final String oid;
  final String name;
  final String description;
  final String mapImage;
  final String worldMap;
  final String worldView;
  final bool deleted;
  final bool ownerDeleted;
  final String ownerUid;
  final String originator;
  final OriginUserInfo ownerUser;
  final String originVersion;
  final DateTime? originVersionTime;
  final int versionNum;
  final int definitionVersion;
  final String language;
  final String currentTime;
  final int status;
  final String startTime;
  final bool showOpeningSheet;
  final int copyCount;
  final int interactCount;
  final int discussCount;
  final int characterCount;
  final int locationCount;
  final int maxTickCount;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OriginCharacter> characters;
  final List<OriginLocation> locations;
  final List<OriginLocation> allLocations;
  final List<OriginEvent> events;
  final List<Map<String, dynamic>> ticks;
  final Map<String, dynamic> metric;
  final GenesisImageResource coverResource;
  final OriginInitLocationGroup? initLocationGroup;
  final List<LocationTreeNode<OriginLocation>> locationTree;
  final ProcessedLocationTree<OriginLocation> processedLocationTree;

  int get connectCount => interactCount;

  factory OriginDetail.fromJson(Map<String, dynamic> json) {
    final info = json['info'] is Map ? asJsonMap(json['info']) : json;
    final stats = json['stats'] is Map ? asJsonMap(json['stats']) : json;
    final coverResource = GenesisImageResourceRegistry.register(
      GenesisImageResource.fromJson(
        info['cover'] ?? info['map_image'],
        fallback: info['map_url'],
      ),
    );
    final mapImage = coverResource.displayUrl;
    final ownerUserRaw = info['owner_user'] is Map
        ? asJsonMap(info['owner_user'])
        : const <String, dynamic>{};
    final flatLocations = (json['locations'] is List)
        ? asJsonList(json['locations'])
              .map((e) => OriginLocation.fromJson(asJsonMap(e)))
              .toList(growable: false)
        : const <OriginLocation>[];
    final worldMap = asImageUrl(
      info['world_map'],
      fallback: asImageUrl(info['map_url'], fallback: mapImage),
    );
    final oid = asString(info['oid'], fallback: asString(info['origin_id']));
    final id = asInt(info['id'], fallback: _originStableInt(oid));
    final locationTree = buildOriginLocationTree(
      flatLocations,
      originMapUrl: worldMap,
      originId: id,
    );
    final originVersion = asString(
      info['origin_version'],
      fallback: asString(info['version_num']),
    );
    return OriginDetail(
      id: id,
      oid: oid,
      name: decodeGenesisUgcTextForDisplay(
        asString(info['name'], fallback: asString(info['origin_name'])),
      ),
      description: decodeGenesisUgcTextForDisplay(
        asString(info['description'], fallback: asString(info['brief'])),
      ),
      mapImage: mapImage,
      worldMap: worldMap,
      worldView: decodeGenesisUgcTextForDisplay(
        asString(info['world_view'], fallback: asString(info['brief'])),
      ),
      deleted: entityDeleted(info['deleted'], fallback: info['origin_deleted']),
      ownerDeleted: entityDeleted(
        ownerUserRaw['deleted'],
        fallback: info['owner_deleted'],
      ),
      ownerUid: asString(info['owner_uid']),
      originator: asString(info['owner_name']),
      ownerUser: OriginUserInfo.fromJson(ownerUserRaw),
      originVersion: originVersion,
      originVersionTime: asDateTime(info['origin_version_time']),
      versionNum: asInt(originVersion, fallback: asInt(info['version_num'])),
      definitionVersion: asInt(info['definition_version'], fallback: 1),
      language: asString(info['language']),
      currentTime: asString(info['current_time']),
      status: asInt(info['status']),
      startTime: asString(
        info['start_time'],
        fallback: asString(info['started_at']),
      ),
      showOpeningSheet: asBool(json['show_opening_sheet']),
      copyCount: asInt(stats['copy_cnt'], fallback: asInt(info['copy_count'])),
      interactCount: asInt(
        stats['connect_cnt'],
        fallback: asInt(info['interact_count']),
      ),
      discussCount: asInt(
        stats['discuss_cnt'],
        fallback: asInt(info['discuss_count']),
      ),
      characterCount: asInt(
        stats['character_cnt'],
        fallback: asInt(info['character_count']),
      ),
      locationCount: asInt(stats['location_cnt']),
      maxTickCount: asInt(stats['max_tick_cnt']),
      tags: _originTagsFromJson(info['tags']),
      createdAt: asDateTime(info['created_at']),
      updatedAt: asDateTime(info['updated_at'] ?? info['origin_version_time']),
      characters: (json['characters'] is List)
          ? asJsonList(json['characters'])
                .map((e) => OriginCharacter.fromJson(asJsonMap(e)))
                .toList(growable: false)
          : const <OriginCharacter>[],
      locations: buildOriginLocationHierarchy(flatLocations),
      allLocations: flatLocations,
      events: (json['events'] is List)
          ? asJsonList(json['events'])
                .map((e) => OriginEvent.fromJson(asJsonMap(e)))
                .toList(growable: false)
          : const <OriginEvent>[],
      ticks: _originTicksFromJson(json['ticks'] ?? json['tick_list']),
      metric: json['metric'] is Map
          ? asJsonMap(json['metric'])
          : info['metric'] is Map
          ? asJsonMap(info['metric'])
          : const <String, dynamic>{},
      coverResource: coverResource,
      initLocationGroup: OriginInitLocationGroup.fromJsonOrNull(
        json['init_location_group'] ?? info['init_location_group'],
      ),
      locationTree: locationTree,
      processedLocationTree: processLocationTree(locationTree),
    );
  }
}

@immutable
class OriginUserInfo {
  const OriginUserInfo({
    this.uid = '',
    this.name = '',
    this.avatar = '',
    this.avatarResource = const GenesisImageResource(),
    this.deleted = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.friendCount = 0,
    this.createOriginCount = 0,
    this.launchWorldCount = 0,
    this.joinWorldCount = 0,
  });

  final String uid;
  final String name;
  final String avatar;
  final GenesisImageResource avatarResource;
  final bool deleted;
  final int followerCount;
  final int followingCount;
  final int friendCount;
  final int createOriginCount;
  final int launchWorldCount;
  final int joinWorldCount;

  factory OriginUserInfo.fromJson(Map<String, dynamic> json) {
    final avatarResource = GenesisImageResourceRegistry.register(
      GenesisImageResource.fromJson(json['avatar']),
    );
    return OriginUserInfo(
      uid: asString(json['uid']),
      name: asString(json['name']),
      avatar: avatarResource.displayUrl,
      avatarResource: avatarResource,
      deleted: entityDeleted(json['deleted']),
      followerCount: asInt(json['follower_cnt']),
      followingCount: asInt(json['following_cnt']),
      friendCount: asInt(json['friend_cnt']),
      createOriginCount: asInt(json['create_origin_cnt']),
      launchWorldCount: asInt(json['launch_world_cnt']),
      joinWorldCount: asInt(json['join_world_cnt']),
    );
  }
}

@immutable
class OriginInitLocationGroup {
  const OriginInitLocationGroup({
    required this.locationId,
    required this.initialDialogue,
  });

  final String locationId;
  final List<OriginDialogueLine> initialDialogue;

  static OriginInitLocationGroup? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final json = asJsonMap(raw);
    return OriginInitLocationGroup(
      locationId: asString(json['location_id']),
      initialDialogue: _originDialogueLinesFromJson(
        json['initial_dialogue'] ?? json['dialogue'],
      ),
    );
  }
}

@immutable
class OriginEvent {
  const OriginEvent({
    required this.label,
    required this.timestamp,
    required this.content,
  });

  final String label;
  final String timestamp;
  final String content;

  factory OriginEvent.fromJson(Map<String, dynamic> json) {
    return OriginEvent(
      label: decodeGenesisUgcTextForDisplay(
        asString(
          json['label'],
          fallback: asString(
            json['location_name'],
            fallback: asString(
              json['name'],
              fallback: asString(
                json['scene'],
                fallback: asString(json['scope']),
              ),
            ),
          ),
        ),
      ),
      timestamp: asString(
        json['timestamp'],
        fallback: asString(
          json['created_at'],
          fallback: asString(
            json['create_time'],
            fallback: asString(json['time']),
          ),
        ),
      ),
      content: decodeGenesisUgcTextForDisplay(
        asString(
          json['content'],
          fallback: asString(
            json['text'],
            fallback: asString(
              json['summary'],
              fallback: asString(json['narrator']),
            ),
          ),
        ),
      ),
    );
  }
}

const String originSyntheticRootLocationId = '__origin_root__';

List<LocationTreeNode<OriginLocation>> buildOriginLocationTree(
  List<OriginLocation> locations, {
  required String originMapUrl,
  required int originId,
}) {
  final tree = buildLocationTree(
    locations,
    idOf: (location) => location.locationId,
    parentIdOf: (location) => location.parentLocationId,
  );
  return withSyntheticRoot<OriginLocation>(
    tree,
    id: originSyntheticRootLocationId,
    value: OriginLocation(
      id: 0,
      originId: originId,
      name: '',
      icon: '',
      mapUrl: originMapUrl,
      description: '',
      position: 0,
      isActive: true,
      xPercent: 0,
      yPercent: 0,
      createdAt: null,
      updatedAt: null,
      locationId: originSyntheticRootLocationId,
      parentLocationId: '',
    ),
  );
}

@immutable
class OriginCharacter {
  const OriginCharacter({
    required this.id,
    this.characterId = '',
    required this.originId,
    required this.name,
    this.type = 'ai',
    this.playerUid = '',
    this.playerUsername = '',
    this.playerDeleted = false,
    this.playerUser = const OriginUserInfo(),
    this.playerJoinedAt = 0,
    required this.avatar,
    this.avatarResource = const GenesisImageResource(),
    required this.tags,
    this.tagline = '',
    this.goal = '',
    required this.currentLocationId,
    required this.initialLocationId,
    this.currentLocationBusinessId = '',
    this.initialLocationBusinessId = '',
    this.metricValue = 0,
    this.delta = 0,
    this.isRecommend = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String characterId;
  final int originId;
  final String name;
  final String type;
  final String playerUid;
  final String playerUsername;
  final bool playerDeleted;
  final OriginUserInfo playerUser;
  final int playerJoinedAt;
  final String avatar;
  final GenesisImageResource avatarResource;
  final String tags;
  final String tagline;
  final String goal;
  final int currentLocationId;
  final int initialLocationId;
  final String currentLocationBusinessId;
  final String initialLocationBusinessId;
  final int metricValue;
  final int delta;
  final int isRecommend;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get identity => tags;

  String get brief => tagline;

  bool get isRecommended => isRecommend == 1;

  factory OriginCharacter.fromJson(Map<String, dynamic> json) {
    final currentLocation = json['current_location'];
    int currentLocationId = 0;
    if (json['current_location_id'] != null) {
      currentLocationId = asInt(json['current_location_id']);
    } else if (currentLocation is int) {
      currentLocationId = currentLocation;
    } else if (currentLocation is Map) {
      final map = asJsonMap(currentLocation);
      currentLocationId = asInt(
        map['id'],
        fallback: asInt(map['location_id'], fallback: 0),
      );
    }
    final playerUser = json['player_user'] is Map
        ? asJsonMap(json['player_user'])
        : const <String, dynamic>{};
    final avatarResource = GenesisImageResourceRegistry.register(
      GenesisImageResource.fromJson(json['avatar']),
    );
    final currentLocationBusinessId = asString(json['location_id']);
    final initialLocationBusinessId = asString(json['initial_location_id']);
    if (currentLocationId == 0) {
      currentLocationId = _originStableInt(
        currentLocationBusinessId.isNotEmpty
            ? currentLocationBusinessId
            : initialLocationBusinessId,
      );
    }
    final initialLocationId = asInt(
      json['initial_location_id'],
      fallback: _originStableInt(
        initialLocationBusinessId.isNotEmpty
            ? initialLocationBusinessId
            : currentLocationBusinessId,
      ),
    );
    final characterId = asString(
      json['character_id'],
      fallback: asString(json['char_id']),
    );

    return OriginCharacter(
      id: asInt(json['id'], fallback: _originStableInt(characterId)),
      characterId: characterId,
      originId: asInt(json['origin_id']),
      name: decodeGenesisUgcTextForDisplay(asString(json['name'])),
      type: asString(json['type'], fallback: 'ai'),
      playerUid: asString(json['player_uid']),
      playerUsername: asString(
        playerUser['name'],
        fallback: asString(json['player_username']),
      ),
      playerDeleted: entityDeleted(
        playerUser['deleted'],
        fallback: json['player_deleted'],
      ),
      playerUser: OriginUserInfo.fromJson(playerUser),
      playerJoinedAt: asInt(json['player_joined_at']),
      avatar: avatarResource.displayUrl,
      avatarResource: avatarResource,
      tags: decodeGenesisUgcTextForDisplay(
        asString(json['tags'], fallback: asString(json['identity'])),
      ),
      tagline: decodeGenesisUgcTextForDisplay(asString(json['brief'])),
      goal: decodeGenesisUgcTextForDisplay(asString(json['goal'])),
      currentLocationId: currentLocationId,
      initialLocationId: initialLocationId,
      currentLocationBusinessId: currentLocationBusinessId,
      initialLocationBusinessId: initialLocationBusinessId,
      metricValue: asInt(json['metric_value']),
      delta: asInt(json['delta']),
      isRecommend: asInt(json['is_recommend']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

@immutable
class OriginMyLaunchPresetCharacter {
  const OriginMyLaunchPresetCharacter({
    required this.charId,
    required this.type,
    required this.name,
    required this.identity,
    required this.brief,
    required this.goal,
    required this.avatar,
    required this.avatarResource,
    required this.initialLocationId,
    required this.lastLaunchedAt,
    this.worldId = '',
    this.tickCount = 0,
    this.currentTime = '',
  });

  final String charId;
  final String type;
  final String name;
  final String identity;
  final String brief;
  final String goal;
  final String avatar;
  final GenesisImageResource avatarResource;
  final String initialLocationId;
  final int lastLaunchedAt;
  final String worldId;
  final int tickCount;
  final String currentTime;
}

@immutable
class OriginLocation {
  const OriginLocation({
    required this.id,
    required this.originId,
    required this.name,
    required this.icon,
    required this.mapUrl,
    required this.description,
    this.level = 0,
    this.locationParagraph = '',
    this.locationTimestamp = '',
    this.locationSummary = '',
    required this.position,
    required this.isActive,
    required this.xPercent,
    required this.yPercent,
    this.x = 0,
    this.y = 0,
    this.imageResource = const GenesisImageResource(),
    required this.createdAt,
    required this.updatedAt,
    this.locationId = '',
    this.parentLocationId = '',
    this.dialogue = const <OriginDialogueLine>[],
    this.locations = const <OriginLocation>[],
  });

  final int id;
  final int originId;
  final String name;
  final String icon;
  final String mapUrl;
  final String description;
  final int level;
  final String locationParagraph;
  final String locationTimestamp;
  final String locationSummary;
  final int position;
  final bool isActive;
  final double xPercent;
  final double yPercent;
  final double x;
  final double y;
  final GenesisImageResource imageResource;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String locationId;
  final String parentLocationId;
  final List<OriginDialogueLine> dialogue;
  final List<OriginLocation> locations;

  factory OriginLocation.fromJson(Map<String, dynamic> json) {
    final rawX = json['x_percent'] ?? json['xPercent'];
    final rawY = json['y_percent'] ?? json['yPercent'];
    final xPercent = rawX is num
        ? rawX.toDouble()
        : double.tryParse('$rawX') ?? 0;
    final yPercent = rawY is num
        ? rawY.toDouble()
        : double.tryParse('$rawY') ?? 0;
    final imageResource = GenesisImageResourceRegistry.register(
      GenesisImageResource.fromJson(json['image'], fallback: json['icon']),
    );
    final locationId = asString(json['location_id']);
    return OriginLocation(
      id: asInt(json['id'], fallback: _originStableInt(locationId)),
      originId: asInt(json['origin_id']),
      name: decodeGenesisUgcTextForDisplay(
        asString(json['name'], fallback: asString(json['location_name'])),
      ),
      icon: imageResource.displayUrl,
      mapUrl: asString(json['map_url']),
      description: decodeGenesisUgcTextForDisplay(
        asString(
          json['location_description'],
          fallback: asString(
            json['description'],
            fallback: asString(json['location_summary']),
          ),
        ),
      ),
      level: asInt(json['level']),
      locationParagraph: asString(
        json['location_paragraph'],
        fallback: asString(json['location_garagraph']),
      ),
      locationTimestamp: asString(json['location_timestamp']),
      locationSummary: asString(json['location_summary']),
      position: asInt(json['position']),
      isActive: asBool(json['is_active'], fallback: true),
      xPercent: xPercent,
      yPercent: yPercent,
      x: _asDoubleValue(json['x']),
      y: _asDoubleValue(json['y']),
      imageResource: imageResource,
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      locationId: locationId,
      parentLocationId: asString(json['location_pid']),
      dialogue: _originDialogueLinesFromJson(json['dialogue']),
    );
  }

  OriginLocation copyWith({List<OriginLocation>? locations}) {
    return OriginLocation(
      id: id,
      originId: originId,
      name: name,
      icon: icon,
      mapUrl: mapUrl,
      description: description,
      level: level,
      locationParagraph: locationParagraph,
      locationTimestamp: locationTimestamp,
      locationSummary: locationSummary,
      position: position,
      isActive: isActive,
      xPercent: xPercent,
      yPercent: yPercent,
      x: x,
      y: y,
      imageResource: imageResource,
      createdAt: createdAt,
      updatedAt: updatedAt,
      locationId: locationId,
      parentLocationId: parentLocationId,
      dialogue: dialogue,
      locations: locations ?? this.locations,
    );
  }
}

@immutable
class OriginDialogueLine {
  const OriginDialogueLine({
    required this.charId,
    required this.charName,
    required this.content,
  });

  final String charId;
  final String charName;
  final String content;

  factory OriginDialogueLine.fromJson(Map<String, dynamic> json) {
    return OriginDialogueLine(
      charId: asString(
        json['char_id'],
        fallback: asString(
          json['character_id'],
          fallback: asString(json['sender_id']),
        ),
      ),
      charName: asString(
        json['char_name'],
        fallback: asString(
          json['name'],
          fallback: asString(json['sender_name']),
        ),
      ),
      content: asString(json['content'], fallback: asString(json['text'])),
    );
  }
}

List<OriginDialogueLine> _originDialogueLinesFromJson(Object? raw) {
  if (raw is! List) return const <OriginDialogueLine>[];
  return asJsonList(raw)
      .whereType<Map>()
      .map((item) => OriginDialogueLine.fromJson(asJsonMap(item)))
      .toList(growable: false);
}

List<OriginLocation> buildOriginLocationHierarchy(
  List<OriginLocation> flatLocations,
) {
  if (flatLocations.isEmpty) return const <OriginLocation>[];

  final rootList = flatLocations.toList(growable: true);
  final pOneList = <OriginLocation>[];
  for (final location in flatLocations) {
    if (location.parentLocationId.trim().isEmpty) {
      pOneList.add(location);
      rootList.remove(location);
    }
  }

  OriginLocation attachChildren(OriginLocation parent) {
    final childLocations = rootList
        .where(
          (location) => location.parentLocationId.trim() == parent.locationId,
        )
        .map(attachChildren)
        .toList(growable: false);
    return parent.copyWith(locations: childLocations);
  }

  return pOneList.map(attachChildren).toList(growable: false);
}

List<Map<String, dynamic>> _originTicksFromJson(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return asJsonList(raw)
      .whereType<Map>()
      .indexed
      .map((entry) {
        final index = entry.$1;
        final tick = asJsonMap(entry.$2);
        final result = tick['tick_result'] is Map
            ? asJsonMap(tick['tick_result'])
            : tick;
        final paragraphsRaw = result['paragraphs'];
        final paragraphs = paragraphsRaw is List
            ? asJsonList(paragraphsRaw)
                  .whereType<Map>()
                  .map((item) => asJsonMap(item))
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];
        final locationGroupsRaw = result['location_groups'];
        final locationGroups = locationGroupsRaw is List
            ? asJsonList(locationGroupsRaw)
                  .whereType<Map>()
                  .map((item) => asJsonMap(item))
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];

        return <String, dynamic>{
          'tick_id': asString(tick['tick_id']),
          'tick_no': asInt(tick['tick_no'], fallback: index + 1),
          'sub_tick_no': asInt(tick['sub_tick_no'], fallback: 1),
          'status': asInt(tick['status']),
          'created_at': tick['created_at'],
          'tick_result': <String, dynamic>{
            'current_time': asString(
              result['current_time'],
              fallback: asString(tick['current_time']),
            ),
            'narrator': asString(
              result['narrator'],
              fallback: asString(
                tick['narrator'],
                fallback: asString(tick['summary']),
              ),
            ),
            'paragraphs': paragraphs,
            if (locationGroupsRaw is List) 'location_groups': locationGroups,
          },
        };
      })
      .toList(growable: false);
}

List<String> _splitTags(String tags) {
  if (tags.trim().isEmpty) return const [];
  return tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

List<String> _originTagsFromJson(Object? raw) {
  if (raw is List) {
    return raw
        .map(asString)
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }
  return _splitTags(asString(raw));
}

double _asDoubleValue(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw') ?? 0;
}

int _originStableInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 0;
  var hash = 0;
  for (final unit in trimmed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
