import 'package:flutter/foundation.dart';

import '../json_utils.dart';
import 'location_tree.dart';
import 'origin.dart';

@immutable
class World {
  const World({
    required this.id,
    required this.wid,
    required this.originId,
    required this.ownerUid,
    required this.name,
    required this.progressCount,
    required this.interactCount,
    required this.inviteToken,
    required this.createdAt,
  });

  final int id;
  final String wid;
  final int originId;
  final String ownerUid;
  final String name;
  final int progressCount;
  final int interactCount;
  final String inviteToken;
  final DateTime? createdAt;

  factory World.fromJson(Map<String, dynamic> json) {
    return World(
      id: asInt(json['id']),
      wid: asString(json['wid']),
      originId: asInt(json['origin_id']),
      ownerUid: asString(json['owner_uid']),
      name: asString(json['name']),
      progressCount: asInt(json['progress_count']),
      interactCount: asInt(json['interact_count']),
      inviteToken: asString(json['invite_token']),
      createdAt: asDateTime(json['created_at']),
    );
  }
}

@immutable
class WorldDetail {
  WorldDetail({
    required this.id,
    required this.worldId,
    required this.originId,
    required this.ownerUid,
    required this.name,
    required this.tickCount,
    required this.connectCount,
    required this.characterCount,
    required this.playerCount,
    required this.latestTickAt,
    required this.latestNarrator,
    required this.isProgressing,
    required this.relationStatus,
    required this.metric,
    required this.inviteToken,
    required this.createdAt,
    required this.updatedAt,
    required this.origin,
    required this.characters,
    required this.ticks,
    required this.locations,
    this.locationTree = const <LocationTreeNode<Map<String, dynamic>>>[],
    ProcessedLocationTree<Map<String, dynamic>>? processedLocationTree,
    required this.characterPositions,
    required this.userPositions,
  }) : processedLocationTree =
           processedLocationTree ??
           ProcessedLocationTree<Map<String, dynamic>>(locationTree);

  final int id;
  final String worldId;
  final int originId;
  final String ownerUid;
  final String name;
  final int tickCount;
  final int connectCount;
  final int characterCount;
  final int playerCount;
  final DateTime? latestTickAt;
  final String latestNarrator;
  final bool isProgressing;
  final String relationStatus;
  final Map<String, dynamic> metric;
  final String inviteToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final OriginSummary origin;
  final List<Map<String, dynamic>> characters;
  final List<Map<String, dynamic>> ticks;
  final List<Map<String, dynamic>> locations;
  final List<LocationTreeNode<Map<String, dynamic>>> locationTree;
  final ProcessedLocationTree<Map<String, dynamic>> processedLocationTree;
  final List<Map<String, dynamic>> characterPositions;
  final List<Map<String, dynamic>> userPositions;

  WorldDetail copyWith({
    int? id,
    String? worldId,
    int? originId,
    String? ownerUid,
    String? name,
    int? tickCount,
    int? connectCount,
    int? characterCount,
    int? playerCount,
    DateTime? latestTickAt,
    String? latestNarrator,
    bool? isProgressing,
    String? relationStatus,
    Map<String, dynamic>? metric,
    String? inviteToken,
    DateTime? createdAt,
    DateTime? updatedAt,
    OriginSummary? origin,
    List<Map<String, dynamic>>? characters,
    List<Map<String, dynamic>>? ticks,
    List<Map<String, dynamic>>? locations,
    List<LocationTreeNode<Map<String, dynamic>>>? locationTree,
    ProcessedLocationTree<Map<String, dynamic>>? processedLocationTree,
    List<Map<String, dynamic>>? characterPositions,
    List<Map<String, dynamic>>? userPositions,
  }) {
    final nextLocations = locations ?? this.locations;
    List<LocationTreeNode<Map<String, dynamic>>>? nextLocationTree =
        locationTree;
    if (nextLocationTree == null && locations != null) {
      nextLocationTree = buildLocationTree(
        nextLocations,
        idOf: (location) => asString(location['location_id']),
        parentIdOf: (location) => asString(location['location_pid']),
      );
    }
    final resolvedLocationTree = nextLocationTree ?? this.locationTree;
    final resolvedProcessedLocationTree =
        processedLocationTree ??
        (nextLocationTree == null
            ? this.processedLocationTree
            : processLocationTree(resolvedLocationTree));
    return WorldDetail(
      id: id ?? this.id,
      worldId: worldId ?? this.worldId,
      originId: originId ?? this.originId,
      ownerUid: ownerUid ?? this.ownerUid,
      name: name ?? this.name,
      tickCount: tickCount ?? this.tickCount,
      connectCount: connectCount ?? this.connectCount,
      characterCount: characterCount ?? this.characterCount,
      playerCount: playerCount ?? this.playerCount,
      latestTickAt: latestTickAt ?? this.latestTickAt,
      latestNarrator: latestNarrator ?? this.latestNarrator,
      isProgressing: isProgressing ?? this.isProgressing,
      relationStatus: relationStatus ?? this.relationStatus,
      metric: metric ?? this.metric,
      inviteToken: inviteToken ?? this.inviteToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      origin: origin ?? this.origin,
      characters: characters ?? this.characters,
      ticks: ticks ?? this.ticks,
      locations: nextLocations,
      locationTree: resolvedLocationTree,
      processedLocationTree: resolvedProcessedLocationTree,
      characterPositions: characterPositions ?? this.characterPositions,
      userPositions: userPositions ?? this.userPositions,
    );
  }

  factory WorldDetail.fromJson(Map<String, dynamic> json) {
    final rawWorldLocations = (json['locations'] is List)
        ? asJsonList(
            json['locations'],
          ).map((e) => asJsonMap(e)).toList(growable: false)
        : const <Map<String, dynamic>>[];
    final worldLocationTree = buildLocationTree(
      rawWorldLocations,
      idOf: (location) => asString(location['location_id']),
      parentIdOf: (location) => asString(location['location_pid']),
    );
    return WorldDetail(
      id: asInt(json['id']),
      worldId: asString(json['world_id']),
      originId: asInt(json['origin_id']),
      ownerUid: asString(json['owner_uid']),
      name: asString(json['name']),
      tickCount: asInt(json['tick_count']),
      connectCount: asInt(json['connect_count']),
      characterCount: asInt(json['character_count']),
      playerCount: asInt(json['player_count']),
      latestTickAt: asDateTime(json['latest_tick_at']),
      latestNarrator: asString(json['latest_narrator']),
      isProgressing: asBool(json['is_progressing']),
      relationStatus: asString(json['relation_status']),
      metric: asJsonMap(json['metric']),
      inviteToken: asString(json['invite_token']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      origin: (json['origin'] is Map)
          ? OriginSummary.fromJson(asJsonMap(json['origin']))
          : const OriginSummary(
              id: 0,
              oid: '',
              name: '',
              description: '',
              mapImage: '',
              worldMap: '',
              worldView: '',
              copyCount: 0,
              interactCount: 0,
              tags: <String>[],
              createdAt: null,
              updatedAt: null,
              characters: <OriginCharacter>[],
              locations: <OriginLocation>[],
            ),
      characters: (json['characters'] is List)
          ? asJsonList(
              json['characters'],
            ).map((e) => asJsonMap(e)).toList(growable: false)
          : const [],
      ticks: (json['ticks'] is List)
          ? asJsonList(
              json['ticks'],
            ).map((e) => asJsonMap(e)).toList(growable: false)
          : const [],
      locations: rawWorldLocations,
      locationTree: worldLocationTree,
      processedLocationTree: processLocationTree(worldLocationTree),
      characterPositions: (json['character_positions'] is List)
          ? asJsonList(
              json['character_positions'],
            ).map((e) => asJsonMap(e)).toList(growable: false)
          : const [],
      userPositions: (json['user_positions'] is List)
          ? asJsonList(
              json['user_positions'],
            ).map((e) => asJsonMap(e)).toList(growable: false)
          : const [],
    );
  }
}

@immutable
class WorldMember {
  const WorldMember({
    required this.id,
    required this.worldId,
    required this.uid,
    required this.roleAvatar,
    required this.roleNickname,
    required this.joinedAt,
  });

  final int id;
  final int worldId;
  final String uid;
  final String roleAvatar;
  final String roleNickname;
  final DateTime? joinedAt;

  factory WorldMember.fromJson(Map<String, dynamic> json) {
    return WorldMember(
      id: asInt(json['id']),
      worldId: asInt(json['world_id']),
      uid: asString(json['uid']),
      roleAvatar: asImageUrl(json['role_avatar']),
      roleNickname: asString(json['role_nickname']),
      joinedAt: asDateTime(json['joined_at']),
    );
  }
}

@immutable
class JoinedWorld {
  const JoinedWorld({required this.id, required this.wid, required this.name});

  final int id;
  final String wid;
  final String name;

  factory JoinedWorld.fromJson(Map<String, dynamic> json) {
    return JoinedWorld(
      id: asInt(json['id']),
      wid: asString(json['wid']),
      name: asString(json['name']),
    );
  }
}
