import '../../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';

import '../../pages/create/create_form_widgets.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_colors.dart';

const int originCharacterNameMaxLength = 30;
const int originCharacterIdentityMaxLength = 100;
const int originCharacterPersonalityMaxLength = 100;
const int originCharacterBioMaxLength = 500;
const Size originCharacterAvatarUploadSize = Size.square(1080);

class OriginCharacterForm {
  OriginCharacterForm({
    required this.charId,
    required this.avatarUrl,
    required this.name,
    required this.identity,
    required this.personality,
    required this.bio,
    required this.goal,
    this.isRecommended = false,
    OriginCharacterFormFocusNodes? focusNodes,
  }) : focusNodes = focusNodes ?? OriginCharacterFormFocusNodes();

  factory OriginCharacterForm.empty({required String charId}) {
    return OriginCharacterForm(
      charId: charId,
      avatarUrl: TextEditingController(),
      name: TextEditingController(),
      identity: TextEditingController(),
      personality: TextEditingController(),
      bio: TextEditingController(),
      goal: TextEditingController(),
    );
  }

  factory OriginCharacterForm.fromValues({
    required String charId,
    String avatarUrl = '',
    String name = '',
    String identity = '',
    String personality = '',
    String bio = '',
    String goal = '',
    bool isRecommended = false,
  }) {
    return OriginCharacterForm(
      charId: charId,
      avatarUrl: TextEditingController(text: avatarUrl),
      name: TextEditingController(text: name),
      identity: TextEditingController(text: identity),
      personality: TextEditingController(text: personality),
      bio: TextEditingController(text: bio),
      goal: TextEditingController(text: goal),
      isRecommended: isRecommended,
    );
  }

  final String charId;
  final TextEditingController avatarUrl;
  final TextEditingController name;
  final TextEditingController identity;
  final TextEditingController personality;
  final TextEditingController bio;
  final TextEditingController goal;
  bool isRecommended;
  final OriginCharacterFormFocusNodes focusNodes;

  List<TextEditingController> get controllers {
    return <TextEditingController>[
      avatarUrl,
      name,
      identity,
      personality,
      bio,
      goal,
    ];
  }

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    focusNodes.dispose();
  }

  void addListener(VoidCallback listener) {
    for (final controller in controllers) {
      controller.addListener(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    for (final controller in controllers) {
      controller.removeListener(listener);
    }
  }

  bool get hasContent {
    return isRecommended ||
        controllers.any((controller) => controller.text.trim().isNotEmpty);
  }

  void clear() {
    isRecommended = false;
    for (final controller in controllers) {
      controller.clear();
    }
  }
}

class OriginCharacterFormFocusNodes {
  OriginCharacterFormFocusNodes();

  final FocusNode name = FocusNode();
  final FocusNode identity = FocusNode();
  final FocusNode personality = FocusNode();
  final FocusNode goal = FocusNode();
  final FocusNode bio = FocusNode();

  void dispose() {
    name.dispose();
    identity.dispose();
    personality.dispose();
    goal.dispose();
    bio.dispose();
  }
}

class OriginCharacterFormFields extends StatelessWidget {
  const OriginCharacterFormFields({
    super.key,
    required this.form,
    required this.onChanged,
    this.showPersonality = true,
    this.showGoal = true,
    this.avatarWidth = 104,
    this.avatarHeight = 104,
    this.avatarIconSize = 38,
    this.avatarCropSize = originCharacterAvatarUploadSize,
    this.avatarMaxOutputSize = originCharacterAvatarUploadSize,
    this.showAvatarRemoveLink = true,
    this.topSpacing = 6,
    this.horizontalGap = 12,
    this.fieldGap = 12,
    this.sectionGap = 12,
    this.labelInputGap = 8,
    this.avatarEmptyIconLabelGap = 8,
    this.labelSize = 14,
    this.labelFontWeight = FontWeight.w600,
    this.avatarEmptyLabelFontWeight = FontWeight.w600,
    this.avatarRemoveLinkFontWeight = FontWeight.w600,
    this.bioMaxLines,
    this.identityBelowAvatarRow = true,
    this.showFieldNotes = false,
    this.showPlaceholders = true,
    this.textFieldScrollPadding,
    this.textFieldFillColor,
    this.handoffTextFieldVerticalDragToAncestor = false,
    this.nextFocusNode,
    this.nameSupportLeading,
  });

  final OriginCharacterForm form;
  final VoidCallback onChanged;
  final bool showPersonality;
  final bool showGoal;
  final double avatarWidth;
  final double avatarHeight;
  final double avatarIconSize;
  final Size avatarCropSize;
  final Size? avatarMaxOutputSize;
  final bool showAvatarRemoveLink;
  final double topSpacing;
  // Module internal horizontal spacing: avatar upload block -> right-side text fields.
  final double horizontalGap;
  // Module internal vertical spacing: stacked fields inside the same right-side column.
  final double fieldGap;
  // Spacing between form modules: avatar/name row -> identity row -> bio -> goal.
  final double sectionGap;
  // Field internal spacing: each label -> its input box.
  final double labelInputGap;
  // Avatar upload internal spacing: empty-state icon -> empty-state label.
  final double avatarEmptyIconLabelGap;
  final double labelSize;
  final FontWeight labelFontWeight;
  final FontWeight avatarEmptyLabelFontWeight;
  final FontWeight avatarRemoveLinkFontWeight;
  final int? bioMaxLines;
  final bool identityBelowAvatarRow;
  final bool showFieldNotes;
  final bool showPlaceholders;
  final EdgeInsets? textFieldScrollPadding;
  final Color? textFieldFillColor;
  final bool handoffTextFieldVerticalDragToAncestor;
  final FocusNode? nextFocusNode;
  final Widget? nameSupportLeading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topSpacing > 0) SizedBox(height: topSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CreateUploadBox(
              controller: form.avatarUrl,
              label: GenesisL10n
                  .current
                  .createCharacterAvatarOptional,
              emptyBackgroundColor: CreateFormTheme.colorOf(
                context,
                const Color(0x6BF4F4F6),
                GenesisColors.darkFaintFill,
              ),
              emptyBorderColor: CreateFormTheme.colorOf(
                context,
                createFormUploadBorder,
                GenesisColors.darkTextTertiary,
              ),
              emptyIconColor: GenesisColors.createAdd,
              emptyLabelColor: CreateFormTheme.colorOf(
                context,
                createFormMuted,
                GenesisColors.darkTextSecondary,
              ),
              width: avatarWidth,
              height: avatarHeight,
              iconSize: avatarIconSize,
              cropSize: avatarCropSize,
              maxOutputSize: avatarMaxOutputSize,
              borderRadius: GenesisAvatarRadii.character,
              previewAlignment: Alignment.topCenter,
              showRemoveLinkWhenFilled: showAvatarRemoveLink,
              emptyLabelFontWeight: avatarEmptyLabelFontWeight,
              emptyIconLabelGap: avatarEmptyIconLabelGap,
              removeLinkFontWeight: avatarRemoveLinkFontWeight,
              onChanged: onChanged,
            ),
            SizedBox(width: horizontalGap),
            Expanded(
              child: Column(
                children: [
                  CreateTextFieldBlock(
                    label: GenesisL10n
                        .current
                        .createCharacterName,
                    controller: form.name,
                    hintText: _placeholder(
                      GenesisL10n
                          .current
                          .createCharacterEnterName,
                    ),
                    maxLength: originCharacterNameMaxLength,
                    labelSize: labelSize,
                    labelFontWeight: labelFontWeight,
                    labelInputGap: labelInputGap,
                    maxLines: 1,
                    scrollPadding: textFieldScrollPadding,
                    fillColor: textFieldFillColor,
                    handoffVerticalDragToAncestor:
                        handoffTextFieldVerticalDragToAncestor,
                    focusNode: form.focusNodes.name,
                    nextFocusNode: form.focusNodes.identity,
                    supportLeading: nameSupportLeading,
                    onChanged: (_) => onChanged(),
                  ),
                  if (!identityBelowAvatarRow) ...[
                    SizedBox(height: fieldGap),
                    CreateTextFieldBlock(
                      label: GenesisL10n
                          .current
                          .createCharacterIdentity,
                      controller: form.identity,
                      hintText: _placeholder(
                        GenesisL10n
                            .current
                            .createCharacterEgHometownKidBack,
                      ),
                      maxLength: originCharacterIdentityMaxLength,
                      note: showFieldNotes
                          ? GenesisL10n
                                .current
                                .createCharacterRoleHint
                          : null,
                      labelSize: labelSize,
                      labelFontWeight: labelFontWeight,
                      labelInputGap: labelInputGap,
                      maxLines: 3,
                      scrollPadding: textFieldScrollPadding,
                      fillColor: textFieldFillColor,
                      handoffVerticalDragToAncestor:
                          handoffTextFieldVerticalDragToAncestor,
                      focusNode: form.focusNodes.identity,
                      nextFocusNode: _nextAfterIdentity,
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                  if (showPersonality && !identityBelowAvatarRow) ...[
                    SizedBox(height: fieldGap),
                    CreateTextFieldBlock(
                      label: GenesisL10n
                          .current
                          .createCharacterPersonality,
                      controller: form.personality,
                      hintText: _placeholder(
                        GenesisL10n
                            .current
                            .createCharacterEgUnderdog,
                      ),
                      maxLength: originCharacterPersonalityMaxLength,
                      note: showFieldNotes
                          ? GenesisL10n
                                .current
                                .createCharacterMannerHint
                          : null,
                      labelSize: labelSize,
                      labelFontWeight: labelFontWeight,
                      labelInputGap: labelInputGap,
                      maxLines: 3,
                      scrollPadding: textFieldScrollPadding,
                      fillColor: textFieldFillColor,
                      handoffVerticalDragToAncestor:
                          handoffTextFieldVerticalDragToAncestor,
                      focusNode: form.focusNodes.personality,
                      nextFocusNode: _nextAfterPersonality,
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: sectionGap),
        if (identityBelowAvatarRow) ...[
          CreateTextFieldBlock(
            label: GenesisL10n
                .current
                .createCharacterIdentity,
            controller: form.identity,
            hintText: _placeholder(
              GenesisL10n
                  .current
                  .createCharacterEgHometownKidBack,
            ),
            maxLength: originCharacterIdentityMaxLength,
            note: showFieldNotes
                ? GenesisL10n
                      .current
                      .createCharacterRoleHint
                : null,
            labelSize: labelSize,
            labelFontWeight: labelFontWeight,
            labelInputGap: labelInputGap,
            maxLines: 3,
            scrollPadding: textFieldScrollPadding,
            fillColor: textFieldFillColor,
            handoffVerticalDragToAncestor:
                handoffTextFieldVerticalDragToAncestor,
            focusNode: form.focusNodes.identity,
            nextFocusNode: _nextAfterIdentity,
            onChanged: (_) => onChanged(),
          ),
          if (showPersonality) ...[
            SizedBox(height: fieldGap),
            CreateTextFieldBlock(
              label: GenesisL10n
                  .current
                  .createCharacterPersonality,
              controller: form.personality,
              hintText: _placeholder(
                GenesisL10n
                    .current
                    .createCharacterEgUnderdog,
              ),
              maxLength: originCharacterPersonalityMaxLength,
              note: showFieldNotes
                  ? GenesisL10n
                        .current
                        .createCharacterMannerHint
                  : null,
              labelSize: labelSize,
              labelFontWeight: labelFontWeight,
              labelInputGap: labelInputGap,
              maxLines: 3,
              scrollPadding: textFieldScrollPadding,
              fillColor: textFieldFillColor,
              handoffVerticalDragToAncestor:
                  handoffTextFieldVerticalDragToAncestor,
              focusNode: form.focusNodes.personality,
              nextFocusNode: _nextAfterPersonality,
              onChanged: (_) => onChanged(),
            ),
          ],
          SizedBox(height: sectionGap),
        ],
        if (showGoal) ...[
          CreateTextFieldBlock(
            label: GenesisL10n
                .current
                .createCharacterGoalOptional,
            controller: form.goal,
            hintText: _placeholder(
              GenesisL10n
                  .current
                  .createCharacterEgRichestOwner,
            ),
            maxLength: 100,
            note: showFieldNotes
                ? GenesisL10n
                      .current
                      .createCharacterGoalHint
                : null,
            minLines: 2,
            maxLines: 3,
            labelSize: labelSize,
            labelFontWeight: labelFontWeight,
            labelInputGap: labelInputGap,
            scrollPadding: textFieldScrollPadding,
            fillColor: textFieldFillColor,
            handoffVerticalDragToAncestor:
                handoffTextFieldVerticalDragToAncestor,
            focusNode: form.focusNodes.goal,
            nextFocusNode: form.focusNodes.bio,
            onChanged: (_) => onChanged(),
          ),
          SizedBox(height: sectionGap),
        ],
        CreateTextFieldBlock(
          label: GenesisL10n
              .current
              .createCharacterBackgroundHidden,
          controller: form.bio,
          hintText: _placeholder(
            GenesisL10n
                .current
                .createCharacterEgLeftTownYears,
          ),
          maxLength: originCharacterBioMaxLength,
          note: showFieldNotes
              ? GenesisL10n
                    .current
                    .createCharacterBackgroundHint
              : null,
          minLines: 3,
          maxLines: bioMaxLines ?? 8,
          labelSize: labelSize,
          labelFontWeight: labelFontWeight,
          labelInputGap: labelInputGap,
          scrollPadding: textFieldScrollPadding,
          fillColor: textFieldFillColor,
          handoffVerticalDragToAncestor: handoffTextFieldVerticalDragToAncestor,
          focusNode: form.focusNodes.bio,
          nextFocusNode: nextFocusNode,
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }

  String _placeholder(String value) {
    return showPlaceholders ? value : '';
  }

  FocusNode get _nextAfterIdentity {
    if (showPersonality) return form.focusNodes.personality;
    if (showGoal) return form.focusNodes.goal;
    return form.focusNodes.bio;
  }

  FocusNode get _nextAfterPersonality {
    if (showGoal) return form.focusNodes.goal;
    return form.focusNodes.bio;
  }
}
