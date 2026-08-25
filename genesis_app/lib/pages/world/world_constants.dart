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
// 设计稿原文:拉起条 `margin:10px auto 12px` + 自身 4 = 26。
// 实机上条与 Playing 行之间显空,底部留白收到 8,内容整体上移 4。
const double worldPanelHandleBandHeight = 22;
// 与主页面底 bar 同源:BottomTabs 的内容带也是 50(见 bottom_tabs.dart),
// 安全区由 GenesisSafeAreaInsets.bottom 的真实 inset 补,不再各算各的。
const double worldMainTabsHeight = 50;
const double worldBottomTagHeight = 34;
// Playing 行:头像外框 48(与详情页 Cast 行同规格,红环内置)+ 13 下内边距
// + 1 分隔线。
const double worldInfoHeaderHeight = 62;
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

/// Detail/Cast 行头像的显示 = 拉取尺寸。设计稿 9f 是 40,放大一档到 48
/// (56 试过,太大)。
const double worldCharacterAvatarLogicalSize = 48;

/// Detail/Cast 行头像圆角。设计稿 9f 头像原生就是 12,
/// 也落在封面(9)与 Status 卡片头像(13)之间。
const double worldCharacterAvatarRadius = 12;
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

/// 详情页纵向节奏,三档从紧到松:
///   标题→正文 12  <  Cast 行间 24  <  分区间 28
/// 标题必须离自己的正文最近(邻近原则),分区断点必须比行间距大才读得出来。
/// 设计稿 9f 原文是 20/17,标题反而比分区间距更远,这里按上述层级修正。
const double worldDetailSectionGap = 28;

/// 分区标题到它下面第一块内容的间距,约为 Cast 行间距的一半。
const double worldDetailSectionTitleContentGap = 12;

/// Cast 标题到第一个角色行要补的间距。角色行自身还带
/// worldCharacterRowVerticalPadding 的上内边距,两者相加才是
/// worldDetailSectionTitleContentGap,和 World brief 那侧对齐。
const double worldDetailCastTitleGap =
    worldDetailSectionTitleContentGap - worldCharacterRowVerticalPadding;
