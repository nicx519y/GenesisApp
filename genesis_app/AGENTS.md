# AGENTS.md

本文件是 `genesis_app/` Flutter 工程内的项目索引和编码约束。修改本目录下文件时，先按这里的接口文档、业务入口和共享组件边界定位，再做最小可验证改动。

## 项目定位

GenesisApp 是 Flutter App，入口在 `lib/main.dart`。`AppBootstrap.initialize()` 负责初始化 Flutter binding、Firebase、服务注册和 guest bind；`GenesisApp` 使用 `MaterialApp`，默认路由是 `RouteNames.home`，路由表在 `lib/routers/app_router.dart`。

底部主 Tab 由 `lib/pages/app_shell_page.dart` 管理：

- `HomePage`：`lib/pages/home/home_page.dart`
- `OriginPage`：`lib/pages/origin/origin_page.dart`
- `CreateOriginPage`：`lib/pages/create/create_origin_page.dart`
- `MessagesPage`：`lib/pages/messages/messages_page.dart`
- `MePage`：`lib/pages/me/me_page.dart`

## 目录定义

- `lib/app/`：配置、服务注册、依赖注入和 App scope。运行参数集中在 `lib/app/config/app_config.dart`，服务装配在 `lib/app/bootstrap/service_registry.dart`。
- `lib/routers/`：路由名、路由参数兼容解析和页面实例化。新增页面入口时先更新 `RouteNames` 和 `AppRouter.onGenerateRoute`。
- `lib/pages/`：页面级业务逻辑。页面负责拉取/组合数据、导航、刷新、分页和本页面状态。
- `lib/components/`：跨页面 UI 组件。共享样式、弹窗、头像、地图、聊天 UI、讨论列表等应改这里，避免页面局部复制。
- `lib/network/`：HTTP client、Genesis API facade、V1 API resource、chatroom WebSocket/HTTP、mock transport、SQLite 缓存和网络模型。
- `lib/platform/`：设备 ID、session store、Google/Apple/Firebase 登录、原生图片选择等平台能力。
- `lib/utils/`：图片资源选择、上传图片处理、显示名、相对时间、数字格式化等纯工具。
- `lib/ui/`：主题和基础 UI token。
- `assets/`：静态图片、自定义图标 png/svg/font。
- `docs/`：接口契约、组件说明、跨平台目录和联调记录。
- `test/`：按 `network/components/pages/ui/utils/storage` 分组的 focused tests。

## 运行和配置

常规运行：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter pub get
flutter run
```

可用 dart-define：

- `GENESIS_API_ENV=mock|local|debug|real|prod|production|auto`：控制是否使用 `LocalMockGenesisTransport`。
- `GENESIS_CHATROOM_WS_URL=...`：覆盖 WebSocket 地址，默认 `wss://dev.hushie.ai/aitown-chat/ws`。
- `GENESIS_CHATROOM_HTTP_URL=...`：覆盖 chatroom HTTP base，默认 `https://dev.hushie.ai/`。
- `GENESIS_DEBUG_PROXY=host:port`：HTTP 和 WebSocket 代理调试。
- `GENESIS_DEBUG_WS_LOG=true`：打印 WebSocket frame。
- `GENESIS_ALLOW_IOS_PLATFORM_HEADER=true`：允许 iOS 发送 `x-platform: ios`；默认仍发送 `android`。

外层 `scripts/flutter_run_debug_proxy.sh` 会自动注入真机代理参数。

## 接口文档位置

HTTP 接口以 Apifox 文档为准：

- 主文档：`docs/apifox-http-api-contract.md`
- API facade：`lib/network/genesis_api.dart`
- V1 resource：`lib/network/v1/*.dart`
- 通用 client：`lib/network/api_client.dart`
- 本地 mock：`lib/network/local_mock_genesis_transport.dart`
- 主要测试：`test/network/genesis_api_test.dart`、`test/network/local_mock_genesis_transport_test.dart`

`docs/apifox-http-api-contract.md` 当前覆盖用户、origin、world、chatroom、search、discuss、direct_message、notify、upload。所有 Apifox 200 响应按 `{err_no, err_msg, data}` envelope 处理。改 HTTP 字段时要同步文档、V1 resource、`GenesisApi` 映射、本地 mock 和 focused tests。

Chatroom WebSocket/HTTP 另有独立契约：

- WebSocket 文档：`docs/chatroom-websocket-api.md`
- WebSocket client：`lib/network/chatroom/chatroom_client.dart`
- WebSocket envelope/model/parser：`lib/network/chatroom/chatroom_models.dart`
- 连接控制：`lib/network/chatroom/chatroom_connection_controller.dart`
- 世界聊天室业务服务：`lib/network/chatroom/world_chatroom_service.dart`
- Chatroom HTTP resource：`lib/network/chatroom/chatroom_http_api.dart`
- Chatroom HTTP models：`lib/network/chatroom/chatroom_http_models.dart`
- 消息本地缓存：`lib/network/chatroom/chatroom_message_storage.dart`
- 主要测试：`test/network/chatroom/chatroom_client_test.dart`、`test/network/chatroom/world_chatroom_service_test.dart`、`test/network/chatroom_http_api_test.dart`

WebSocket 当前协议规则：

- 建联：`GET {GENESIS_CHATROOM_WS_URL}?world_id={world_id}`，`Authorization: Bearer ...` 由 session store 注入。
- JSON 字段命名使用 `snake_case`。
- 客户端上行 `join/send_message/heartbeat/leave`，上行业务字段在顶层，不包旧版 `payload`。
- `join` 必须带 `world_id`、`location_id`、`user_id`、`sender_id`、`sender_name`。
- 服务端下行公共字段在顶层，个性化内容在 `payload`。
- 错误统一由 `type: "ack"` 携带 `err_no`、`err_msg`，不要恢复旧 `error` 事件。
- `tick_advance` 使用顶层 `current_time` 和 `payload.tick_no`；页面展示只保留连续 tick 的最新可见项时，在页面/聊天 UI 层处理。
- `WorldChatroomService` 负责把世界级事件分发到地点队列；tick 事件需要扇出到所有 leaf location 队列。

## 关键页面业务逻辑

- `HomePage`：首页 feed 和我的 world 卡片入口，默认 App 首屏。列表/卡片展示字段来自 `GenesisApi` 对 v1/home 和 world/origin 数据的映射。
- `OriginPage`：Origin 模板列表和模板卡片入口。卡片组件主要在 `lib/components/origin/origin_item_card.dart` 和 `lib/components/home/popular_origin_list.dart`。
- `OriginWorldPage`：Origin 详情/预览页，不等同于已加入 world。复用 `WorldDetailsPageScaffold`、`WorldDetailsShell`、`WorldMap`、`WorldTickEventItem`；Launch 通过 `showOriginRoleLaunchSheet` 选择角色后创建/进入 world。Origin inline chat 是 launch-only 预览，不应显示真实连接状态。
- `WorldPage`：已创建/加入的 world 详情页。使用同一套 floating map + panel scaffold。进入页面后先拉 world detail，只有 `relation_status` 为 `owner` 或 `joined` 才启动长期 chatroom WebSocket；`approved` 只用于 Launch 流，不代表已连接。
- `LocationChatPage`：地点聊天室页。页面可以从 world drill-down 打开，但只有 leaf location 才允许 `join`/`leave`。非 leaf 只展示页面/地图层级，不产生聊天室副作用。
- `ChatPage`：私信会话页。会话列表和消息缓存由 `DirectMessageConversationStore`、`DirectMessageMessageStore` 以及 `lib/network/direct_message_database.dart` 管理。
- `MessagesPage`：消息中心。负责未读 summary、通知分组、私信入口和 mark-read 刷新；通知列表页是 `MessageCategoryListPage`。
- `DiscussPage`：Origin 讨论列表页，先拉 Origin summary，再通过 `OriginDiscussList` 分页加载顶级评论。发帖入口使用共享 `DiscussPostInput`。
- `PostDetailPage`：单条讨论详情和回复分页。不要把“进入详情”和“直接打开回复 sheet”混在一起；详情页自己负责回复 composer。
- `CreateOriginPage`：创建 Origin 的多步骤 flow。草稿存储在 `CreateOriginDraftStore`，缓存 key 是 `create_origin_draft_v1`；最终 payload 由 draft 转为 `/api/v1/origin/create` 所需结构。
- `EditOriginPage`：编辑已有 Origin。先拉详情并转换成 `MemoryOriginDraftRepository`，复用 origin editor 页和 create flow 外壳，保存走 update 接口。
- `SearchPage`：全局搜索，结果按 origin/world/user 分流，历史记录在 `SearchHistoryStore`。
- `MePage/UserInfoPage/FollowsPage`：当前用户、他人资料、关注/粉丝。Me 优先使用本地 session/cache，避免入口被网络阻塞。
- `SettingsPage/DeveloperPage`：设置和开发维护入口。开发页包含 direct message cache 清理等调试功能。

## 图片下发、匹配和上传逻辑

图片资源解析的共享入口是 `lib/utils/genesis_image_resource.dart`：

- `GenesisImageResource.fromJson` 支持字符串和 map。
- map 支持 `url`、`image_url`、`image`、`avatar`、`cover`、`sm_url`、`xl_url`、`object_key`。
- `displayUrl` 优先级是 `xl_url -> sm_url -> legacy url`。
- `GenesisImageResourceRegistry` 会用 legacy/sm/xl/object key/display url 建索引；如果后续 UI 只拿到其中一个 key，可以回查完整资源。
- `selectGenesisImageUrl` 会根据组件逻辑尺寸、DPR 和 URL 中的 `width/w/height/h` query 或文件名尺寸，选择足够清晰的最小图；没有尺寸信息时回退到 `displayUrl`。

HTTP 映射层的图片规则：

- `GenesisApi._resolveImageAssetUrl` 会把后端相对路径经 `resolveAssetUrl` 转成可显示 URL，并注册到 `GenesisImageResourceRegistry`。
- user avatar 主要兼容 `avatar_url` 和 `avatar`。
- origin/world cover、map、snapshot、character avatar、location image 都在 `genesis_api.dart` 的对应 mapper 中解析，修改字段时先查 mapper，不要只改 UI。
- 搜索/讨论等局部 parser 也可能直接使用 `asImageUrl` 或 `GenesisImageResourceRegistry.resolve`，改字段名时要扫调用点。

上传入口：

- 通用 upload API：`lib/network/v1/upload_api.dart`，`POST /api/v1/upload/image`，multipart 字段名是 `file`。
- 创建/编辑 Origin 图片：`CreateUploadBox` 在 `lib/pages/create/create_form_widgets.dart`，先进入 `LocalImageCropPage` 裁剪，再上传。成功后 controller 写入上传 URL，失败恢复旧 URL。
- 讨论图片：`DiscussPostInput` 在 `lib/components/discuss/discuss_post_input.dart`，使用 `native_image_picker.dart` 选图，`resizeImageToMaxWidth` 预处理后上传，最多 6 张并按剩余槽位限制选择。
- 上传进度视觉统一使用 `GenesisUploadProgressOverlay`，不要新增页面局部 spinner。

头像和非头像要分开处理：

- 用户/通用头像共享 `GenesisAvatar`。
- 角色头像共享 `GenesisCharacterAvatar`，带红星角色标识。
- 当前头像默认 top-center crop；不要把头像裁剪规则扩散到 cover、location image、map、list thumbnail 等非头像图片。
- `CharactersList` 和 `OriginWorldPage` 的部分角色肖像有页面级尺寸例外，修改前先确认是否应走共享头像组件。

## 共享组件边界

- 通用底部弹层：`GenesisBottomSheetPanel`
- 通用确认/操作框：`genesis_action_box.dart`
- 居中 toast：`showGenesisToast`，不要用 `SnackBar` 替代项目内短提示。
- 聊天 UI token 和结构：`lib/components/chat/shared/chat_ui.dart`、`chat_ui_style_config.dart`
- 世界/Origin floating panel：`WorldDetailsPageScaffold`、`WorldDetailsShell`
- 世界地图和点位：`WorldMap`、`WorldMapStage`、`WorldPoint`
- Discuss 列表/回复/输入：`OriginDiscussList`、`OriginDiscussRepliesList`、`DiscussPostInput`
- 图片查看器：`GenesisImageViewerOverlay`

如果多个页面使用同一个组件，优先改共享组件并检查所有 call site；只有明确是页面例外时才加 caller override。

## 验证要求

按改动范围选择最小能证明正确性的验证：

- 格式：`dart format <touched files>`
- 静态检查：`flutter analyze` 或文件相关 analyze
- HTTP/API：`flutter test test/network/genesis_api_test.dart`、`flutter test test/network/local_mock_genesis_transport_test.dart`
- Chatroom：`flutter test test/network/chatroom/chatroom_client_test.dart`、`flutter test test/network/chatroom/world_chatroom_service_test.dart`、`flutter test test/network/chatroom_http_api_test.dart`
- Discuss：`flutter test test/components/discuss_page_test.dart`、`flutter test test/components/origin_discuss_list_test.dart`
- 图片/头像：`flutter test test/utils/image_upload_processing_test.dart`、`flutter test test/ui/genesis_avatar_test.dart`、`flutter test test/ui/genesis_list_image_test.dart`
- 页面流：优先使用 `test/widget_test.dart --plain-name "<case name>"` 跑相关窄用例，不要默认只跑全量大烟测。

完成前报告实际跑过的命令；不能运行时说明原因和剩余风险。
