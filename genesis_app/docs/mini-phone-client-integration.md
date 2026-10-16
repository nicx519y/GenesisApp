# MiniPhone Chat client integration

The supplied [`mini-phone-chat-client-api-2026-10-12.md`](mini-phone-chat-client-api-2026-10-12.md)
now records the **2026-10-16 current dev contract**, aligned to Chat `b21774e`
and API `50e0287f`. It replaces the earlier draft and backend-pending claims.
Source-contract alignment and controlled tests do not establish live account or
device acceptance. Earlier date-specific deltas retain their historical scope.

## Ownership and transport

`GenesisApi.miniPhone` is a `MiniPhoneApi` built from the existing signed Chat
HTTP client. It exposes 17 routes below `/aitown-chat/api/v1/phone` (the original
16 plus `GET /post/authors`).
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
image URL and reply target. Requests are not automatically resent. DM submission
immediately shows a separate temporary user bubble and clears
the submitted input without a Send spinner. Delivery/history reconciles that
bubble by request ID; an empty HTTP success only confirms acceptance. Explicit
rejection removes the temporary bubble and restores the submitted draft if the
input is still empty. Uncertain failures retain the bubble and original request
ID, and newer drafts are never overwritten. Automatic DMs cannot finish an
unrelated request. Final failures
preserve committed user messages. Pending AI replies have no timeout-based
failure rule.

Reads, refreshes and incoming events are independent. Event refreshes coalesce
and retain a dirty flag during an in-flight refresh. Message recovery crosses
pages until it reaches a known boundary. Existing history and delivered batches
merge by ID; display order is numeric ascending. Notification pages replace
rather than merge: two indistinguishable facts about one post remain two rows.

## User behavior

- In-app navigation uses a nested Navigator and `GenesisDarkPageRoute`, matching
  app-wide Android/iOS push/pop transitions. Returning from chat retains the
  Messages list instance/scroll position; iOS swipe back updates the screen state.
  The fixed Close exits the outer phone route. Home app-entry expansion remains
  in `AppLaunchTransitionHost`, independent of these page transitions.

- Messages renders only `/dm_sessions` entries in server order, merging pages by
  `(world_id, char_id)`. Multiple virtual entries with `dm_session_id=0` remain
  separate. Opening a virtual entry shows an empty chat without history/read
  requests; sending uses `char_id`, and a later real ID replaces that entry.
  Positive IDs remain real even when `last_message=null`.
- Chat reuses `LocationChatAnchoredMessageList`, `LocationChatScrollCoordinator`,
  `ChatComposer` and `kPrivateChatStyle`. Both chats use the extracted
  `ChatKeyboardInsetLayout`. MiniPhone keeps the keyboard on Send, disables
  reply-reserve positioning, preserves detached history, and shows a local
  waiting-for-reply indicator for AI only. Player peers (`peer_uid` nonempty)
  have no AI status. Message direction always compares sender_id to login UID;
  another player's user message belongs on the peer side.
  New reply batches reveal the first bubble immediately and subsequent bubbles
  at one-second intervals, retaining AI typing until the queue drains. Existing
  history/pagination appears immediately; refreshes and duplicate pushes cannot
  bypass a pending reveal. The top history spinner is reserved for upward
  pagination, never automatic recovery or refreshing existing content.
- Read DM on successful foreground conversation load and newly delivered
  content while that conversation is visible, then query authoritative counts.
- Entering Posts and successfully loading it marks all current world Post
  notifications read once. Later events while remaining in Posts do not clear
  newly arrived notifications.
- Posts author shortcuts come only from the unpaginated `/post/authors` list,
  joined to existing world character profiles (including player characters).
  Unknown profiles display their character ID until profile data is available.
  All omits `char_id`; selecting an author sends their character ID, resets to
  page 1 and discards old in-flight pages. Feed refreshes also refresh authors
  without clearing the selected filter; tapping the active shortcut restores all.
  Errors use the shared Toast and existing pull-to-refresh.
- Posts Feed uses a lazy variable-height list and builds only rows around the
  viewport (200 logical pixels of render cache). Rows keep their identity by
  post ID, and account/author changes reset the scroll position. Feed photos
  reserve exactly 200 logical pixels before loading and after failure, retain
  the existing width bound/aspect fit with left-aligned image content and square
  corners, and show only background when loading or
  failed: no placeholder asset, error icon, text, spinner or Toast. Thumbnail
  requests replace the existing OSS transform with fixed-height resize plus
  WebP (`image/resize,h_{ceil(200 * cappedDpr)}/format,webp`), retaining unrelated
  query parameters. The rendered and prefetched thumbnails share identical
  URL/decode/cache keys; tapping opens the original image URL and passes the
  displayed thumbnail provider to the shared viewer, so its cached frame is
  shown immediately until the full image loads (and retained if that fails). The
  shared source anchor also captures the left-aligned painted thumbnail bounds
  for the viewer's 320 ms easeOutCubic opening expansion. The original tile is
  hidden only during flight; full-image loading continues underneath. Missing
  cached frames fall back to fade, and reduced motion opens directly.
  After layout/scroll, inspect the actual visible row bounds and prefetch images
  from the five posts immediately below the last visible post (text-only posts
  count toward five; this is not five extra rendered rows). Prefetch work is
  bounded to five concurrent loads, deduplicated within the moving window, and
  stops queuing while Posts is covered/inactive. Details keep their own image
  sizing. Existing pull refresh, scroll pagination and author shortcuts remain.
- Post publishing requires nonblank UTF-8 text (up to 65535 bytes) and accepts an
  optional locally selected image. Android/iOS enable the shared native image
  preparation: preserve aspect ratio, never enlarge, longest edge <=4096 and
  <=16 million pixels (older Android retains its lower memory safety cap), PNG
  for transparent pixels or JPEG quality 90 otherwise. GIF selections become a
  static first frame. If encoded bytes exceed 10 MiB, reduce dimensions again
  while retaining format/JPEG quality until the file fits. Byte-limit encoding
  runs off the UI isolate. Selection only prepares and previews locally, without
  progress UI or an upload. Only Post starts upload followed by post/create;
  the Post button shows its spinner throughout both stages and keeps its color.
  Text, picture selection/replacement/removal are locked while sending; no
  page-wide blocker prevents back, close or navigation. The World-owned draft
  continues submission across phone close/reopen, discards account-stale work,
  and retains the draft on failure. Preserve the complete returned xl_url
  including query parameters, reuse an uploaded URL on retry until the image
  changes, and retry uncertain posts with their original request ID/content/URL.
  Photos remains a read-only world album; image upload is independent of it.
- Post detail displays all detail comments. Reply selection queries the
  independent comments endpoint for real IDs; it never guesses IDs by text or
  position. Likes are serialized per post and queried after uncertain results.
- Photos uses the server album and shared image viewer. Each tile passes the
  exact grid thumbnail provider and a cover-fit source anchor to the common
  viewer, enabling the same cached-preview/320 ms opening expansion as Posts.
  The gallery snapshot filters empty original URLs and locates the selected
  asset by ID so the initial image and all preview providers stay aligned.
  Opening and each page change prefetch the immediately previous/next full
  images; bounds checks avoid wrapping at either end. Full-image prefetch uses
  the same screen width, DPR, CDN transform, decode width and fitWidth cache key
  as display, so swiping reuses the loaded frame. Failures remain silent.
  Home's world time comes
  from the world snapshot and existing world socket state, not device time.

World-backed routes use live data even on errors. The developer's explicit
worldless style preview and existing preview tests retain demo fixtures; this
is not a fallback for live requests. The local mock transport returns explicit
empty reads and refuses unsupported writes instead of simulating successful
AI replies.

## Current recovery and acceptance boundaries

- HTTP history includes `reply_status` and `failure` on the player's AI source
  message. Recover unresolved requests with `/messages?client_request_id=...`,
  including old IDs whose status changed. `completed/failed` never regress to
  pending/generating. Full correlated AI delivery batches also confirm completion.
- Generating WS events allow `failure=null`; final failure retains the source
  bubble. Automatic DMs and player messages cannot complete an unrelated request.
- Pending AI requests use foreground backoff queries (2 to 30 seconds), stop on
  server terminal state and never infer failure from empty results or errors.
- Phone pushes are immediate attempts only, with no offline replay guarantee.
  Reconnect/foreground recovery refreshes sessions, message history and counts.
- The optional legacy Feed `comments_preview` extension is still consumed if
  present. Current dev does not define it; absent previews cause no per-post
  requests and do not supply comment IDs. Real replies use `/comments`.
- Controlled transports prove client behavior only. Live authorization, player
  delivery, charging, upload readability and Android/iOS acceptance remain to be
  exercised with real accounts/devices. An upload URL may briefly be unreadable;
  completed AI replies do not independently prove wallet settlement.

## 2026-10-16 current dev alignment validation

- Updated virtual sessions, peer UID presentation, request-filtered reply recovery,
  generating/failed events, server list ordering, local post-image upload and
  UTF-8 text/page/URL limits to the supplied current dev contract.
- `flutter test --no-pub test/network/mini_phone test/pages/mini_phone test/network/chatroom/chatroom_client_test.dart test/network/chatroom/world_chatroom_service_test.dart`: **364 passed**.
- Regression includes six zero-ID rows, first-send promotion, player user-message
  direction/no AI typing, terminal-state ordering and offline HTTP recovery,
  local image upload/full URL preservation and idempotent uncertain post retry.
- Source/static/controlled UI evidence only; no authenticated dev end-to-end,
  physical-device keyboard, upload-readability or wallet settlement acceptance
  was performed in this change. Historical device records below remain historical.

## 2026-10-16 Messages presentation validation

- DM submission uses temporary outgoing rows reconciled by request ID; explicit
  rejection rolls back, uncertain transport results retain the original request,
  and delivery before HTTP wins over a late HTTP error.
- Live reply batches reveal one bubble per second after the first immediate row.
  Existing history is immediate; refresh/duplicate delivery cannot bypass the queue.
  Only upward pagination uses the top history-loading placeholder.
- `flutter test --no-pub test/network/mini_phone test/pages/mini_phone`: **169 passed**.
  Includes keyboard retention, history anchoring, first-session promotion, retry
  identity, rollback/new draft preservation and pending reveal disposal.
- Controlled client tests only; authenticated backend and physical-device
  acceptance remain unverified.

## Client maintenance reference

以下详情由 MiniPhone AGENTS.md 移入本文件，供相关任务按节读取。它们描述当前客户端调用和必须保持的行为，**以当前 dev 主稿为准，不新增任何真实后端或真机验收结论**。下文 `lib/`、`docs/`、`test/` 路径均以 `genesis_app/` 为基准；代码入口表中未带目录的文件位于 `lib/pages/mini_phone/`。

- 当前 dev 手机接口：`docs/mini-phone-chat-client-api-2026-10-12.md`。
- Posts 作者增量契约：`docs/mini-phone-post-authors-client-delta-2026-10-14.md`。
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
| `GET /messages` | 真实会话历史、分页及恢复；client_request_id 查询旧请求状态，按消息 ID 合并；虚拟会话不调用 |
| `POST /dm/send` | 发送角色私聊及首次私聊；提交 `world_id/char_id/client_request_id/content`；空成功响应不生成气泡 |
| `POST /dm_session/read` | 前台会话成功加载或收到新消息后标记该会话已读；只提交 `dm_session_id`，成功后重查会话和未读 |
| `GET /post/authors` | 只传 `world_id`，获取全世界已发帖角色 ID，不分页；关联世界角色名称和头像；Feed 刷新时一并更新 |
| `GET /posts` | Feed、`char_id` 作者筛选、刷新、分页；全部作者省略 `char_id`，玩家使用世界角色 ID；发帖、评论、点赞后刷新；读取 `comments_preview` 展示前三条评论 |
| `GET /post/detail` | 打开帖子或通知详情，展示正文和完整评论；点赞后查询实际状态；详情可见时随事件刷新 |
| `POST /post/create` | 发布文字／图文帖子；提交 `content` 和可选相册图片 URL 字段 `image`，成功后刷新 Feed |
| `POST /post/like` | 点赞；同帖操作串行，随后查询详情确认状态 |
| `POST /post/unlike` | 取消点赞；与点赞共用串行处理和状态查询 |
| `GET /comments` | 选择具体评论进行回复及分页，取得真实 `comment_id`；评论提交后刷新；普通详情的完整评论来自 `/post/detail` |
| `POST /comment/create` | 发布评论／回复；回复携带 `reply_to_comment_id`，成功后刷新详情、评论列表和 Feed |
| `GET /post/notifications` | Home 的查看更多、通知页、未读筛选、刷新和分页；通知点击按 `post_id` 打开详情 |
| `POST /post/notifications/read` | 进入 Posts 并成功加载后清除当前世界全部 Post 未读；只提交 `world_id`；停留期间不持续清除新通知 |
| `GET /album` | Photos 三列只读世界相册、刷新和分页；发帖独立使用本机图片上传 |

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

- Home 壁纸在设置页覆盖期间保留旧画面；返回桌面且新图片解码就绪后，以 300ms 淡入淡出切换，加载失败保留旧背景。
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
| `phone.reply.updated` | 处理关联请求的 generating（failure 可空）和 failed；终态优先、失败保留玩家源消息；触发聚合刷新 |
| `phone.post.notification.created` | Post 新通知；触发聚合刷新；Posts、相关详情和通知页可见时刷新相应数据 |

- 三类事件均按 `event_id` 去重。聚合刷新包括 Home、未读和会话；列表、详情和通知根据当前可见状态刷新，当前会话及待确认私聊另执行历史恢复。
- 未读数使用 HTTP 查询结果，不按事件次数增减。密集事件合并刷新；刷新期间新事件必须保留下一轮刷新。
- 手机关闭后继续处理当前世界事件；退出世界释放订阅。首次初始化、Socket 重连和返回前台恢复查询。
- Home 时钟还观察共享世界状态的 `latestSocketCurrentTime`；不能用设备时间代替世界时间。

### Required client behavior

- Messages 仅用 `/dm_sessions` 返回条目，保持服务端顺序，按 world_id + char_id 合并分页；多个 ID 为 0 的虚拟条目互不覆盖，跳过历史和已读查询，首次发送取得正数 ID 后替换。已有条目的消息摘要可随送达更新，不在客户端按消息 ID 或 updated_at 重排。
- 数据和写请求按环境、账号、世界隔离；上下文改变后丢弃旧请求结果，清除旧草稿和恢复页面引用。
- 保存写请求 ID 与原始正文、图片和回复目标；同一次操作重试复用原请求，不建立自动重发队列。超时／断线保持待确认状态，不能据此判定 AI 最终失败。
- DM 提交即显示本地临时气泡并清空原输入，Send 不转圈；正式消息来自送达／历史，按请求键合并临时气泡，按完整 int64 消息 ID 去重、升序展示。明确拒绝撤回临时气泡、空输入时恢复草稿；不确定失败保留气泡和原请求键。空成功响应只表示受理。新回复首条立即显示，后续每隔一秒显示一条；已有历史／分页不延迟，补查和重复推送不能提前展示排队消息。顶部历史加载占位只在向上翻页时出现。
- HTTP 200 下非零 `err_no` 仍为业务错误；展示原始 `ApiException.message`／`err_msg`，失败保留草稿。区分 Feed 的 `text` 和详情／提交的 `content`。
- 聊天复用 `LocationChatAnchoredMessageList`、`LocationChatScrollCoordinator`、`ChatMessageRow`、`ChatComposer`、共享 `ChatKeyboardInsetLayout`，视觉采用 `kPrivateChatStyle`。发送保持键盘，不预留回复空白；阅读历史时保留锚点和返回最新入口。
- “正在输入”是本地请求等待提示；仅 AI 会话等待期间允许编辑草稿、禁止再次发送，其他角色独立运行；请求关联状态可从 HTTP 恢复，终态不回退。玩家互发不显示 AI 状态，user 消息按 UID 判断方向。
- Posts 作者列表来自 `/post/authors`，与当前 Feed 分页和筛选无关；`char_id` 筛选先由服务端执行再分页。切换作者重置分页并丢弃旧响应；通知刷新保留筛选并刷新作者列表。两个 GET 均不标记已读，进入 Posts 的显式已读流程保持不变。评论预览使用 Feed 返回值，不逐帖请求详情补齐；回复必须使用 `/comments` 的真实 ID。
- 同帖点赞／取消点赞串行执行；结果不确定时查询详情，再处理最新操作意图。进入 Posts 的全部已读只在本次进入成功加载后执行，停留期间不自动清除新通知。
- 通知逐页替换，不按帖子合并、不制造通知 ID 或正文。Photos 保留网格和共享查看器；发帖从本机选图后仅统一预处理和预览，点击 Post 才上传（处理后最大 10 MiB）并发帖；发送中 Post 显示圆环、锁定正文和图片操作，返回和关闭仍可用，World 会话继续发送；失败保留草稿并复用已上传图片 URL，保留完整 xl_url；纯文字也可提交，正文不超过 65535 UTF-8 字节。
- 2026-10-16 布局回归以 `c6b7600e` 为基准：Messages 沿用标题加会话列表，不再增加 Unread / New message；会话与角色资料请求失败只用公共 Toast 展示原始错误，同轮相同错误合并提示，不因无关状态更新重复弹出，列表底部不显示错误文字和 Retry，通过下拉刷新重试；Posts 恢复头像叠加号、等分作者栏（角色较多时可横滑），再次点击选中作者取消筛选，不再增加 All。发帖恢复右上角 Post、动态作者及世界信息、虚线选图区；2026-10-16 当前 dev 契约更新后配图使用本机选择和上传；正文必填，按 UTF-8 字节限制，不恢复演示的 500 字或 3 MiB 限制。
- 评论沿用原帖排版、评论分隔线和输入头像；点击有真实 comment_id 的评论设置回复目标，不额外增加 Reply to a comment 按钮。详情摘要缺少 comment_id 时只展示，不伪造回复目标；真实评论列表从 `/comments` 获取。昵称、时间等缺失字段不使用演示占位值填充。
- 会话、Feed、评论、相册通过滚动加载下一页，不增加 Load more 按钮。首次空列表合并其依赖请求为一个 loading，下拉刷新使用既有刷新指示器，有内容后台刷新不追加转圈；私聊首次 loading 和历史页 loading 互斥。移除 Home 额外的 More messages / More notifications 操作行及原版没有的独立通知页面，保留原通知卡片展开与点击行为，通知接口及数据处理仍保留。
- 保持现有 MiniPhone 样式、导航、启动动画、音乐和壁纸行为；共享聊天修改须回归 LocationChat。动态请求错误使用公共 Toast；演示数据仅用于明确的无世界预览。

### MiniPhone 原版布局复核（2026-10-16）

基准为 `miniphone-origin` 的 `c6b7600e`；保留正式数据、原请求重试、已有启动动画和音乐服务，不以演示值填补缺失字段。

| 页面 | 本轮复核与修正 |
| --- | --- |
| Home | 删除首页通知区上方的接口错误段落与 Retry，错误只用 Toast，不挤动时钟和通知卡片。 |
| Messages / Posts / Photos | 删除列表内的错误／重试和通用空数据段落，保留原标题、列表／三列图片网格，以及下拉刷新与滚动分页。 |
| Comments / Create | 删除写入状态／Retry same request 占位区；原 Send／Post 按钮复用未确认请求 ID、正文、图片和回复 ID。评论回复目标仅改变原输入框提示，再点同一评论取消，不增加一行回复栏。 |
| Private chat | 删除输入区的错误／Refresh 和等待区 Retry；保留正在输入提示与历史锚点，未确认且未受理的请求由原 Send 按钮重试。恢复动态世界日期的 Private conversation 标题，去掉额外的自制长按复制菜单。 |
| Settings | 删除新增的错误／重试、不可用／空目录提示段落，读取失败使用 Toast 与下拉刷新；正常宽度恢复原版最多四项一排，窄屏和更多动态选项允许换行。Apply 及现有图片裁剪和保存进度保持。 |
| Music | 删除目录错误／Retry 与播放错误段落，读取失败使用 Toast 与下拉刷新，播放失败仍可用原播放按钮重试；现有封面、长标题滚动、进度和点赞逻辑保留。 |
| Models / 图片查看器 | 延用原版共享页面及查看器的结构，不改其公共样式。 |

动态头像、作者数量、时间和正文取接口；没有真实音乐点赞数量或用户 handle 时不补演示数字和账号。首次空内容的网络加载、聊天等待与阅读历史返回最新入口属于真实数据交互状态，不表示新增常驻操作栏。

### Backend contract boundaries

当前手机主稿替代旧草案与待部署说明；虚拟会话、玩家互发、请求关联状态和即时推送按主稿处理。源码契约与受控测试不能替代真实 dev 账号、Android/iOS 键盘及上传/计费验收。推送不保证离线重放，恢复走 HTTP；上传成功可能暂时不可读，AI completed 也不代表钱包收尾完成。JavaScript 目标仍需无损 int64 JSON 支持。

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
