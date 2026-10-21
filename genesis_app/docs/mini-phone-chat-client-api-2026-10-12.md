# Mini Phone 客户端接口对接稿（当前 dev）

更新日期：2026-10-16；客户端请求调度补充：2026-10-17；Posts 列表增量契约：2026-10-20（见 [phone_posts.yaml](phone_posts.yaml)，仅覆盖 `/posts`，优先于本文旧字段）。保留原文件名，本文整体替代之前的草案和“待实施”说明。

对齐基线：Chat `origin/dev` **b21774e**；API `origin/dev` **50e0287f**。以这两个已推送版本的路由、DTO 和实际实现为准，未纳入其他任务的未提交修改。本次做源码契约核对，未使用登录账号执行 dev 端到端联调。

覆盖 17 个 Chat 手机 HTTP 接口、3 类 WebSocket 事件，以及 API 图片上传和手机背景接口。已包含：AI 私聊及回复状态恢复、玩家互发、全角色会话列表、Post 作者筛选、玩家发帖/评论/点赞、通知与相册、自动反应、主动私聊和角色自动发帖。

## 1. 公共约定

### 1.1 地址、登录与权限

Chat 手机接口前缀：

```text
{chat_base_url}/aitown-chat/api/v1/phone
```

后文 `/home` 等路径相对此前缀；第 8 节的 API 接口使用 `{api_base_url}`。

- 手机接口全部要求登录，沿用 `Authorization` 或 `Cookie: AIUSS=<session>`；两者同时存在时 Authorization 优先。
- 沿用客户端现有网关鉴权及公共请求头：`x-device-id`、`x-app-id`、`x-platform`、`x-app-version`、`x-app-version-code`、`x-system-language`、`x-app-timezone`，及已有的语言设置头。POST 使用 `Content-Type: application/json`。
- 手机请求校验当前登录用户的世界可见性；发消息、发帖、评论和点赞还需有效玩家角色。仅有世界访问权不等于可以扮演世界内任意角色。
- `uid/player_uid/author_id/sender_id` 等操作者身份由服务端解析，客户端不在写请求中指定。
- 私聊查询和已读只允许访问本人会话。玩家互发双方使用各自的会话 ID 和消息 ID，不能互换使用。
- Chat 调 API 的内部鉴权由服务端处理，客户端不提交 `x-internal-token` 或 `access_scope`。
- 所有手机接口返回 `Cache-Control: no-store`，GET 不自动标记已读、不触发生成。

### 1.2 响应与错误

成功包装：

```json
{"err_no":0,"err_msg":"succ","data":{}}
```

常规业务成功和失败均为 HTTP 200；客户端同时检查 HTTP/网络状态和整数 `err_no`。`err_no=0` 才是本次操作成功。错误 `data` 为 `{}`，`err_msg` 可能已按语言本地化，不能依赖英文文案判断业务。

| Chat 错误码 | 含义与处理 |
| --- | --- |
| `10001` | 未登录或登录凭据无效 |
| `1001` | 参数、格式、长度或分页不合法 |
| `2060` | 手机资源不存在，或不属于当前用户/世界 |
| `2061` | 世界访问或角色权限不足 |
| `2062` | 请求冲突；可能是同请求 ID 内容不同，也可能是 AI 会话仍在处理或历史快照发生变化。先刷新会话/原请求状态，不盲目换 ID 重发 |

API、网关或上游权限错误也可能透出，表格不是全部错误码白名单。AI 私聊在接受后才进行预占/生成，接受成功不代表余额已扣除或 AI 必定回复；后续失败见 `reply_status/failure`。当前手机失败对象固定为 `{"message":"Reply generation failed."}`，不含内部原因。

### 1.3 ID、时间、分页

| 项目 | 当前契约 |
| --- | --- |
| `post_id/message_id/dm_session_id/comment_id/asset_id` | JSON integer/int64，取各自表自增主键；不同实体可同号，不保证连续。只有虚拟会话允许 `dm_session_id=0` |
| `reply_to_comment_id` | int64 或 null，引用同帖评论 |
| `world_id/char_id/peer_uid/author_id/sender_id/event_id/client_request_id` | 字符串，保持原值；UID 与 char_id 不可混用 |
| `published_at/delivered_at/created_at/updated_at/read_at` | RFC3339 UTC 字符串，秒精度，例如 `2026-10-16T08:00:00Z`；未读 `read_at=null`，虚拟会话 `updated_at=""` |
| WebSocket 外层 `ts` | Unix 毫秒时间戳整数；不要套用上述时间字符串解析 |
| `current_time` | 剧情时间原文，例如 `Day 2/10:00`；不用设备时间覆盖，也不用于消息/Feed 排序 |
| `pn/rn` | 页码从 1 开始，省略时默认 `pn=1,rn=10`，`rn` 最大 100；显式传值须是合法正整数 |
| 分页包装 | `{"list":[],"total":0,"pn":1,"rn":10}`；空列表为 `[]` |
| `total` | 当前筛选条件的总量；分页是页码方式，不是增量游标。并发新增时可能跨页重复，按业务 ID 合并 |

JavaScript 等客户端须在 JSON 解析、存储、排序和回传全过程保持 int64 精度，不能先解析成不安全的 Number 再转字符串。传输字段仍为 JSON 整数，不自行更改服务端字段类型。

### 1.4 写入与重试

`dm/send`、`post/create`、`comment/create` 必传 `client_request_id`，最长 128 字符，不能空白或有首尾空白。同一操作首次提交前生成并保存，重试复用原 ID 与完全相同内容。同一用户各类操作的请求键均需保持唯一，不因切换世界/角色/帖子复用旧键。

- 超时不等于未落库，不能自动生成新 ID 再提交。
- 同 ID 同内容成功重放仍返回 `data={}`，不返回原对象，也不重新生成、通知或补推送。
- 同 ID 改世界、目标、正文、图片或回复目标会冲突。修改内容应作为用户确认的新操作使用新 ID。
- `post/create.image` 省略与 `""` 等价；重试保留完整 URL（含查询参数）。
- 点赞/取消和已读不传 `client_request_id`，重复调用按当前状态处理。
- 手机写请求体最大 1 MiB；私聊、帖子、评论正文均为非空白 UTF-8 文本，最多 **65535 字节**，服务端不修剪或截断正文。此限制是字节，不是字符数。

## 2. Chat 接口总表

下表全部已在当前 dev 路由注册。所有 POST 成功统一返回 `data={}`。

| 方法 | 路径 | 必填参数 | 可选参数 | data |
| --- | --- | --- | --- | --- |
| GET | `/home` | `world_id` | — | `dms/posts` 未读聚合 |
| GET | `/dm_sessions` | `world_id` | `pn,rn,unread_only` | 分页 `DMSession` |
| GET | `/messages` | `world_id,dm_session_id` | `pn,rn,client_request_id` | 分页 `PhoneMessage` |
| POST | `/dm/send` | `world_id,char_id,client_request_id,content` | — | `{}` |
| POST | `/dm_session/read` | `dm_session_id` | — | `{}` |
| GET | `/unread` | `world_id` | — | `unread_count,char_id` |
| GET | `/post/notifications` | `world_id` | `pn,rn,unread_only` | 分页 `PostNotification` |
| POST | `/post/notifications/read` | `world_id` | — | `{}` |
| GET | `/posts` | `world_id` | `pn,rn,char_id` | 分页 `PhonePost` |
| GET | `/post/authors` | `world_id` | — | `{"list":["char_id"]}`，不分页 |
| GET | `/post/detail` | `world_id,post_id` | — | `PostDetail` |
| POST | `/post/create` | `world_id,client_request_id,content` | `image` | `{}` |
| POST | `/post/like` | `world_id,post_id` | — | `{}` |
| POST | `/post/unlike` | `world_id,post_id` | — | `{}` |
| GET | `/comments` | `world_id,post_id` | `pn,rn` | 分页 `PhoneComment` |
| POST | `/comment/create` | `world_id,post_id,client_request_id,content` | `reply_to_comment_id` | `{}` |
| GET | `/album` | `world_id` | `pn,rn` | 分页 `AlbumAsset` |

`world_id/char_id` 最长 64 字符，不接受首尾空白。只使用表中列出的过滤参数：例如 `unread_only` 只对会话列表和通知列表有意义，不能用它筛选消息、帖子、评论或相册。

## 3. 公共响应对象

以下均为现有 DTO 字段。可空字段返回 null，不应当成缺字段或空对象。

### 3.1 PhoneMessage

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | int64 | 当前用户可见消息 ID |
| `world_id` | string | 世界 ID |
| `dm_session_id` | int64 | 本人的真实会话 ID |
| `sender_type` | string | `user` 或 `char` |
| `sender_id` | string | user 时为真实发送者 UID；char 时为角色 char_id |
| `type` | string | 当前为 `text` |
| `content` | string | 正文 |
| `current_time` | string | 保存时的剧情时间 |
| `delivered_at` | string | 消息送达时间，RFC3339 UTC |
| `client_request_id` | string/null | 本人请求或对应 A 回复的原请求键；自动私聊和玩家互发的接收副本为 null |
| `reply_status` | string/null | 仅本人发给 AI 的玩家消息有 `pending/generating/completed/failed`；AI 气泡和玩家互发均为 null |
| `failure` | object/null | 仅 `reply_status=failed` 时为固定 `message` 对象 |

**消息方向必须比较 `sender_id` 与当前登录 UID。** `sender_type=user` 可能是其他玩家发来的消息，不能全部画在本人侧。

A 的玩家源消息和全部 AI 回复气泡拥有相同的 `client_request_id`。自动私聊无此关联，不能把随后到达的任意角色消息当作 A 成功。PhoneMessage 不返回 `read_at`、来源任务 ID、气泡下标或内部历史字段。

### 3.2 DMSession

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `dm_session_id` | int64 | 真实会话 ID；尚无会话时为 0 |
| `world_id` | string | 世界 ID |
| `char_id` | string | 对端角色 ID，AI 和玩家都用角色 ID |
| `peer_uid` | string | 对端玩家 UID；AI 为 `""` |
| `char_name` | string | 对端角色名 |
| `char_avatar_url` | string | 对端角色头像 |
| `unread_count` | int64 | 本会话收到的未读消息数 |
| `last_message` | PhoneMessage/null | 最新消息；没有消息时为 null |
| `updated_at` | string | 真实会话更新时间；虚拟会话为 `""` |

条目唯一键用 `world_id + char_id`，不能用可能为 0 的 `dm_session_id`。不返回最新消息 ID 或已读边界。

### 3.3 PhonePost

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `post_id` | int64 | 帖子 ID |
| `world_id` | string | 世界 ID |
| `author_type` | integer | `1` 玩家，`2` AI 角色 |
| `author_id` | string | 玩家为 UID，AI 为 char_id；不能一律当角色 ID |
| `author_name` | string | 作者角色名 |
| `author_avatar_url` | string | 作者角色头像 |
| `text` | string | Feed 正文；与详情/创建中的 `content` 字段名不同 |
| `current_time` | string | 剧情时间 |
| `published_at` | string | 实际发布时间 |
| `image` | string | 完整图片 URL；纯文字帖为 `""` |
| `like_count` | int64 | 有效点赞数 |
| `is_liked` | boolean | 当前用户是否已点赞 |
| `comments` | PhoneComment[] | 最新至多 4 条评论及回复，按 published_at DESC、comment_id DESC；无评论为 `[]` |

Feed 不返回 `comment_count`，不能由截断的 `comments` 数组推断总数。客户端取返回的最新 3 条后按时间正序展示，第 4 条仅用于判断存在更多评论，点击预览或评论入口打开完整评论页；不为 Feed 逐帖请求 `/comments` 或详情。`phone_posts.yaml` 引用的 `phone-query-types.yaml` 未随本次附件提供，评论对象沿用第 3.4 节 PhoneComment 解析。

Feed 不直接返回 `author_char_id`。作者筛选用 `/post/authors` 的 char_id；详情返回作者 char_id，玩家 Feed 作者 UID 不能直接用作 char_id 筛选。

### 3.4 PhoneComment

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `comment_id` | int64 | 评论 ID |
| `post_id` | int64 | 所属帖子 |
| `author_type` | integer | `1` 玩家，`2` AI 角色 |
| `author_id` | string | 玩家 UID 或 AI char_id |
| `author_name` | string | 作者角色名 |
| `author_avatar_url` | string | 作者角色头像 |
| `comment_type` | integer | `1` 原帖评论，`2` 评论回复 |
| `text` | string | 正文 |
| `reply_to_char_id` | string/null | 回复目标角色，可空；不能假设所有回复都有此字段值 |
| `reply_to_comment_id` | int64/null | 被回复的同帖评论；按此定位父评论 |
| `current_time` | string | 剧情时间 |
| `published_at` | string | 实际发布时间 |

全部评论和回复是一条扁平时间线。玩家提交回复只传 `reply_to_comment_id`，当前实现不保证为玩家回复补出 `reply_to_char_id`；需要目标名时通过父评论的作者资料解析。

E1 自动反应已支持回复已有评论或同批先前评论，落库后仍使用上述两个既有引用字段。客户端不传模型输出字段 `reply_to`，不接收内部批次下标。无有效目标或父评论落库失败时不会出现悬空回复。

### 3.5 PostDetail

详情直接返回下列对象，不嵌套 `post`；评论数组全量返回，不分页。

```json
{
  "char_id":"char_ai_1",
  "char_name":"Alice",
  "content":"今天去湖边走了走。",
  "image":"",
  "like_count":2,
  "comment_count":1,
  "is_liked":false,
  "comments":[{"char_id":"char_player_1","char_name":"Alex","content":"风景怎么样？"}],
  "published_at":"2026-10-16T08:00:00Z"
}
```

`comment_count` 等于本次 `comments` 数组长度。详情精简评论只有 `char_id/char_name/content`，没有 `comment_id`、回复关系或评论时间；要实现“回复这条评论”、回复标识或精确定位，另查 `/comments`，不要按数组下标推导 comment_id。

### 3.6 PostNotification

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `world_id` | string | 世界 ID |
| `event_type` | string | `post/like/comment/reply` |
| `post_id` | int64 | 点击后打开的帖子 |
| `actor_type` | integer | `1` 玩家，`2` AI 角色 |
| `actor_id` | string | 玩家 UID 或 AI char_id |
| `current_time` | string | 事件剧情时间 |
| `published_at` | string | 事件实际时间 |
| `read_at` | string/null | 已读时间；null 为未读 |

HTTP 通知没有 `notification_id/event_id/asset_id/comment_id/like_id`。同帖多个通知保留多条，不能按 post_id 去重。分页刷新按页整体替换；HTTP 字段可能完全相同，不要以组合字段擅自合并。WS 的 `payload.event_id` 仅用于传输事件去重。

### 3.7 AlbumAsset

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `asset_id` | int64 | 相册条目 ID |
| `world_id` | string | 世界 ID |
| `image_url` | string | 完整图片 URL |
| `thumbnail_url` | string/null | 缩略图；null 时可使用 image_url |
| `desc` | string | 图片描述，可为空 |
| `created_at` | string | 登记时间 |

仅返回成功登记且可见的图片，没有生成中/失败状态、尺寸、来源或人物列表。不同资产可有相同 URL，客户端按 asset_id 管理条目。

## 4. Home、未读与通知

### 4.1 GET /home

必传 `world_id`。不分页，分别返回全部未读计数和最近最多 20 条未读明细：

```json
{
  "dms":{"unread_count":0,"list":[]},
  "posts":{"unread_count":0,"list":[]}
}
```

- `dms.list` 是 PhoneMessage，按 message_id 倒序。
- `posts.list` 是 PostNotification，按 published_at、内部记录 ID 倒序。
- DM 未读按收到的消息/气泡计数：包括 AI 消息及其他玩家发来的消息；本人发送不计入。
- Post 每条已保存的通知计 1；回复不额外再计一次 comment，图文帖也只计一次 post。
- 不返回世界时钟、world_id 或总未读字段。计数与明细分别查询，允许并发时暂时不同步。

客户端 DM 缓存策略：进入 Home 时以 `dms.list/unread_count` 建立 SQLite 未读基准；随后由去重后的 WebSocket 消息和本地阅读更新首页列表、数量及角标。响应不得覆盖请求期间的新增消息或本地已读；未返回的未读数量保存为差额，不能据此制造消息或猜测归属。普通历史查询不自行推断未读。Posts 通知维持原逻辑。

### 4.2 GET /unread

必传 `world_id`，只返回两类未读的合计及最新未读作者的角色 ID：

```json
{"unread_count":3,"char_id":"char_ai_1"}
```

无未读时为 `{"unread_count":0,"char_id":null}`。不返回 DM/Post 分项。比较两类最新候选的实际时间，同时间优先 DM；玩家通知作者 UID 会转换为角色 ID。并发变化或无法解析角色时，即使计数大于 0，char_id 也可能为 null。

### 4.3 GET /post/notifications

`world_id` 必填，`pn/rn` 可选，`unread_only` **默认为 true**；传 false 查询全部已保存通知。返回分页 PostNotification，按 published_at DESC、内部 ID DESC。GET 不已读。

### 4.4 POST /post/notifications/read

```json
{"world_id":"world_1"}
```

标记本人在该世界的全部存量未读通知，成功 `data={}`。不传通知 ID 或截止时间，重复调用保留原已读时间。完成后客户端只刷新 `/post/notifications?pn=1&rn=20&unread_only=true` 帖子聚合及正在显示的通知列表，不请求 Home/unread 或私聊接口；不会另推未读/已读事件。之后新到的通知仍为未读。

通知跳转仅有 post_id，先打开详情；不支持仅凭通知精确跳转某条评论。客户端从 Home 通知直达详情时，在详情成功加载且仍前台可见后调用此全部已读接口；普通详情浏览不额外调用。已触发的上报与通知查询由 World 会话继续处理，不随关闭手机取消；失败保留提示。已读写请求不自动重放，查询失败在重新打开手机、前台恢复或重连时补查。此行为不提供单条通知已读能力。

## 5. 私聊列表、发送与恢复

### 5.1 GET /dm_sessions

`world_id` 必填，`pn/rn` 可选。`unread_only` 默认为 false；true 时先筛选未读会话，再计算 total 和分页。

返回世界内**除本人角色外的所有角色**，包括 AI、其他玩家及从未聊过的角色。服务端先补全列表再排序/分页：有消息的会话按最新消息 delivered_at DESC、message_id DESC；没有消息的条目按世界角色原顺序。

客户端展示规则：已有条目合并最新送达／历史缓存后，使用同样的 delivered_at DESC、message_id DESC 规则即时排序，包括仍停留在聊天页时的外层 Messages 列表。无消息条目保留服务端相对顺序；不按 updated_at 或世界时间 current_time 重排，也不为排序额外请求会话列表。

尚无会话的例子：

```json
{
  "dm_session_id":0,
  "world_id":"world_1",
  "char_id":"char_player_2",
  "peer_uid":"user_2",
  "char_name":"Sam",
  "char_avatar_url":"https://cdn.example.com/sam.webp",
  "unread_count":0,
  "last_message":null,
  "updated_at":""
}
```

`dm_session_id=0` 时展示空聊天页，跳过 `/messages` 和 `/dm_session/read`，仍可按 char_id 发送。GET 不创建空会话。已有真实空会话保留其正数 ID，不以 `last_message=null` 推断为虚拟会话。

### 5.2 GET /messages

```text
/messages?world_id=world_1&dm_session_id=101&pn=1&rn=10
/messages?world_id=world_1&dm_session_id=101&client_request_id=dm_req_001&pn=1&rn=10
```

返回分页 PhoneMessage，**message_id DESC**；客户端聊天时间线合并后按 ID 升序展示。没有增量游标/after_id 参数。翻页期间可能有新增消息，按 ID 去重并更新已有对象。

按 client_request_id 查询时，返回该本人原请求的玩家消息，以及其已落库的全部 A 回复；不夹带自动私聊。当前 A 最多 5 个气泡，因此 `pn=1,rn=10` 足以恢复单个请求。玩家互发按本人请求键只查本人发送记录，接收副本无原请求键。

消息、原请求关联和 A 状态在同一数据库快照读取。原请求无匹配是 `list=[],total=0`，不是“生成失败”；接口失败也不能转成消息 failed。

### 5.3 POST /dm/send

```json
{"world_id":"world_1","char_id":"char_ai_1","client_request_id":"dm_req_001","content":"今天过得怎么样？"}
```

成功 `data={}`，不返回 message_id、会话 ID、价格或任务对象。首次发送按目标 char_id 创建真实会话；通过即时推送或刷新会话列表获得 ID。不能发给本人或世界外角色。

| 对端 | 行为 | 客户端状态 |
| --- | --- | --- |
| AI（peer_uid 为空） | 接受玩家消息，异步预占、生成 A、保存完整回复；每个会话同时最多一个未终结 A | 玩家源消息有 reply_status，收到生成中/失败事件或查询恢复 |
| 其他玩家（peer_uid 非空） | 同事务保存双方记录，提交后分别即时推送；免费，不调用模型 | reply_status/failure 均 null；不展示 AI 正在输入或生成失败 |

AI 的模型、历史快照和报价在首次接受时固定。当前收费为服务端主线报价整数 cent 的 40%，最终 cent 向上取整；客户端不提交金额/金额上限，没有手机价格预览接口。先预占，完整回复落库后提交扣费；`completed` 仅表示回复可读，不是扣费确认。资金收尾失败不撤回消息或将 completed 改为 failed，钱包展示另按已有钱包接口刷新。

玩家互发只在手机中展示，不进入模型历史、P5、轮次或自动触发计数；不套用 App 普通私信的互关/拉黑规则。发送方保留 client_request_id，接收方为 null；双方 message_id/dm_session_id 不同。

### 5.4 A 状态与断线恢复

| reply_status | 客户端含义 |
| --- | --- |
| `pending` | 已接受，等待预占/生成调度 |
| `generating` | 正在生成，可显示输入提示 |
| `completed` | 完整 A 回复已落库，可以展示 |
| `failed` | 本次 A 失败；玩家消息保留，显示统一失败提示 |
| `null` | 此消息没有 A 回复状态，例如 AI 气泡、自动私聊、玩家互发 |

推荐流程：

1. 提交前保存 world_id、char_id、client_request_id 和原内容；成功 data={} 只确认接受。允许本地临时气泡，但收到正式消息后按请求键/消息 ID 合并，不能重复插入。
2. WS 可能先于 HTTP 返回；消息 ID 去重，重复 ID 更新状态和内容。A 完整回复批次可确认对应请求 completed，不等待额外完成事件或账务通知。
3. 未收到首次会话 ID：刷新 dm_sessions，按 world_id+char_id 找真实 ID，再按原请求键查询。
4. 重连／返回前台后校准 Home/unread、同步当前可见聊天，并对待确认请求按 client_request_id 查询。只有仍缺少真实会话 ID 的待确认发送才按需跨页查 dm_sessions，不顺带重拉应用列表。不能只拉新消息，因为旧 message_id 的状态也会变化。
5. 离线内容超过一页时逐页取回；单页可能拆开不同回复批次，普通列表不能假设“一页等于一轮”。
6. 发送受理及超时／断网等结果不明后均启动只读恢复，前台按 2→4→8→16→30 秒退避，整轮完成后计时，同请求不重叠。缺少会话 ID 时先做第 3 步；玩家发送查询到本人正式消息即结束受理恢复，A 等待只由服务端终态或同请求完整 A 批次结束。查询错误／空结果不推断失败，后台暂停新增查询；客户端不自动换键或重发。
7. completed/failed 优先于迟到的 pending/generating，终态不回退。已 failed 的同 ID 重试只返回原接受结果；用户主动重新发送才使用新 ID。

### 5.5 POST /dm_session/read

```json
{"dm_session_id":101}
```

只传本人真实会话 ID，不传 world_id、消息 ID 或已读游标。将该会话全部存量未读消息设为已读，成功 `data={}`；本人发出的消息也可能被标记，但未读数只统计收到的消息。保留已读时间，不提供对方已读回执。

客户端进入前台会话即本地已读，先持久化已读边界和待同步操作，再调用此接口。边界未推进且无新未读时不重复创建已读操作，已有失败记录仍可重试。离线或失败保留本地已读并在恢复时串行重试；成功后校准 Home/unread，不额外重拉 dm_sessions，也不等待推送。虚拟会话 ID 0 不调用。旧请求完成不清除新的待同步操作或本地新增未读；服务端整会话已读且无游标，客户端不承诺跨设备强一致。

## 6. Post、评论与相册

### 6.1 GET /posts 与 GET /post/authors

```text
/posts?world_id=world_1&pn=1&rn=10
/posts?world_id=world_1&char_id=char_player_1&pn=1&rn=10
/post/authors?world_id=world_1
```

posts 返回分页 PhonePost，每帖内含最新至多 4 条 `comments`（倒序），不再返回 `comment_count`；按 published_at DESC、post_id DESC；char_id 省略或空字符串表示全部作者，非空则同时筛选 list 和 total。玩家也用其角色 char_id，不传 author_type 或 UID。

post/authors 只返回已发帖作者的去重 char_id，包含玩家和 AI；char_id 升序，排除空 ID，不分页：

```json
{"list":["char_ai_1","char_player_1"]}
```

不是所有世界角色名单，也不受当前 Feed 分页或作者筛选影响。客户端用已有角色资料解析名称/头像，自己提供“全部”选项。切换作者重置 pn=1；收到新通知刷新 Feed 时保留当前筛选，同时刷新作者列表。

### 6.2 GET /post/detail 与 GET /comments

```text
/post/detail?world_id=world_1&post_id=201
/comments?world_id=world_1&post_id=201&pn=1&rn=10
```

详情为第 3.5 节 PostDetail，包含全部精简评论；独立 comments 为分页 PhoneComment。两者评论均按 published_at ASC、comment_id ASC，包含普通评论及回复。跨世界或不存在帖子返回业务错误。读取不会清除 Post 通知未读。

客户端展示策略（2026-10-21）：进入详情先使用 Feed 当条数据渲染原帖，评论区显示 3 行静态骨架；并行刷新详情与 `/comments?pn=1&rn=100`，有后续页自动取齐，按真实 ID 去重并正序一次性替换。详情精简评论不再作为列表兜底。进入保持顶部；回复键盘弹起后等完整评论与视口布局就绪再定位到底部，用户主动滚动取消跟随。此策略不改变上述服务端协议。

### 6.3 POST /post/create

图片来自玩家手机本地选择，**可不选图片**。有图时先通过现有上传能力获得 OSS/CDN 完整 URL，再提交：

客户端选图阶段仅做本地统一预处理和预览，不上传、不显示处理进度：最长边 ≤4096px、总像素 ≤1600 万（旧 Android 保留更低的内存安全上限），不放大小图，透明像素保留 PNG，否则 JPEG 质量 90%；编码超过 10 MiB 时继续等比缩小至上限内。GIF 按静态首帧处理。点击 Post 后才上传并提交帖子，按钮全程 loading、正文和图片操作锁定；返回和关闭仍可用，World 会话继续持有发送。失败保留草稿和已上传 URL，未确认帖子重试仍遵循请求幂等规则。

```json
{"world_id":"world_1","client_request_id":"post_req_001","content":"今天的风景。","image":"https://cdn.example.com/uploads/photo.jpg?x-oss-process=image/format,webp"}
```

纯文字：

```json
{"world_id":"world_1","client_request_id":"post_req_002","content":"今天想休息一下。"}
```

- 图片省略或 `""` 均为纯文字；有图也必须有非空正文。
- image 是完整 HTTP/HTTPS URL，最长 2048 字符，无首尾空白、URL 用户凭据或 fragment；保留全部查询参数，不传 base64、文件路径、object_key 或 asset_id。
- 不要求先在游戏相册登记，也不要求从相册选择。Chat 不联网探测图片是否上传完成；上传接口说明见第 8 节。
- 成功 `data={}` 后主动刷新 posts、post/authors 及相关 Home/unread；不会返回新 post_id。后续可能产生 T2 自动公开互动。
- 已提交有图帖子独立登记相册；登记失败不撤销帖子，重试成功请求不会自动补登记。

### 6.4 POST /comment/create

普通评论：

```json
{"world_id":"world_1","post_id":201,"client_request_id":"comment_req_001","content":"看起来不错。"}
```

回复指定评论：

```json
{"world_id":"world_1","post_id":201,"client_request_id":"comment_req_002","content":"下次一起去。","reply_to_comment_id":301}
```

reply_to_comment_id 省略或 null 为普通评论；正数表示同帖已有评论，0/负数非法。客户端不传 reply_to_char_id 或 comment_type。成功 data={}，随后刷新详情/comments；当用户在 AI 帖子下进行前两次评论或回复时，可能触发第 7 节的自动反应。

### 6.5 POST /post/like 与 POST /post/unlike

两者均只提交：

```json
{"world_id":"world_1","post_id":201}
```

成功 data={}，主动刷新 like_count/is_liked。重复 like/unlike 不重复计数；取消后再次点赞会产生新的点赞事实。取消不会撤回旧通知，也不会发送新通知/WS。客户端应串行提交同帖点赞状态，避免迟到的 like 在 unlike 后再次生效。

### 6.6 GET /album

`world_id` 必填，`pn/rn` 可选，返回分页 AlbumAsset，按 created_at DESC、asset_id DESC。只读，不提供客户端登记/删除/生图接口。

相册包含当前世界已登记且仍符合可见条件的世界图片资源及已发布帖子图片。新世界创建后登记封面、头像、地点图；历史世界不补登记，后续资源变化也不自动同步。图片登记失败可能导致相册缺项，查询不补写。世界资源入册不产生 Post 通知，新帖图片也不额外产生第二条通知。

客户端展示策略（2026-10-21）：Photos 每页显式请求上限 `rn=100`。每次进入回到顶部，先显示当前 World 会话缓存并请求 `pn=1`；响应按 asset_id 和完整字段增量更新对应页，复用未变化条目及图片控件，后续缓存页保留到按需校验，无下一页时移除更后面的缓存。视口接近本轮已确认页经展示过滤、URL 去重后的网格边界时请求下一页，不以缓存尾部代替本轮分页边界；连续过滤为空的页继续按视口需要补页。失败保留缓存，账号切换清空页缓存。此策略不改变上述服务端协议。

## 7. 自动内容在客户端的表现

客户端不直接调用 C/D/E/F 模型或提交生成状态；按已送达的 Post/DM 数据展示。

| 来源 | 当前行为 |
| --- | --- |
| 玩家发帖（T2） | 可能出现 AI 点赞、评论或回复，不产生 T2 私聊 |
| 同玩家在同一 AI 帖下第 1 次评论/回复（T3） | 可能出现公开评论或回复 |
| 第 2 次评论/回复（T3） | 公开反应和帖作者私聊独立执行，任何一方失败不阻断另一方 |
| 第 3 次起，或评论玩家帖子 | 只保存玩家评论/通知，不触发 T3 模型反应 |
| 主动私聊（T1） | 成功主线/A 累计及服务端判断可能触发角色主动私聊，沿用普通私聊展示 |
| 角色自动发帖（F） | 发布后进入 posts、作者列表和通知；可能继续产生点赞、评论/回复 |

T3 按每位玩家/每个帖子分别计数，普通评论和回复均计入，历史评论也计入，请求重放不重复累计。每次 T3 最多 3 条有效角色评论/回复、每角色最多 1 条，**不占 F/T2 原帖每角色最多 2 条的互动额度**。T3 作者私聊不受 T1 日额度及上一条主动私聊未回复限制。

T2 互动按原帖发布时间起依次延迟；T3 公开反应计划在原评论后 15–60 秒、第二次作者私聊在原评论后 120 秒送达。生成晚于计划会尽快送达，客户端不据此显示保证到达倒计时。无有效结果或生成失败可能没有任何自动动作，也不会生成失败气泡或新增客户端状态。

当前主动内容累计要求原主线/A 请求 `x-app-version >= 0.5.5`；应在既有 HTTP/WS 入口准确携带版本。此门槛不用于屏蔽已送达内容，也不限制 T2/T3 或已存在任务的送达。

F 的图片描述为空、空白或缺失时直接发布**纯文字帖**，HTTP `image=""`，正常通知和后续互动，不登记图片。描述非空才生图/上传；该过程失败跳过整帖，不发布“图片生成失败”占位，也不自动降级成文字帖。

自动私聊为免费消息，client_request_id/reply_status/failure 均 null，不当作用户某次 A 请求的成功。Post/自动内容当前流程没有额外客户端报价或确认付款接口，不使用 AI 私聊 40% 报价展示其费用。

## 8. API 上传与背景接口

以下使用 API 服务地址，与 Chat `/phone` 前缀不同。

### 8.1 POST /api/v1/upload/image

沿用登录、封禁校验及网关公共头。`multipart/form-data`：必传二进制 `file`，可选 `scene`。最大 10 MiB；支持 jpg/jpeg/png/gif/webp/heic/heif，HEIC/HEIF 只处理静态主图。

data 示例：

```json
{"sm_url":"https://cdn.example.com/uploads/photo.jpg?x-oss-process=image/resize,p_50/format,webp","xl_url":"https://cdn.example.com/uploads/photo.jpg?x-oss-process=image/format,webp","object_key":"uploads/photo.jpg"}
```

发帖可用完整 xl_url 作为 image，保留查询参数。接口成功仅表示已接收并启动异步上传，URL 可能短暂不可读；客户端需处理图片加载中/失败，重新上传会得到新的上传结果。Chat 不等待或检查上传完成，发帖成功也不保证图片 URL 已可读取。不要用新的 URL 静默重试已经提交的同一 post 请求 ID。

### 8.2 GET /api/v1/world/miniphoneinfo

必传 world_id，按世界可见性读取，可游客访问。data：

```json
{"background_image":"https://cdn-001.worldo.ai/predata/miniphonebg/1.webp","default_background_images":[{"image_url":"https://cdn-001.worldo.ai/predata/miniphonebg/1.webp","title":"默认背景"}]}
```

default_background_images 的标题以实际配置返回为准，未配置可为 []。background_image 是当前用户**跨世界共用**的个人设置；游客或未设置时回退默认图。

### 8.3 POST /api/v1/world/setminiphonebackground

登录且未封禁用户提交：

```json
{"world_id":"world_1","background_image":"https://cdn.example.com/background.webp"}
```

world_id 必填并校验可见性，不要求是世界 owner。background_image 字段必传，`""` 清除个人选择并恢复默认；非空为无凭据 HTTP/HTTPS URL，最多 512 字符且无首尾空白。成功 data={}，通过 miniphoneinfo 刷新；不是只修改某一个世界的背景。

## 9. WebSocket 实时事件

### 9.1 连接与包装

沿用当前世界的 `/aitown-chat/ws?world_id=...` 登录连接及 V2 协议；没有独立手机 socket 或手机 join 命令。手机个人消息按世界+登录玩家投递，与主线地点无关。手机 message_id/dm_session_id 位于 payload，不从主线外层 message_id/session_id 取值。

下面是 V2 相关字段示例，通用 V2 外层其他字段仍沿用现有协议：

```json
{
  "type":"phone.messages.delivered",
  "stream_type":"",
  "ts":1792137600000,
  "world_id":"world_1",
  "trigger_uid":"",
  "payload":{
    "event_id":"phone:messages:401:401",
    "dm_session_id":101,
    "client_request_id":"dm_req_001",
    "messages":[{
      "message_id":401,
      "world_id":"world_1",
      "dm_session_id":101,
      "sender_type":"user",
      "sender_id":"user_1",
      "type":"text",
      "content":"今天过得怎么样？",
      "current_time":"Day 2/10:00",
      "delivered_at":"2026-10-16T08:00:00Z",
      "client_request_id":"dm_req_001",
      "reply_status":"pending",
      "failure":null
    }]
  },
  "err_no":0,
  "err_msg":""
}
```

### 9.2 三类事件及 payload

| 外层 type | payload 字段 | 客户端处理 |
| --- | --- | --- |
| `phone.messages.delivered` | `event_id,dm_session_id,client_request_id,messages` | 按 message_id 合并本次完整批次，刷新会话列表/Home/unread；未知会话刷新列表并替换 char_id 对应虚拟条目 |
| `phone.reply.updated` | `event_id,dm_session_id,message_id,client_request_id,job_status,failure` | 仅 A，job_status 为 generating 或 failed；message_id 指玩家源消息。显示输入提示或失败，终态优先 |
| `phone.post.notification.created` | `event_id` 加完整 PostNotification 字段 | 刷新 posts（保留作者筛选）、post/authors、Home/unread；详情或通知页正在展示时一起刷新 |

生成中 payload 示例：

```json
{"event_id":"phone:reply:401:generating","dm_session_id":101,"message_id":401,"client_request_id":"dm_req_001","job_status":"generating","failure":null}
```

失败 payload 示例：

```json
{"event_id":"phone:reply:401:failed","dm_session_id":101,"message_id":401,"client_request_id":"dm_req_001","job_status":"failed","failure":{"message":"Reply generation failed."}}
```

Post 通知 payload 示例（event_id 按不透明字符串处理，不拼接/解析）：

```json
{"event_id":"post_event_example","world_id":"world_1","event_type":"reply","post_id":201,"actor_type":2,"actor_id":"char_ai_1","current_time":"Day 2/10:00","published_at":"2026-10-16T08:00:00Z","read_at":null}
```

### 9.3 去重、刷新与遗漏

- event_id 去重；PhoneMessage 还须按 message_id 合并并更新字段。A 完成一次推送全部回复气泡，不逐气泡发送；成功不另发 completed 状态事件。
- 玩家发给 AI 的消息提交与 A 回复提交分别推送；玩家互发向双方分别推送各自数据，无 phone.reply.updated。
- 自动私聊批次 client_request_id=null。玩家互发接收方同样为 null，须结合 sender_type/sender_id 判断。
- Post 内容先提交，再独立保存每位接收者的通知并即时推送，包含有效世界玩家中的发起者和离线玩家的持久通知。回复只发 reply，不重复发 comment；取消点赞不发通知。
- 所有推送只即时尝试，不重试、不离线重放。内容已保存但推送失败时，通过 HTTP 恢复；通知写入本身失败可能永久缺项，Feed 中内容仍然存在。
- 不按事件次数累加未读，不按 post_id 合并通知。客户端 DM 以 Home 查询建立本地基准，之后按唯一消息 ID 和阅读操作更新，并在 Home 查询时校准；Posts 未读仍以查询结果为准。
- 没有会话更新、未读更新或已读同步专用事件；HTTP 成功后按业务范围主动校准，不依赖自己的 WS：DM 已读校准 Home/unread；帖子通知、发帖及 Post 已读只通过 `/post/notifications?pn=1&rn=20&unread_only=true` 更新帖子数量与明细，不触发私聊历史、请求状态、已读或 Home/unread；点赞查询帖子详情。
- 不需要为手机新建多设备同步流程；连接断开或被替换后走既有重连和 HTTP 恢复。

## 10. 客户端联调清单

1. **基础**：HTTP 200 业务错误正确处理；int64 不丢精度；RFC3339 时间与 WS 毫秒时间分别解析；无数据 list=[]、可空字段 null 正确显示。
2. **列表**：所有其他角色可见；多个 dm_session_id=0 条目不互相覆盖；空会话跳过消息/已读查询，首次发送后替换成真实会话。
3. **玩家互发**：双方 user 消息按真实 UID 判断方向；双方使用自己的 ID；接收副本请求键为 null；不显示 AI 状态；未读只计算收到的消息。
4. **AI 回复**：HTTP/WS 乱序、重复消息、离线完成/失败、仅旧消息状态变化、首次会话 ID 丢失、单页不足等都可恢复；迟到 pending/generating 不覆盖终态；不等待扣费完成才展示。
5. **幂等**：超时复用原 ID/正文/URL；同 ID 改内容冲突；成功重放不重复消息、帖子、评论或自动反应；失败 A 要主动新操作才重发。
6. **Post**：本地图片上传后发帖、纯文字发帖、完整 URL 参数保存、作者筛选及筛选后 total；刷新保留筛选，新增作者及时可见。
7. **回复**：详情精简评论不用于构造 comment_id；comments 可读取自动回复的真实父评论；玩家回复允许 reply_to_char_id=null；普通评论与回复保持扁平展示。
8. **自动内容**：T3 第 1/2/3 次行为及两种动作独立；T1/自动私聊不误配 A 请求；F 无图时正常显示文字帖，有图生成失败不出现半成品。
9. **通知/已读**：同帖多通知不合并；未读以服务端为准；取消点赞不撤回旧通知；两个已读接口只清理相应范围，成功主动刷新。
10. **相册/背景**：相册缺图不影响已发帖显示；无缩略图时回退原图；背景按当前用户跨世界生效，空字符串恢复默认。

## 11. 依据与维护

主稿按上述 dev 基线核对；各日期增量稿保留其历史范围，不再用旧稿里的“未实现/待上线”说明判断当前能力。

- Chat [手机路由](/Users/cun/work/aitown-chat/router/phone.go)、[查询 DTO](/Users/cun/work/aitown-chat/components/dto/phone_query.go)、[写入 DTO](/Users/cun/work/aitown-chat/components/dto/phone_write.go)、[发送 DTO](/Users/cun/work/aitown-chat/components/dto/phone_send.go)、[事件 DTO](/Users/cun/work/aitown-chat/components/dto/phone_events.go)。
- Chat [会话列表](/Users/cun/work/aitown-chat/service/svc_phone_query/sessions.go)、[消息投影与状态](/Users/cun/work/aitown-chat/service/svc_phone_query/mapper.go)、[时间格式](/Users/cun/work/aitown-chat/components/utils/phone_query.go)、[私聊发送](/Users/cun/work/aitown-chat/service/svc_phone_dm/send.go)。
- Chat [玩家互发增量](/Users/cun/work/aitown-chat/docs/phone-player-dm-client-delta.md)、[自动反应增量](/Users/cun/work/aitown-chat/docs/miniphone-auto-reactions-client-delta.md)、[通知与相册增量](/Users/cun/work/aitown-chat/docs/phone-post-notifications-album-client.md)。
- API [图片上传](/Users/cun/work/aitown-api/docs/openapi/upload_image.yaml)、[读取背景](/Users/cun/work/aitown-api/docs/openapi/world_miniphoneinfo.yaml)、[设置背景](/Users/cun/work/aitown-api/docs/openapi/world_setminiphonebackground.yaml)。
