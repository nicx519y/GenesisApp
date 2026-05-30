import 'package:flutter/foundation.dart';

import '../json_utils.dart';
import 'location_tree.dart';

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
    final mapImage = asString(json['map_image']);
    return OriginSummary(
      id: asInt(json['id']),
      oid: asString(json['oid']),
      name: asString(json['name']),
      description: asString(json['description']),
      mapImage: mapImage,
      worldMap: asString(json['world_map'], fallback: mapImage),
      worldView: asString(json['world_view']),
      originator: asString(json['originator']),
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
    this.events = const <OriginEvent>[],
    this.locationTree = const <LocationTreeNode<OriginLocation>>[],
    ProcessedLocationTree<OriginLocation>? processedLocationTree,
  }) : processedLocationTree =
           processedLocationTree ??
           ProcessedLocationTree<OriginLocation>(locationTree);

  final int id;
  final String oid;
  final String name;
  final String description;
  final String mapImage;
  final String worldMap;
  final String worldView;
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
  final List<OriginEvent> events;
  final List<LocationTreeNode<OriginLocation>> locationTree;
  final ProcessedLocationTree<OriginLocation> processedLocationTree;

  factory OriginDetail.fromJson(Map<String, dynamic> json) {
    final mapImage = asString(json['map_image']);
    final locations = (json['locations'] is List)
        ? asJsonList(json['locations'])
              .map((e) => OriginLocation.fromJson(asJsonMap(e)))
              .toList(growable: false)
        : const <OriginLocation>[];
    final locationTree = buildLocationTree(
      locations,
      idOf: (location) => location.locationId,
      parentIdOf: (location) => location.parentLocationId,
    );
    return OriginDetail(
      id: asInt(json['id']),
      oid: asString(json['oid']),
      name: asString(json['name']),
      description: asString(json['description']),
      mapImage: mapImage,
      worldMap: asString(json['world_map'], fallback: mapImage),
      worldView: asString(json['world_view']),
      originator: asString(json['originator']),
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
      locations: locations,
      events: (json['events'] is List)
          ? asJsonList(json['events'])
                .map((e) => OriginEvent.fromJson(asJsonMap(e)))
                .toList(growable: false)
          : const <OriginEvent>[],
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
      label: asString(
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
      content: asString(
        json['content'],
        fallback: asString(
          json['text'],
          fallback: asString(
            json['summary'],
            fallback: asString(json['narrator']),
          ),
        ),
      ),
    );
  }
}

@immutable
class OriginCharacter {
  const OriginCharacter({
    required this.id,
    this.characterId = '',
    required this.originId,
    required this.name,
    required this.avatar,
    required this.tags,
    this.tagline = '',
    required this.description,
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
  final String avatar;
  final String tags;
  final String tagline;
  final String description;
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

    return OriginCharacter(
      id: asInt(json['id']),
      characterId: asString(
        json['character_id'],
        fallback: asString(json['char_id']),
      ),
      originId: asInt(json['origin_id']),
      name: asString(json['name']),
      avatar: asString(json['avatar']),
      tags: asString(json['tags'], fallback: asString(json['identity'])),
      tagline: asString(json['tagline'], fallback: asString(json['brief'])),
      description: asString(
        json['description'],
        fallback: asString(json['bio']),
      ),
      goal: asString(json['goal']),
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
    required this.position,
    required this.isActive,
    required this.xPercent,
    required this.yPercent,
    required this.createdAt,
    required this.updatedAt,
    this.locationId = '',
    this.parentLocationId = '',
  });

  final int id;
  final int originId;
  final String name;
  final String icon;
  final String mapUrl;
  final String description;
  final int position;
  final bool isActive;
  final double xPercent;
  final double yPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String locationId;
  final String parentLocationId;

  factory OriginLocation.fromJson(Map<String, dynamic> json) {
    final rawX = json['x_percent'] ?? json['xPercent'];
    final rawY = json['y_percent'] ?? json['yPercent'];
    final x = rawX is num ? rawX.toDouble() : double.tryParse('$rawX') ?? 0;
    final y = rawY is num ? rawY.toDouble() : double.tryParse('$rawY') ?? 0;
    return OriginLocation(
      id: asInt(json['id']),
      originId: asInt(json['origin_id']),
      name: asString(json['name'], fallback: asString(json['location_name'])),
      icon: asString(json['icon'], fallback: asString(json['image'])),
      mapUrl: asString(json['map_url']),
      description: asString(
        json['description'],
        fallback: asString(json['location_summary']),
      ),
      position: asInt(json['position']),
      isActive: asBool(json['is_active']),
      xPercent: x,
      yPercent: y,
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      locationId: asString(json['location_id']),
      parentLocationId: asString(json['location_pid']),
    );
  }
}

List<String> _splitTags(String tags) {
  if (tags.trim().isEmpty) return const [];
  return tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
