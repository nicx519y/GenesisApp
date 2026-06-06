import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/page_header.dart';
import '../../network/api_exception.dart';
import '../create/create_origin_draft_store.dart';
import '../create/create_origin_id_utils.dart';
import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';
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
  MemoryOriginDraftRepository? _repository;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrigin();
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
      final detail = await api.v1.origin.detail(originId: originId);
      if (!mounted) return;
      setState(() {
        _repository = MemoryOriginDraftRepository(
          initialDraft: originDraftFromV1Detail(detail),
        );
        _isLoading = false;
      });
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
        appBar: GenesisBackAppBar(pageName: 'Edit Origin'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final repository = _repository;
    if (_error != null || repository == null) {
      return Scaffold(
        appBar: const GenesisBackAppBar(pageName: 'Edit Origin'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ?? 'Origin detail is unavailable.',
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

    return OriginDraftFlowPage(
      key: ValueKey('edit-origin-${widget.originId}'),
      title: 'Edit Origin',
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
      confirmLeaveWithDraftOptions: true,
      onSubmit: _onSave,
    );
  }

  Future<OriginSubmitResult> _onSave(
    BuildContext context,
    OriginDraftRepository repository,
    CreateOriginDraft draft,
  ) async {
    final originId = draft.basics.originId.trim();
    final api = AppServicesScope.read(context).api;
    final uid = await readCreateOriginUid(context);
    final result = await api.updateOrigin(
      oid: originId,
      payload: draft.toCreateOriginPayload(uid: uid),
    );
    if (repository is MemoryOriginDraftRepository) {
      repository.markCurrentAsOriginal();
    }
    return OriginSubmitResult(
      message: 'Origin published successfully: ${result.oid}',
    );
  }
}
