part of 'developer_page.dart';

extension _DeveloperWorldHistoryActions on _DeveloperPageContentState {
  Future<void> _loadWorldHistoryAccess() async {
    final sessionStore = AppServicesScope.read(context).sessionStore;
    final session = await sessionStore.readCompleteSession();
    if (!mounted) return;
    _updateState(() {
      _hasWorldHistoryAccess = session != null;
      _loadingWorldHistoryAccess = false;
    });
  }

  Future<void> _fetchWorldHistorySettings() {
    return _runWorldHistoryAction(
      action: 'fetch',
      successMessage: 'World History watermarks loaded',
      request: () =>
          AppServicesScope.read(context).api.v1.user.worldHistorySettings(),
    );
  }

  Future<void> _updateWorldHistorySettings() async {
    final values = _parseWorldHistoryWatermarks(
      highWatermarkInput: _worldHistoryHighWatermarkController.text,
      lowWatermarkInput: _worldHistoryLowWatermarkController.text,
    );
    if (values == null) return;
    FocusScope.of(context).unfocus();
    await _runWorldHistoryAction(
      action: 'update',
      successMessage: 'World History watermarks updated',
      request: () =>
          AppServicesScope.read(context).api.v1.user.updateWorldHistorySettings(
            highWatermark: values.highWatermark,
            lowWatermark: values.lowWatermark,
          ),
    );
  }

  Future<void> _resetWorldHistorySettings() {
    FocusScope.of(context).unfocus();
    return _runWorldHistoryAction(
      action: 'delete',
      successMessage: 'World History watermarks reset',
      request: () => AppServicesScope.read(
        context,
      ).api.v1.user.resetWorldHistorySettings(),
    );
  }

  Future<void> _runWorldHistoryAction({
    required String action,
    required String successMessage,
    required Future<WorldHistorySettings> Function() request,
  }) async {
    if (_worldHistoryBusyAction != null) return;
    _updateState(() => _worldHistoryBusyAction = action);
    try {
      final settings = await request();
      if (!mounted) return;
      _worldHistoryHighWatermarkController.text = '${settings.highWatermark}';
      _worldHistoryLowWatermarkController.text = '${settings.lowWatermark}';
      _updateState(() => _worldHistorySettings = settings);
      showGenesisToast(context, successMessage);
    } catch (error) {
      if (mounted) {
        showGenesisToast(context, 'World History request failed: $error');
      }
    } finally {
      if (mounted) _updateState(() => _worldHistoryBusyAction = null);
    }
  }

  _WorldHistoryWatermarkValues? _parseWorldHistoryWatermarks({
    required String highWatermarkInput,
    required String lowWatermarkInput,
  }) {
    final highWatermark = int.tryParse(highWatermarkInput.trim());
    final lowWatermark = int.tryParse(lowWatermarkInput.trim());
    if (highWatermark == null || lowWatermark == null) {
      showGenesisToast(context, 'Enter both watermarks as whole numbers');
      return null;
    }
    if (highWatermark < 20 || highWatermark > 30) {
      showGenesisToast(context, 'high_watermark must be between 20 and 30');
      return null;
    }
    if (lowWatermark < 10 || lowWatermark > 20) {
      showGenesisToast(context, 'low_watermark must be between 10 and 20');
      return null;
    }
    return _WorldHistoryWatermarkValues(
      highWatermark: highWatermark,
      lowWatermark: lowWatermark,
    );
  }
}

class _WorldHistoryWatermarkValues {
  const _WorldHistoryWatermarkValues({
    required this.highWatermark,
    required this.lowWatermark,
  });

  final int highWatermark;
  final int lowWatermark;
}
