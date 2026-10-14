# MiniPhone Chat client integration

The supplied `mini-phone-chat-client-api-2026-10-12.md` is a **draft, not a
published backend contract**. This implementation adds the client side only.

## Ownership and transport

`GenesisApi.miniPhone` is a `MiniPhoneApi` built from the existing signed Chat
HTTP client. It exposes all 16 draft routes below `/aitown-chat/api/v1/phone`.
Phone DTOs preserve native Dart int64 IDs. Android/iOS are the supported targets;
JavaScript targets require a lossless JSON transport before this ID contract can
be claimed there. HTTP 200 does not override a nonzero business error.

`MiniPhoneSession.data` owns a `MiniPhoneStore` scoped to API environment,
account and world. `WorldPage` binds it to `WorldChatroomService.phoneEvents`.
The existing V2 connection parses the three phone event types without a
location join. Phone events never enter LocationChat's visible timeline.
Closing the phone keeps the world session alive; leaving the world disposes it.
Requests from a replaced account are discarded. Home, badges and unread lists
use server counts, never event counts or the length of a 20-item Home list.

Write journals persist request IDs and original content in account/environment/
world-scoped preferences. Retries preserve the complete operation, including
image URL and reply target. Requests are not automatically resent. A sent user
bubble is created only from a delivery or history query, not a successful empty
HTTP response. Automatic DMs cannot finish an unrelated request. Final failures
preserve committed user messages. Pending AI replies have no timeout-based
failure rule.

Reads, refreshes and incoming events are independent. Event refreshes coalesce
and retain a dirty flag during an in-flight refresh. Message recovery crosses
pages until it reaches a known boundary. Existing history and delivered batches
merge by ID; display order is numeric ascending. Notification pages replace
rather than merge: two indistinguishable facts about one post remain two rows.

## User behavior

- Messages supports server pagination, unread filtering and new AI-character
  conversations from world character data.
- Chat reuses `LocationChatAnchoredMessageList`, `LocationChatScrollCoordinator`,
  `ChatComposer` and `kPrivateChatStyle`. Both chats use the extracted
  `ChatKeyboardInsetLayout`. MiniPhone keeps the keyboard on Send, disables
  reply-reserve positioning, preserves detached history, and shows a local
  waiting-for-reply indicator. This is not a real typing event.
- Read DM on successful foreground conversation load and newly delivered
  content while that conversation is visible, then query authoritative counts.
- Entering Posts and successfully loading it marks all current world Post
  notifications read once. Later events while remaining in Posts do not clear
  newly arrived notifications.
- Post publishing requires nonblank text and optionally an existing Album URL;
  no device upload or image generation path is used. Wallpaper upload is separate.
- Post detail displays all detail comments. Reply selection queries the
  independent comments endpoint for real IDs; it never guesses IDs by text or
  position. Likes are serialized per post and queried after uncertain results.
- Photos uses the server album and shared image viewer. Home's world time comes
  from the world snapshot and existing world socket state, not device time.

World-backed routes use live data even on errors. The developer's explicit
worldless style preview and existing preview tests retain demo fixtures; this
is not a fallback for live requests. The local mock transport returns explicit
empty reads and refuses unsupported writes instead of simulating successful
AI replies.

## Backend dependencies before acceptance

1. `GET /posts` must support optional `author_type` + `author_id` filters before
   pagination, and `comments_preview: PhoneComment[]` containing up to three
   earliest comments in server order. The client sends the filters and consumes
   this optional extension. It does not fetch every post detail to fake previews.
2. `dm/send` must create/resolve the first session, and confirm whether only one
   nonterminal request per session is allowed. Client defaults to that restriction.
3. A reconnect must reliably replay correlated successful AI batches and final
   failures. History messages have no AI request correlation or failure state;
   HTTP history alone cannot resolve a missing final event. In this case the
   client keeps the request unresolved, does not invent success/failure, and
   does not automatically send a new charged request. There is no polling endpoint.
4. Final DTOs, paging limits and business codes must be confirmed. The client uses
   `pn=1/rn=10`, no guessed character limit, and no local price calculation.

Tests with controlled transports prove client behavior only. They do not prove
backend deployment, event outbox replay, authorization, charging, or real-device
keyboard behavior. Those require backend and Android/iOS acceptance separately.

## Client maintenance reference

以下详情由 MiniPhone AGENTS.md 移入本文件，供相关任务按节读取。它们描述当前客户端调用和必须保持的行为，**不代表草案已成为正式服务端契约，也不新增任何真实后端或真机验收结论**。下文 `lib/`、`docs/`、`test/` 路径均以 `genesis_app/` 为基准；代码入口表中未带目录的文件位于 `lib/pages/mini_phone/`。

- 手机接口草案：`docs/mini-phone-chat-client-api-2026-10-12.md`。
- 既有 HTTP、Gateway、WebSocket、共享 UI：`docs/apifox-http-api-contract.md`、`docs/gateway-auth.md`、`docs/chatroom-websocket-api.md`、`docs/ui-component-library.md`。
- 修改前核对正式调用代码和接口契约；接口或行为改变时同步模块指引和对应文档，区分客户端实现、草案扩展和真实后端验证。

### Code entry points

| 入口 | 职责 |
| --- | --- |
| `mini_phone_page.dart` | 页面导航、`MiniPhoneSession`、世界级服务装配和恢复页面状态 |
| `mini_phone_store.dart` | 服务端数据、分页、未读、事件合并、请求日志、账号隔离和恢复查询 |
| `mini_phone_live.dart` | Messages、Posts、评论、通知、相册及发帖选图 |
| `mini_phone_live_chat.dart` | 私聊列表、输入框、键盘、历史翻页和等待回复展示 |
| `mini_phone_home.dart`、`mini_phone_ui.dart` | Home 通知、世界时钟、应用角标和手机入口 |
| `mini_phone_music*.dart` | 音乐目录、播放、点赞和本地播放进度 |
| `mini_phone_wallpaper*.dart`、`mini_phone_media.dart` | 壁纸缓存、设备选图、上传、保存和图片查看 |
| `mini_phone_models.dart` | 模型目录展示及本地模型／记忆长度设置 |
| `lib/network/mini_phone/mini_phone_api.dart`、`mini_phone_models.dart` | 手机 HTTP resource 和 DTO，经 `GenesisApi.miniPhone` 暴露 |
| `lib/network/chatroom/chatroom_phone_events.dart` | V2 手机事件模型，解析入口在 `chatroom_models.dart` |
| `lib/pages/world/world_page_chatroom_session.dart` | 将 World 的现有 Socket 服务绑定到手机 Store |

### Phone HTTP routes

统一前缀 `/aitown-chat/api/v1/phone`。复用现有签名 Chat HTTP client、登录态和 Gateway header，不在页面创建独立 client。分页默认 `pn=1、rn=10`；按服务端 `total/pn/rn` 判断后续页面。

| 方法与相对路径 | 当前使用场景 |
| --- | --- |
| `GET /home` | Home 的 DM／Post 未读数及各自最多 20 条明细；通知卡片和应用角标；初始化、Home 展示、事件、已读成功及恢复时刷新 |
| `GET /unread` | DM 与 Post 合计未读数、最新未读作者；地图和 LocationChat 手机入口提示；与 Home 聚合刷新 |
| `GET /dm_sessions` | Messages 会话列表、未读筛选、刷新和分页；首次私聊恢复时跨页查找角色的会话 ID，查找不受未读筛选限制 |
| `GET /messages` | 打开会话、向上加载历史、重连及前台恢复；补齐遗漏消息并合并已有气泡 |
| `POST /dm/send` | 发送角色私聊及首次私聊；提交 `world_id/char_id/client_request_id/content`；空成功响应不生成气泡 |
| `POST /dm_session/read` | 前台会话成功加载或收到新消息后标记该会话已读；只提交 `dm_session_id`，成功后重查会话和未读 |
| `GET /posts` | Feed、作者筛选、刷新、分页；发帖、评论、点赞后刷新；读取 `comments_preview` 展示前三条评论 |
| `GET /post/detail` | 打开帖子或通知详情，展示正文和完整评论；点赞后查询实际状态；详情可见时随事件刷新 |
| `POST /post/create` | 发布文字／图文帖子；提交 `content` 和可选相册图片 URL 字段 `image`，成功后刷新 Feed |
| `POST /post/like` | 点赞；同帖操作串行，随后查询详情确认状态 |
| `POST /post/unlike` | 取消点赞；与点赞共用串行处理和状态查询 |
| `GET /comments` | 选择具体评论进行回复及分页，取得真实 `comment_id`；评论提交后刷新；普通详情的完整评论来自 `/post/detail` |
| `POST /comment/create` | 发布评论／回复；回复携带 `reply_to_comment_id`，成功后刷新详情、评论列表和 Feed |
| `GET /post/notifications` | Home 的查看更多、通知页、未读筛选、刷新和分页；通知点击按 `post_id` 打开详情 |
| `POST /post/notifications/read` | 进入 Posts 并成功加载后清除当前世界全部 Post 未读；只提交 `world_id`；停留期间不持续清除新通知 |
| `GET /album` | Photos 三列相册、刷新和分页；发帖配图选择服务器相册图片 |

### Reused HTTP routes

这些接口使用既有 `GenesisApi`／V1 resource，保持各自的认证与签名流程。

| 方法与完整路径 | 当前使用场景 |
| --- | --- |
| `GET /api/v1/music/list` | 音乐目录、歌曲、音频地址、封面和作者信息；无分页 |
| `GET /api/v1/music/like_status` | 打开播放器或切歌后查询当前歌曲的点赞状态和数量，参数为目录中的原始 `file` |
| `POST /api/v1/music/like` | 歌曲爱心点赞；乐观更新、失败回滚，按歌曲串行处理 |
| `POST /api/v1/music/unlike` | 取消歌曲点赞；与点赞共用状态管理 |
| `GET /api/v1/world/miniphoneinfo` | 打开手机时读取当前世界壁纸配置 |
| `POST /api/v1/world/setminiphonebackground` | 保存壁纸／恢复默认；提交 `world_id/background_image` |
| `POST /api/v1/upload/image` | 壁纸设备选图上传；multipart 字段为 `file`，取得 URL 后保存壁纸配置 |
| `GET /api/v1/world/detail` | 世界角色、名称、头像和世界时间；初始化、前台恢复时获取，供首次私聊、作者入口和 Home 时钟使用 |
| `GET /api/v1/user/info` | 按 UID 补充用户名称和头像，主要用于世界资料未覆盖的 Post 通知作者 |
| `GET /api/v1/gem/model/list` | 读取世界模型目录；优先复用已有缓存，供 MiniPhone 模型页展示 |

- 音乐实现见 `lib/network/v1/music_api.dart`；壁纸、上传、角色和用户资料分别见 `world_api.dart`、`upload_api.dart`、`user_api.dart`；模型目录见 `gem_api.dart`。
- 当前模型选择和记忆 Token 修改仅更新本地 `MiniPhoneSession`。不要将页面上的选择或折扣展示解释为后端设置／计费已生效。
- 音频、封面、头像和相册图片还请求返回的媒体 URL；它们不计入上面的业务接口数。
- 模型页复用 `MemoryModelPage` 的 Collect 上报：`pay_event/switch_model_page`、`pay_event/switch_model_save`。默认采集地址为 `https://collect.worldo.ai/api/v1/collect`，由公共配置和上传策略控制；当前模型页上报的 `object1` 是 `local-mini-phone-preview`。相关代码在 `lib/pages/gems/memory_model_page.dart` 和 `lib/app/telemetry/`。

### World WebSocket events

- 复用 `WorldChatroomService` 的 V2 连接：`/aitown-chat/ws?world_id={world_id}`，不创建独立手机 Socket，也不为接收手机事件加入地点。
- 默认 Release：`wss://api.worldo.ai/aitown-chat/ws`；默认 Debug／非 Release：`wss://dev.hushie.ai/aitown-chat/ws`。实际地址由 `GENESIS_CHATROOM_WS_URL`／Developer 配置决定，HTTP 对应 `GENESIS_CHATROOM_HTTP_URL`；不要在页面硬编码环境地址。
- 建联复用当前认证和 Gateway handshake signer。手机业务字段位于 V2 `payload`；不要将其混入 LocationChat 时间线或地点队列。

| 下行事件 | 当前使用场景及处理 |
| --- | --- |
| `phone.messages.delivered` | 玩家送达消息、AI 回复及角色主动私聊；批量合并消息、确定会话 ID；关联 AI 回复结束等待；当前前台会话收到消息后提交已读；触发聚合刷新 |
| `phone.reply.updated` | 当前仅处理关联请求的 `job_status=failed` 最终失败；结束等待、显示失败信息、保留已送达玩家消息；触发聚合刷新 |
| `phone.post.notification.created` | Post 新通知；触发聚合刷新；Posts、相关详情和通知页可见时刷新相应数据 |

- 三类事件均按 `event_id` 去重。聚合刷新包括 Home、未读和会话；列表、详情和通知根据当前可见状态刷新，当前会话及待确认私聊另执行历史恢复。
- 未读数使用 HTTP 查询结果，不按事件次数增减。密集事件合并刷新；刷新期间新事件必须保留下一轮刷新。
- 手机关闭后继续处理当前世界事件；退出世界释放订阅。首次初始化、Socket 重连和返回前台恢复查询。
- Home 时钟还观察共享世界状态的 `latestSocketCurrentTime`；不能用设备时间代替世界时间。

### Required client behavior

- 数据和写请求按环境、账号、世界隔离；上下文改变后丢弃旧请求结果，清除旧草稿和恢复页面引用。
- 保存写请求 ID 与原始正文、图片和回复目标；同一次操作重试复用原请求，不建立自动重发队列。超时／断线保持待确认状态，不能据此判定 AI 最终失败。
- DM 正式气泡只来自送达事件或历史查询；支持推送先于 HTTP 响应，按完整 int64 消息 ID 去重、升序展示。空成功响应只表示操作受理／成功。
- HTTP 200 下非零 `err_no` 仍为业务错误；展示原始 `ApiException.message`／`err_msg`，失败保留草稿。区分 Feed 的 `text` 和详情／提交的 `content`。
- 聊天复用 `LocationChatAnchoredMessageList`、`LocationChatScrollCoordinator`、`ChatMessageRow`、`ChatComposer`、共享 `ChatKeyboardInsetLayout`，视觉采用 `kPrivateChatStyle`。发送保持键盘，不预留回复空白；阅读历史时保留锚点和返回最新入口。
- “正在输入”是本地请求等待提示；同一角色等待期间允许编辑草稿、禁止再次发送，其他角色独立运行；关联 AI 回复或最终失败结束等待。
- Posts 作者筛选先由服务端执行再分页，切换作者重置分页。评论预览使用 Feed 返回值，不逐帖请求详情补齐；回复必须使用 `/comments` 的真实 ID。
- 同帖点赞／取消点赞串行执行；结果不确定时查询详情，再处理最新操作意图。进入 Posts 的全部已读只在本次进入成功加载后执行，停留期间不自动清除新通知。
- 通知逐页替换，不按帖子合并、不制造通知 ID 或正文。Photos 保留网格和共享查看器；发帖只选择服务器图片，正文必填，不添加未确认的字数限制。
- 保持现有 MiniPhone 样式、导航、启动动画、音乐和壁纸行为；共享聊天修改须回归 LocationChat。真实请求错误展示错误／重试；演示数据仅用于明确的无世界预览。

### Backend contract boundaries

以下项目必须与后端确认并记录证据，不把草案或受控测试当作服务端已支持：

1. `/posts` 的 `author_type + author_id` 服务端筛选，以及正序、最多三条的 `comments_preview`。
2. 首次 `/dm/send` 自动创建／解析会话，以及同会话一个未结束请求的限制。
3. 断线后关联 AI 成功批次／最终失败事件可靠重放；仅历史消息不能证明完整请求终态。
4. 最终 DTO、分页限制和业务错误码。原生 Dart 保留 int64；JavaScript 目标需先解决无损 JSON ID 传输。

### Verification commands

以下命令从 `genesis_app/` 执行。按改动选择相关检查；纯文档修改只检查路径、接口表、Markdown 和 `git diff --check`。

```sh
# 手机 HTTP、状态和页面
flutter test --no-pub test/network/mini_phone test/pages/mini_phone
flutter analyze --no-pub lib/network/mini_phone lib/pages/mini_phone

# 修改公共 HTTP／Gateway／WebSocket 时追加对应验证
flutter test --no-pub test/network/genesis_api_test.dart test/network/local_mock_genesis_transport_test.dart test/network/gateway_auth_test.dart
flutter test --no-pub test/network/chatroom/chatroom_client_test.dart test/network/chatroom/world_chatroom_service_test.dart test/network/chatroom_http_api_test.dart

# 修改共享聊天或键盘布局时追加回归
flutter test --no-pub test/pages/chat/location_chat_scroll_coordinator_test.dart test/pages/chat/location_chat_waiting_scroll_test.dart
flutter test --no-pub test/pages/chat/location_chat_page_test.dart --name 'manual keyboard inset|keyboard inset excludes|Android 11 uses|location chat follows iOS keyboard|composer follows keyboard frames|composer Send dismisses keyboard'

git diff --check
```

- Dart 修改运行 `dart format`，只格式化本次涉及文件；静态检查同时包含实际修改的目录外文件。
- 重点验证重复／乱序推送、推送先于 HTTP、首次私聊、历史锚点、同请求重试、跨账号旧响应隔离、点赞快速切换、通知分页和 Posts 进入已读。
- 分别报告受控测试、真实后端和 Android／iOS 真机结果。键盘升降、发送保持键盘、多行输入、窄屏、大字体、横屏和断线恢复需要对应证据；过去的通过记录不能代替本次验证。

## Validation record — 2026-10-13

- 579 network, state, MiniPhone and shared-scroll tests passed, including 21 new
  API/store/live-widget cases. A separate 6-case LocationChat keyboard regression
  passed (585 distinct cases total). Coverage includes music, wallpaper and
  launch animations already present in this working tree.
- Targeted static analysis: no issues. `git diff --check`: passed.
- Production-flavor Android ARM64 debug APK: built successfully.
- Pixel 6: installed debug build; verified World → phone → Messages → real world
  character selection → empty chat and keyboard opening. Fixed and rechecked
  Home world-time parsing and keyboard bottom-safe-area overlap. No messages,
  posts, comments or likes were submitted to the live backend for this check.
- The connected environment displayed API errors for Home, Sessions and session
  discovery. Error/retry UI remained visible with no demo fallback. Successful
  live phone reads/writes and event replay are **not verified**; no claim is made
  about why this environment failed. iOS, landscape and full multi-device
  keyboard acceptance remain pending.

Executed from `genesis_app`:

```sh
flutter test --no-pub test/pages/mini_phone test/network/mini_phone test/network/miniphone_api_test.dart test/network/genesis_api_test.dart test/network/local_mock_genesis_transport_test.dart test/network/chatroom/chatroom_client_test.dart test/network/chatroom/world_chatroom_service_test.dart test/network/chatroom_http_api_test.dart test/pages/chat/location_chat_scroll_coordinator_test.dart test/pages/chat/location_chat_waiting_scroll_test.dart
flutter test --no-pub test/pages/chat/location_chat_page_test.dart --name 'manual keyboard inset|keyboard inset excludes|Android 11 uses|location chat follows iOS keyboard|composer follows keyboard frames|composer Send dismisses keyboard'
flutter analyze --no-pub lib/network/mini_phone lib/network/chatroom lib/network/genesis_api.dart lib/network/genesis_api_context.dart lib/network/local_mock_genesis_transport.dart lib/pages/mini_phone lib/pages/chat/location_chat_page.dart lib/pages/world/world_page_chatroom_session.dart lib/components/chat/shared/chat_keyboard_inset_layout.dart test/network/mini_phone test/pages/mini_phone/mini_phone_store_test.dart test/pages/mini_phone/mini_phone_live_test.dart test/support/mini_phone_chat_backend.dart
flutter build apk --debug --flavor production --target-platform android-arm64 --no-pub
git diff --check
```
