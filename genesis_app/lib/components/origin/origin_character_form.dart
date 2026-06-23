import 'package:flutter/material.dart';

import '../../pages/create/create_form_widgets.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';

class OriginCharacterForm {
  OriginCharacterForm({
    required this.charId,
    required this.avatarUrl,
    required this.name,
    required this.identity,
    required this.personality,
    required this.bio,
    required this.goal,
  });

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
  }) {
    return OriginCharacterForm(
      charId: charId,
      avatarUrl: TextEditingController(text: avatarUrl),
      name: TextEditingController(text: name),
      identity: TextEditingController(text: identity),
      personality: TextEditingController(text: personality),
      bio: TextEditingController(text: bio),
      goal: TextEditingController(text: goal),
    );
  }

  final String charId;
  final TextEditingController avatarUrl;
  final TextEditingController name;
  final TextEditingController identity;
  final TextEditingController personality;
  final TextEditingController bio;
  final TextEditingController goal;

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
    return controllers.any((controller) => controller.text.trim().isNotEmpty);
  }

  void clear() {
    for (final controller in controllers) {
      controller.clear();
    }
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
    this.avatarCropSize = const Size(512, 512),
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
    this.textFieldScrollPadding,
  });

  final OriginCharacterForm form;
  final VoidCallback onChanged;
  final bool showPersonality;
  final bool showGoal;
  final double avatarWidth;
  final double avatarHeight;
  final double avatarIconSize;
  final Size avatarCropSize;
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
  final EdgeInsets? textFieldScrollPadding;

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
              label: 'AVATAR\n(Optional)',
              width: avatarWidth,
              height: avatarHeight,
              iconSize: avatarIconSize,
              cropSize: avatarCropSize,
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
                    label: 'Name *',
                    controller: form.name,
                    hintText: 'Enter name...',
                    maxLength: 30,
                    labelSize: labelSize,
                    labelFontWeight: labelFontWeight,
                    labelInputGap: labelInputGap,
                    maxLines: 1,
                    scrollPadding: textFieldScrollPadding,
                    onChanged: (_) => onChanged(),
                  ),
                  if (!identityBelowAvatarRow) ...[
                    SizedBox(height: fieldGap),
                    CreateTextFieldBlock(
                      label: 'Identity *',
                      controller: form.identity,
                      hintText: 'Who they are in the world',
                      maxLength: 100,
                      labelSize: labelSize,
                      labelFontWeight: labelFontWeight,
                      labelInputGap: labelInputGap,
                      maxLines: 3,
                      scrollPadding: textFieldScrollPadding,
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                  if (showPersonality && !identityBelowAvatarRow) ...[
                    SizedBox(height: fieldGap),
                    CreateTextFieldBlock(
                      label: 'Personality *',
                      controller: form.personality,
                      hintText: 'How they speak and behave',
                      maxLength: 100,
                      labelSize: labelSize,
                      labelFontWeight: labelFontWeight,
                      labelInputGap: labelInputGap,
                      maxLines: 3,
                      scrollPadding: textFieldScrollPadding,
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
            label: 'Identity *',
            controller: form.identity,
            hintText: 'Who they are in the world',
            maxLength: 100,
            labelSize: labelSize,
            labelFontWeight: labelFontWeight,
            labelInputGap: labelInputGap,
            maxLines: 3,
            scrollPadding: textFieldScrollPadding,
            onChanged: (_) => onChanged(),
          ),
          if (showPersonality) ...[
            SizedBox(height: fieldGap),
            CreateTextFieldBlock(
              label: 'Personality *',
              controller: form.personality,
              hintText: 'How they speak and behave',
              maxLength: 100,
              labelSize: labelSize,
              labelFontWeight: labelFontWeight,
              labelInputGap: labelInputGap,
              maxLines: 3,
              scrollPadding: textFieldScrollPadding,
              onChanged: (_) => onChanged(),
            ),
          ],
          SizedBox(height: sectionGap),
        ],
        if (showGoal) ...[
          CreateTextFieldBlock(
            label: 'Goal (Optional)',
            controller: form.goal,
            hintText: 'What they want to achieve',
            maxLength: 100,
            minLines: 2,
            labelSize: labelSize,
            labelFontWeight: labelFontWeight,
            labelInputGap: labelInputGap,
            scrollPadding: textFieldScrollPadding,
            onChanged: (_) => onChanged(),
          ),
          SizedBox(height: sectionGap),
        ],
        CreateTextFieldBlock(
          label: 'Backgroud - Hidden (Optional)',
          controller: form.bio,
          hintText: 'Background and relationships',
          maxLength: 500,
          minLines: 3,
          maxLines: bioMaxLines,
          labelSize: labelSize,
          labelFontWeight: labelFontWeight,
          labelInputGap: labelInputGap,
          scrollPadding: textFieldScrollPadding,
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
