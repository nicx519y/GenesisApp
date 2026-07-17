import '../create/create_origin_draft_store.dart';

List<String> originDraftGenerationWaitLines(
  CreateOriginDraft draft, {
  String originatorName = '',
}) {
  final originator = originatorName.trim();
  final lines = <String>[
    if (originator.isNotEmpty) ...['Originator', originator],
  ];
  final brief = draft.basics.worldView.trim();
  final settings = draft.basics.worldLogic.trim();
  if (brief.isNotEmpty) lines.add(brief);
  if (settings.isNotEmpty) lines.add(settings);

  for (final character in draft.characters) {
    final name = character.name.trim();
    if (name.isEmpty) continue;
    final details = [
      character.identity.trim(),
      character.personality.trim(),
    ].where((item) => item.isNotEmpty).join('. ');
    if (details.isEmpty) continue;
    lines.add('$name: $details');
  }

  return lines;
}
