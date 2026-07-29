part of 'origin_editor_pages.dart';

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.index,
    required this.form,
    required this.nextFocusNode,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final OriginCharacterForm form;
  final FocusNode? nextFocusNode;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Character $index',
      onDelete: onDelete,
      showBorder: false,
      child: OriginCharacterFormFields(
        form: form,
        onChanged: onChanged,
        showFieldNotes: true,
        labelFontWeight: FontWeight.w400,
        nextFocusNode: nextFocusNode,
      ),
    );
  }
}
