import '../../../ui/tokens/genesis_colors.dart';

import '../../../ui/tokens/genesis_blur.dart';

import 'package:flutter/material.dart';

const double kChatStreamingTextFeatherWidth = 12;
const double kLocationChatOuterPadding = 10;
const double kChatScenePlateBubbleHorizontalPadding = 13;
const double kChatScenePlateBubbleVerticalPadding = 11;
const EdgeInsets kChatScenePlateBubblePadding = EdgeInsets.symmetric(
  horizontal: kChatScenePlateBubbleHorizontalPadding,
  vertical: kChatScenePlateBubbleVerticalPadding,
);
const double kChatBubbleRadius = 14;
const double kChatBubbleTailRadius = 2;
const double kLocationChatMessageBottomGap = 14;
const Color kChatBubbleTextColor = Color(0xFFF4F3F6);
const Color kChatBubbleEmphasisColor = Color(0xFF888888);
const Color kChatSelfBubbleColor = Color(0x99C41F2E);

/// [kChatSelfBubbleColor] at full strength, for marks that stand for the
/// user and would read muddy through the bubble's translucency.
const Color kChatSelfAccentColor = Color(0xFFC41F2E);
const Color kChatNarratorBubbleColor = Color(0x80151517);
const TextStyle kChatNarratorTextStyle = TextStyle(
  color: Color.fromRGBO(255, 255, 255, 0.73),
  fontSize: 14,
  height: 1.3,
  fontWeight: FontWeight.w400,
);
const double kChatSystemBubbleRadius = 8;
const EdgeInsets kChatSystemBubblePadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 6,
);
const Duration kChatReplyWaitingPeriod = Duration(milliseconds: 1050);
const double kChatReplyWaitingDotSize = 7;
const double kChatReplyWaitingDotSlotSize = 10;
const double kChatReplyWaitingDotGap = 3;
const double kChatReplyWaitingMinScale = 0.65;
const double kChatReplyWaitingScaleRange = 0.55;
const Color kChatScenePlateAiBubbleColor = Color(0x993A3942);
const Color kChatScenePlatePlayerRoleBorderColor = GenesisColors.redPrimary;
const double kChatScenePlateBubbleBlurSigma = GenesisBlur.strong;
const TextStyle kChatScenePlateBubbleTextStyle = TextStyle(
  color: kChatBubbleTextColor,
  fontSize: 14,
  height: 1.4,
  fontWeight: FontWeight.w400,
);
const BorderRadius kChatScenePlateAiBubbleBorderRadius = BorderRadius.only(
  topLeft: Radius.circular(kChatBubbleTailRadius),
  topRight: Radius.circular(kChatBubbleRadius),
  bottomRight: Radius.circular(kChatBubbleRadius),
  bottomLeft: Radius.circular(kChatBubbleRadius),
);
const BorderRadius kChatScenePlateSelfBubbleBorderRadius = BorderRadius.only(
  topLeft: Radius.circular(kChatBubbleRadius),
  topRight: Radius.circular(kChatBubbleTailRadius),
  bottomRight: Radius.circular(kChatBubbleRadius),
  bottomLeft: Radius.circular(kChatBubbleRadius),
);
