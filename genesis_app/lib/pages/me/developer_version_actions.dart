part of 'developer_page.dart';

extension _DeveloperVersionActions on _DeveloperPageContentState {
  Future<void> _loadVersionOverrides() async {
    final results = await Future.wait<Object>([
      AppMetadataService.buildAppVersion(),
      AppVersionOverrideStore.load(),
    ]);
    if (!mounted) return;
    final buildVersion = results[0] as AppVersionInfo;
    final overrides = results[1] as AppVersionOverrides;
    _versionNameController.text =
        overrides.versionName ?? buildVersion.versionName;
    _versionCodeController.text =
        overrides.versionCode ?? buildVersion.versionCode;
    _updateState(() {
      _hasVersionOverrides = overrides.hasAny;
      _loadingVersionOverrides = false;
    });
  }

  Future<void> _saveVersionOverrides() async {
    if (_loadingVersionOverrides || _savingVersionOverrides) return;
    _updateState(() => _savingVersionOverrides = true);
    try {
      final overrides = AppVersionOverrides(
        versionName: _versionNameController.text,
        versionCode: _versionCodeController.text,
      );
      await AppVersionOverrideStore.save(overrides);
      final storedOverrides = await AppVersionOverrideStore.load();
      final effectiveVersion = await AppMetadataService.appVersion();
      if (!mounted) return;
      _versionNameController.text = effectiveVersion.versionName;
      _versionCodeController.text = effectiveVersion.versionCode;
      _updateState(() {
        _hasVersionOverrides = storedOverrides.hasAny;
        _appVersionFuture = Future<AppVersionInfo>.value(effectiveVersion);
      });
      showGenesisToast(context, 'Saved. New version reads use overrides.');
    } on FormatException catch (error) {
      if (mounted) showGenesisToast(context, error.message);
    } catch (error) {
      if (mounted) showGenesisToast(context, 'Save failed: $error');
    } finally {
      if (mounted) {
        _updateState(() => _savingVersionOverrides = false);
      }
    }
  }

  Future<void> _resetVersionOverrides() async {
    if (_loadingVersionOverrides || _savingVersionOverrides) return;
    _updateState(() => _savingVersionOverrides = true);
    try {
      await AppVersionOverrideStore.clear();
      final buildVersion = await AppMetadataService.buildAppVersion();
      if (!mounted) return;
      _versionNameController.text = buildVersion.versionName;
      _versionCodeController.text = buildVersion.versionCode;
      _updateState(() {
        _hasVersionOverrides = false;
        _appVersionFuture = Future<AppVersionInfo>.value(buildVersion);
      });
      showGenesisToast(context, 'Restored build version');
    } catch (error) {
      if (mounted) showGenesisToast(context, 'Reset failed: $error');
    } finally {
      if (mounted) {
        _updateState(() => _savingVersionOverrides = false);
      }
    }
  }
}
