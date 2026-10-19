import '../../l10n/genesis_l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../ui/components/genesis_localized_rich_text.dart';
import '../../l10n/genesis_localizations.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../app/genesis_navigator.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../platform/session/user_session_store.dart';
import '../create/create_origin_draft_store.dart';
import 'origin_pending_submission_store.dart';

typedef OriginInfoLoader =
    Future<Map<String, dynamic>> Function(String originId);
typedef OriginPendingSubmissionSaver =
    Future<void> Function(
      String ownerUid,
      String originId, {
      String originName,
    });

enum OriginPendingSubmissionKind { create, publish }

enum OriginPendingSubmissionPhase { checkingPending, processing }

class OriginPendingSubmissionRuntimeState {
  const OriginPendingSubmissionRuntimeState({
    required this.kind,
    required this.originId,
    required this.phase,
  });

  final OriginPendingSubmissionKind kind;
  final String originId;
  final OriginPendingSubmissionPhase phase;
}

class OriginPendingSubmissionOutcome {
  const OriginPendingSubmissionOutcome({
    required this.kind,
    required this.originId,
    required this.completed,
  });

  final OriginPendingSubmissionKind kind;
  final String originId;
  final bool completed;
}

class OriginPendingSubmissionCoordinator {
  OriginPendingSubmissionCoordinator._()
    : creatingState = ValueNotifier<OriginPendingSubmissionRuntimeState?>(null),
      publishingState = ValueNotifier<OriginPendingSubmissionRuntimeState?>(
        null,
      ) {
    _createPoller = _OriginPendingSubmissionPoller(
      kind: OriginPendingSubmissionKind.create,
      state: creatingState,
      loadPending: (ownerUid) =>
          OriginPendingSubmissionStore.loadCreating(ownerUid: ownerUid),
      savePending: (ownerUid, originId, {originName = ''}) =>
          OriginPendingSubmissionStore.saveCreating(
            originId,
            originName: originName,
            ownerUid: ownerUid,
          ),
      clearPending: (ownerUid) =>
          OriginPendingSubmissionStore.clearCreating(ownerUid: ownerUid),
      clearDraft: (ownerUid) =>
          CreateOriginDraftStore.clear(ownerUid: ownerUid),
      timeoutMessage: () => GenesisL10n.current.createTimeout,
      completeOnTimeout: true,
      completeOnPollError: true,
      successTitle: (originName) =>
          GenesisL10n.current.worldoCreated(worldName: '#$originName'),
      notifyOutcome: _notifyCreateOutcome,
    );
    _publishPoller = _OriginPendingSubmissionPoller(
      kind: OriginPendingSubmissionKind.publish,
      state: publishingState,
      loadPending: (_) => OriginPendingSubmissionStore.loadPublishing(),
      savePending: (_, originId, {originName = ''}) =>
          OriginPendingSubmissionStore.savePublishing(
            originId,
            originName: originName,
          ),
      clearPending: (_) => OriginPendingSubmissionStore.clearPublishing(),
      timeoutMessage: () => GenesisL10n.current.publishTimeout,
      completeOnTimeout: true,
      completeOnPollError: true,
      successTitle: (originName) =>
          GenesisL10n.current.worldoPublished(worldName: '#$originName'),
      notifyOutcome: _notifyPublishOutcome,
    );
  }

  static final OriginPendingSubmissionCoordinator instance =
      OriginPendingSubmissionCoordinator._();

  final ValueNotifier<OriginPendingSubmissionRuntimeState?> creatingState;
  final ValueNotifier<OriginPendingSubmissionRuntimeState?> publishingState;

  final Set<ValueChanged<OriginPendingSubmissionOutcome>>
  _createOutcomeListeners = <ValueChanged<OriginPendingSubmissionOutcome>>{};
  final Set<ValueChanged<OriginPendingSubmissionOutcome>>
  _publishOutcomeListeners = <ValueChanged<OriginPendingSubmissionOutcome>>{};

  late final _OriginPendingSubmissionPoller _createPoller;
  late final _OriginPendingSubmissionPoller _publishPoller;

  VoidCallback addCreateOutcomeListener(
    ValueChanged<OriginPendingSubmissionOutcome> listener,
  ) {
    _createOutcomeListeners.add(listener);
    return () => _createOutcomeListeners.remove(listener);
  }

  VoidCallback addPublishOutcomeListener(
    ValueChanged<OriginPendingSubmissionOutcome> listener,
  ) {
    _publishOutcomeListeners.add(listener);
    return () => _publishOutcomeListeners.remove(listener);
  }

  Future<void> startCreating({
    required String originId,
    String originName = '',
    String? ownerUid,
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) {
    return _createPoller.start(
      originId: originId,
      originName: originName,
      ownerUid: ownerUid,
      loadOriginInfo: loadOriginInfo,
      context: context,
    );
  }

  Future<void> ensureCreatingPolling({
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) {
    return _createPoller.ensure(
      loadOriginInfo: loadOriginInfo,
      context: context,
    );
  }

  Future<void> startPublishing({
    required String originId,
    String originName = '',
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) {
    return _publishPoller.start(
      originId: originId,
      originName: originName,
      loadOriginInfo: loadOriginInfo,
      context: context,
    );
  }

  Future<void> ensurePublishingPolling({
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) {
    return _publishPoller.ensure(
      loadOriginInfo: loadOriginInfo,
      context: context,
    );
  }

  void resetForTesting() {
    _createPoller.cancel();
    _publishPoller.cancel();
    creatingState.value = null;
    publishingState.value = null;
    _createOutcomeListeners.clear();
    _publishOutcomeListeners.clear();
  }

  void _notifyCreateOutcome(OriginPendingSubmissionOutcome outcome) {
    for (final listener in List.of(_createOutcomeListeners)) {
      listener(outcome);
    }
  }

  void _notifyPublishOutcome(OriginPendingSubmissionOutcome outcome) {
    for (final listener in List.of(_publishOutcomeListeners)) {
      listener(outcome);
    }
  }
}

class _OriginPendingSubmissionPoller {
  _OriginPendingSubmissionPoller({
    required this.kind,
    required this.state,
    required this.loadPending,
    required this.savePending,
    required this.clearPending,
    required this.timeoutMessage,
    required this.successTitle,
    required this.notifyOutcome,
    this.completeOnTimeout = false,
    this.completeOnPollError = false,
    this.clearDraft,
  });

  static const Duration _pollInterval = Duration(seconds: 10);

  final OriginPendingSubmissionKind kind;
  final ValueNotifier<OriginPendingSubmissionRuntimeState?> state;
  final Future<OriginPendingSubmission?> Function(String ownerUid) loadPending;
  final OriginPendingSubmissionSaver savePending;
  final Future<void> Function(String ownerUid) clearPending;
  final Future<void> Function(String ownerUid)? clearDraft;
  final String Function() timeoutMessage;
  final String Function(String originName) successTitle;
  final ValueChanged<OriginPendingSubmissionOutcome> notifyOutcome;
  final bool completeOnTimeout;
  final bool completeOnPollError;

  Timer? _timer;
  String? _originId;
  String? _ownerUid;
  String? _originName;
  OriginInfoLoader? _loadOriginInfo;
  BuildContext? _fallbackContext;
  UserSessionStore? _sessionStore;
  bool _pollInFlight = false;
  int _pollRevision = 0;

  Future<void> start({
    required String originId,
    String originName = '',
    String? ownerUid,
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) async {
    _rememberContext(context);
    final pendingOwner = ownerUid ?? await _currentOwner();
    final resolvedOriginId = originId.trim();
    if (resolvedOriginId.isEmpty) {
      throw StateError('origin_id is missing from accepted upsert response');
    }
    final resolvedOriginName = originName.trim().isEmpty
        ? resolvedOriginId
        : originName.trim();
    OriginPendingSubmission? pending;
    try {
      await savePending(
        pendingOwner,
        resolvedOriginId,
        originName: resolvedOriginName,
      );
      pending = await loadPending(pendingOwner);
    } catch (_) {
      if (!completeOnPollError) rethrow;
      await _handleCompleted(
        originId: resolvedOriginId,
        originName: resolvedOriginName,
        ownerUid: pendingOwner,
      );
      return;
    }
    if (pending == null) {
      if (!completeOnPollError) return;
      await _handleCompleted(
        originId: resolvedOriginId,
        originName: resolvedOriginName,
        ownerUid: pendingOwner,
      );
      return;
    }
    _begin(
      pending: pending,
      loadOriginInfo: loadOriginInfo,
      context: context != null && context.mounted ? context : null,
    );
  }

  Future<void> ensure({
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) async {
    _rememberContext(context);
    final ownerUid = await _currentOwner();
    final pending = await loadPending(ownerUid);
    if (pending == null) {
      if (_originId != null && _ownerUid != ownerUid) cancel();
      if (_originId == null) state.value = null;
      return;
    }
    if (pending.isExpired) {
      await _handleExpired(pending);
      return;
    }
    _begin(
      pending: pending,
      loadOriginInfo: loadOriginInfo,
      context: context != null && context.mounted ? context : null,
    );
  }

  void cancel() {
    _pollRevision += 1;
    _timer?.cancel();
    _timer = null;
    _originId = null;
    _ownerUid = null;
    _originName = null;
    _loadOriginInfo = null;
    _fallbackContext = null;
    _sessionStore = null;
    _pollInFlight = false;
  }

  void _begin({
    required OriginPendingSubmission pending,
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) {
    if (_originId == pending.originId &&
        _ownerUid == pending.ownerUid &&
        (_pollInFlight || _timer?.isActive == true)) {
      return;
    }
    if (_originId != null &&
        (_originId != pending.originId || _ownerUid != pending.ownerUid)) {
      cancel();
    }
    _rememberContext(context);
    _loadOriginInfo = loadOriginInfo;
    _timer?.cancel();
    _originId = pending.originId;
    _ownerUid = pending.ownerUid;
    _originName = pending.originName.trim().isEmpty
        ? pending.originId
        : pending.originName.trim();
    state.value = OriginPendingSubmissionRuntimeState(
      kind: kind,
      originId: pending.originId,
      phase: OriginPendingSubmissionPhase.checkingPending,
    );
    unawaited(_poll(pending));
  }

  void _rememberContext(BuildContext? context) {
    if (context != null && context.mounted) {
      _fallbackContext = context;
      _sessionStore = AppServicesScope.maybeRead(context)?.sessionStore;
    }
  }

  Future<String> _currentOwner() => kind == OriginPendingSubmissionKind.create
      ? CreateOriginDraftStore.readOwnerUid(sessionStore: _sessionStore)
      : Future.value(CreateOriginDraftStore.anonymousOwner);

  Future<bool> _ownerStillCurrent(String ownerUid) async {
    try {
      return await _currentOwner() == ownerUid;
    } catch (_) {
      // An unreadable session must never let an old poll affect a new owner.
      return false;
    }
  }

  Future<void> _poll(OriginPendingSubmission pending) async {
    if (_originId != pending.originId ||
        _ownerUid != pending.ownerUid ||
        _pollInFlight) {
      return;
    }
    final pollRevision = _pollRevision;
    if (pending.isExpired) {
      await _handleExpired(pending);
      return;
    }

    _pollInFlight = true;
    try {
      if (kind == OriginPendingSubmissionKind.create &&
          !await _ownerStillCurrent(pending.ownerUid)) {
        if (pollRevision == _pollRevision) {
          cancel();
          state.value = null;
        }
        return;
      }
      if (pollRevision != _pollRevision || _ownerUid != pending.ownerUid) {
        return;
      }
      final loadOriginInfo = _loadOriginInfo;
      if (loadOriginInfo == null) return;
      final info = await loadOriginInfo(pending.originId);
      if (pollRevision != _pollRevision || _ownerUid != pending.ownerUid) {
        return;
      }
      if (kind == OriginPendingSubmissionKind.create &&
          !await _ownerStillCurrent(pending.ownerUid)) {
        cancel();
        state.value = null;
        return;
      }
      final status = _originInfoStatus(info);
      if (status == 10) {
        await _handleCompleted(
          originId: pending.originId,
          originName: _originInfoName(
            info,
            fallback: _completionOriginName(pending),
          ),
          ownerUid: pending.ownerUid,
        );
        return;
      }
    } catch (_) {
      if (pollRevision != _pollRevision || _ownerUid != pending.ownerUid) {
        return;
      }
      if (kind == OriginPendingSubmissionKind.create &&
          !await _ownerStillCurrent(pending.ownerUid)) {
        cancel();
        state.value = null;
        return;
      }
      if (completeOnPollError) {
        await _handleCompleted(
          originId: pending.originId,
          originName: _completionOriginName(pending),
          ownerUid: pending.ownerUid,
        );
        return;
      }
    } finally {
      if (pollRevision == _pollRevision) _pollInFlight = false;
    }

    if (pollRevision == _pollRevision) _scheduleNextPoll(pending);
  }

  void _scheduleNextPoll(OriginPendingSubmission pending) {
    if (_originId != pending.originId || _ownerUid != pending.ownerUid) return;
    if (pending.isExpired) {
      unawaited(_handleExpired(pending));
      return;
    }
    state.value = OriginPendingSubmissionRuntimeState(
      kind: kind,
      originId: pending.originId,
      phase: OriginPendingSubmissionPhase.processing,
    );
    _timer?.cancel();
    _timer = Timer(_pollInterval, () => unawaited(_poll(pending)));
  }

  Future<void> _handleCompleted({
    required String originId,
    required String originName,
    required String ownerUid,
  }) async {
    final sessionStore = _sessionStore;
    final affectsActive =
        _originId == null || (_originId == originId && _ownerUid == ownerUid);
    if (affectsActive) cancel();
    await _runBestEffort(() => clearPending(ownerUid));
    final clearDraftAction = clearDraft;
    if (clearDraftAction != null) {
      await _runBestEffort(() => clearDraftAction(ownerUid));
    }
    if (affectsActive) state.value = null;
    if (kind == OriginPendingSubmissionKind.create &&
        await CreateOriginDraftStore.readOwnerUid(sessionStore: sessionStore) !=
            ownerUid) {
      return;
    }
    notifyOutcome(
      OriginPendingSubmissionOutcome(
        kind: kind,
        originId: originId,
        completed: true,
      ),
    );
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: switch (kind) {
        OriginPendingSubmissionKind.create => 'create_worldo_async_complete',
        OriginPendingSubmissionKind.publish => 'edit_worldo_async_complete',
      },
      object1: originId,
    );

    final shouldGo = await _showSuccessDialog(originName);
    if (shouldGo != true) return;
    if (kind == OriginPendingSubmissionKind.create &&
        await CreateOriginDraftStore.readOwnerUid(sessionStore: sessionStore) !=
            ownerUid) {
      return;
    }
    final navigator = genesisNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(RouteNames.home, (_) => false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      navigator.pushNamed(
        RouteNames.originWorld,
        arguments: {'oid': originId, 'originId': 0, 'initialName': originName},
      );
    });
  }

  Future<bool?> _showSuccessDialog(String originName) {
    final context = _globalDialogContext;
    if (context == null) return Future<bool?>.value();
    final title = successTitle(originName);
    return showGenesisActionBox<bool>(
      context: context,
      title: title,
      titleWidget: _successActionBoxTitle(
        template: kind == OriginPendingSubmissionKind.create
            ? context.l10n.worldoCreated(
                worldName: GenesisLocalizedRichText.placeholder('worldName'),
              )
            : context.l10n.worldoPublished(
                worldName: GenesisLocalizedRichText.placeholder('worldName'),
              ),
        highlightedText: '#$originName',
      ),
      actions: [
        GenesisActionBoxAction<bool>(
          label: GenesisL10n.current.createView,
          value: true,
        ),
      ],
    );
  }

  Future<void> _handleExpired(OriginPendingSubmission pending) {
    if (!completeOnTimeout) {
      return _handleTimedOut(pending.originId, pending.ownerUid);
    }
    return _handleCompleted(
      originId: pending.originId,
      originName: _completionOriginName(pending),
      ownerUid: pending.ownerUid,
    );
  }

  String _completionOriginName(OriginPendingSubmission pending) {
    final pendingName = pending.originName.trim();
    if (pendingName.isNotEmpty) return pendingName;
    final runtimeName = _originName?.trim() ?? '';
    return runtimeName.isEmpty ? pending.originId : runtimeName;
  }

  Future<void> _runBestEffort(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // The remote upsert already succeeded, so local cleanup cannot turn the
      // completed operation back into a failure.
    }
  }

  Future<void> _handleTimedOut(String originId, String ownerUid) async {
    final overlay = genesisNavigatorKey.currentState?.overlay;
    final context = _fallbackContext;
    final sessionStore = _sessionStore;
    final affectsActive =
        _originId == null || (_originId == originId && _ownerUid == ownerUid);
    if (affectsActive) cancel();
    await clearPending(ownerUid);
    if (affectsActive) state.value = null;
    if (kind == OriginPendingSubmissionKind.create &&
        await CreateOriginDraftStore.readOwnerUid(sessionStore: sessionStore) !=
            ownerUid) {
      return;
    }
    notifyOutcome(
      OriginPendingSubmissionOutcome(
        kind: kind,
        originId: originId,
        completed: false,
      ),
    );
    if (overlay != null) {
      showGenesisToastInOverlay(overlay, timeoutMessage());
      return;
    }
    if (context != null && context.mounted) {
      showGenesisToast(context, timeoutMessage());
    }
  }

  BuildContext? get _globalDialogContext {
    final navigator = genesisNavigatorKey.currentState;
    final overlayContext = navigator?.overlay?.context;
    if (overlayContext != null && overlayContext.mounted) {
      return overlayContext;
    }
    final navigatorContext = navigator?.context;
    if (navigatorContext != null && navigatorContext.mounted) {
      return navigatorContext;
    }
    return null;
  }

  int _originInfoStatus(Map<String, dynamic> data) {
    final info = data['info'] is Map ? asJsonMap(data['info']) : data;
    return asInt(info['status']);
  }

  String _originInfoName(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final info = data['info'] is Map ? asJsonMap(data['info']) : data;
    final name = asString(info['origin_name']).trim();
    return name.isEmpty ? fallback : name;
  }
}

Widget _successActionBoxTitle({
  required String template,
  required String highlightedText,
}) {
  const baseStyle = TextStyle(
    fontFamily: GenesisTypography.fontFamily,
    fontFamilyFallback: GenesisTypography.fontFamilyFallback,
    color: GenesisColors.darkTextPrimary,
    fontSize: 15,
    height: 1.16,
    fontWeight: FontWeight.w600,
  );
  return GenesisLocalizedRichText(
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    template: template,
    placeholders: {
      'worldName': TextSpan(
        text: highlightedText,
        style: baseStyle.copyWith(color: GenesisColors.redSecondary),
      ),
    },
    style: baseStyle,
  );
}
