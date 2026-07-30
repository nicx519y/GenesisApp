part of 'developer_page.dart';

extension _DeveloperEndpointActions on _DeveloperPageContentState {
  void _handleEndpointTextChanged() {
    if (!mounted) return;
    _updateState(() {});
  }

  Future<void> _loadEndpointOverrides() async {
    final overrides = await AppEndpointOverrideStore.load();
    if (!mounted) return;
    _apiBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
      overrides.apiBaseUrl ?? overrides.chatroomHttpBaseUrl,
    );
    _gatewayApiBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
      overrides.gatewayApiBaseUrl,
    );
    _chatroomWsBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
      overrides.chatroomWsBaseUrl,
    );
    _updateState(() => _loadingEndpointOverrides = false);
  }

  Future<void> _clearDirectMessageCache() async {
    if (_clearingDirectMessageCache) return;
    _updateState(() => _clearingDirectMessageCache = true);
    final services = AppServicesScope.read(context);
    try {
      await services.directMessageConversations.clearCache();
      await services.directMessageMessages.clearCache();
      if (!mounted) return;
      showGenesisToast(context, 'Direct message cache cleared');
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(context, 'Clear failed: $error');
    } finally {
      if (mounted) {
        _updateState(() => _clearingDirectMessageCache = false);
      }
    }
  }

  Future<void> _clearImageCache() async {
    if (_clearingImageCache) return;
    _updateState(() => _clearingImageCache = true);
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await GenesisHttpCacheManager().emptyCache();
      if (!mounted) return;
      showGenesisToast(context, 'Image cache cleared');
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(context, 'Clear failed: $error');
    } finally {
      if (mounted) {
        _updateState(() => _clearingImageCache = false);
      }
    }
  }

  Future<void> _clearGatewayAuth() async {
    if (_clearingGatewayAuth) return;
    _updateState(() => _clearingGatewayAuth = true);
    try {
      await clearGatewayAuthLocalState();
      if (!mounted) return;
      final config = AppServicesScope.read(context).config;
      AppServicesScope.replaceWithConfig(context, config);
      showGenesisToast(context, 'Gateway auth cleared');
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(context, 'Clear failed: $error');
    } finally {
      if (mounted) {
        _updateState(() => _clearingGatewayAuth = false);
      }
    }
  }

  Future<void> _verifyGatewaySignature() async {
    if (_verifyingGatewaySignature) return;
    _updateState(() {
      _verifyingGatewaySignature = true;
      _gatewaySignatureVerifyResult = 'Testing...';
    });
    try {
      final coordinator = AppServicesScope.read(context).gatewayAuth;
      if (coordinator == null) {
        throw StateError('Gateway auth is unavailable in mock mode.');
      }
      final response = await coordinator.verifyLocalSignature();
      final output = 'HTTP ${response.statusCode}\n${response.prettyBody()}';
      debugPrint('[GatewayAuth][SignatureVerify]\n$output');
      if (!mounted) return;
      _updateState(() => _gatewaySignatureVerifyResult = output);
      showGenesisToast(context, 'Gateway signature verify completed');
    } catch (error) {
      debugPrint('[GatewayAuth][SignatureVerify] failed: $error');
      if (!mounted) return;
      final output = 'Failed: $error';
      _updateState(() => _gatewaySignatureVerifyResult = output);
      showGenesisToast(context, output);
    } finally {
      if (mounted) {
        _updateState(() => _verifyingGatewaySignature = false);
      }
    }
  }

  Future<bool> _saveEndpointOverrides({
    String? successMessage,
    bool signOutCurrentSession = false,
  }) async {
    if (_savingEndpointOverrides || _loadingEndpointOverrides) return false;
    _updateState(() => _savingEndpointOverrides = true);
    try {
      final currentServices = AppServicesScope.read(context);
      final overrides = AppEndpointOverrides(
        apiBaseUrl: AppEndpointOverrideStore.normalizeHttpsApiBaseUrl(
          _apiBaseUrlController.text,
        ),
        gatewayApiBaseUrl:
            AppEndpointOverrideStore.normalizeHttpsGatewayApiBaseUrl(
              _gatewayApiBaseUrlController.text,
            ),
        chatroomHttpBaseUrl: AppEndpointOverrideStore.normalizeHttpsBaseUrl(
          _apiBaseUrlController.text,
        ),
        chatroomWsBaseUrl: AppEndpointOverrideStore.normalizeWssBaseUrl(
          _chatroomWsBaseUrlController.text,
        ),
      );
      await AppEndpointOverrideStore.save(overrides);
      if (signOutCurrentSession) {
        await currentServices.backendAuth.signOut();
      }
      if (!mounted) return false;
      final config = overrides.applyTo(const AppConfig());
      final updatedServices = AppServicesScope.replaceWithConfig(
        context,
        config,
      );
      if (signOutCurrentSession) {
        updatedServices.notifySessionChanged();
      }
      _apiBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
        overrides.apiBaseUrl,
      );
      _gatewayApiBaseUrlController.text =
          AppEndpointOverrideStore.displayDomain(overrides.gatewayApiBaseUrl);
      _chatroomWsBaseUrlController.text =
          AppEndpointOverrideStore.displayDomain(overrides.chatroomWsBaseUrl);
      showGenesisToast(
        context,
        successMessage ?? 'Saved. New requests use endpoints.',
      );
      return true;
    } on FormatException catch (error) {
      if (mounted) {
        showGenesisToast(context, error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        showGenesisToast(context, 'Save failed: $error');
      }
      return false;
    } finally {
      if (mounted) {
        _updateState(() => _savingEndpointOverrides = false);
      }
    }
  }

  void _hideDebugButton() {
    hideGenesisDebugFloatingButton();
    Navigator.of(context).maybePop();
  }

  bool get _isUsingTestEndpointHost {
    return _effectiveEndpointHost(_apiBaseUrlController) ==
            _DeveloperPageContentState._testEndpointHost &&
        _effectiveEndpointHost(_gatewayApiBaseUrlController) ==
            _DeveloperPageContentState._testEndpointHost &&
        _effectiveEndpointHost(_chatroomWsBaseUrlController) ==
            _DeveloperPageContentState._testEndpointHost;
  }

  String _effectiveEndpointHost(TextEditingController controller) {
    final value = controller.text.trim().toLowerCase();
    return value.isEmpty
        ? _DeveloperPageContentState._defaultEndpointHost
        : value;
  }

  Future<void> _switchEndpointEnvironment() async {
    if (_loadingEndpointOverrides || _savingEndpointOverrides) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final host = _isUsingTestEndpointHost
        ? _DeveloperPageContentState._productionEndpointHost
        : _DeveloperPageContentState._testEndpointHost;
    final successMessage = _isUsingTestEndpointHost ? '已切换到正式环境' : '已切换到测试环境';
    _apiBaseUrlController.text = host;
    _gatewayApiBaseUrlController.text = host;
    _chatroomWsBaseUrlController.text = host;
    final switched = await _saveEndpointOverrides(
      successMessage: successMessage,
      signOutCurrentSession: true,
    );
    if (!switched || !navigator.mounted) return;
    unawaited(
      navigator.pushNamedAndRemoveUntil<void>(RouteNames.me, (_) => false),
    );
  }
}
