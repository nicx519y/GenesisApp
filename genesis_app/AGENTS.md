# Flutter 工程维护指引

本文件适用于 `genesis_app/` 及其子目录。下文路径以本工程目录为基准。按正式业务入口定位，做最小可验证改动；涉及目录外文件时遵循其所属目录的指引。

涉及 MiniPhone 页面、手机网络、相关测试或 World 手机接入时，先阅读 [MiniPhone 指引](lib/pages/mini_phone/AGENTS.md)。

## 产品信息回答边界

- 讨论实际产品逻辑、正式接口字段、线上数据、商品配置、命名规则或用户可见行为时，只依据正式业务代码、接口契约和实际运行链路。
- 不得把 mock、fixture、测试数据、自测配置或测试辅助实现混入产品结论，也不得用它们推断正式商品档位、字段值或命名规则。
- 只有用户明确询问测试实现、mock 或 fixture 时，才讨论这些内容，并清楚标明其测试属性。
- 如果正式代码或接口契约不足以确认答案，直接说明尚不能确认并继续查正式来源，不用测试数据补全答案。

## 工程职责与改动边界

- 入口 `lib/main.dart`，装配在 `lib/app/`；页面业务在 `lib/pages/`，路由在 `lib/routers/`。新增页面入口同步 `RouteNames` 与 `AppRouter.onGenerateRoute`。
- `lib/network/` 管理 HTTP、API facade、DTO、WebSocket 与缓存；`lib/platform/` 管理原生能力，`lib/utils/` 管理纯工具，`lib/ui/` 管理主题、token 和基础 UI，`lib/components/` 管理跨页面业务组件。
- 共享组件优先在公共实现中修改并检查调用方；页面只组合业务和布局，不复制头像、气泡、弹窗、输入框、角标或加载反馈。明确的页面例外继续保留。
- 接口字段变化同步契约、V1 resource、`GenesisApi` 映射、本地 mock 和相关测试；保留协议字段、商店错误码及内部标识兼容。
- HTTP 200 中非零 `err_no` 仍为业务错误。复用既有 HTTP 认证、Gateway 签名和 WebSocket 链路；业务接口与 Gateway `/apix/` 诊断接口保持区分。
- Origin 预览不表示已加入 World；只有 `owner`／`joined` 启动长期世界连接，`approved` 只用于 Launch。LocationChat 仅 leaf location 执行 `join`／`leave`。

## UI 常驻约束

- 默认使用 `GenesisTheme.dark()`，复用公共颜色、字体、模糊 token 与组件；已有局部浅色、浮动菜单、Toast、NPC 和特殊肖像等例外按专项规则保留。
- 上传进度复用 `GenesisUploadProgressOverlay`；聊天气泡复用共享 UI 和场景 token；页面短提示复用 `showGenesisToast`，不用 `SnackBar` 替代。
- 提交中保留原底色、阻止重复提交；已有圆环保留，没有圆环的不新增。普通校验禁用态独立处理。
- 加载骨架保持静态纯色；禁用 Material stretch overscroll，保留已有滚动、回弹和刷新行为。
- 用户名会员徽章只由所属用户模型的整数状态 1 驱动，不单独请求、缓存或轮询；World 与 Chat（含 LocationChat）不显示该徽章。

## 按任务读取专项规则

专项详情在 [工程维护参考](docs/project-maintenance-reference.md)。涉及以下任务时，读取对应章节及所列契约；不要求每次改动通读整份参考文档。

| 本次任务 | 必须读取的相关入口 |
| --- | --- |
| 工程装配、配置、运行参数 | [工程入口与配置](docs/project-maintenance-reference.md#project-entry) |
| HTTP／DTO／Gateway／Socket | [协议与调用入口](docs/project-maintenance-reference.md#network)；`docs/apifox-http-api-contract.md`、`docs/gateway-auth.md` 或 `docs/chatroom-websocket-api.md` 的相关章节；Gems cent 另读 `docs/gem-cent-app-contract.md` |
| 页面流程、World／Origin／LocationChat | [页面职责与会话边界](docs/project-maintenance-reference.md#pages) |
| 图片地址、尺寸选择、上传、头像 | [图片与头像](docs/project-maintenance-reference.md#images)；默认头像细节见 `docs/ui-component-library.md` |
| Header、Sheet、Tab、卡片、输入框、浮层 | [布局与场景例外](docs/project-maintenance-reference.md#ui-layout)；组件接口见 `docs/ui-component-library.md` |
| 字体、富文本、文字测量、斜体 | [字体规则](docs/project-maintenance-reference.md#typography) |
| 深色主题、红色层级、背景模糊 | [主题与 token](docs/project-maintenance-reference.md#colors) |
| 操作弹窗、提交、关闭／删除、Toast、刷新、骨架 | [交互与反馈](docs/project-maintenance-reference.md#ui-feedback)；提交清单见 `docs/button-loading-states.md` |
| 滚动反馈、原生启动资源 | [平台行为](docs/project-maintenance-reference.md#platform) |
| 聊天气泡或其他共享业务组件 | [共享边界](docs/project-maintenance-reference.md#shared-components)；气泡另读 `docs/location-chat-bubble-design.md` |
| 数字角标、用户名会员徽章 | [角标与徽章](docs/project-maintenance-reference.md#badges)；用户字段接入见 `docs/user-membership-badge-integration.md` |
| 选择回归用例或打包 | [验证命令](docs/project-maintenance-reference.md#verification) |

## 名称展示规则

- 会员文案中，已持有的订阅、订阅升级及订阅不可用使用 `subscription`；月付/年付套餐选项、套餐列表和 `selected plan` 使用 `plan`。

- 用户可见的会员名称统一使用 `Premium`，包括页面、购买浮层、Toast 与 Developer 页面；不使用 `VIP`。取消提示统一采用美式拼写 `canceled`，不使用 `cancelled`。外部协议字段、商店错误码、内部标识和诊断代码保留兼容，不因展示文案调整而改名。

- Worldo 创建者的界面标签统一为 `Creator`，覆盖详情、Discuss 摘要和搜索结果；内部 `originator` 模型字段和接口字段保持兼容。

- Origin（即 Worldo）name 在所有展示位置前加 `#`；使用 `originDisplayName`，避免重复添加。
- World name 在所有展示位置都不加 `#`；直接展示原始 world name（为空时可回退 WID）。

## 最小验证与维护

- 按改动选能证明正确性的最小检查。Dart 修改只格式化涉及文件，静态检查覆盖实际修改文件；相关测试目标见上表的验证命令。
- Android production ARM64 release 使用 `flutter build apk --release --flavor production --target-platform android-arm64`；禁止 `--split-per-abi`，避免改写 `versionCode`。
- 纯文档修改检查规则迁移、引用路径、Markdown 和 `git diff --check`，不因文档整理运行 Flutter 测试或构建。
- 完成时报告实际执行的检查；无法运行时说明原因和剩余风险。受控测试、真实后端与设备验收分别报告，不用历史通过记录代替本次验证。
- 接口或行为变化同步对应规则和契约；详细参数、页面索引、测试命令与运行记录留在按需文档，AGENTS.md 保留短规则及明确入口。
