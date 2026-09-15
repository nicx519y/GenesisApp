# Genesis UI Component Library

本文档定义 Flutter 侧 UI 组件库的边界、样式 token 和迁移规则。目标是让页面代码少写内联样式，把颜色、字体、间距、圆角和常用控件统一到 `lib/ui`。

## 目录边界

```text
lib/ui/
  genesis_ui.dart              # 组件库统一出口
  tokens/                      # 设计 token：颜色、字体、间距、圆角
  theme/                       # 全局 ThemeData
  components/                  # 纯 UI 组件，不放业务请求和路由逻辑
```

业务组件仍保留在 `lib/components`，例如 `PageHeader`、`BottomTabs`、`origin/*`。这些组件可以组合 `lib/ui` 的 token 和基础组件，但不要把新 token 继续散落到页面内联常量里。

## Subscription 权益图标

统一使用 `lib/components/gems/subscription_benefit_icon.dart` 的 `SubscriptionBenefitIcon`。图标占位为 18×18、颜色为 `GenesisColors.darkTextSecondary`（约 72% 白），弱于 14 号权益正文的主文字色；权益行保留 28×28、圆角 8 的淡色底框。

所有图形在 18×18 占位中居中：gem、badge 绘制为 18×18；edit、inspiration 按 85% 绘制为 15.3×15.3；memory、recharge 和默认圆圈五角星按 90% 绘制为 16.2×16.2。传入其他 size 时保持相同比例。该调整只用于 Subscription 权益列表，不修改 Message 操作栏、右侧状态标签或共享 SVG。

| 后端 icon_key | 简洁图形 | 本地资源 |
| --- | --- | --- |
| gem | Buy Gems Tab 同款线条宝石 | icon_benefit_gem.svg |
| memory | 存储卡图标 | Material sd_storage_outlined |
| inspiration | Message 操作栏同款灵感图标 | icon_benefit_inspiration.svg |
| edit | Message 操作栏同款编辑图标 | icon_benefit_edit.svg |
| badge | 皇冠轮廓 | icon_benefit_badge.svg |
| recharge | 保留卡片加号 | Material add_card_outlined |
| 未知值（含已废弃 key） | 原圆圈内五角星 | Material stars_outlined |

原有四个 SVG 直接重命名为 `assets/custom-icons/svg/icon_benefit_<icon_key>.svg`，共享资源常量同步更新，其他页面继续引用同一份文件，不保留旧文件或额外副本。memory、recharge 和未知值继续使用原 Material 内置图标，不生成 SVG 或 PNG。

只按 `icon_key` 映射，不根据 title/code 猜测，不保留旧 key 别名。文案和排序继续由后端提供；`display_type` 决定右侧 enhanced 红色 UP、included 白色勾、locked 白色锁，客户端不为某项权益覆盖状态。共享 SVG 在其他页面仍有引用时不得删除。

## 使用入口

新代码优先只导入统一出口：

```dart
import 'package:genesis_flutter_android/ui/genesis_ui.dart';
```

现有页面暂时可以继续使用旧组件名，例如 `SearchBarPlaceholder`。它已经兼容转接到 `GenesisSearchField`，后续迁移页面时可以逐步替换为新的命名。

## 样式 Token

- `GenesisColors`：品牌色、文本色、背景色、边框色、状态色。
- `GenesisTypography`：页面标题、正文、强调正文、辅助文案、底部 tab 文案。
- `GenesisSpacing`：常用间距和页面左右边距。
- `GenesisRadii`：输入框、卡片、面板、底部弹层等圆角。

新增样式时先判断是否是全局语义。如果多个页面会共用，放入 token；如果只是某个业务卡片的个性样式，保留在对应业务组件内。

## 公共头像与默认头像

用户/通用头像使用 `GenesisAvatar`，角色头像使用 `GenesisCharacterAvatar`。两者在无头像或图片加载失败时使用公共 `GenesisAvatarFallback`，实现集中在 `lib/ui/components/genesis_avatar.dart`。Private Chat、Location Chat 非 NPC 消息、Tick 角色列表、地图、资料与列表等场景均遵循此规则。

| 属性 | 统一规则 |
| --- | --- |
| 默认底色 | `avatarColorForName(name)` 按名字稳定生成，同名保持同色 |
| 默认文字 | `initialsForAvatarName(name)` 生成名字缩写 |
| 字号 | 头像高度 × 0.34，最小 11、最大 28 个逻辑像素；40px 头像对应 13.6px |
| 字重 / 行高 | `FontWeight.w600` / 1 |
| 文字颜色 / 字体 | 白色；沿用公共字体体系 |
| 图片裁剪 | 默认 top-center；特殊角色肖像保留现有比例与布局 |

缩写规则由公共函数唯一实现：名字含中文汉字时，1–2 个汉字取首字，超过 2 个取最后两个；其他名字按空白、点、下划线、连字符分词，取前两个词的首字符并转大写；空名字显示 `?`。例如“张三”→“张”、“李七七”→“七七”、“Tom Lee”→“TL”。

调用方只管理名字、图片 URL、尺寸、圆角、玩家角色边框和外部布局，不自行绘制默认头像或覆盖默认文字的字号、字重、颜色、行高。调整相邻正文的字体不影响默认头像排版。特殊比例肖像可以直接复用 `GenesisAvatarFallback`；图片加载中的占位行为保持各场景已有约定。

**NPC 例外：** Location Chat 的 `char_npc` 保留 `ChatNpcAvatar` 固定“NPC”圆标及原有尺寸、底色、描边和文字样式，不改为名字缩写头像，也不因本规范替换为普通角色头像。

## Create Flow Typography

- Create 入口页的分组标题使用 `14px`，例如 `Basics`、`Characters`、`Locations`、`Story Events`。
- Create 入口页的终表摘要正文使用 `12px`，例如 `World Name: ...`、`1 characters: ...`、`2 Events`。
- Create 入口页 Basics 摘要里的 `World Name`、`Worldo Brief`、`Worldo Settings` 每项固定单行显示，超长内容使用省略号，不允许自动换行。
- 分组完成态使用绿色 check 图标表达，不再用 `Completed` 文案占用摘要位置。

## Theme

全局主题由 `GenesisTheme.light()` 提供，并在 `lib/app/genesis_app.dart` 的 `MaterialApp.theme` 中使用。主题负责基础 Material 控件默认值，例如：

- `ColorScheme`
- `scaffoldBackgroundColor`
- `TextTheme`
- `FilledButtonTheme`
- `InputDecorationTheme`

页面内不要再直接创建新的全局 `ThemeData`。如果需要页面局部覆盖，优先用组件参数或局部 `Theme` 包裹。

## 已落地组件

### GenesisActionBox

标准确认弹窗复用 `lib/components/common/genesis_action_box.dart`，按钮沿用组件默认样式：

- 第一个确认 / 主操作：`GenesisColors.redSecondary` + `FontWeight.w600`。
- Cancel：`GenesisColors.darkTextPrimary`（一级白）+ `FontWeight.w400`。
- 禁用操作：三级白，不可点击。Cancel 与主面板连接或分离时样式一致。

调用方提供文案、结果和业务行为，不重复覆盖确认按钮与 Cancel 的颜色、字重。

### GenesisInfoCard

普通深色信息卡的公共容器：6% 白底（`darkCardBackground`）、6% 白 1px 描边、8px 圆角，无模糊。选中态为 12% 品牌红底和 1.5px 红边。`darkPurchaseCardBackground` 引用同一底色；订阅 / Gems 的业务结构仍使用原组件。

```dart
GenesisInfoCard(
  padding: const EdgeInsets.all(14),
  selected: isSelected,
  onTap: onSelect, // 静态信息卡可省略
  child: content,
)
```

组件集中管理表面和点击反馈；业务层保留内容、选择逻辑及保存操作。Memory & Model 的内存上限卡、模型选择卡已接入。静态卡允许滑块浮标超出内容边界；可点击卡按圆角裁切。

Memory & Model 使用公共返回 Header，正文左右 16；正文使用 `GenesisTypography.body`（14px），辅助文案使用 `supporting`（12px）。“Max memory token limit / Choose model”为主标题，保留一级白。


### GenesisSearchField

通用搜索输入/占位组件，支持只读跳转和可编辑输入两种模式。

```dart
GenesisSearchField(
  hintText: 'Search origins, worlds, users...',
  onTap: () => Navigator.of(context).pushNamed(RouteNames.search),
)
```

兼容入口：`SearchBarPlaceholder` 仍可用，底层已复用 `GenesisSearchField`。

### GenesisPageTitle

页面标题组件，统一使用 `GenesisTypography.pageTitle`。

```dart
GenesisPageTitle(text: 'Origin')
```

### GenesisPageHeader

纯 UI 页面头部组件，组合标题和搜索框。它不依赖路由，业务层需要传入 `onSearchTap`。

```dart
GenesisPageHeader(
  title: 'Origin',
  onSearchTap: openSearchPage,
)
```

兼容入口：`components/PageHeader` 仍保留，负责把 `onSearchTap` 接到 `RouteNames.search`。

### GenesisPrimaryButton

主按钮组件，默认使用全局 `FilledButtonTheme`，固定单行省略，适合表单提交和页面底部主操作。

```dart
GenesisPrimaryButton(
  label: 'Continue',
  onPressed: canSubmit ? submit : null,
)
```

### GenesisBottomNavigation

底部导航的纯 UI/交互组件。业务层传入 items、选中下标和 `onTap`，组件本身不认识页面路由。

```dart
GenesisBottomNavigation(
  currentIndex: currentIndex,
  onTap: onTabTap,
  items: items,
)
```

兼容入口：`components/BottomTabs` 负责提供当前 App 的固定 tab 数据。

### GenesisTabBar

横向二级 TabBar 样式组件。业务层只传 labels，`TabController` 仍由上层页面或 `DefaultTabController` 提供。

```dart
GenesisTabBar(labels: categories)
```

### SecendTabs

项目内二级 tab 的稳定对外组件名，已经放在 `lib/ui` 并通过 `genesis_ui.dart` 导出。它支持直接传入 `controller`，适合 Me 页这种自己管理 `TabBarView` 的场景。

```dart
SecendTabs(
  controller: tabController,
  labels: const ['Origin', 'World'],
)
```

兼容入口：`components/secend_tabs.dart` 只 re-export UI 层组件。

## 迁移规则

1. 新 UI 优先使用 `lib/ui/genesis_ui.dart`。
2. 页面里出现重复的 `Color(...)`、`TextStyle(...)`、`EdgeInsets...`、`BorderRadius...` 时，先查 token。
3. 基础组件放 `lib/ui/components`，业务组合组件放 `lib/components`。
4. 基础组件不要直接依赖 `GenesisApi`、路由名、平台服务或页面状态。
5. 每迁移一个共享组件，至少保留一个 widget test 或现有回归测试覆盖关键行为。

## 下一批建议迁移

- `lib/components/page_header.dart`：已变成 `GenesisPageHeader` 的路由适配壳。
- `lib/components/bottom_tabs.dart`：已变成 `GenesisBottomNavigation` 的数据适配壳。
- `lib/components/secend_tabs.dart`：已变成 UI 层 `SecendTabs` 的兼容 re-export。
- `lib/pages/create/*`：表单输入框、图片占位块、底部主按钮重复度高，适合下一轮迁移到 `GenesisPrimaryButton` 和表单字段组件。
- `lib/components/origin/*`：卡片、统计项、详情区可以逐步收敛到统一卡片 token。


### 游客订阅后的强制登录预览

Developer Page → button → **Preview guest subscription login**（Creating 下方）。入口直接复用 `LoginSheet(isDismissible: false)`，用于检查游客订阅后必须登录的界面，不需要先购买订阅。

- 点击遮罩、下拉和系统返回均不能关闭登录面板。
- 面板外的 **Close preview** 是开发退出控件，不属于正式登录 UI。
- 点击 Google / Apple 模拟登录成功并关闭预览；不会调用 OAuth、创建订单或更改真实账号。
- 模拟登录等待期间退出，迟到的结果不会再次关闭底层页面。

Gems 购买仍通过 `PurchaseOptionsSheet` 的 Buy Gems Tab 展示。`GemPurchaseBottomSheet` 仅保留内嵌内容，已删除独立 header、关闭按钮、`embedded` 开关和旧的 `alert` 展示参数；余额告警入口仍保留实际告警到购买埋点的映射。

### GenesisActionSheetHeader

用户端交互 / 提交 Sheet 的公共 Header，总高 68（含正文前留白），标题 18 / 600、行高 24，左对齐，左右边距 16，标题与左右操作在 Header 内垂直居中。普通深色 `GenesisBottomSheetPanel` 自动复用；无固定高度的发帖 / 回复编辑弹层也直接复用，并将右侧关闭接到原有键盘退出动画。允许关闭的弹层使用标准圆形关闭按钮；新用户订阅保留 Skip。

购买 Sheet 使用 `.tabs` 变体，同样高 68，保留 16 / 600 的图标 Tab 与下划线；Subscription 正文在该容器中设 `topSpacing: 0`，Buy Gems 设 `compactBalance: true`；两个 Tab 正文顶部均与 Header 底部对齐，Wallet 页面仍保留原有余额区布局。Mention、World / Worldo 内容面板和开发工具保留各自 Header。

### GenesisActionSheetBody

交互 / 提交 Sheet 的正文公共布局，左右外边距固定 16。`GenesisActionSheetHeader.inset` 与正文引用同一个常量；普通深色 `GenesisBottomSheetPanel` 自动应用。购买 Tab 和新用户多步骤容器设置 `insetBody: false`，每页正文使用一次 `GenesisActionSheetBody`。发帖 / 回复等独立弹层也直接使用该控件。

标准边界覆盖表单、登录按钮、角色选择区、订阅权益卡、套餐和底部主按钮。订阅内容使用 `horizontalInset: 0` 接受外层布局，Wallet 完整页面使用 `horizontalInset: 16`，正文左右边距为 16。卡片内部留白及卡片间距不受此规范影响。
