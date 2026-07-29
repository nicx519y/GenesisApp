part of 'developer_page.dart';

extension _DeveloperPreviews on _DeveloperPageContentState {
  Future<void> _showCreatingWaitOverlayPreview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.dismissBeforePreview) {
      await widget.onDismissBeforePreview?.call();
    }
    if (!navigator.mounted) return;
    await showGeneralDialog<void>(
      context: navigator.context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return GenesisGenerationWaitOverlay(
          title: 'Creating your Worldo',
          illustration: const Center(
            child: GenesisLogo(height: 88, width: 152),
          ),
          perspectiveLines: _creatingPreviewWaitLines,
          centeredPerspectiveLineCount: 2,
          onBarrierTap: () => Navigator.of(dialogContext).maybePop(),
          onBackPressed: () => Navigator.of(dialogContext).maybePop(),
        );
      },
    );
  }

  Future<void> _showLaunchingWaitOverlayPreview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.dismissBeforePreview) {
      await widget.onDismissBeforePreview?.call();
    }
    final avatars = await _loadPreviewOriginAvatars();
    if (avatars == null) {
      if (navigator.mounted) {
        showGenesisToast(
          navigator.context,
          'Failed to load launch preview origin.',
        );
      }
      return;
    }
    if (!navigator.mounted) return;
    await showGeneralDialog<void>(
      context: navigator.context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return GenesisGenerationWaitOverlay(
          title: _launchPreviewWaitTitle,
          message: _launchPreviewWaitMessage,
          characterAvatars: avatars,
          onBarrierTap: () => Navigator.of(dialogContext).maybePop(),
          onBackPressed: () => Navigator.of(dialogContext).maybePop(),
        );
      },
    );
  }

  Future<void> _showProgressingWaitOverlayPreview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.dismissBeforePreview) {
      await widget.onDismissBeforePreview?.call();
    }
    final avatars = await _loadPreviewOriginAvatars();
    if (avatars == null) {
      if (navigator.mounted) {
        showGenesisToast(
          navigator.context,
          'Failed to load progress preview origin.',
        );
      }
      return;
    }
    if (!navigator.mounted) return;
    await showGeneralDialog<void>(
      context: navigator.context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return GenesisGenerationWaitOverlay(
          title: _progressPreviewWaitTitle,
          message: _progressPreviewWaitMessage,
          characterAvatars: avatars,
          onBarrierTap: () => Navigator.of(dialogContext).maybePop(),
          onBackPressed: () => Navigator.of(dialogContext).maybePop(),
        );
      },
    );
  }

  Future<void> _showGemPurchaseSheetPreview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.dismissBeforePreview) {
      await widget.onDismissBeforePreview?.call();
    }
    if (!navigator.mounted) return;
    final preview = _DeveloperGemPurchasePreview();
    try {
      await showGemPurchaseBottomSheet(
        navigator.context,
        alert: const GemBalanceAlert(
          kind: GemBalanceAlertKind.insufficient,
          balance: 12,
          message: 'Insufficient Gems',
        ),
        productsLoader: () async => preview.products,
        walletStore: preview.walletStore,
        billingService: preview.billing,
      );
    } finally {
      preview.dispose();
    }
  }

  Future<void> _showGemPurchaseOverlayPreview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.dismissBeforePreview) {
      await widget.onDismissBeforePreview?.call();
    }
    if (!navigator.mounted) return;
    await showGemBillingPurchaseOverlayPreview(navigator.context);
  }

  Future<void> _showDailyCheckInPreview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.dismissBeforePreview) {
      await widget.onDismissBeforePreview?.call();
    }
    if (!navigator.mounted) return;
    final checkedIn = await showDailyCheckInDialog(
      navigator.context,
      status: _dailyCheckInPreviewClaimed
          ? DailyCheckInDialogStatus.claimed
          : DailyCheckInDialogStatus.checkIn,
    );
    if (!checkedIn || !navigator.mounted) return;
    if (mounted) {
      _updateState(() => _dailyCheckInPreviewClaimed = true);
    }
    await showDailyCheckInSuccessDialog(navigator.context);
  }

  Future<List<GenesisGenerationWaitAvatar>?> _loadPreviewOriginAvatars() async {
    final api = AppServicesScope.read(context).api;
    try {
      final origin = await api.getOrigin(_launchPreviewOriginId);
      return origin.characters
          .map((character) {
            return GenesisGenerationWaitAvatar(
              name: character.name.trim(),
              url: character.avatar.trim(),
            );
          })
          .where((avatar) => avatar.name.isNotEmpty || avatar.url.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Widget _buildDeviceIdDiagnostics(DeviceIdDiagnostics? diagnostics) {
    final deviceId = _infoValue(diagnostics?.deviceId);
    if (diagnostics?.hasAndroidBreakdown != true) {
      return _DeveloperInfoRow(title: 'Device ID', content: deviceId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeveloperInfoSingleLineRow(
          title: 'ANDROID_ID',
          content: _infoValue(diagnostics?.androidId),
        ),
        const SizedBox(height: _DeveloperPageContentState._itemGap),
        _DeveloperInfoSingleLineRow(
          title: 'AAID',
          content: _infoValue(diagnostics?.aaid),
        ),
        const SizedBox(height: _DeveloperPageContentState._itemGap),
        _DeveloperInfoSingleLineRow(title: 'Device ID', content: deviceId),
      ],
    );
  }

  String _infoValue(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? 'unknown' : trimmed;
  }

  String _versionLabel(AppVersionInfo? versionInfo) {
    final versionName = versionInfo?.versionName.trim() ?? '';
    final versionCode = versionInfo?.versionCode.trim() ?? '';
    final base = AboutUsPage.versionLabel(
      versionName,
    ).replaceFirst(RegExp('^v'), '');
    return versionCode.isEmpty ? base : '$base/$versionCode';
  }

  String _formatAgentControlStatus(AgentControlStatus status) {
    final parts = <String>[status.label];
    final port = status.port;
    if (status.running && port != null) {
      parts.add('${status.host}:$port');
    }
    if (status.enabled) {
      parts.add(
        status.tokenConfigured ? 'token configured' : 'generated token',
      );
      final preview = status.tokenPreview;
      if (preview != null) parts.add(preview);
    }
    final error = status.lastError;
    if (error != null && error.trim().isNotEmpty) {
      parts.add(error);
    }
    return parts.join(' / ');
  }

  Widget _buildGemBalanceInfoRow() {
    final walletState = AppServicesScope.of(context).gemWallet.state;
    return ValueListenableBuilder<GemWalletState>(
      valueListenable: walletState,
      builder: (context, state, _) {
        final balance = state.balance;
        final content = balance == null
            ? (state.isRefreshing ? 'Loading...' : '0')
            : formatGemInteger(balance);
        return _DeveloperInfoSingleLineRow(
          title: 'My Balance',
          content: content,
        );
      },
    );
  }
}
