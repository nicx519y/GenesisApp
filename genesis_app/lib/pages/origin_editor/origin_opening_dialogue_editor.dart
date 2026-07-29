part of 'origin_editor_pages.dart';

class _OpeningDialogueEditor extends StatelessWidget {
  const _OpeningDialogueEditor({
    required this.items,
    required this.characters,
    required this.onAddNarrator,
    required this.onAddCharacter,
    required this.onAddImage,
    required this.onDelete,
    required this.onChanged,
  });

  final List<_OpeningDialogueItem> items;
  final List<CharacterDraft> characters;
  final VoidCallback onAddNarrator;
  final ValueChanged<CharacterDraft> onAddCharacter;
  final VoidCallback onAddImage;
  final ValueChanged<_OpeningDialogueItem> onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final style = kLocationChatStyle;
    final namedCharacters = characters
        .where((character) => character.name.trim().isNotEmpty)
        .toList(growable: false);
    return SizedBox(
      key: const ValueKey<String>('opening-dialogue-editor'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int index = 0; index < items.length; index++) ...[
            CreateKeyboardSafeFocusRegion(
              builder: (context, focusNode) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OpeningDialogueContentEditor(
                    item: items[index],
                    style: style,
                    onDelete: () => onDelete(items[index]),
                    onChanged: onChanged,
                    focusNode: focusNode,
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
          Column(
            key: const ValueKey<String>('opening-dialogue-add-buttons'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (namedCharacters.isNotEmpty) ...[
                Wrap(
                  key: const ValueKey<String>(
                    'opening-dialogue-character-buttons',
                  ),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final character in namedCharacters)
                      _OpeningDialogueAddButton(
                        key: ValueKey<String>(
                          'opening-add-character-${character.charId.trim()}',
                        ),
                        label: character.name.trim(),
                        leading: SvgPicture.asset(
                          characterStatIconAsset,
                          width: 14,
                          height: 14,
                        ),
                        onTap: () => onAddCharacter(character),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                key: const ValueKey<String>('opening-dialogue-media-buttons'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OpeningDialogueAddButton(
                    key: const ValueKey<String>('opening-add-narrator'),
                    label: 'Narrator',
                    leading: SvgPicture.asset(
                      paragraphIconAsset,
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        createFormText,
                        BlendMode.srcIn,
                      ),
                    ),
                    onTap: onAddNarrator,
                  ),
                  _OpeningDialogueAddButton(
                    key: const ValueKey<String>('opening-add-image'),
                    label: 'Image',
                    leading: const Icon(
                      Icons.image_outlined,
                      color: createFormText,
                      size: 16,
                    ),
                    onTap: onAddImage,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpeningDialogueContentEditor extends StatelessWidget {
  const _OpeningDialogueContentEditor({
    required this.item,
    required this.style,
    required this.onDelete,
    required this.onChanged,
    required this.focusNode,
  });

  final _OpeningDialogueItem item;
  final ChatUiStyleConfig style;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return switch (item.type) {
      _OpeningDialogueType.narrator => _OpeningNarratorEditor(
        item: item,
        style: style,
        onDelete: onDelete,
        onChanged: onChanged,
        focusNode: focusNode,
      ),
      _OpeningDialogueType.character => _OpeningCharacterEditor(
        item: item,
        style: style,
        onDelete: onDelete,
        onChanged: onChanged,
        focusNode: focusNode,
      ),
      _OpeningDialogueType.image => _OpeningImageEditor(
        item: item,
        style: style,
        onDelete: onDelete,
        onChanged: onChanged,
      ),
    };
  }
}

class _OpeningNarratorEditor extends StatelessWidget {
  const _OpeningNarratorEditor({
    required this.item,
    required this.style,
    required this.onDelete,
    required this.onChanged,
    required this.focusNode,
  });

  final _OpeningDialogueItem item;
  final ChatUiStyleConfig style;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: style.systemMessageMargin.left,
            right: style.systemMessageMargin.right,
          ),
          child: Container(
            key: ValueKey<String>('${item.id}-narrator'),
            width: double.infinity,
            padding: style.systemMessagePadding,
            decoration: BoxDecoration(
              color: style.systemMessageBackgroundColor,
              borderRadius: BorderRadius.circular(
                style.systemMessageBorderRadius,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: SvgPicture.asset(
                    paragraphIconAsset,
                    width: 14,
                    height: 14,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _OpeningDialogueTextField(
                    key: ValueKey<String>(
                      '${item.id}-keyboard-safe-text-field',
                    ),
                    item: item,
                    hintText: 'Enter narrator dialogue',
                    style: style.systemMessageTextStyle,
                    onChanged: onChanged,
                    focusNode: focusNode,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: -8,
          child: CreateFormDeleteButton(
            buttonKey: ValueKey<String>('${item.id}-delete'),
            decorationKey: ValueKey<String>('${item.id}-delete-container'),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

class _OpeningCharacterEditor extends StatelessWidget {
  const _OpeningCharacterEditor({
    required this.item,
    required this.style,
    required this.onDelete,
    required this.onChanged,
    required this.focusNode,
  });

  final _OpeningDialogueItem item;
  final ChatUiStyleConfig style;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final character = item.character!;
    final name = character.name.trim();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          key: ValueKey<String>('${item.id}-character'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatAvatar(
              label: chatInitials(name),
              imageUrl: character.avatarUrl,
              colors: style.otherAvatarColors,
              seed: name,
              borderColor: createFormBorder,
              style: style,
            ),
            SizedBox(width: style.avatarBubbleGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    key: ValueKey<String>('${item.id}-name-row'),
                    height: 16,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.senderNameTextStyle.copyWith(
                            color: createFormText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: style.senderNameBottomGap),
                  Container(
                    key: ValueKey<String>('${item.id}-bubble'),
                    width: double.infinity,
                    padding: style.bubblePadding,
                    decoration: BoxDecoration(
                      color: style.otherBubbleColor,
                      border: Border.all(color: createFormBorder),
                      borderRadius: BorderRadius.circular(
                        style.bubbleBorderRadius,
                      ),
                    ),
                    child: _OpeningDialogueTextField(
                      key: ValueKey<String>(
                        '${item.id}-keyboard-safe-text-field',
                      ),
                      item: item,
                      hintText: 'Enter $name dialogue',
                      style: style.bubbleTextStyle,
                      onChanged: onChanged,
                      focusNode: focusNode,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: style.avatarSideSpacerWidth),
          ],
        ),
        Positioned(
          right: 0,
          top: -8,
          child: CreateFormDeleteButton(
            buttonKey: ValueKey<String>('${item.id}-delete'),
            decorationKey: ValueKey<String>('${item.id}-delete-container'),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

class _OpeningDialogueTextField extends StatelessWidget {
  const _OpeningDialogueTextField({
    super.key,
    required this.item,
    required this.hintText,
    required this.style,
    required this.onChanged,
    required this.focusNode,
  });

  final _OpeningDialogueItem item;
  final String hintText;
  final TextStyle style;
  final VoidCallback onChanged;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey<String>('${item.id}-field'),
      controller: item.controller,
      focusNode: focusNode,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      scrollPadding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        kMinInteractiveDimension,
      ),
      minLines: 3,
      maxLines: null,
      style: style,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hintText,
        hintStyle: style.copyWith(
          color: (style.color ?? createFormHint).withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _OpeningImageEditor extends StatelessWidget {
  const _OpeningImageEditor({
    required this.item,
    required this.style,
    required this.onDelete,
    required this.onChanged,
  });

  final _OpeningDialogueItem item;
  final ChatUiStyleConfig style;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: style.systemMessageMargin.left,
            right: style.systemMessageMargin.right,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Align(
                alignment: Alignment.centerLeft,
                child: CreateUploadBox(
                  key: ValueKey<String>('${item.id}-image'),
                  controller: item.controller,
                  label: 'UPLOAD IMAGE',
                  width: width,
                  height: width,
                  uploadOriginalImage: true,
                  preserveImageAspectRatio: true,
                  useMessageImageSizing: true,
                  previewAlignment: Alignment.center,
                  showRemoveLinkWhenFilled: false,
                  onChanged: onChanged,
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 0,
          top: -8,
          child: CreateFormDeleteButton(
            buttonKey: ValueKey<String>('${item.id}-delete'),
            decorationKey: ValueKey<String>('${item.id}-delete-container'),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

class _OpeningDialogueAddButton extends StatelessWidget {
  const _OpeningDialogueAddButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: createFormFieldFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: createFormBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: createFormText, size: 17),
              const SizedBox(width: 4),
              leading,
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: createFormText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
