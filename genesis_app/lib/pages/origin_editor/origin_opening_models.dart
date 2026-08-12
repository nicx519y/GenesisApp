part of 'origin_editor_pages.dart';

enum _OpeningDialogueType { narrator, character, image }

_OpeningDialogueType? _openingDialogueTypeFromDraft(String value) {
  return switch (value.trim()) {
    OpeningDialogueDraft.narratorType => _OpeningDialogueType.narrator,
    OpeningDialogueDraft.characterType => _OpeningDialogueType.character,
    OpeningDialogueDraft.imageType => _OpeningDialogueType.image,
    _ => null,
  };
}

class _OpeningDialogueItem {
  _OpeningDialogueItem({
    required this.id,
    required this.type,
    this.character,
    String initialContent = '',
  }) : controller = TextEditingController(text: initialContent);

  final String id;
  final _OpeningDialogueType type;
  final CharacterDraft? character;
  final TextEditingController controller;

  bool get hasContent => controller.text.trim().isNotEmpty;

  OpeningDialogueDraft toDraft() {
    return OpeningDialogueDraft(
      type: switch (type) {
        _OpeningDialogueType.narrator => OpeningDialogueDraft.narratorType,
        _OpeningDialogueType.character => OpeningDialogueDraft.characterType,
        _OpeningDialogueType.image => OpeningDialogueDraft.imageType,
      },
      content: controller.text.trim(),
      characterId: character?.charId.trim() ?? '',
    );
  }

  void dispose() {
    controller.dispose();
  }
}
