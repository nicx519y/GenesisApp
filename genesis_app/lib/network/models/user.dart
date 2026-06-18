import 'package:flutter/foundation.dart';

import '../json_utils.dart';
import '../../utils/entity_deleted.dart';

@immutable
class User {
  const User({
    required this.id,
    required this.uid,
    required this.did,
    required this.nickname,
    required this.avatar,
    this.deleted = false,
    required this.createdAt,
  });

  final int id;
  final String uid;
  final String did;
  final String nickname;
  final String avatar;
  final bool deleted;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: asInt(json['id']),
      uid: asString(json['uid']),
      did: asString(json['did']),
      nickname: asString(json['nickname']),
      avatar: asImageUrl(json['avatar']),
      deleted: entityDeleted(json['deleted']),
      createdAt: asDateTime(json['created_at']),
    );
  }
}
