# Worldo UI Design System

本文档是 Worldo Flutter UI 的实现规范。当前生产视觉基准是
`GenesisSkin.worldoRedesign`。新页面必须从统一出口导入组件：

```dart
import 'package:genesis_flutter_android/ui/genesis_ui.dart';
```

## 分层边界

```text
lib/ui/tokens/          字体、间距、圆角、触控、动效、阴影
lib/ui/theme/           ThemeData、语义颜色、皮肤和组件尺寸
lib/ui/components/      不依赖接口、路由或业务状态的纯 UI 组件
lib/components/common/ 跨页面弹窗、Toast、上传反馈等交互组件
lib/components/feature/ World、Origin、Chat、Gem 等业务 UI
lib/pages/feature/      页面状态、数据组合、导航和页面私有 Widget
```

地图地形、Fog、图片内容、裁剪器和业务状态色属于 feature，不要为了消除
颜色常量而错误地映射为页面背景或文字色。

## Token 规范

- 间距只使用 `GenesisSpacing`：2、4、6、8、10、12、14、16、20、24。
- 普通页面左右边距 16；表单/编辑页 20；大区块间距 24。
- 圆角使用 `GenesisRadii`；输入框 11、卡片 14、Sheet 顶部 24、Pill 999。
- 字体使用 `GenesisTypography`，标题不得在页面内重新声明近似字号：

| 角色 | 规范 | 入口 |
|---|---|---|
| 根页面大标题 | 24/900/1，字距 -0.015em | `GenesisPageTitle`、`GenesisLargePageHeader` |
| 用户显示名 | 24/900/1 | `GenesisDisplayTitle` |
| 普通导航标题 | 17/800/1 | `GenesisAppBar.leadingTitle`、`GenesisBackAppBar` |
| 沉浸式标题 | 17/800/1.1 | `GenesisTypography.immersiveTitle` |
| 内容实体标题 | 17/900/1.15 | `GenesisTypography.contentTitle` |
| 区块标题 | 15/800/1 | `GenesisSectionHeader` |
| 常规数值 | 24/900/1 | `GenesisMetricValueText` |
| 强调数值 | 30/900/1 | `GenesisMetricValueText(size: prominent)` |

Body 14、Supporting 12、Label 13/700、Caption 10 继续使用对应的
`GenesisTypography` token。
- 所有交互点击区域至少 44×44；视觉尺寸与点击区域不同的控件使用
  `GenesisControlMetrics`。
- 动效使用 `GenesisMotion`，阴影使用 `GenesisShadows`。
- Widget 不直接读取 `GenesisPalette`，只读取 `context.genesisColors` 或
  feature ThemeExtension。

## Light / Dark 换肤

Worldo 只有一套布局和一个皮肤身份，明暗模式只替换颜色：

```dart
MaterialApp(
  theme: GenesisTheme.worldoLight(),
  darkTheme: GenesisTheme.worldoDark(),
  themeMode: themeMode,
)
```

- 不再使用或新增 `GenesisTheme.light()`、`GenesisTheme.worldoRedesign()`。
- Light 和 Dark 都使用 `GenesisSkin.worldoRedesign`，并共享同一个
  `GenesisUiTheme.worldo()` 尺寸配置。
- 页面和组件不得根据 `ThemeMode`、`Brightness` 或皮肤身份改变 Widget
  结构、边距、字号、尺寸、圆角和交互。
- 页面只读取语义色；Feature 专用颜色从对应 ThemeExtension 读取。
- 地图、Fog、Terrain、图片遮罩和场景上的光学叠层属于内容视觉，不进行
  简单反色。
- Developer Page 的 Appearance 选择器用于验证 System、Light、Dark；
  普通生产用户仍默认使用当前 Dark 视觉。

## 页面与标题

### 根 Tab 页面

需要显示文字大标题的根页面使用 24px/w900/1、左对齐和左右 20；使用
`GenesisLargePageHeader`。例如 Messages：

```dart
GenesisLargePageHeader(
  title: 'Messages',
)
```

Home 的 Logo + Search、Worlds 的 Search + Tabs、Me 的滚动折叠头属于已定义的
根页面变体，不另行复制大标题样式。

### 普通二级页面

标题左对齐，17px/w800/1，AppBar 高 64。返回按钮视觉 34×34、图标 14、
圆角 11，点击区域 44×44，视觉左边距 20，标题与返回按钮间距 12：

```dart
GenesisPageScaffold.secondary(
  title: 'Settings',
  body: const SettingsContent(),
)
```

### 创建和编辑页

与普通二级页使用同一套 17px/w800 导航标题和 64px AppBar。右侧文字入口
使用 12px/w600、9px 同色箭头。返回按钮与标题间距 12，页面左右
边距 20，并保持 44×44
最小点击区；使用 `GenesisAppBarActionLink`，不要在页面内组合 `TextButton`
和系统 Chevron：

```dart
GenesisPageScaffold.editor(
  title: 'Basics',
  actions: [
    Padding(
      padding: const EdgeInsets.only(right: 20),
      child: GenesisAppBarActionLink(
        label: 'Records',
        onPressed: openRecords,
      ),
    ),
  ],
  body: const BasicsForm(),
)
```

沉浸式地图、聊天和图片页面使用 `GenesisPageScaffold.immersive`，内部结构
仍由 feature 管理，但返回按钮、SafeArea 和系统栏必须使用公共能力。

AppBar 标题固定单行省略。禁止通过页面局部修改标题字号、位置或高度来处理
长标题。

## 表单与按钮

- 单行输入最小高 44，使用 `GenesisTextField`。
- 多行输入使用 `GenesisTextArea`，选择入口使用 `GenesisSelectField`。
- Label、必填星号、Hint、错误、帮助文案、Focus 边框和字数统计由组件处理。
- Create/Edit 中已有的复杂键盘、草稿和焦点链路可以保留 feature wrapper，
  但其表面、颜色和文字层级必须来自公共 token。
- 页面主操作使用 `GenesisButton`，变体只有 primary、secondary、muted、
  destructive；常规高 42，紧凑高 40。Loading 时组件负责禁用重复点击。

```dart
GenesisTextField(
  controller: nameController,
  label: 'Name',
  requiredIndicator: true,
  hintText: 'Enter a name',
  errorText: nameError,
  maxLength: 30,
)
```

## 区块、轻量控件与元数据

- 页面中的“标题 + 内容卡片”使用 `GenesisSectionPanel`，不要在新页面重复
  `GenesisSectionHeader + GenesisSurface` 的组合。
- 页头、卡片或面板中的小型图标操作使用 `GenesisControlButton`。其视觉尺寸
  默认 34，但实际点击区域为 44；返回和 Sheet 关闭仍分别使用
  `GenesisBackButton`、`GenesisBottomSheetCloseButton`。
- 筛选条件使用 `GenesisFilterChip`。选中态遵循表面反转规则：Light 为深色
  底，Dark 为浅色底，不使用 Accent 冒充选中状态。
- 不可点击的分类、属性和状态短文本使用 `GenesisTag`；可选 tone 只有
  neutral、accent、danger。可点击或可选择内容不能伪装成 Tag。
- 未读数量使用 `GenesisUnreadBadge`，组件负责隐藏 0 和把大于 99 的数量
  显示为 `99+`。

```dart
GenesisSectionPanel(
  title: 'Preferences',
  child: Wrap(
    spacing: GenesisSpacing.md,
    children: [
      GenesisFilterChip(
        label: 'Active',
        selected: filter == Filter.active,
        onPressed: selectActive,
      ),
      const GenesisTag(label: 'world'),
    ],
  ),
)
```

## 图标规范

参考 Worldo Redesign 的图标审计，公共图标按用途而不是按页面选择：

- Navigation：22px、2.3 stroke，只用于底部导航。
- Control：14–15px、1.8 stroke，用于返回、关闭、搜索、展开和更多操作。
- Meta：12–14px、1.4 stroke，用于时间、位置、编辑、目标等行内信息。
- Cover stat：10px、outline，用于图片上的播放、消息和角色统计。

同一含义只能有一个 drawing 和一个 scale family。状态点、头像、Gem 和品牌
资产可以是实心；普通控件不得用字体字符临时代替图标。业务专属图标仍由
feature 管理，但尺寸、线宽和语义颜色遵循上述 family。

## Dialog 与 Bottom Sheet

### Action Box

确认、删除和不超过三个操作的选择使用 `showGenesisActionBox`。固定规范为：

- 手机宽度的 70%，圆角 18。
- 边框 1px、`textPrimary` 14% 不透明度。
- 默认标题区高 82，操作行高 51。
- 操作超过三个时必须改为 Bottom Sheet。

```dart
final confirmed = await showGenesisActionBox<bool>(
  context: context,
  title: 'Delete this item?',
  actions: const [
    GenesisActionBoxAction(label: 'Delete', value: true),
  ],
);
```

### Content Dialog

包含结构化内容、进度或表单时使用 `showGenesisContentDialog` 和
`GenesisDialog`。只有不可中断的进行中操作才设置
`barrierDismissible: false`。

### Bottom Sheet

使用 `showGenesisModalBottomSheet` 展示路由，内容使用以下之一：

- `GenesisBottomSheetPanel`：固定高度。
- `GenesisBottomSheetPanel.content`：随内容高度。
- `GenesisBottomSheetPanel.scrollable`：固定可用高度、内部滚动。

Sheet 顶部圆角 24，默认 padding 为 16/20/16/14，标题 17px/w800，
标题与内容间距 20。关闭图标视觉 24，点击区域 44。长内容和输入表单必须
开启 `isScrollControlled` 并验证键盘避让。

## 反馈、列表和媒体

- Loading、Empty、Error、Retry、Load More 使用 `GenesisStateView`。
- 骨架使用 `GenesisSkeleton`，不要在页面复制 shimmer 实现。
- 短提示使用 `showGenesisToast`，不要新增 SnackBar。
- 设置/入口行使用 `GenesisNavigationRow`；默认高 47。
- 搜索使用 `GenesisSearchField.launcher/editable`；标准高 38，紧凑高 36。
- 头像、角色头像和列表图片分别使用 `GenesisAvatar`、
  `GenesisCharacterAvatar`、`GenesisListImage`，不要混用裁剪策略。

完整状态可在 Developer Page 的 **Design System Gallery** 中查看。

## 保持在 Feature 内的组件

以下组件虽然在业务内部可能重复，但包含稳定的业务语义，不进入通用 UI 层：

- World 地图位置、玩家环、拥挤人数和未读事件标记。
- Chat 对话气泡、发送/失败状态、Tick 与叙事事件卡。
- Origin 角色选择、Launch、Opening、Location 等业务卡片。
- Gem 商品、奖励、余额和购买状态组件。
- Discuss 点赞、回复、Story 状态和评论组合行。

如果两个页面只是“看起来接近”，但数据、状态或交互语义不同，应优先共享
token 或内部 primitive，不创建带大量开关参数的万能业务组件。

## Do / Don't

Do：

- 修改公共默认值前检查全部 call site 和组件测试。
- 页面只组合组件、处理状态、导航和业务回调。
- 新增语义颜色前先确认它代表稳定用途，而不是某个截图中的物理颜色。
- 对长文本、1.3 倍文字缩放、窄屏、键盘和 SafeArea 做验证。

Don't：

- 不在页面直接使用 `AppBar`、`AlertDialog`、`showDialog`、
  `showModalBottomSheet` 或 `showGeneralDialog`。
- 不在页面直接使用 `Color(0x...)`、`Colors.white/black` 或
  `GenesisPalette`。
- 不为一次性尺寸创建新的全局 token，也不把业务卡片强行放进 `lib/ui`。
- 不因 UI 迁移修改文案、路由、接口、分页、草稿、上传、埋点或购买逻辑。

## PR 检查表

- [ ] 新页面使用正确的 root/secondary/editor/immersive 页面骨架。
- [ ] 返回按钮、标题、边距、按钮、表单和弹层来自公共组件。
- [ ] 颜色为语义色，常用间距和字体来自 token。
- [ ] 覆盖 Loading、Empty、Error、Retry 和 Disabled/Loading 操作状态。
- [ ] 通过长文本、文字缩放、窄屏、SafeArea 和键盘验证。
- [ ] 运行相关 widget tests、`theme_architecture_test.dart`、
      `flutter analyze`，并进行 Android/iOS 截图对比。
