import 'package:flutter/material.dart';

const String worldSectionEventsIconAsset = 'assets/custom-icons/svg/events.svg';
const String worldSectionStatusIconAsset =
    'assets/custom-icons/svg/world_tab_status.svg';
const String worldSectionCastIconAsset =
    'assets/custom-icons/svg/world_tab_cast.svg';
const String worldDetailIconAsset =
    'assets/custom-icons/svg/worlddetail-icon.svg';
const double worldMapTabsHeight = 38;
const double worldMapBackButtonLeft = 9.5;
const double worldMapIdentityHorizontalGap = 12;
const double worldMapHeaderHorizontalPadding = 18;
const double worldMapHeaderTopPadding = 12;
const double worldMapHeaderButtonSize = 34;
const double worldMapHeaderTitleGap = 10;
const double worldSheetTitleBottomGap = 8;
// 设计稿原文:拉起条 `margin:10px auto 12px` + 自身 4px = 26。
const double worldPanelHandleBandHeight = 26;
const double worldMainTabsHeight = 45;
const double worldBottomTagHeight = 34;
// 设计稿原文:Playing 行 `padding:0 20px 13px`,头像 40 + 2px 红环 = 44。
const double worldInfoHeaderHeight = 57;
// 34 是设计稿里最常用的控件高度(34 次):Home 搜索方块、Info 玻璃片、
// 9i 的 Select 按钮都是它。原先的 40 比同级控件高一档。
const double worldInfoHeaderContentHeight = 34;
const double worldCollapsedPanelBaseHeight =
    worldPanelHandleBandHeight + worldInfoHeaderHeight + worldMainTabsHeight;
const double worldTimePillTopGap = 12;
const double worldTimePillHeight = 22;
const double worldTimePillMinWidth = 96;
const double worldSecondaryMapControlWidth = 160;
const double worldTimePillHorizontalPadding = 12;
const double worldMapContentTopOffset =
    worldMapTabsHeight + worldTimePillTopGap + worldTimePillHeight + 8;
const double worldCharacterAvatarLogicalSize = 48;
const int worldMainPageCount = 1;

const TextStyle worldHeaderMetaTextStyle = TextStyle(
  fontSize: 13,
  height: 1.1,
  fontWeight: FontWeight.w400,
);
const TextStyle worldDetailBodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.45,
  fontWeight: FontWeight.w400,
);

/// World 详情浮窗统一行高。设计稿各行原本混着 1 / 1.15 / 1.4 / 1.5,
/// 落地时统一到 1.3。
const double worldDetailLineHeight = 1.3;

/// 详情页 WID / Owner / Source 三条 meta。设计稿 9f 是 9.5px,落地时提到 11px;
/// 颜色仍是 rgba(255,255,255,.56),字重 400。
const double worldDetailMetaFontSize = 11;
const TextStyle worldDetailMetaTextStyle = TextStyle(
  fontSize: worldDetailMetaFontSize,
  height: worldDetailLineHeight,
  fontWeight: FontWeight.w400,
);

/// meta 行尾图标边长。跟着字号走,描边才不会比正文重。
const double worldDetailMetaIconSize = worldDetailMetaFontSize;

/// 分区标题前那枚红色小方块的斜切角度。设计稿原文 `transform:skewY(-14deg)`。
const double worldDetailSectionGlyphSkew = -0.2443;

/// 角色行自身的上下内边距。设计稿 9f 原文 `padding:11px 0`。
/// 算 Cast 的行间距时要减掉两倍的它。
const double worldCharacterRowVerticalPadding = 11;

/// Cast 列表里两个角色之间的间距。
const double worldDetailCastRowGap = 24;

/// 详情浮窗顶部固定头(页码条 + 标题行)的高度。设计稿 9f:
/// 页码条 `padding:12px 0 14px` + 4px 圆点 = 30,标题行 26 高、`padding:0 20px 12px`,
/// 合计 30 + 26 + 12 = 68。正文从这里往下排,才有设计稿那 12px 的呼吸。
const double worldDetailSheetHeaderHeight = 68;

/// 标题行在固定头里的起始位置(页码条整段的下沿)。
const double worldDetailSheetHeaderTitleTop = 30;

/// 分区之间的间距。设计稿 9f 里 World brief / Cast 两处标题都是 `margin-top:17px`。
const double worldDetailSectionGap = 17;

/// 分区标题到它下面第一块内容的间距。设计稿 brief 是 9+11、Cast 是 10+11,
/// 落地统一到 20 —— 原先 Cast 那侧只有 12~17,和 brief 对不齐。
const double worldDetailSectionTitleContentGap = 20;

/// Cast 标题到第一个角色行要补的间距。角色行自身还带
/// worldCharacterRowVerticalPadding 的上内边距,两者相加才是
/// worldDetailSectionTitleContentGap,和 World brief 那侧对齐。
const double worldDetailCastTitleGap =
    worldDetailSectionTitleContentGap - worldCharacterRowVerticalPadding;
