import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/genesis_navigator.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../create/create_origin_draft_store.dart';
import 'origin_pending_submission_store.dart';

typedef OriginInfoLoader =
    Future<Map<String, dynamic>> Function(String originId);

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
      loadPending: OriginPendingSubmissionStore.loadCreating,
      savePending: OriginPendingSubmissionStore.saveCreating,
      clearPending: OriginPendingSubmissionStore.clearCreating,
      clearDraft: CreateOriginDraftStore.clear,
      timeoutMessage: 'Worldo creation timed out.',
      successTitle: (originName) =>
          'Worldo $originName has been created successfully. ',
      notifyOutcome: _notifyCreateOutcome,
    );
    _publishPoller = _OriginPendingSubmissionPoller(
      kind: OriginPendingSubmissionKind.publish,
      state: publishingState,
      loadPending: OriginPendingSubmissionStore.loadPublishing,
      savePending: OriginPendingSubmissionStore.savePublishing,
      clearPending: OriginPendingSubmissionStore.clearPublishing,
      timeoutMessage: 'Worldo publishing timed out',
      successTitle: (originName) =>
          'Worldo $originName has been published successfully.',
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
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) {
    return _createPoller.start(
      originId: originId,
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
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) {
    return _publishPoller.start(
      originId: originId,
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
    this.clearDraft,
  });

  static const Duration _pollInterval = Duration(seconds: 5);

  final OriginPendingSubmissionKind kind;
  final ValueNotifier<OriginPendingSubmissionRuntimeState?> state;
  final Future<OriginPendingSubmission?> Function() loadPending;
  final Future<void> Function(String originId) savePending;
  final Future<void> Function() clearPending;
  final Future<void> Function()? clearDraft;
  final String timeoutMessage;
  final String Function(String originName) successTitle;
  final ValueChanged<OriginPendingSubmissionOutcome> notifyOutcome;

  Timer? _timer;
  String? _originId;
  OriginInfoLoader? _loadOriginInfo;
  BuildContext? _fallbackContext;
  bool _pollInFlight = false;

  Future<void> start({
    required String originId,
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) async {
    _rememberContext(context);
    await savePending(originId);
    final pending = await loadPending();
    if (pending == null) return;
    _begin(pending: pending, loadOriginInfo: loadOriginInfo);
  }

  Future<void> ensure({
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) async {
    _rememberContext(context);
    final pending = await loadPending();
    if (pending == null) {
      if (_originId == null) state.value = null;
      return;
    }
    if (pending.isExpired) {
      await _handleTimedOut(pending.originId);
      return;
    }
    _begin(pending: pending, loadOriginInfo: loadOriginInfo);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _originId = null;
    _loadOriginInfo = null;
    _fallbackContext = null;
    _pollInFlight = false;
  }

  void _begin({
    required OriginPendingSubmission pending,
    required OriginInfoLoader loadOriginInfo,
    BuildContext? context,
  }) {
    _loadOriginInfo = loadOriginInfo;
    if (context != null && context.mounted) {
      _fallbackContext = context;
    }
    if (_originId == pending.originId &&
        (_pollInFlight || _timer?.isActive == true)) {
      return;
    }
    _timer?.cancel();
    _originId = pending.originId;
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
    }
  }

  Future<void> _poll(OriginPendingSubmission pending) async {
    if (_originId != pending.originId || _pollInFlight) return;
    if (pending.isExpired) {
      await _handleTimedOut(pending.originId);
      return;
    }

    _pollInFlight = true;
    try {
      final loadOriginInfo = _loadOriginInfo;
      if (loadOriginInfo == null) return;
      final info = await loadOriginInfo(pending.originId);
      if (_originId != pending.originId) return;
      final status = _originInfoStatus(info);
      if (status == 10) {
        await _handleCompleted(
          originId: pending.originId,
          originName: _originInfoName(info, fallback: pending.originId),
        );
        return;
      }
    } catch (_) {
      if (_originId != pending.originId) return;
    } finally {
      _pollInFlight = false;
    }

    _scheduleNextPoll(pending);
  }

  void _scheduleNextPoll(OriginPendingSubmission pending) {
    if (_originId != pending.originId) return;
    if (pending.isExpired) {
      unawaited(_handleTimedOut(pending.originId));
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
  }) async {
    cancel();
    await clearPending();
    await clearDraft?.call();
    state.value = null;
    notifyOutcome(
      OriginPendingSubmissionOutcome(
        kind: kind,
        originId: originId,
        completed: true,
      ),
    );

    final shouldGo = await _showSuccessDialog(originName);
    if (shouldGo != true) return;
    final navigator = genesisNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(
      RouteNames.originWorld,
      (_) => false,
      arguments: {'oid': originId, 'originId': 0},
    );
  }

  Future<bool?> _showSuccessDialog(String originName) {
    final context = _globalDialogContext;
    if (context == null) return Future<bool?>.value();
    return showGenesisActionBox<bool>(
      context: context,
      title: successTitle(originName),
      actions: const [GenesisActionBoxAction<bool>(label: 'Go', value: true)],
    );
  }

  Future<void> _handleTimedOut(String originId) async {
    final overlay = genesisNavigatorKey.currentState?.overlay;
    final context = _fallbackContext;
    cancel();
    await clearPending();
    await clearDraft?.call();
    state.value = null;
    notifyOutcome(
      OriginPendingSubmissionOutcome(
        kind: kind,
        originId: originId,
        completed: false,
      ),
    );
    if (overlay != null) {
      showGenesisToastInOverlay(overlay, timeoutMessage);
      return;
    }
    if (context != null && context.mounted) {
      showGenesisToast(context, timeoutMessage);
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
