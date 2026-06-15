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
    this.avatarHeight = 168,
    this.avatarIconSize = 38,
    this.avatarCropSize = const Size(512, 512),
    this.showAvatarRemoveLink = false,
    this.topSpacing = 12,
    this.horizontalGap = 14,
    this.fieldGap = 14,
    this.sectionGap = 16,
    this.labelSize = 14,
    this.bioMaxLines,
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
  final double horizontalGap;
  final double fieldGap;
  final double sectionGap;
  final double labelSize;
  final int? bioMaxLines;

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
                    maxLength: 25,
                    labelSize: labelSize,
                    maxLines: 1,
                    onChanged: (_) => onChanged(),
                  ),
                  SizedBox(height: fieldGap),
                  CreateTextFieldBlock(
                    label: 'Identity *',
                    controller: form.identity,
                    hintText: 'Who they are in the world',
                    maxLength: 50,
                    labelSize: labelSize,
                    maxLines: 1,
                    onChanged: (_) => onChanged(),
                  ),
                  if (showPersonality) ...[
                    SizedBox(height: fieldGap),
                    CreateTextFieldBlock(
                      label: 'Personality *',
                      controller: form.personality,
                      hintText: 'How they speak and behave',
                      maxLength: 50,
                      labelSize: labelSize,
                      maxLines: 1,
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: sectionGap),
        CreateTextFieldBlock(
          label: 'Bio (Optional)',
          controller: form.bio,
          hintText: 'Background and relationships',
          maxLength: 1000,
          minLines: 3,
          maxLines: bioMaxLines,
          labelSize: labelSize,
          onChanged: (_) => onChanged(),
        ),
        if (showGoal) ...[
          SizedBox(height: sectionGap),
          CreateTextFieldBlock(
            label: 'Goal (Optional)',
            controller: form.goal,
            hintText: 'What they want to achieve',
            maxLength: 300,
            minLines: 2,
            labelSize: labelSize,
            onChanged: (_) => onChanged(),
          ),
        ],
      ],
    );
  }
}
