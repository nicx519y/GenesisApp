import 'package:flutter/material.dart';

import '../../components/create/genesis_create_theme.dart';
import '../../pages/create/create_form_widgets.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';

const int originCharacterNameMaxLength = 30;
const int originCharacterIdentityMaxLength = 100;
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
    this.labelSize = 13,
    this.labelFontWeight = FontWeight.w600,
    this.avatarEmptyLabelFontWeight = FontWeight.w600,
    this.avatarRemoveLinkFontWeight = FontWeight.w600,
    this.bioMaxLines,
    this.identityBelowAvatarRow = true,
    this.showFieldNotes = false,
    this.showPlaceholders = true,
    this.textFieldScrollPadding,
    this.nextFocusNode,
    this.nameSupportLeading,
    this.createWorldoStyle = false,
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
  final FocusNode? nextFocusNode;
  final Widget? nameSupportLeading;
  final bool createWorldoStyle;

  @override
  Widget build(BuildContext context) {
    final worldoStyle = createWorldoStyle;
    final resolvedLabelSize = worldoStyle ? 14.0 : labelSize;
    // SPEC 5c: field labels are 700 14px.
    final resolvedLabelFontWeight = worldoStyle
        ? FontWeight.w700
        : labelFontWeight;
    final resolvedLabelInputGap = worldoStyle ? 8.0 : labelInputGap;
    final resolvedFieldGap = worldoStyle ? 16.0 : fieldGap;
    final resolvedSectionGap = worldoStyle ? 18.0 : sectionGap;
    final worldoSupportStyle = TextStyle(
      color: context.genesisColors.textMuted,
      fontSize: 11,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );
    final worldoCounterStyle = TextStyle(
      color: context.genesisColors.textTertiary,
      fontSize: 9.5,
      height: 1.5,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!worldoStyle && topSpacing > 0) SizedBox(height: topSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CreateUploadBox(
              controller: form.avatarUrl,
              label: 'AVATAR\n(Optional)',
              width: worldoStyle ? 100 : avatarWidth,
              height: worldoStyle ? 100 : avatarHeight,
              iconSize: worldoStyle ? 22 : avatarIconSize,
              cropSize: avatarCropSize,
              maxOutputSize: avatarMaxOutputSize,
              borderRadius: worldoStyle ? 13 : GenesisAvatarRadii.character,
              previewAlignment: Alignment.topCenter,
              showRemoveLinkWhenFilled: showAvatarRemoveLink,
              emptyLabelFontWeight: worldoStyle
                  ? FontWeight.w600
                  : avatarEmptyLabelFontWeight,
              emptyLabelFontSize: worldoStyle ? 11 : 12,
              emptyIconLabelGap: worldoStyle ? 7 : avatarEmptyIconLabelGap,
              removeLinkFontWeight: avatarRemoveLinkFontWeight,
              emptyBackgroundColor: worldoStyle ? Colors.transparent : null,
              emptyIconColor: worldoStyle
                  ? context.genesisCreateColors.successText
                  : null,
              emptyLabelColor: worldoStyle
                  ? context.genesisCreateColors.successText
                  : null,
              dashColor: worldoStyle
                  ? context.genesisColors.textDisabled
                  : null,
              dashStrokeWidth: worldoStyle ? 1.5 : 1.2,
              onChanged: onChanged,
            ),
            SizedBox(width: worldoStyle ? 13 : horizontalGap),
            Expanded(
              child: Column(
                children: [
                  CreateTextFieldBlock(
                    label: worldoStyle ? 'Name' : 'Name *',
                    controller: form.name,
                    hintText: _placeholder('Enter name...'),
                    maxLength: originCharacterNameMaxLength,
                    requiredIndicator: worldoStyle,
                    labelSize: resolvedLabelSize,
                    labelFontWeight: resolvedLabelFontWeight,
                    labelInputGap: resolvedLabelInputGap,
                    fieldBorderRadius: worldoStyle ? 13 : 8,
                    fieldPadding: worldoStyle
                        ? const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          )
                        : const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                    minimumHeight: worldoStyle ? 46 : null,
                    inputFontSize: worldoStyle ? 13 : 14,
                    hintFontSize: worldoStyle ? 13 : null,
                    inputLineHeight: worldoStyle ? 1.55 : 1.42,
                    supportLineGap: worldoStyle ? 7 : 8,
                    supportItemGap: worldoStyle ? 7 : 12,
                    counterTextStyle: worldoStyle ? worldoCounterStyle : null,
                    maxLines: 1,
                    scrollPadding: textFieldScrollPadding,
                    focusNode: form.focusNodes.name,
                    nextFocusNode: form.focusNodes.identity,
                    supportLeading: nameSupportLeading,
                    onChanged: (_) => onChanged(),
                  ),
                  if (!identityBelowAvatarRow) ...[
                    SizedBox(height: resolvedFieldGap),
                    CreateTextFieldBlock(
                      label: worldoStyle ? 'Identity' : 'Identity *',
                      controller: form.identity,
                      hintText: _placeholder(
                        'eg. A hometown kid back for one real shot',
                      ),
                      maxLength: originCharacterIdentityMaxLength,
                      requiredIndicator: worldoStyle,
                      note: showFieldNotes
                          ? "The character's role in the worldo."
                          : null,
                      labelSize: resolvedLabelSize,
                      labelFontWeight: resolvedLabelFontWeight,
                      labelInputGap: resolvedLabelInputGap,
                      fieldBorderRadius: worldoStyle ? 13 : 8,
                      fieldPadding: worldoStyle
                          ? const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                      minimumHeight: worldoStyle ? 46 : null,
                      inputFontSize: worldoStyle ? 13 : 14,
                      hintFontSize: worldoStyle ? 13 : null,
                      inputLineHeight: worldoStyle ? 1.55 : 1.42,
                      supportLineGap: worldoStyle ? 8 : 8,
                      supportItemGap: worldoStyle ? 7 : 12,
                      supportTextStyle: worldoStyle ? worldoSupportStyle : null,
                      supportIconColor: worldoStyle
                          ? context.genesisColors.textTimestamp
                          : null,
                      supportIconSize: worldoStyle ? 12 : 16,
                      supportIconGap: worldoStyle ? 7 : 5,
                      counterTextStyle: worldoStyle ? worldoCounterStyle : null,
                      maxLines: 3,
                      scrollPadding: textFieldScrollPadding,
                      focusNode: form.focusNodes.identity,
                      nextFocusNode: _nextAfterIdentity,
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                  if (showPersonality && !identityBelowAvatarRow) ...[
                    SizedBox(height: resolvedFieldGap),
                    CreateTextFieldBlock(
                      label: worldoStyle ? 'Personality' : 'Personality *',
                      controller: form.personality,
                      hintText: _placeholder(
                        'eg. Underdog with goodwill but little capital',
                      ),
                      maxLength: 100,
                      requiredIndicator: worldoStyle,
                      note: showFieldNotes
                          ? "The character's manner of speaking and behaving, which drives their dialogue."
                          : null,
                      labelSize: resolvedLabelSize,
                      labelFontWeight: resolvedLabelFontWeight,
                      labelInputGap: resolvedLabelInputGap,
                      fieldBorderRadius: worldoStyle ? 13 : 8,
                      fieldPadding: worldoStyle
                          ? const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                      minimumHeight: worldoStyle ? 46 : null,
                      inputFontSize: worldoStyle ? 13 : 14,
                      hintFontSize: worldoStyle ? 13 : null,
                      inputLineHeight: worldoStyle ? 1.55 : 1.42,
                      supportLineGap: worldoStyle ? 8 : 8,
                      supportItemGap: worldoStyle ? 7 : 12,
                      supportTextStyle: worldoStyle ? worldoSupportStyle : null,
                      supportIconColor: worldoStyle
                          ? context.genesisColors.textTimestamp
                          : null,
                      supportIconSize: worldoStyle ? 12 : 16,
                      supportIconGap: worldoStyle ? 7 : 5,
                      counterTextStyle: worldoStyle ? worldoCounterStyle : null,
                      maxLines: 3,
                      scrollPadding: textFieldScrollPadding,
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
        SizedBox(height: resolvedSectionGap),
        if (identityBelowAvatarRow) ...[
          CreateTextFieldBlock(
            label: worldoStyle ? 'Identity' : 'Identity *',
            controller: form.identity,
            hintText: _placeholder('eg. A hometown kid back for one real shot'),
            maxLength: originCharacterIdentityMaxLength,
            requiredIndicator: worldoStyle,
            note: showFieldNotes ? "The character's role in the worldo." : null,
            labelSize: resolvedLabelSize,
            labelFontWeight: resolvedLabelFontWeight,
            labelInputGap: resolvedLabelInputGap,
            fieldBorderRadius: worldoStyle ? 13 : 8,
            fieldPadding: worldoStyle
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            minimumHeight: worldoStyle ? 46 : null,
            inputFontSize: worldoStyle ? 13 : 14,
            hintFontSize: worldoStyle ? 13 : null,
            inputLineHeight: worldoStyle ? 1.55 : 1.42,
            supportLineGap: worldoStyle ? 8 : 8,
            supportItemGap: worldoStyle ? 7 : 12,
            supportTextStyle: worldoStyle ? worldoSupportStyle : null,
            supportIconColor: worldoStyle
                ? context.genesisColors.textTimestamp
                : null,
            supportIconSize: worldoStyle ? 12 : 16,
            supportIconGap: worldoStyle ? 7 : 5,
            counterTextStyle: worldoStyle ? worldoCounterStyle : null,
            maxLines: 3,
            scrollPadding: textFieldScrollPadding,
            focusNode: form.focusNodes.identity,
            nextFocusNode: _nextAfterIdentity,
            onChanged: (_) => onChanged(),
          ),
          if (showPersonality) ...[
            SizedBox(height: resolvedFieldGap),
            CreateTextFieldBlock(
              label: worldoStyle ? 'Personality' : 'Personality *',
              controller: form.personality,
              hintText: _placeholder(
                'eg. Underdog with goodwill but little capital',
              ),
              maxLength: 100,
              requiredIndicator: worldoStyle,
              note: showFieldNotes
                  ? "The character's manner of speaking and behaving, which drives their dialogue."
                  : null,
              labelSize: resolvedLabelSize,
              labelFontWeight: resolvedLabelFontWeight,
              labelInputGap: resolvedLabelInputGap,
              fieldBorderRadius: worldoStyle ? 13 : 8,
              fieldPadding: worldoStyle
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              minimumHeight: worldoStyle ? 46 : null,
              inputFontSize: worldoStyle ? 13 : 14,
              hintFontSize: worldoStyle ? 13 : null,
              inputLineHeight: worldoStyle ? 1.55 : 1.42,
              supportLineGap: worldoStyle ? 8 : 8,
              supportItemGap: worldoStyle ? 7 : 12,
              supportTextStyle: worldoStyle ? worldoSupportStyle : null,
              supportIconColor: worldoStyle
                  ? context.genesisColors.textTimestamp
                  : null,
              supportIconSize: worldoStyle ? 12 : 16,
              supportIconGap: worldoStyle ? 7 : 5,
              counterTextStyle: worldoStyle ? worldoCounterStyle : null,
              maxLines: 3,
              scrollPadding: textFieldScrollPadding,
              focusNode: form.focusNodes.personality,
              nextFocusNode: _nextAfterPersonality,
              onChanged: (_) => onChanged(),
            ),
          ],
          SizedBox(height: resolvedFieldGap),
        ],
        if (showGoal) ...[
          CreateTextFieldBlock(
            label: 'Goal (Optional)',
            controller: form.goal,
            hintText: _placeholder(
              'eg. Be the richest owner on Main Street by Labor Day',
            ),
            maxLength: 100,
            note: showFieldNotes
                ? "The character's goal or behavioral direction, which drives how they act."
                : null,
            minLines: 2,
            maxLines: 3,
            labelSize: resolvedLabelSize,
            labelFontWeight: resolvedLabelFontWeight,
            labelInputGap: resolvedLabelInputGap,
            fieldBorderRadius: worldoStyle ? 13 : 8,
            fieldPadding: worldoStyle
                ? const EdgeInsets.fromLTRB(14, 13, 14, 13)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            minimumHeight: worldoStyle ? 66 : null,
            inputFontSize: worldoStyle ? 13 : 14,
            hintFontSize: worldoStyle ? 13 : null,
            inputLineHeight: worldoStyle ? 1.55 : 1.42,
            supportLineGap: worldoStyle ? 8 : 8,
            supportItemGap: worldoStyle ? 7 : 12,
            supportTextStyle: worldoStyle ? worldoSupportStyle : null,
            supportIconColor: worldoStyle
                ? context.genesisColors.textTimestamp
                : null,
            supportIconSize: worldoStyle ? 12 : 16,
            supportIconGap: worldoStyle ? 7 : 5,
            counterTextStyle: worldoStyle ? worldoCounterStyle : null,
            scrollPadding: textFieldScrollPadding,
            focusNode: form.focusNodes.goal,
            nextFocusNode: form.focusNodes.bio,
            onChanged: (_) => onChanged(),
          ),
          SizedBox(height: resolvedFieldGap),
        ],
        CreateTextFieldBlock(
          label: 'Background - Hidden (Optional)',
          controller: form.bio,
          hintText: _placeholder(
            'eg. Left town years ago; returned to a boarded-up Main Street for one chance.',
          ),
          maxLength: originCharacterBioMaxLength,
          note: showFieldNotes
              ? "The character's background and relationships."
              : null,
          minLines: 3,
          maxLines: bioMaxLines ?? 8,
          labelSize: resolvedLabelSize,
          labelFontWeight: resolvedLabelFontWeight,
          labelInputGap: resolvedLabelInputGap,
          fieldBorderRadius: worldoStyle ? 13 : 8,
          fieldPadding: worldoStyle
              ? const EdgeInsets.fromLTRB(14, 13, 14, 13)
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          minimumHeight: worldoStyle ? 88 : null,
          inputFontSize: worldoStyle ? 13 : 14,
          hintFontSize: worldoStyle ? 13 : null,
          inputLineHeight: worldoStyle ? 1.55 : 1.42,
          supportLineGap: worldoStyle ? 8 : 8,
          supportItemGap: worldoStyle ? 7 : 12,
          supportTextStyle: worldoStyle ? worldoSupportStyle : null,
          supportIconColor: worldoStyle
              ? context.genesisColors.textTimestamp
              : null,
          supportIconSize: worldoStyle ? 12 : 16,
          supportIconGap: worldoStyle ? 7 : 5,
          counterTextStyle: worldoStyle ? worldoCounterStyle : null,
          scrollPadding: textFieldScrollPadding,
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
