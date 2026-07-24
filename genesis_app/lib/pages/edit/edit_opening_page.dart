import 'package:flutter/material.dart';

import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';

class EditOpeningPage extends StatelessWidget {
  const EditOpeningPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  Widget build(BuildContext context) {
    return OriginOpeningEditorPage(repository: repository);
  }
}
