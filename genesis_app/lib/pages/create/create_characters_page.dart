import 'package:flutter/material.dart';

import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';

class CreateCharactersPage extends StatelessWidget {
  const CreateCharactersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OriginCharactersEditorPage(
      repository: CreateOriginDraftRepository(),
    );
  }
}
