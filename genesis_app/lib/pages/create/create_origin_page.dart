import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';
import 'create_basics_page.dart';
import 'create_characters_page.dart';
import 'create_locations_page.dart';
import 'create_origin_draft_store.dart';
import 'create_story_events_page.dart';

class CreateOriginPage extends StatelessWidget {
  const CreateOriginPage({super.key});

  static const CreateOriginDraftRepository _repository =
      CreateOriginDraftRepository();

  @override
  Widget build(BuildContext context) {
    return OriginDraftFlowPage(
      title: 'Create Worldo',
      repository: _repository,
      basicsPageBuilder: (_) => const CreateBasicsPage(),
      charactersPageBuilder: (_) => const CreateCharactersPage(),
      locationsPageBuilder: (_) => const CreateLocationsPage(),
      storyEventsPageBuilder: (_) => const CreateStoryEventsPage(),
      failurePrefix: 'Create failed',
      submitLabel: 'Create',
      submittingLabel: 'Creating...',
      onSubmit: _onCreate,
      popOnSubmitSuccess: true,
      confirmLeaveWithDraftOptions: true,
      onDiscardDraft: (_) => CreateOriginDraftStore.clear(),
    );
  }

  Future<OriginSubmitResult> _onCreate(
    BuildContext context,
    OriginDraftRepository repository,
    CreateOriginDraft draft,
  ) async {
    final api = AppServicesScope.read(context).api;
    final result = await api.createOrigin(
      payload: draft.toCreateOriginPayload(),
    );
    await CreateOriginDraftStore.clear();
    return OriginSubmitResult(
      message: 'Worldo created successfully: ${result.oid}',
      draft: CreateOriginDraft.empty(),
    );
  }
}
