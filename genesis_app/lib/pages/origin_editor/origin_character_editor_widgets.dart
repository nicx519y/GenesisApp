part of 'origin_editor_pages.dart';

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.index,
    required this.form,
    required this.nextFocusNode,
    required this.onChanged,
    required this.onRecommendationChanged,
    required this.onDelete,
  });

  final int index;
  final OriginCharacterForm form;
  final FocusNode? nextFocusNode;
  final VoidCallback onChanged;
  final Future<void> Function(bool recommended) onRecommendationChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Character $index',
      onDelete: onDelete,
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OriginCharacterFormFields(
            form: form,
            onChanged: onChanged,
            showFieldNotes: true,
            labelFontWeight: FontWeight.w400,
            nextFocusNode: nextFocusNode,
          ),
          const SizedBox(height: 17),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                unawaited(onRecommendationChanged(!form.isRecommended)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OriginRoleSelectionMark(
                  key: ValueKey('origin-character-recommended-${form.charId}'),
                  selected: form.isRecommended,
                  semanticLabel: 'Recommend as the best role',
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recommend as the best role',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
