import 'package:flutter/foundation.dart';

import '../json_utils.dart';

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
    required this.copyCount,
    required this.interactCount,
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
  final int copyCount;
  final int interactCount;
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
      copyCount: asInt(json['copy_count']),
      interactCount: asInt(json['interact_count']),
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
  const OriginDetail({
    required this.id,
    required this.oid,
    required this.name,
    required this.description,
    required this.mapImage,
    required this.worldMap,
    required this.worldView,
    required this.copyCount,
    required this.interactCount,
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
  final int copyCount;
  final int interactCount;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OriginCharacter> characters;
  final List<OriginLocation> locations;

  factory OriginDetail.fromJson(Map<String, dynamic> json) {
    final mapImage = asString(json['map_image']);
    return OriginDetail(
      id: asInt(json['id']),
      oid: asString(json['oid']),
      name: asString(json['name']),
      description: asString(json['description']),
      mapImage: mapImage,
      worldMap: asString(json['world_map'], fallback: mapImage),
      worldView: asString(json['world_view']),
      copyCount: asInt(json['copy_count']),
      interactCount: asInt(json['interact_count']),
      tags: _splitTags(asString(json['tags'])),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      characters: (json['characters'] is List)
          ? asJsonList(json['characters'])
                .map((e) => OriginCharacter.fromJson(asJsonMap(e)))
                .toList(growable: false)
          : const <OriginCharacter>[],
      locations: (json['locations'] is List)
          ? asJsonList(json['locations'])
                .map((e) => OriginLocation.fromJson(asJsonMap(e)))
                .toList(growable: false)
          : const <OriginLocation>[],
    );
  }
}

@immutable
class OriginCharacter {
  const OriginCharacter({
    required this.id,
    required this.originId,
    required this.name,
    required this.avatar,
    required this.tags,
    required this.description,
    required this.currentLocationId,
    required this.initialLocationId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int originId;
  final String name;
  final String avatar;
  final String tags;
  final String description;
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
      originId: asInt(json['origin_id']),
      name: asString(json['name']),
      avatar: asString(json['avatar']),
      tags: asString(json['tags']),
      description: asString(json['description']),
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
    required this.description,
    required this.position,
    required this.isActive,
    required this.xPercent,
    required this.yPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int originId;
  final String name;
  final String icon;
  final String description;
  final int position;
  final bool isActive;
  final double xPercent;
  final double yPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OriginLocation.fromJson(Map<String, dynamic> json) {
    final rawX = json['x_percent'] ?? json['xPercent'];
    final rawY = json['y_percent'] ?? json['yPercent'];
    final x = rawX is num ? rawX.toDouble() : double.tryParse('$rawX') ?? 0;
    final y = rawY is num ? rawY.toDouble() : double.tryParse('$rawY') ?? 0;
    return OriginLocation(
      id: asInt(json['id']),
      originId: asInt(json['origin_id']),
      name: asString(json['name']),
      icon: asString(json['icon']),
      description: asString(json['description']),
      position: asInt(json['position']),
      isActive: asBool(json['is_active']),
      xPercent: x,
      yPercent: y,
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
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
