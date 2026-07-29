part of 'genesis_api.dart';

mixin _GenesisApiAuthOperations on _GenesisApiContext {
  Future<String> ensureUid() => _ensureUid();

  @override
  Future<String> _ensureUid() async {
    final cached = (await _sessionStore.readUid())?.trim() ?? '';
    if (cached.isNotEmpty && !cached.startsWith('guest_')) return cached;
    if (cached.startsWith('guest_')) await _sessionStore.clearUid();
    final user = await bindDevice();
    final uid = user.uid.trim();
    if (uid.isNotEmpty) return uid;
    throw ApiException(message: 'User uid is unavailable');
  }

  Future<User> bindDevice({String? did}) async {
    final deviceId = did ?? await _deviceIdService.getDeviceId();

    try {
      final profileEnvelope = await v1.user.info();
      final profile = asJsonMap(profileEnvelope['user']);
      final uid = asString(
        profile['id'],
        fallback: asString(profile['uid']),
      ).trim();
      if (uid.isEmpty || uid.startsWith('guest_')) {
        await _sessionStore.clearUid();
        return User(
          id: 0,
          uid: '',
          did: deviceId,
          nickname: '',
          avatar: '',
          createdAt: null,
        );
      }
      final user = User(
        id: _stableInt(uid),
        uid: uid,
        did: deviceId,
        nickname: asString(
          profile['display_name'],
          fallback: asString(profile['name']),
        ),
        avatar: _resolveImageAssetUrl(
          profile['avatar_url'],
          fallback: profile['avatar'],
        ),
        createdAt: null,
      );
      await _sessionStore.saveUid(user.uid);
      return user;
    } catch (_) {
      await _sessionStore.clearUid();
      return User(
        id: 0,
        uid: '',
        did: deviceId,
        nickname: '',
        avatar: '',
        createdAt: null,
      );
    }
  }

  Future<bool> hasAuthenticatedSession({bool tryAutoRefresh = true}) async {
    try {
      final profileEnvelope = await v1.user.info();
      final profile = asJsonMap(profileEnvelope['user']);
      final uid = asString(profile['id'], fallback: asString(profile['uid']));
      if (uid.trim().isEmpty || uid.startsWith('guest_')) {
        await _sessionStore.clearUid();
        return false;
      }
      await _sessionStore.saveUid(uid);
      return true;
    } on ApiException catch (e) {
      if (!tryAutoRefresh || !_isAuthFailureStatus(e.statusCode)) {
        return false;
      }

      debugPrint(
        '[Auth][GenesisApi] session check failed with ${e.statusCode}, trying silent refresh',
      );

      final session = await _identityAuthService.refreshSilently();
      if (session == null || !session.hasProviderToken) {
        debugPrint('[Auth][GenesisApi] silent refresh unavailable');
        await _sessionStore.clearUid();
        return false;
      }

      try {
        await loginWithIdentity(session);
      } catch (reauthError, reauthStack) {
        debugPrint('[Auth][GenesisApi] backend re-login failed: $reauthError');
        debugPrint(
          '[Auth][GenesisApi] backend re-login stacktrace:\n$reauthStack',
        );
        return false;
      }

      return hasAuthenticatedSession(tryAutoRefresh: false);
    } catch (_) {
      return false;
    }
  }

  Future<User> getUser(String uid) async {
    final profileEnvelope = await v1.user.info(uid: uid);
    final profile = asJsonMap(profileEnvelope['user']);
    return User(
      id: _stableInt(uid),
      uid: asString(
        profile['id'],
        fallback: asString(profile['uid'], fallback: uid),
      ),
      did: '',
      nickname: asString(
        profile['display_name'],
        fallback: asString(profile['name']),
      ),
      avatar: _resolveImageAssetUrl(
        profile['avatar_url'],
        fallback: profile['avatar'],
      ),
      createdAt: null,
    );
  }

  Future<String> getDisplayUserCode() async {
    final profileEnvelope = await v1.user.info();
    final profile = asJsonMap(profileEnvelope['user']);
    return asString(
      profile['user_code'],
      fallback: asString(profile['id'], fallback: asString(profile['uid'])),
    ).trim();
  }

  Future<User> loginWithGoogle({
    required String idToken,
    String? nonce,
    String? name,
    String? avatar,
  }) {
    return _loginWithGoogle(
      idToken: idToken,
      nonce: nonce,
      name: name,
      avatar: avatar,
    );
  }

  Future<User> loginWithIdentity(AuthSession session) async {
    final user = switch (session.provider) {
      IdentityProvider.google => await _loginWithGoogle(
        idToken: session.providerIdToken,
        name: session.displayName,
        avatar: session.photoUrl,
      ),
      IdentityProvider.apple => await loginWithApple(
        identityToken: session.providerIdToken,
        name: session.displayName,
        avatar: session.photoUrl,
      ),
    };
    final cachedUserInfo = await _sessionStore.readUserInfo();
    await _sessionStore.saveUserInfo({
      if (cachedUserInfo != null) ...cachedUserInfo,
      'login_provider': session.provider.name,
    });
    return user;
  }

  Future<User> _loginWithGoogle({
    required String idToken,
    String? nonce,
    String? name,
    String? avatar,
  }) async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/oauth/google start');
    final json = await v1.user.googleAuth(
      idToken: idToken,
      nonce: nonce,
      name: name,
      avatar: avatar,
    );
    final user = await _persistLoginResponse(json);
    debugPrint(
      '[Auth][GenesisApi] POST /api/v1/user/oauth/google success uid=${user.uid}',
    );
    return user;
  }

  Future<User> loginWithApple({
    required String identityToken,
    String? name,
    String? avatar,
  }) async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/oauth/apple start');
    final json = await v1.user.appleAuth(
      idToken: identityToken.trim(),
      name: name,
      avatar: avatar,
    );
    final user = await _persistLoginResponse(json);
    debugPrint(
      '[Auth][GenesisApi] POST /api/v1/user/oauth/apple success uid=${user.uid}',
    );
    return user;
  }

  Future<void> logout({Map<String, String>? headers}) async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/logout start');
    await v1.user.logout(headers: headers);
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/logout success');
  }

  Future<void> deleteAccount({Map<String, String>? headers}) async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/delete start');
    await v1.user.deleteAccount(headers: headers);
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/delete success');
  }

  Future<User> _persistLoginResponse(Object? json) async {
    final map = asJsonMap(json);
    final userRaw = map['user'];
    final userMap = userRaw is Map ? asJsonMap(userRaw) : map;
    final uid = _loginResponseUid(userMap);
    if (uid.isEmpty || uid.startsWith('guest_')) {
      await _sessionStore.clearUid();
      throw ApiException(message: 'Login response missing user uid');
    }
    final user = User(
      id: _stableInt(uid),
      uid: uid,
      did: '',
      nickname: asString(
        userMap['display_name'],
        fallback: asString(userMap['name']),
      ),
      avatar: _resolveImageAssetUrl(
        userMap['avatar_url'],
        fallback: userMap['avatar'] ?? userMap['picture'],
      ),
      createdAt: null,
    );
    if (user.uid.trim().isNotEmpty) {
      await _sessionStore.saveUid(user.uid);
    }
    final cachedUserInfo = Map<String, dynamic>.from(userMap);
    cachedUserInfo['uid'] = user.uid;
    if (user.nickname.trim().isNotEmpty) {
      cachedUserInfo.putIfAbsent('name', () => user.nickname);
    }
    if (user.avatar.trim().isNotEmpty) {
      cachedUserInfo.putIfAbsent('avatar', () => user.avatar);
    }
    await _sessionStore.saveUserInfo(cachedUserInfo);
    final authToken = asString(
      map['token'],
      fallback: asString(map['access_token'], fallback: asString(map['jwt'])),
    ).trim();
    if (authToken.isNotEmpty) {
      await _sessionStore.saveAuthToken(authToken);
    }
    return user;
  }
}
