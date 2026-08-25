part of 'origin_editor_pages.dart';

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.index,
    required this.form,
    required this.createWorldoStyle,
    required this.nextFocusNode,
    required this.onChanged,
    required this.onRecommendationChanged,
    required this.onDelete,
  });

  final int index;
  final OriginCharacterForm form;
  final bool createWorldoStyle;
  final FocusNode? nextFocusNode;
  final VoidCallback onChanged;
  final ValueChanged<bool> onRecommendationChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Character $index',
      onDelete: onDelete,
      showBorder: false,
      padding: createWorldoStyle ? EdgeInsets.zero : null,
      backgroundColor: createWorldoStyle
          ? context.genesisColors.pageBackground
          : null,
      titleFontSize: createWorldoStyle ? 15 : 16,
      titleFontWeight: createWorldoStyle ? FontWeight.w800 : FontWeight.w600,
      titleColor: createWorldoStyle ? context.genesisCreateColors.text : null,
      headerBottomSpacing: createWorldoStyle ? 13 : 0,
      deleteButtonSize: createWorldoStyle ? 30 : 24,
      deleteIconSize: 14,
      deleteBackgroundColor: createWorldoStyle
          ? context.genesisCreateColors.fieldFill
          : null,
      deleteBorderColor: createWorldoStyle ? Colors.transparent : null,
      deleteBorderRadius: createWorldoStyle ? 10 : null,
      deleteIconColor: createWorldoStyle
          ? context.genesisColors.textMuted
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OriginCharacterFormFields(
            form: form,
            onChanged: onChanged,
            createWorldoStyle: createWorldoStyle,
            showFieldNotes: true,
            labelFontWeight: createWorldoStyle
                ? FontWeight.w800
                : FontWeight.w400,
            nextFocusNode: nextFocusNode,
            nameSupportLeading: _BestRoleSelector(
              form: form,
              createWorldoStyle: createWorldoStyle,
              onChanged: onRecommendationChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateCharactersAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _CreateCharactersAppBar({
    required this.characterCount,
    required this.maxCharacters,
  });

  static const double _height = 64;

  final int characterCount;
  final int maxCharacters;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return GenesisAppBar(
      title: 'Characters',
      variant: GenesisAppBarVariant.leadingTitle,
      backgroundColor: context.genesisColors.pageBackground,
      backForegroundColor: context.genesisCreateColors.text,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Center(
            child: Text(
              '$characterCount/$maxCharacters (Added / Max)',
              style: TextStyle(
                fontSize: 9.5,
                height: 1,
                fontWeight: FontWeight.w600,
                color: context.genesisColors.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateCharactersAddButton extends StatelessWidget {
  const _CreateCharactersAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('create-characters-add-button'),
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: CustomPaint(
          // Same look as the Story Events "+ Add Event" button.
          painter: CreateDashedRRectPainter(
            color: context.genesisColors.foregroundStrong.withValues(
              alpha: 0.24,
            ),
            radius: 13,
            strokeWidth: 1.5,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: context.genesisCreateColors.successText,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Character',
                  style: TextStyle(
                    color: context.genesisCreateColors.successText,
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BestRoleSelector extends StatelessWidget {
  const _BestRoleSelector({
    required this.form,
    required this.createWorldoStyle,
    required this.onChanged,
  });

  final OriginCharacterForm form;
  final bool createWorldoStyle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('origin-character-best-role-hit-target-${form.charId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!form.isRecommended),
      child: SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OriginRoleSelectionMark(
                key: ValueKey('origin-character-recommended-${form.charId}'),
                selected: form.isRecommended,
                semanticLabel: 'Creator suggests this role for the user',
                style: OriginRoleSelectionMarkStyle.circle,
                dimension: 14,
              ),
              SizedBox(width: 6),
              Text(
                'Suggest',
                style: TextStyle(
                  color: createWorldoStyle
                      ? context.genesisColors.textMuted
                      : context.genesisCreateColors.text,
                  fontSize: createWorldoStyle ? 9.5 : 11,
                  height: createWorldoStyle ? 1.5 : 1.2,
                  fontWeight: createWorldoStyle
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
