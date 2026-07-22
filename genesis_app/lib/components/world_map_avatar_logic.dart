import 'world_point.dart';

String worldMapAvatarStableId(UserAvatar avatar) {
  final id = avatar.id.trim();
  if (id.isNotEmpty) return id;

  final name = (avatar.name ?? '').trim();
  return '$name|${avatar.avatarUrl.trim()}|${avatar.initials.trim()}';
}

List<UserAvatar> worldMapVisibleAvatarsForPoint(WorldPoint point) {
  return worldMapDeduplicatedAvatars(point.users);
}

List<UserAvatar> worldMapVisibleAvatarsForLocation(
  WorldMapLocationNode? location,
) {
  if (location == null) return const <UserAvatar>[];
  return worldMapVisibleAvatarsForPoint(location.point);
}

List<UserAvatar> worldMapDeduplicatedAvatars(Iterable<UserAvatar> avatars) {
  final visible = <UserAvatar>[];
  final seen = <String>{};
  for (final avatar in avatars) {
    if (!seen.add(worldMapAvatarStableId(avatar))) continue;
    visible.add(avatar);
  }
  return List<UserAvatar>.unmodifiable(visible);
}
