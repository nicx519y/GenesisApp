import 'package:flutter/material.dart';

import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';

class CreateLocationsPage extends StatelessWidget {
  const CreateLocationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OriginLocationsEditorPage(
      repository: CreateOriginDraftRepository(),
    );
  }
}
