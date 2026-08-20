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
          ? GenesisPalette.redesignBackground
          : null,
      titleFontSize: createWorldoStyle ? 15 : 16,
      titleFontWeight: createWorldoStyle ? FontWeight.w800 : FontWeight.w600,
      titleColor: createWorldoStyle ? GenesisPalette.white : null,
      headerBottomSpacing: createWorldoStyle ? 13 : 0,
      deleteButtonSize: createWorldoStyle ? 30 : 24,
      deleteIconSize: 14,
      deleteBackgroundColor: createWorldoStyle
          ? GenesisPalette.redesignWhite07
          : null,
      deleteBorderColor: createWorldoStyle ? GenesisPalette.transparent : null,
      deleteBorderRadius: createWorldoStyle ? 10 : null,
      deleteIconColor: createWorldoStyle
          ? GenesisPalette.redesignWhite60
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
                ? FontWeight.w700
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
    return AppBar(
      toolbarHeight: _height,
      automaticallyImplyLeading: false,
      backgroundColor: GenesisPalette.redesignBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leadingWidth: 54,
      titleSpacing: 12,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Center(
          child: GenesisBackButton(
            foregroundColor: GenesisPalette.white,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      title: const Text(
        'Characters',
        style: TextStyle(
          fontSize: 17,
          height: 1,
          fontWeight: FontWeight.w800,
          color: GenesisPalette.white,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Center(
            child: Text(
              '$characterCount/$maxCharacters (Added / Max)',
              style: const TextStyle(
                fontSize: 9.5,
                height: 1,
                fontWeight: FontWeight.w500,
                color: GenesisPalette.redesignWhite50,
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
          painter: CreateDashedRRectPainter(
            color: GenesisPalette.redesignWhite22,
            radius: 13,
            strokeWidth: 1.5,
          ),
          child: const SizedBox(
            width: double.infinity,
            height: 44,
            child: Center(
              child: Text(
                '+ Add Character',
                style: TextStyle(
                  color: GenesisPalette.redesignAccentSoft,
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                style: OriginRoleSelectionMarkStyle.star,
              ),
              SizedBox(width: 6),
              Text(
                'Suggest',
                style: TextStyle(
                  color: createWorldoStyle
                      ? GenesisPalette.redesignWhite60
                      : context.genesisCreateColors.text,
                  fontSize: createWorldoStyle ? 9.5 : 12,
                  height: createWorldoStyle ? 1.5 : 1.2,
                  fontWeight: createWorldoStyle
                      ? FontWeight.w500
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
