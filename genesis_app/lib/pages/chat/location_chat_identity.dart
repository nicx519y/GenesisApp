part of 'location_chat_page.dart';

@visibleForTesting
String resolveLocationChatAvatarUrlForTesting({
  required String imageUrl,
  required double devicePixelRatio,
}) {
  final url = imageUrl.trim();
  final resizedUrl = resizeGenesisImageUrl(
    url,
    logicalWidth: _locationChatAvatarLogicalSize,
    devicePixelRatio: devicePixelRatio,
    maxDevicePixelRatio: GenesisImageConfig.chatAvatarMaxDevicePixelRatio,
  );
  return resizedUrl.isNotEmpty ? resizedUrl : url;
}

extension _LocationChatIdentity on _LocationChatPanelState {
  String _messageSenderDisplayName(
    WorldChatroomMessage message, {
    WorldChatroomState? identityState,
  }) {
    final state = identityState ?? _chatroomState;
    return resolveLocationChatMessageSenderNameForTesting(
      senderId: message.senderId,
      senderName: message.senderName,
      characters: state.world?.characters ?? const <Map<String, dynamic>>[],
    );
  }

  bool _messageSenderIsPlayerControlledRole(
    WorldChatroomMessage message, {
    WorldChatroomState? identityState,
  }) {
    return _identityCandidatesArePlayerControlledRole([
      message.userId,
      message.senderId,
    ], identityState: identityState);
  }

  String _messageAvatarUrl(
    WorldChatroomMessage message, {
    WorldChatroomState? identityState,
  }) {
    final state = identityState ?? _chatroomState;
    final avatarUrl = resolveLocationChatMessageAvatarForTesting(
      userId: message.userId,
      senderId: message.senderId,
      characters: state.world?.characters ?? const <Map<String, dynamic>>[],
      entitiesById: state.entitiesById,
    );
    return _resizedLocationChatAvatarUrl(avatarUrl);
  }

  String _resizedLocationChatAvatarUrl(String rawUrl) {
    return resolveLocationChatAvatarUrlForTesting(
      imageUrl: rawUrl,
      devicePixelRatio: _devicePixelRatio,
    );
  }

  String _localSelfDisplayName() {
    return firstNonEmpty([
      _roleNameForIdentityCandidates([_myUserId, _mySenderId]),
      _entityNameForIdentity(_myUserId),
      _entityNameForIdentity(_mySenderId),
      _mySenderName,
    ]);
  }

  String _localSelfAvatarUrl() {
    return firstNonEmpty([
      _entityAvatarForIdentity(_myUserId),
      _entityAvatarForIdentity(_mySenderId),
      _roleAvatarForIdentityCandidates([_myUserId, _mySenderId]),
      _myAvatarUrl,
    ]);
  }

  String _entityNameForIdentity(
    String value, {
    WorldChatroomState? identityState,
  }) {
    final key = _chatroomIdentityKey(value);
    if (key.isEmpty) return '';
    final state = identityState ?? _chatroomState;
    for (final entry in state.entitiesById.entries) {
      if (_chatroomIdentityKey(entry.key) != key) continue;
      return entry.value.name;
    }
    return '';
  }

  bool _identityCandidatesArePlayerControlledRole(
    List<String?> identities, {
    WorldChatroomState? identityState,
  }) {
    final keys = identities
        .map(_chatroomIdentityKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return false;
    final state = identityState ?? _chatroomState;
    for (final entry in state.entitiesById.entries) {
      if (!keys.contains(_chatroomIdentityKey(entry.key))) continue;
      if (entry.value.type == WorldChatroomEntityType.player) return true;
    }
    return _worldHasPlayerControlledRoleForIdentity(keys, state.world);
  }

  String _entityAvatarForIdentity(String value) {
    final key = _chatroomIdentityKey(value);
    if (key.isEmpty) return '';
    for (final entry in _chatroomState.entitiesById.entries) {
      if (_chatroomIdentityKey(entry.key) != key) continue;
      return entry.value.avatarUrl;
    }
    return '';
  }

  bool _worldHasPlayerControlledRoleForIdentity(
    Set<String> identityKeys,
    WorldDetail? world,
  ) {
    if (world == null) return false;
    for (final character in world.characterPositions) {
      if (_characterCandidateIsPlayerControlled(character, identityKeys)) {
        return true;
      }
    }
    for (final character in world.characters) {
      if (_characterCandidateIsPlayerControlled(character, identityKeys)) {
        return true;
      }
    }
    return false;
  }

  bool _characterCandidateIsPlayerControlled(
    Map<String, dynamic> candidate,
    Set<String> identityKeys,
  ) {
    final rawCharacter = candidate['character'];
    final character = rawCharacter is Map
        ? _stringKeyMap(rawCharacter)
        : candidate;
    if (!_characterMatchesIdentity(character, identityKeys)) return false;
    return _firstMapString(character, const [
      'player_uid',
      'user_id',
      'uid',
    ]).isNotEmpty;
  }

  String _roleNameForIdentityCandidates(
    List<String?> identities, {
    WorldChatroomState? identityState,
  }) {
    final keys = identities
        .map(_chatroomIdentityKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return '';
    final world = (identityState ?? _chatroomState).world;
    if (world == null) return '';
    for (final character in world.characterPositions) {
      final candidate = _roleNameFromCharacterCandidate(character, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    for (final character in world.characters) {
      final candidate = _roleNameFromCharacterCandidate(character, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    for (final position in world.userPositions) {
      final candidate = _roleNameFromUserPosition(position, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  String _roleNameFromCharacterCandidate(
    Map<String, dynamic> candidate,
    Set<String> identityKeys,
  ) {
    final rawCharacter = candidate['character'];
    final character = rawCharacter is Map
        ? _stringKeyMap(rawCharacter)
        : candidate;
    if (!_characterMatchesIdentity(character, identityKeys)) return '';
    return _firstMapString(character, const [
      'name',
      'role_nickname',
      'role_name',
      'character_name',
    ]);
  }

  String _roleAvatarForIdentityCandidates(List<String?> identities) {
    final keys = identities
        .map(_chatroomIdentityKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return '';
    final world = _chatroomState.world;
    if (world == null) return '';
    for (final character in world.characterPositions) {
      final candidate = _roleAvatarFromCharacterCandidate(character, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    for (final character in world.characters) {
      final candidate = _roleAvatarFromCharacterCandidate(character, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    for (final position in world.userPositions) {
      final candidate = _roleAvatarFromUserPosition(position, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  String _roleAvatarFromCharacterCandidate(
    Map<String, dynamic> candidate,
    Set<String> identityKeys,
  ) {
    final rawCharacter = candidate['character'];
    final character = rawCharacter is Map
        ? _stringKeyMap(rawCharacter)
        : candidate;
    if (!_characterMatchesIdentity(character, identityKeys)) return '';
    return _firstMapImageUrl(character, const ['avatar', 'avatar_url']);
  }

  String _roleAvatarFromUserPosition(
    Map<String, dynamic> position,
    Set<String> identityKeys,
  ) {
    final rawUser = position['user'];
    final user = rawUser is Map ? _stringKeyMap(rawUser) : position;
    final userId = _firstMapString(user, const ['user_id', 'uid', 'id']);
    final userKey = _chatroomIdentityKey(userId);
    if (userKey.isEmpty || !identityKeys.contains(userKey)) return '';
    return _firstMapImageUrl(user, const ['avatar', 'avatar_url']);
  }

  bool _characterMatchesIdentity(
    Map<String, dynamic> character,
    Set<String> identityKeys,
  ) {
    for (final key in const [
      'player_uid',
      'user_id',
      'uid',
      'character_id',
      'char_id',
      'id',
    ]) {
      final value = _chatroomIdentityKey(_mapString(character, key));
      if (value.isNotEmpty && identityKeys.contains(value)) return true;
    }
    return false;
  }

  String _roleNameFromUserPosition(
    Map<String, dynamic> position,
    Set<String> identityKeys,
  ) {
    final rawUser = position['user'];
    final user = rawUser is Map ? _stringKeyMap(rawUser) : position;
    final userId = _firstMapString(user, const ['user_id', 'uid', 'id']);
    final userKey = _chatroomIdentityKey(userId);
    if (userKey.isEmpty || !identityKeys.contains(userKey)) return '';
    return _firstMapString(user, const [
      'role_nickname',
      'role_name',
      'character_name',
      'name',
    ]);
  }
}
