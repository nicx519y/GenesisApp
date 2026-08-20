part of 'user_profile_library.dart';

class UserProfileCollectionState<T> {
  const UserProfileCollectionState({
    required this.items,
    required this.isLoading,
    this.total = 0,
  });

  final List<T> items;
  final bool isLoading;
  final int total;
}

class UserProfileData {
  const UserProfileData({
    required this.avatarUrl,
    required this.displayName,
    required this.uid,
    required this.followingCount,
    required this.followerCount,
    this.isSelf = true,
    this.isFollowed = false,
    this.deleted = false,
    required this.origins,
    required this.worlds,
  });

  final String avatarUrl;
  final String displayName;
  final String uid;
  final int followingCount;
  final int followerCount;
  final bool isSelf;
  final bool isFollowed;
  final bool deleted;
  final List<UserProfileOriginItem> origins;
  final List<UserProfileWorldItem> worlds;

  UserProfileData copyWith({
    String? avatarUrl,
    String? displayName,
    String? uid,
    int? followingCount,
    int? followerCount,
    bool? isSelf,
    bool? isFollowed,
    bool? deleted,
    List<UserProfileOriginItem>? origins,
    List<UserProfileWorldItem>? worlds,
  }) {
    return UserProfileData(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      uid: uid ?? this.uid,
      followingCount: followingCount ?? this.followingCount,
      followerCount: followerCount ?? this.followerCount,
      isSelf: isSelf ?? this.isSelf,
      isFollowed: isFollowed ?? this.isFollowed,
      deleted: deleted ?? this.deleted,
      origins: origins ?? this.origins,
      worlds: worlds ?? this.worlds,
    );
  }
}
