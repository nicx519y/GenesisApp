part of 'user_profile_library.dart';

class UserProfileCollectionState<T> {
  const UserProfileCollectionState({
    required this.items,
    required this.isLoading,
    this.total,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<T> items;
  final bool isLoading;
  final int? total;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  int get count => total ?? items.length;
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
    this.gender = '',
    this.age = '',
    this.membershipStatus = 0,
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
  final String gender;
  final String age;
  final int membershipStatus;
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
    String? gender,
    String? age,
    int? membershipStatus,
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
      gender: gender ?? this.gender,
      age: age ?? this.age,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      origins: origins ?? this.origins,
      worlds: worlds ?? this.worlds,
    );
  }
}
