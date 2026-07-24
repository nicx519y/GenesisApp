import 'package:flutter/material.dart';

import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';

class CreateOpeningPage extends StatelessWidget {
  const CreateOpeningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OriginOpeningEditorPage(
      repository: CreateOriginDraftRepository(),
    );
  }
}
