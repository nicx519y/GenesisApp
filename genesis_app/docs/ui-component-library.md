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

统一使用 `lib/components/gems/subscription_benefit_icon.dart` 的 `SubscriptionBenefitIcon`。购买页权益行传入 18×18 图标占位和会员金色，不再显示淡色底框或右侧状态标签。

gem、badge、recharge 与兜底箭头按占位尺寸绘制；edit、inspiration 按 85% 绘制；memory 按 90% 绘制。传入其他 size 时保持相同比例，不修改 Message 操作栏或共享 SVG。

| 后端 icon_key | 图形 | 本地资源 |
| --- | --- | --- |
| gem | 宝石 | gem_diamond.svg |
| memory | 书本 | Material auto_stories_outlined |
| inspiration | 灵感 | icon_benefit_inspiration.svg |
| edit | 编辑 | icon_benefit_edit.svg |
| badge | 皇冠 | icon_benefit_badge.svg |
| recharge | 向上升级箭头 | `upgradeIconAsset` |
| 未知值（含已废弃 key） | 向上升级箭头 | `upgradeIconAsset` |

保留仍在使用的 `icon_benefit_edit`、`icon_benefit_inspiration`、`icon_benefit_badge` 共享资源，不恢复旧路径；旧线框宝石 `icon_benefit_gem` 已由 `gem_diamond` 替换并删除。图标只按 `icon_key` 映射，不根据 title/code 猜测。权益数据来自后端；购买页将 gem 权益合并为一个模块，其余按后端顺序展示，`display_type` 不再生成右侧状态图标，也不作为功能权限判断依据。

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

## Location Chat 连接失败反馈

WebSocket 连接、自动重连和加入地点失败保持静默，不显示横幅、系统消息或连接／加入失败 Toast。用户发送或重试消息时，连接／加入准备失败或明确发送失败才使用公共 `showGenesisToast` 提示；设备网络检查确认无网络时使用 `chatNoNetworkConnection`（英文 `Network unavailable. Check network.`）；设备有网络但 WebSocket 建联失败或 join 失败时使用 `chatConnectionFailed`（英文 `Could not connect to this chat`），发送与手动重试共用；其他明确发送失败缺少可展示错误文案时复用 `genericError`。后端发送错误沿用已有公共 Toast，避免重复展示；结果未知的请求保留未知状态，不自动重发。Regenerate、Go On、Edit 入口与保存、灵感加载与发送均先复用设备网络及连接／join 检查和上述两类提示；前置失败不发起业务请求、不清空输入、不新增气泡、不撤回已有回复。连接准备期间同样保留输入；只有准备成功才进入原提交路径。其他业务失败保留各操作原有提示。

LocationChat 和 MiniPhone Messages 共用系统网络快照检测：先确认设备有网络，再读取 World WebSocket 连接状态；无网络或检测失败时只显示 `chatNoNetworkConnection`，不继续连接检查。Android 使用默认活动网络的 Internet 与 validated 能力，iOS 使用当次 NWPathMonitor 路径，不再以本地 IP／VPN 网卡存在作为手机有网的依据。LocationChat 在 Socket 未连接时直接显示 `chatConnectionFailed`；Socket 已连接后仍须通过原地点 join 检查。Send、重试和四类回复操作沿用相同顺序。此原生通道更新需要重新构建安装，热重载不会更新原生实现。

2026-10-28 已通过飞书客户端同步「多语言翻译」第 112 行 `chatConnectionFailed`、第 115 行 `chatNoNetworkConnection` 的场景、备注、英文和全部 8 种目标译文；第 835 行 `genericError` 仅更新场景和备注。已同步「应用内所有Toast文案」的「toast 注释版」K7、K63、K65、K71，说明设备无网络与有网络但连接／加入失败的两类提示。已逐项回读并确认保存到云端；AI 译文未标为人工审校。

MiniPhone Messages 的发送和手动重试复用上述两条本地化提示：设备网络检查确认无网络时使用 `chatNoNetworkConnection`；设备有网络但共用 World WebSocket 未连接时使用 `chatConnectionFailed`。MiniPhone 不执行地点 join，也不受地点 join 状态限制。检查失败保留草稿及既有待确认请求，不下发 `/dm/send`、不新增请求日志或临时气泡；已下发请求的结果不明仍沿用原恢复流程。

2026-10-28 已同步飞书「多语言翻译」第 112、115 行的 MiniPhone 显示场景与备注，并同步「toast 注释版」K7；英文及全部目标译文复核后保持原样。已回读并确认保存到云端。

2026-10-28 本次追加：将同一前置检查扩展到 Regenerate、Go On、Edit 打开／保存和灵感加载／发送，MiniPhone 检查完成前也不清空输入。`chatConnectionFailed`、`chatNoNetworkConnection` 的英文与 8 种译文保持原样，仅扩展显示场景。用户明确要求本次不再更新飞书文档，因此跳过飞书第 112／115 行及「toast 注释版」备注同步；上文较早同步记录不代表本次场景已同步。

MiniPhone 的 Toast 通过 `shared/mini_phone_toast.dart` 复用公共组件，并在展示层过滤通用 `Request failed` 文本；合并错误时先逐项过滤。错误状态与恢复流程保留，明确的断网、连接失败及其他业务提示不受影响。本次按用户要求不更新飞书文档。

## 聊天输入栏高度通知

共享 `ChatComposer` 的 `onHeightChanged` 报告整个输入栏的布局高度，包含自身内边距及底部安全区。仅在有监听者时，从实际布局中读取尺寸；首次布局和后续高度变化均在本帧结束时通知外层，同帧多次布局只报告最终高度。未变化的高度不重复通知。

保留但尚未布局的隐藏页面等待实际布局，不定时轮询、不主动请求重试帧；脱离渲染树后丢弃待发送通知。新监听者会在布局后收到当前高度。普通私信用它更新列表底部留白及新消息入口，Worldo 开场输入区用变化通知更新键盘避让；地点聊天和 MiniPhone 私聊由父布局分配空间，不依赖此回调。

## 通用大图浏览与缩略图过渡

统一使用 `showGenesisImageViewer`／`GenesisImageViewerOverlay`。调用方传原图 URL 和实际显示的缩略图 `ImageProvider`（含相同 URL、解码尺寸和 fit），公共组件先复用缩略图缓存，大图加载完成后替换，失败时保留缩略图。

有缩略图来源的入口使用 `GenesisImageViewerSourceAnchor` 包装缩略图，将回调中的 `source` 传给 `showGenesisImageViewer`。包装器基于已缓存帧、实际 `BoxFit` 和 `alignment` 捕获绘制区域，并转换为根 Overlay 坐标；不要把固定图片占位区域中的空白算进起始图片尺寸。

公共打开动画位于 `genesis_image_viewer_transition.dart`：320ms、`easeOutCubic`，背景逐渐变黑，当前缓存帧从来源位置放大到大图的 fitWidth 布局；横图居中，超长竖图顶端对齐。飞行期间隐藏来源图片但保留布局和缓存，浏览器在下层正常加载大图，动画结束再接管绘制。中途关闭或完成后恢复来源；关闭继续使用通用浏览器现有交互和淡出。没有已加载缩略图／有效来源时保留淡入入口，系统开启减少动态效果时直接打开。业务页面不复制动画。

多图浏览在打开和当前页变化时预加载前后各一张大图，首尾不循环。预加载按最终页面的完整宽度（不除以 PageView 的分页间隔系数）、同一 DPR 和 CDN 规则选择图片；网络图片的解码宽度及 `BoxFit.fitWidth` 与显示组件一致，以复用同一个内存缓存键。预加载失败不打断浏览或弹出提示。

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

全局默认主题由 `GenesisTheme.dark()` 提供，并在 `lib/app/genesis_app.dart` 的 `MaterialApp.theme` 中使用，不随系统切换浅色；已有明确的局部浅色场景继续保持隔离。主题负责基础 Material 控件默认值，例如：

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

主按钮组件，固定单行省略，适合表单提交和页面底部主操作。

提交中传 `isLoading: true`：禁止重复提交，底色保持正常 `backgroundColor`，不套用普通禁用底色。已有圆环保留；原来没有圆环、只显示文字的按钮同时设置 `showLoadingIndicator: false`，保留原文案。圆环默认 18×18、线宽 2，已有调用的圆环覆盖参数继续保留；不因本规则统一前景颜色或增加圆环。

普通校验禁用仍使用 `onPressed: null` 和公共禁用配色。上述 loading 保留底色的规则也适用于自定义提交按钮：品牌红、灰底、金色渐变和透明底均保持原样。清单见 [用户端提交按钮](button-loading-states.md)。

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

购买 Sheet 使用 `.tabs` 变体，同样高 68，使用 16 / 600 的纯文字 Tab（无图标）与下划线；Subscription 下划线为会员金色、Buy Gems 为品牌红，文字仍用公共一级 / 二级白；Subscription 正文在该容器中设 `topSpacing: 0`，Buy Gems 设 `compactBalance: true`；两个 Tab 正文顶部均与 Header 底部对齐，Wallet 页面仍保留原有余额区布局。Mention、World / Worldo 内容面板和开发工具保留各自 Header。 订阅协议下方统一保留 10px，系统底部安全区由外层处理一次。

### GenesisActionSheetBody

交互 / 提交 Sheet 的正文公共布局，左右外边距固定 16。`GenesisActionSheetHeader.inset` 与正文引用同一个常量；普通深色 `GenesisBottomSheetPanel` 自动应用。购买 Tab 和新用户多步骤容器设置 `insetBody: false`，每页正文使用一次 `GenesisActionSheetBody`。发帖 / 回复等独立弹层也直接使用该控件。

标准边界覆盖表单、登录按钮、角色选择区、订阅权益卡、套餐和底部主按钮。订阅内容使用 `horizontalInset: 0` 接受外层布局，Wallet 完整页面使用 `horizontalInset: 16`，正文左右边距为 16。卡片内部留白及卡片间距不受此规范影响。


### Shared chat keyboard layout

`ChatKeyboardInsetLayout` now owns the keyboard/composer geometry previously
private to LocationChat. LocationChat retains its existing inset and frozen
mention-sheet behavior. MiniPhone uses the same layout with its private-chat
style and `LocationChatScrollCoordinator`, keeps keyboard focus on Send, and
disables reply-reserve positioning. Scroll notifications must be routed to the
coordinator to preserve a detached reader when new bubbles arrive.
