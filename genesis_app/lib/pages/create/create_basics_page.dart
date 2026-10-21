import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../origin_editor/origin_draft_repository.dart';
import '../origin_editor/origin_editor_pages.dart';

class CreateBasicsPage extends StatelessWidget {
  const CreateBasicsPage({super.key, this.repository});

  final CreateOriginDraftRepository? repository;

  @override
  Widget build(BuildContext context) {
    return OriginBasicsEditorPage(
      repository:
          repository ??
          CreateOriginDraftRepository(
            sessionStore: AppServicesScope.read(context).sessionStore,
          ),
    );
  }
}
