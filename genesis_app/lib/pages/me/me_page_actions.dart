part of 'me_page.dart';

extension _MePageActions on _MePageState {
  Future<void> _login(IdentityProvider provider) => submitLogin(provider, (
    submission,
  ) async {
    final login = widget.onLogin;
    if (login == null) {
      showGenesisToast(
        context,
        GenesisL10n.current.homeSignInUnavailable,
        brightness: Brightness.dark,
      );
      return;
    }
    final sessionRevisionBeforeLogin = _sessionRevisionListenable?.value;
    try {
      final ok = await login(provider);
      if (!submission.isActive) return;
      if (ok) submission.markSucceeded();
      if (!mounted) return;
      if (ok) {
        if (_sessionRevisionListenable?.value == sessionRevisionBeforeLogin) {
          _updateState(() {
            _future = _loadData();
          });
        }
        final onLoginCompleted = widget.onLoginCompleted;
        if (onLoginCompleted != null) {
          unawaited(_runPostLoginFlow(onLoginCompleted));
        }
      } else {
        showGenesisToast(
          context,
          GenesisL10n.current.meSignInFailed,
          brightness: Brightness.dark,
        );
      }
    } on AuthCancelledException {
      // User cancelled provider UI.
    } catch (e, st) {
      debugPrint('[Auth][MePage] login failed: $e');
      debugPrint('[Auth][MePage] stacktrace:\n$st');
      if (!mounted || !submission.isActive) return;
      showGenesisToast(
        context,
        loginErrorMessage(e),
        brightness: Brightness.dark,
      );
    }
  });

  Future<void> _runPostLoginFlow(Future<void> Function() flow) async {
    try {
      await flow();
    } catch (e, st) {
      debugPrint('[Auth][MePage] post-login flow failed: $e');
      debugPrint('[Auth][MePage] stacktrace:\n$st');
    }
  }

  Future<void> _openSettings() async {
    final loggedOut = await Navigator.of(context).push<bool>(
      GenesisDarkPageRoute<bool>(builder: (_) => const SettingsPage()),
    );
    if (loggedOut == true) {
      widget.onLoggedOut?.call();
    }
  }

  Widget _buildSettingsButton() => IconButton(
    key: const ValueKey('me-settings-button'),
    onPressed: _openSettings,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    padding: const EdgeInsets.all(12),
    icon: const Icon(Icons.settings, size: 24),
    color: GenesisColors.darkTextPrimary,
  );

  Future<void> _openDiscord() async {
    try {
      final launched = await launchUrl(
        _MePageState._discordUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showGenesisToast(
          context,
          GenesisL10n.current.meFailedOpenDiscord,
          brightness: Brightness.dark,
        );
      }
    } catch (_) {
      if (mounted) {
        showGenesisToast(
          context,
          GenesisL10n.current.meFailedOpenDiscord,
          brightness: Brightness.dark,
        );
      }
    }
  }

  Future<void> _editAvatar() async {
    if (_isUpdatingProfile.value) return;
    final services = AppServicesScope.read(context);
    final editToken = Object();
    _avatarEditToken = editToken;
    bool isCurrent() => mounted && identical(_avatarEditToken, editToken);
    final previousPreview = _avatarPreviewBytes.value;
    _isUpdatingProfile.value = true;
    var failureMessage = GenesisL10n.current.meImagePickFailed;

    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !isCurrent()) return;
      final bytes = await image.readAsBytes();
      if (!isCurrent()) return;
      throwIfGifImage(
        bytes: bytes,
        filename: image.name,
        contentType: image.mimeType ?? '',
      );
      failureMessage = GenesisL10n.current.imageCropUploadFailed;
      final crop = await Navigator.of(context).push<LocalImageCropResult>(
        MaterialPageRoute<LocalImageCropResult>(
          builder: (_) => LocalImageCropPage(
            imageBytes: bytes,
            cropSize: meProfileAvatarUploadSize,
            maxOutputSize: meProfileAvatarUploadSize,
            filename: 'avatar.png',
            contentType: 'image/png',
            uploadOnConfirm: false,
          ),
        ),
      );
      if (crop == null || !isCurrent()) return;
      _avatarPreviewBytes.value = crop.bytes;

      final uploaded = await services.api.v1.upload.image(
        bytes: crop.bytes,
        filename: crop.filename,
        contentType: crop.contentType,
      );
      if (!isCurrent()) return;
      final avatarUrl = asResolvedImageUrl(uploaded, resolveAssetUrl);
      if (avatarUrl.isEmpty) throw StateError('Upload returned an empty URL');

      failureMessage = GenesisL10n.current.meUpdateFailed;
      final response = await services.api.v1.user.update(avatar: avatarUrl);
      if (!isCurrent()) return;
      // A profile refresh started during the edit may still hold the old avatar.
      _loadGeneration += 1;
      final updatedUser = response['user'] is Map
          ? asJsonMap(response['user'])
          : response;
      final updatedAvatar = asResolvedImageUrl(
        updatedUser['avatar'],
        resolveAssetUrl,
      );
      final savedAvatarUrl = updatedAvatar.isEmpty ? avatarUrl : updatedAvatar;
      _avatarUrl.value = savedAvatarUrl;
      try {
        await _cacheUpdatedUserInfo({
          ...updatedUser,
          'avatar': updatedAvatar.isEmpty ? avatarUrl : updatedUser['avatar'],
        }, canSave: isCurrent);
        if (isCurrent()) {
          unawaited(
            services.profileAvatarCache?.replaceFromEdit(
              savedAvatarUrl,
              crop.bytes,
            ),
          );
        }
      } catch (error) {
        debugPrint('[MePage] Could not cache the saved avatar: $error');
      }
    } catch (error) {
      if (!isCurrent()) return;
      _avatarPreviewBytes.value = previousPreview;
      showGenesisToast(
        context,
        error is UnsupportedGifImageException
            ? unsupportedGifImageMessage
            : apiErrorMessage(error, fallback: failureMessage),
        brightness: Brightness.dark,
      );
    } finally {
      if (isCurrent()) {
        _avatarEditToken = null;
        _isUpdatingProfile.value = false;
      }
    }
  }

  Future<void> _editNickName() async {
    if (_isUpdatingProfile.value) return;
    final currentDisplayName = _displayName.value.trim();
    final nickName = await showGenesisDialog<String>(
      context: context,
      builder: (_) => _NickNameDialog(initialValue: currentDisplayName),
    );

    final trimmedName = nickName?.trim() ?? '';
    if (trimmedName.isEmpty || trimmedName == currentDisplayName) return;
    if (!mounted || _isUpdatingProfile.value) return;

    final services = AppServicesScope.read(context);
    await _updateDisplayName(
      update: () => services.api.v1.user.update(name: trimmedName),
      apply: (updatedUser) {
        final updatedName = _mapString(
          updatedUser,
          'name',
          fallback: trimmedName,
        );
        return updatedName;
      },
    );
  }

  Future<void> _updateDisplayName({
    required Future<Map<String, dynamic>> Function() update,
    required String Function(Map<dynamic, dynamic> updatedUser) apply,
  }) async {
    _isUpdatingProfile.value = true;
    try {
      final response = await update();
      final updatedUser = response['user'] is Map
          ? response['user'] as Map
          : response;
      await _cacheUpdatedUserInfo(updatedUser);
      final updatedDisplayName = apply(updatedUser);
      if (!mounted) return;
      _displayName.value = updatedDisplayName;
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(
        context,
        apiErrorMessage(error, fallback: GenesisL10n.current.meUpdateFailed),
        brightness: Brightness.dark,
      );
    } finally {
      if (mounted) _isUpdatingProfile.value = false;
    }
  }

  Future<void> _cacheUpdatedUserInfo(
    Map<dynamic, dynamic> updatedUser, {
    bool Function()? canSave,
  }) async {
    final services = AppServicesScope.read(context);
    final current = await services.sessionStore.readUserInfo();
    final merged = <String, dynamic>{
      if (current != null) ...current,
      for (final entry in updatedUser.entries)
        if (entry.key is String) (entry.key as String): entry.value,
    };
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isNotEmpty) {
      merged.putIfAbsent('uid', () => uid);
    }
    if (canSave?.call() ?? true) {
      await services.sessionStore.saveUserInfo(merged);
    }
  }
}
