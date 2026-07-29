import 'dart:async';

import 'package:flutter/material.dart';

import '../create/create_origin_draft_store.dart';
import 'origin_draft_repository.dart';

typedef OriginDebugDraftGenerator =
    FutureOr<CreateOriginDraft> Function(
      BuildContext context,
      CreateOriginDraft currentDraft,
    );

OriginDebugDraftGenerator? createOriginDebugDraftGenerator() => null;

OriginDebugDraftGenerator? editOriginDebugDraftGenerator(
  TextEditingController updateNotesController,
) => null;

Widget? buildOriginDebugRandomContentButton({
  required OriginDraftRepository repository,
  required OriginDebugDraftGenerator? generator,
  required bool enabled,
  required Future<void> Function() onGenerated,
}) => null;
