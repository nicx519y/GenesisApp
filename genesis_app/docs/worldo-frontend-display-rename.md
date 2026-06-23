# Origin 前端展示改为 Worldo 的改动梳理

## 背景

目标是把用户能看到的 `Origin` / `Origins` / `origin` 概念替换为 `Worldo` / `Worldos` / `worldo`。

本次只改前端展示文案，包括页面标题、按钮、表单标签、toast、空状态、登录提示、消息通知文案和对应 UI 测试。

## 改动边界

### 需要改

- 用户可见的固定文案。
- toast / snackbar / dialog / empty state 等提示文案。
- 搜索页 Tab 和分组标题。
- 创建、编辑、个人主页、未登录态、消息通知中的展示文案。
- 只因为展示文案变化而失败的 UI 测试断言。

### 不需要改

- API 路径，例如 `/api/v1/origin/*`。
- 后端字段名，例如 `origin_id`、`origin_name`、`origin_version`。
- 请求参数和响应字段，例如搜索里的 `type=origin`。
- Dart 内部类名、方法名、变量名、文件夹名，例如 `OriginDetail`、`OriginSummary`、`api.v1.origin`、`pages/origin`。
- 路由内部名，例如 `RouteNames.origin`。
- 缓存 key、`ValueKey`、测试 key。
- `OID` 展示名。
- `Originator` / `originator` 展示名和字段名。

## 需要改的前端文件

### 底部导航

文件：`genesis_app/lib/components/bottom_tabs.dart`

- `Origin` 改为 `Worldo`。

### Origin 列表页标题

文件：`genesis_app/lib/pages/origin/origin_page.dart`

- `PageHeader(pageName: 'Origin')` 改为 `PageHeader(pageName: 'Worldo')`。

### 搜索页

文件：`genesis_app/lib/pages/search/search_page.dart`

- 搜索 Tab 展示名：`Origin` 改为 `Worldo`。
- 搜索分组标题：`Origins` 改为 `Worldos`。
- 不改 `_SearchTab.origin` 的 `apiType: 'origin'`。
- 不改搜索结果 subtitle 中的 `OID` 和 `Originator`。

### 创建流程

文件：`genesis_app/lib/pages/create/create_origin_page.dart`

- 页面标题 `Create Origin` 改为 `Create Worldo`。
- toast `Origin created successfully: ...` 改为 `Worldo created successfully: ...`。

文件：`genesis_app/lib/pages/create/create_origin_draft_store.dart`

- 校验错误 `Basics: Origin Name is required.` 改为 `Basics: Worldo Name is required.`。

### 编辑流程

文件：`genesis_app/lib/pages/edit/edit_origin_page.dart`

- 页面标题 `Edit Origin` 改为 `Edit Worldo`。
- 错误提示 `Origin detail is unavailable.` 改为 `Worldo detail is unavailable.`。
- toast `Origin published successfully: ...` 改为 `Worldo published successfully: ...`。

### 编辑器表单

文件：`genesis_app/lib/pages/origin_editor/origin_basics_editor_page.dart`

- 表单 label `Origin Name *` 改为 `Worldo Name *`。

文件：`genesis_app/lib/pages/origin_editor/origin_story_events_editor_page.dart`

- hint `Show in Origin location list` 改为 `Show in Worldo location list`。

### 详情页

文件：`genesis_app/lib/pages/origin/origin_world_page.dart`

- 按钮 `Edit Origin` 改为 `Edit Worldo`。
- 不改 `OID`。
- 不改 `Originator`。

### 个人主页

文件：`genesis_app/lib/components/me/user_profile_content.dart`

- Tab `Origin` 改为 `Worldo`。
- 空状态 `No Origins you created yet.` 改为 `No Worldos you created yet.`。

文件：`genesis_app/lib/pages/me/me_page.dart`

- 仅检查由 `UserProfileOriginItem` 渲染出来的固定文案；内部方法名和变量名不改。

文件：`genesis_app/lib/pages/me/user_info_page.dart`

- 仅检查由 `UserProfileOriginItem` 渲染出来的固定文案；内部方法名和变量名不改。

### 登录和未登录提示

文件：`genesis_app/lib/components/login_sheet.dart`

- `Create origin, launch worlds and invite friends` 改为 `Create worldo, launch worlds and invite friends`。

文件：`genesis_app/lib/components/me/signed_out_me_view.dart`

- `Launch world, create origin, invite...` 改为 `Launch world, create worldo, invite...`。

### 消息通知

文件：`genesis_app/lib/pages/messages/message_category_list_page.dart`

- 返回给用户看的 suffix `comment your origin` 改为 `comment your worldo`。
- 用于兼容服务端旧内容的判断条件可以继续保留 `commented on your origin` 和 `comment your origin`，因为这不是用户最终看到的文案。

## 需要同步的测试

只改用户展示文案相关断言，不改 API、字段、请求路径和内部 key 的断言。

重点文件：

- `genesis_app/test/ui/genesis_ui_test.dart`
- `genesis_app/test/pages/search/search_page_test.dart`
- `genesis_app/test/widget_test.dart`
- `genesis_app/test/components/profile_collection_list_test.dart`

重点断言：

- `Origin` 改为 `Worldo`。
- `Origins` 改为 `Worldos`。
- `Create Origin` 改为 `Create Worldo`。
- `Edit Origin` 改为 `Edit Worldo`。
- `Origin created successfully: ...` 改为 `Worldo created successfully: ...`。
- `Origin published successfully: ...` 改为 `Worldo published successfully: ...`。
- `Origin Name is required.` 改为 `Worldo Name is required.`。
- `comment your origin` 改为 `comment your worldo`。

## 不建议同步修改的测试内容

以下内容虽然包含 `origin`，但属于协议、mock 数据或内部命名，不应在本次展示文案改名中修改：

- `/api/v1/origin/list`、`/api/v1/origin/detail`、`/api/v1/origin/create` 等路径断言。
- `origin_id`、`origin_name`、`origin_version` 等字段断言。
- `type=origin` 等请求参数断言。
- `OriginSummary`、`OriginDetail`、`originDisplayName` 等内部 API 或工具函数命名。
- `ValueKey('origin-...')`。
- `origin_hot_tags_v1` 等缓存 key。
- `OID` 和 `Originator` 相关断言。

## 建议执行顺序

1. 先改应用固定文案。
2. 再跑一次 `rg "Origin|Origins|origin|origins" genesis_app/lib`，人工过滤掉内部命名、API 字段、`OID` 和 `Originator`。
3. 同步修改 UI 文案断言。
4. 跑 Flutter 测试，优先覆盖搜索、底部导航、创建、编辑、个人主页和消息通知。
