import 'package:flutter/material.dart';

import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';

class CreateStoryEventsPage extends StatelessWidget {
  const CreateStoryEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OriginStoryEventsEditorPage(
      repository: CreateOriginDraftRepository(),
    );
  }
}
