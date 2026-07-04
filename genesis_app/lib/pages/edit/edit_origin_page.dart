import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/auth/login_guard.dart';
import '../../components/common/genesis_generation_wait_overlay.dart';
import '../../components/genesis_logo.dart';
import '../../components/page_header.dart';
import '../../network/api_exception.dart';
import '../create/create_origin_draft_store.dart';
import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';
import '../origin_editor/origin_generation_wait_content.dart';
import '../origin_editor/origin_pending_submission_coordinator.dart';
import 'edit_basics_page.dart';
import 'edit_characters_page.dart';
import 'edit_locations_page.dart';
import 'edit_story_events_page.dart';

class EditOriginPage extends StatefulWidget {
  const EditOriginPage({super.key, required this.originId});

  final String originId;

  @override
  State<EditOriginPage> createState() => _EditOriginPageState();
}

class _EditOriginPageState extends State<EditOriginPage> {
  final OriginPendingSubmissionCoordinator _pendingCoordinator =
      OriginPendingSubmissionCoordinator.instance;
  MemoryOriginDraftRepository? _repository;
  final TextEditingController _updateNotesController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  OriginDraftSubmitStatus _submitStatus = OriginDraftSubmitStatus.idle;
  int _reloadSignal = 0;
  late final VoidCallback _removePublishOutcomeListener;
  List<String> _generationWaitLines = const <String>[];

  @override
  void initState() {
    super.initState();
    _pendingCoordinator.publishingState.addListener(_syncSubmitStatus);
    _removePublishOutcomeListener = _pendingCoordinator
        .addPublishOutcomeListener(_handlePublishOutcome);
    _loadOrigin();
  }

  @override
  void dispose() {
    _pendingCoordinator.publishingState.removeListener(_syncSubmitStatus);
    _removePublishOutcomeListener();
    _updateNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadOrigin() async {
    final originId = widget.originId.trim();
    if (originId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'origin_id is required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = AppServicesScope.read(context).api;
      final detail = await api.v1.origin.forEdit(originId: originId);
      if (!mounted) return;
      final initialDraft = originDraftFromV1Detail(detail);
      setState(() {
        _repository = MemoryOriginDraftRepository(initialDraft: initialDraft);
        _generationWaitLines = originDraftGenerationWaitLines(initialDraft);
        _updateNotesController.clear();
        _submitStatus = OriginDraftSubmitStatus.idle;
        _isLoading = false;
      });
      await _pendingCoordinator.ensurePublishingPolling(
        loadOriginInfo: (originId) => api.v1.origin.info(originId: originId),
        context: context,
      );
      _syncSubmitStatus();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Load failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: GenesisBackAppBar(pageName: 'Edit Worldo'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final repository = _repository;
    if (_error != null || repository == null) {
      return Scaffold(
        appBar: const GenesisBackAppBar(pageName: 'Edit Worldo'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ?? 'Worldo detail is unavailable.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadOrigin,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final flow = OriginDraftFlowPage(
      key: ValueKey('edit-origin-${widget.originId}'),
      title: 'Edit Worldo',
      repository: repository,
      basicsPageBuilder: (repository) => EditBasicsPage(repository: repository),
      charactersPageBuilder: (repository) =>
          EditCharactersPage(repository: repository),
      locationsPageBuilder: (repository) =>
          EditLocationsPage(repository: repository),
      storyEventsPageBuilder: (repository) =>
          EditStoryEventsPage(repository: repository),
      canSubmit: repository.hasSubmitChanges,
      submitLabel: 'Publish',
      submittingLabel: 'Publishing...',
      failurePrefix: 'Publish failed',
      leaveTitle: 'Publish changes before leaving?',
      leaveSubmitLabel: 'Publish',
      submitUnavailableMessage: 'No changes to publish.',
      showCurrentVersion: true,
      updateNotesController: _updateNotesController,
      submitStatus: _submitStatus,
      reloadSignal: _reloadSignal,
      onSubmit: _onSave,
    );
    if (_submitStatus == OriginDraftSubmitStatus.idle) return flow;
    return Stack(
      children: [
        flow,
        Positioned.fill(
          child: GenesisGenerationWaitOverlay(
            title: 'Publishing your Worldo',
            illustration: const Center(
              child: GenesisLogo(height: 88, width: 152),
            ),
            perspectiveLines: _generationWaitLines,
          ),
        ),
      ],
    );
  }

  Future<OriginSubmitResult> _onSave(
    BuildContext context,
    OriginDraftRepository repository,
    CreateOriginDraft draft,
  ) async {
    if (!await ensureGenesisLogin(context)) {
      return const OriginSubmitResult(message: '', showMessage: false);
    }
    if (!context.mounted) {
      return const OriginSubmitResult(message: '', showMessage: false);
    }
    final originId = draft.basics.originId.trim();
    final api = AppServicesScope.read(context).api;
    if (mounted) {
      setState(
        () => _generationWaitLines = originDraftGenerationWaitLines(draft),
      );
    }
    final payload = draft.toCreateOriginPayload();
    if (repository is MemoryOriginDraftRepository) {
      payload['deleted_char_ids'] = repository.deletedCharacterIds(draft);
      payload['deleted_location_ids'] = repository.deletedLocationIds(draft);
    }
    payload['update_notes'] = _updateNotesController.text.trim();
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'edit_worldo_submit_start',
      object1: originId,
    );
    final result = await api.updateOrigin(oid: originId, payload: payload);
    final updatedOriginId = result.oid.trim();
    if (updatedOriginId.isEmpty) {
      throw StateError('origin_id is missing from publish response');
    }
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'edit_worldo_submit_success',
      object1: updatedOriginId,
    );
    await _pendingCoordinator.startPublishing(
      originId: updatedOriginId,
      loadOriginInfo: (originId) => api.v1.origin.info(originId: originId),
    );
    return OriginSubmitResult(message: '', showMessage: false);
  }

  void _syncSubmitStatus() {
    if (!mounted) return;
    final state = _pendingCoordinator.publishingState.value;
    final nextStatus = switch (state?.originId == widget.originId
        ? state?.phase
        : null) {
      OriginPendingSubmissionPhase.checkingPending =>
        OriginDraftSubmitStatus.checkingPending,
      OriginPendingSubmissionPhase.processing =>
        OriginDraftSubmitStatus.processing,
      null => OriginDraftSubmitStatus.idle,
    };
    if (_submitStatus == nextStatus) return;
    setState(() => _submitStatus = nextStatus);
  }

  void _handlePublishOutcome(OriginPendingSubmissionOutcome outcome) {
    if (!mounted || outcome.originId != widget.originId) return;
    if (outcome.completed) {
      _repository?.markCurrentAsOriginal();
    }
    setState(() {
      _submitStatus = OriginDraftSubmitStatus.idle;
      _reloadSignal++;
    });
  }
}
