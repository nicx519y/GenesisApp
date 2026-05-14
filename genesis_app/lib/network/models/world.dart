import 'package:flutter/foundation.dart';

import '../json_utils.dart';
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
  const WorldDetail({
    required this.id,
    required this.wid,
    required this.originId,
    required this.ownerUid,
    required this.name,
    required this.progressCount,
    required this.interactCount,
    required this.lastProgressAt,
    required this.lastProgressUpdate,
    required this.isProgressing,
    required this.inviteToken,
    required this.createdAt,
    required this.updatedAt,
    required this.origin,
    required this.worldLocations,
    required this.characterPositions,
    required this.userPositions,
  });

  final int id;
  final String wid;
  final int originId;
  final String ownerUid;
  final String name;
  final int progressCount;
  final int interactCount;
  final DateTime? lastProgressAt;
  final String lastProgressUpdate;
  final bool isProgressing;
  final String inviteToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final OriginSummary origin;
  final List<Map<String, dynamic>> worldLocations;
  final List<Map<String, dynamic>> characterPositions;
  final List<Map<String, dynamic>> userPositions;

  factory WorldDetail.fromJson(Map<String, dynamic> json) {
    return WorldDetail(
      id: asInt(json['id']),
      wid: asString(json['wid']),
      originId: asInt(json['origin_id']),
      ownerUid: asString(json['owner_uid']),
      name: asString(json['name']),
      progressCount: asInt(json['progress_count']),
      interactCount: asInt(json['interact_count']),
      lastProgressAt: asDateTime(json['last_progress_at']),
      lastProgressUpdate: asString(json['last_progress_update']),
      isProgressing: asBool(json['is_progressing']),
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
      worldLocations: (json['world_locations'] is List)
          ? asJsonList(
              json['world_locations'],
            ).map((e) => asJsonMap(e)).toList(growable: false)
          : const [],
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
      roleAvatar: asString(json['role_avatar']),
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
