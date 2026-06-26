import 'package:flutter/material.dart';

import '../../components/world_details_shell.dart';

const String worldSectionEventsIconAsset =
    'assets/custom-icons/svg/world_tab_events.svg';
const String worldSectionStatusIconAsset =
    'assets/custom-icons/svg/world_tab_status.svg';
const String worldSectionCastIconAsset =
    'assets/custom-icons/svg/world_tab_cast.svg';
const String worldDetailIconAsset =
    'assets/custom-icons/svg/worlddetail-icon.svg';
const double worldMapTabsHeight = 38;
const double worldMapBackButtonLeft = 9.5;
const double worldMapIdentityHorizontalGap = 12;
const double worldMainTabsHeight = 53;
const double worldBottomTagHeight = 34;
const double worldBottomTagToStatsGap = 10;
const double worldStatsTopSpacerHeight =
    (worldMainTabsHeight + worldBottomTagHeight) / 2 -
    WorldDetailsPageScaffold.inlineContentTopPadding +
    worldBottomTagToStatsGap;
const double worldInfoHeaderHeight = 56;
const double worldInfoHeaderContentHeight = 35;
const double worldTimePillTopGap = 12;
const double worldTimePillHeight = 22;
const double worldTimePillMinWidth = 96;
const double worldSecondaryMapControlWidth = 160;
const double worldTimePillHorizontalPadding = 12;
const double worldMapContentTopOffset =
    worldMapTabsHeight + worldTimePillTopGap + worldTimePillHeight + 8;
const double worldCharacterAvatarLogicalSize = 48;
const int worldMainPageCount = 1;

const Color worldHeaderMetaColor = Color(0xFF666666);
const TextStyle worldHeaderMetaTextStyle = TextStyle(
  fontSize: 12,
  height: 1.1,
  fontWeight: FontWeight.w400,
  color: worldHeaderMetaColor,
);
const TextStyle worldDetailBodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.45,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
);
