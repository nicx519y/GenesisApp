import 'package:flutter/material.dart';

class WorldPoint {
  const WorldPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.users,
    this.sceneId = '',
    this.pointId = '',
    this.iconUrl = '',
    this.description = '',
    this.depth = 0,
    this.isLeafLocation = true,
  });

  final String id;
  final String name;
  final WorldPointType type;
  final Offset position;
  final List<UserAvatar> users;
  final String sceneId;
  final String pointId;
  final String iconUrl;
  final String description;
  final int depth;
  final bool isLeafLocation;
}

class UserAvatar {
  const UserAvatar(
    this.initials, {
    this.name,
    this.avatarUrl = '',
    this.showStar = false,
  });

  final String initials;
  final String? name;
  final String avatarUrl;
  final bool showStar;
}

enum WorldPointType { castle, shop, portal, tavern, camp }
