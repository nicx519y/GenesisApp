import 'package:flutter/foundation.dart';

import '../json_utils.dart';

@immutable
class User {
  const User({
    required this.id,
    required this.uid,
    required this.did,
    required this.nickname,
    required this.avatar,
    required this.createdAt,
  });

  final int id;
  final String uid;
  final String did;
  final String nickname;
  final String avatar;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: asInt(json['id']),
      uid: asString(json['uid']),
      did: asString(json['did']),
      nickname: asString(json['nickname']),
      avatar: asImageUrl(json['avatar']),
      createdAt: asDateTime(json['created_at']),
    );
  }
}
