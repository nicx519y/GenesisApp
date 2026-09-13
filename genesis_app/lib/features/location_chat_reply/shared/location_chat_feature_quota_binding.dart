part of '../../../pages/chat/location_chat_page.dart';

extension _LocationChatFeatureQuotaBinding on _LocationChatPanelState {
  void _bindFeatureQuotas(AppServices services) {
    if (identical(services, _quotaServices)) return;
    if (_quotaServices != null) {
      if (_editQuotaChecking || _editQuotaLoading) {
        _editQuotaChecking = false;
        _editQuotaLoading = false;
        _preparingReplyAction = false;
      }
      _resetInspiration();
    }
    _unbindFeatureQuotas();
    _quotaServices = services;
    _featureQuotas = services.featureQuotas;
    services.featureQuotas.addListener(_onFeatureQuotasChanged);
    services.sessionRevision.addListener(_onFeatureQuotaSessionChanged);
    _editQuotaQueried = false;
    _inspirationQuotaQueried = false;
  }

  void _unbindFeatureQuotas() {
    _featureQuotas?.removeListener(_onFeatureQuotasChanged);
    _quotaServices?.sessionRevision.removeListener(
      _onFeatureQuotaSessionChanged,
    );
    _featureQuotas = null;
    _quotaServices = null;
  }

  void _onFeatureQuotasChanged() {
    if (mounted) _setReplyControlsState(() {});
  }

  void _onFeatureQuotaSessionChanged() {
    if (!mounted) return;
    _setReplyControlsState(() {
      _editQuotaQueried = false;
      _inspirationQuotaQueried = false;
      if (_editQuotaChecking || _editQuotaLoading) {
        _editQuotaChecking = false;
        _editQuotaLoading = false;
        _preparingReplyAction = false;
      }
      _resetInspiration();
    });
  }

  int? _freeUsesRemaining(String feature, {required bool queried}) {
    final store = _featureQuotas;
    if (!queried || store == null || store.isMember == true) return null;
    final quota = store.quotaFor(feature);
    return quota == null || quota.unlimited ? null : quota.remaining;
  }

  /// Called only from a deliberate Edit invocation or inspiration expansion.
  Future<bool> _checkReplyFeatureQuota(
    String feature, {
    required bool Function() current,
    required VoidCallback onQuotaLookupStarted,
  }) async {
    final services = _quotaServices;
    if (services == null) return false;
    final session = services.sessionRevision.value;
    bool stillCurrent() =>
        current() &&
        identical(services, _quotaServices) &&
        session == services.sessionRevision.value;
    final member = Completer<bool?>();
    services.membership.checkVip(member.complete);
    final isMember = await member.future;
    if (!stillCurrent()) return false;
    if (isMember == true) {
      services.featureQuotas.confirmMembership(true);
      return true;
    }
    if (isMember == false) {
      final cachedQuota = services.featureQuotas.quotaFor(feature);
      if (cachedQuota != null &&
          !cachedQuota.unlimited &&
          cachedQuota.remaining == 0) {
        _revealReplyFeatureQuota(feature);
        return false;
      }
    }
    try {
      onQuotaLookupStarted();
      await services.featureQuotas.fetch();
      if (!stillCurrent()) return false;
      final quota = services.featureQuotas.quotaFor(feature);
      if (quota == null || (!quota.unlimited && quota.remaining == null)) {
        throw ApiException(
          message: 'Could not check free uses. Please try again.',
          kind: ApiExceptionKind.response,
        );
      }
      _revealReplyFeatureQuota(feature);
      return quota.unlimited || (quota.remaining ?? 0) > 0;
    } catch (error) {
      if (mounted &&
          stillCurrent() &&
          !(error is ApiException && error.code == 10001)) {
        showGenesisToast(context, chatroomOperationErrorMessage(error));
      }
      return false;
    }
  }

  void _revealReplyFeatureQuota(String feature) {
    _setReplyControlsState(() {
      if (feature == 'conversation_edit') {
        _editQuotaQueried = true;
      } else {
        _inspirationQuotaQueried = true;
      }
    });
    _scrollCoordinator.requestBottom(
      reason: feature == 'conversation_edit'
          ? LocationChatBottomReason.editPromptExpanded
          : LocationChatBottomReason.inspirationExpanded,
      behavior: LocationChatBottomBehavior.animate,
    );
  }
}
