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
