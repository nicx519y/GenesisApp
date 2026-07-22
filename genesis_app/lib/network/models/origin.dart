import 'package:flutter/foundation.dart';

import '../json_utils.dart';
import 'location_tree.dart';
import '../../utils/entity_deleted.dart';
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
    this.versionNum = 0,
    this.startTime = '',
    required this.copyCount,
    required this.interactCount,
    this.discussCount = 0,
    this.characterCount = 0,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.characters,
    required this.locations,
    List<OriginLocation>? allLocations,
    this.events = const <OriginEvent>[],
    this.ticks = const <Map<String, dynamic>>[],
    this.metric = const <String, dynamic>{},
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
  final int versionNum;
  final String startTime;
  final int copyCount;
  final int interactCount;
  final int discussCount;
  final int characterCount;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OriginCharacter> characters;
  final List<OriginLocation> locations;
  final List<OriginLocation> allLocations;
  final List<OriginEvent> events;
  final List<Map<String, dynamic>> ticks;
  final Map<String, dynamic> metric;
  final List<LocationTreeNode<OriginLocation>> locationTree;
  final ProcessedLocationTree<OriginLocation> processedLocationTree;

  factory OriginDetail.fromJson(Map<String, dynamic> json) {
    final mapImage = asImageUrl(json['map_image']);
    final ownerUser = json['owner_user'] is Map
        ? asJsonMap(json['owner_user'])
        : const <String, dynamic>{};
    final flatLocations = (json['locations'] is List)
        ? asJsonList(json['locations'])
              .map((e) => OriginLocation.fromJson(asJsonMap(e)))
              .toList(growable: false)
        : const <OriginLocation>[];
    final worldMap = asImageUrl(
      json['world_map'],
      fallback: asImageUrl(json['map_url'], fallback: mapImage),
    );
    final locationTree = buildOriginLocationTree(
      flatLocations,
      originMapUrl: worldMap,
      originId: asInt(json['id']),
    );
    return OriginDetail(
      id: asInt(json['id']),
      oid: asString(json['oid']),
      name: decodeGenesisUgcTextForDisplay(asString(json['name'])),
      description: decodeGenesisUgcTextForDisplay(
        asString(json['description']),
      ),
      mapImage: mapImage,
      worldMap: worldMap,
      worldView: decodeGenesisUgcTextForDisplay(asString(json['world_view'])),
      deleted: entityDeleted(json['deleted'], fallback: json['origin_deleted']),
      ownerDeleted: entityDeleted(
        ownerUser['deleted'],
        fallback: json['owner_deleted'],
      ),
      ownerUid: asString(json['owner_uid']),
      originator: asString(json['owner_name']),
      versionNum: asInt(json['version_num']),
      startTime: asString(json['start_time']),
      copyCount: asInt(json['copy_count']),
      interactCount: asInt(json['interact_count']),
      discussCount: asInt(json['discuss_count']),
      characterCount: asInt(json['character_count']),
      tags: _splitTags(asString(json['tags'])),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
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
          : const <String, dynamic>{},
      locationTree: locationTree,
      processedLocationTree: processLocationTree(locationTree),
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
    this.playerUid = '',
    this.playerUsername = '',
    this.playerDeleted = false,
    required this.avatar,
    required this.tags,
    this.tagline = '',
    this.goal = '',
    required this.currentLocationId,
    required this.initialLocationId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String characterId;
  final int originId;
  final String name;
  final String playerUid;
  final String playerUsername;
  final bool playerDeleted;
  final String avatar;
  final String tags;
  final String tagline;
  final String goal;
  final int currentLocationId;
  final int initialLocationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

    return OriginCharacter(
      id: asInt(json['id']),
      characterId: asString(
        json['character_id'],
        fallback: asString(json['char_id']),
      ),
      originId: asInt(json['origin_id']),
      name: decodeGenesisUgcTextForDisplay(asString(json['name'])),
      playerUid: asString(json['player_uid']),
      playerUsername: asString(
        playerUser['name'],
        fallback: asString(json['player_username']),
      ),
      playerDeleted: entityDeleted(
        playerUser['deleted'],
        fallback: json['player_deleted'],
      ),
      avatar: asImageUrl(json['avatar']),
      tags: decodeGenesisUgcTextForDisplay(
        asString(json['tags'], fallback: asString(json['identity'])),
      ),
      tagline: decodeGenesisUgcTextForDisplay(asString(json['brief'])),
      goal: decodeGenesisUgcTextForDisplay(asString(json['goal'])),
      currentLocationId: currentLocationId,
      initialLocationId: asInt(json['initial_location_id']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
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
    this.locationParagraph = '',
    required this.position,
    required this.isActive,
    required this.xPercent,
    required this.yPercent,
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
  final String locationParagraph;
  final int position;
  final bool isActive;
  final double xPercent;
  final double yPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String locationId;
  final String parentLocationId;
  final List<OriginDialogueLine> dialogue;
  final List<OriginLocation> locations;

  factory OriginLocation.fromJson(Map<String, dynamic> json) {
    final rawX = json['x_percent'] ?? json['xPercent'];
    final rawY = json['y_percent'] ?? json['yPercent'];
    final x = rawX is num ? rawX.toDouble() : double.tryParse('$rawX') ?? 0;
    final y = rawY is num ? rawY.toDouble() : double.tryParse('$rawY') ?? 0;
    return OriginLocation(
      id: asInt(json['id']),
      originId: asInt(json['origin_id']),
      name: decodeGenesisUgcTextForDisplay(
        asString(json['name'], fallback: asString(json['location_name'])),
      ),
      icon: asImageUrl(json['icon'], fallback: json['image']),
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
      locationParagraph: asString(
        json['location_paragraph'],
        fallback: asString(json['location_garagraph']),
      ),
      position: asInt(json['position']),
      isActive: asBool(json['is_active']),
      xPercent: x,
      yPercent: y,
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      locationId: asString(json['location_id']),
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
      locationParagraph: locationParagraph,
      position: position,
      isActive: isActive,
      xPercent: xPercent,
      yPercent: yPercent,
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
  return asJsonList(raw).indexed
      .map((entry) {
        final index = entry.$1;
        final tick = asJsonMap(entry.$2);
        final result = tick['tick_result'] is Map
            ? asJsonMap(tick['tick_result'])
            : tick;
        final paragraphsRaw = result['paragraphs'];
        final paragraphs = paragraphsRaw is List
            ? asJsonList(
                paragraphsRaw,
              ).map((item) => asJsonMap(item)).toList(growable: false)
            : const <Map<String, dynamic>>[];
        final locationGroupsRaw = result['location_groups'];
        final locationGroups = locationGroupsRaw is List
            ? asJsonList(
                locationGroupsRaw,
              ).map((item) => asJsonMap(item)).toList(growable: false)
            : const <Map<String, dynamic>>[];

        return <String, dynamic>{
          'tick_id': asString(tick['tick_id']),
          'tick_no': asInt(tick['tick_no'], fallback: index + 1),
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
            'location_groups': locationGroups,
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
