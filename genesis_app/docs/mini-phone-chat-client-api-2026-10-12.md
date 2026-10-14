# Mini Phone 客户端接口对接稿（Chat 侧）

- 整理日期：2026-10-12。
- 依据：[Mini Phone 技术设计](/Users/cun/Documents/mini-phone-technical-design-2026-10-09.md)，重点为第 2、3、4、7、11 节。
- 范围：客户端直接调用 Chat 的 16 个新增 HTTP 接口，以及 Chat 向客户端发送的实时事件。
- 本次调整：用户确认相册仅提供列表；Home 返回 dms／posts 各自未读数和最近最多 20 条明细，不分页、无世界时钟和总未读数；unread 响应省略 world_id；DM 已读仅传 dm_session_id，服务端标记会话内全部存量消息已读；Post 已读仅传 world_id，标记当前用户在该世界的全部未读通知，两个已读接口成功响应均为 data={}，Post 已读不额外加锁；新增玩家 Post 点赞与取消点赞接口，点赞其他用户的帖子时通知作者，作者通知与已有全玩家通知去重；点赞／取消不做请求幂等校验，不传 client_request_id；Post 详情采用 char_id／char_name／content，返回全部评论，评论项包含 char_id／char_name／content；取消私聊价格预览，发送接口命名为 dm/send，取消发送结果查询接口；dm/send 不提交金额上限，成功 data={}，消息通过 WebSocket 展示；DMSession 响应不提供最新消息 ID 或已读边界；post_id／message_id／dm_session_id 使用 bigint/int64，帖子 author_type 为 tinyint（1 玩家、2 角色），image 为 URL 字符串，精简帖子字段与表设计；PhoneComment 精简角色 ID／评论序号，author_type=1 玩家／2 角色，comment_type=1 评论／2 回复；comment_id／reply_to_comment_id 使用 bigint/int64；PhoneMessage 精简来源关联／气泡下标字段，sender_type 使用 user／char；AlbumAsset 的 asset_id 使用 bigint/int64，响应精简状态／尺寸／人物／来源字段；PostNotification 精简定位与展示字段，actor_type=1 玩家／2 角色；相册合并世界图片资源与发帖图片，角色自动帖先根据正文尝试生图，成功保存后发布图文，失败时发布纯文字；WebSocket 复用 V2，手机业务字段放入 payload；DM 送达仅推送 phone.messages.delivered，客户端收到后展示消息并刷新会话列表和未读；每项 Post 新增通知只推送 phone.post.notification.created，客户端刷新帖子列表与未读。
- 本次补充：不设计多设备同步，移除会话更新与未读更新事件；DM／Post 已读操作不产生推送或已读通知 outbox，客户端在接口成功后主动刷新。
- 状态：**对接草案，Chat 待实现**。技术设计已列明路径和核心行为；本稿补齐字段形状、展示数据、排序和恢复方式，供客户端与 Chat 共同评审。
- 标记：**【补充建议】**表示原技术设计未完整定义的字段或默认值；**【鲁棒性 Rxx】**沿用技术设计中的编号。以下公共数据对象及未在原设计示例中出现的字段均属于本稿补充建议。

## 1. 公共约定

### 1.1 地址与身份

HTTP 前缀：

```text
{chat_base_url}/aitown-chat/api/v1/phone
```

后文路径均相对此前缀。全部接口需要登录，并校验当前用户的世界访问权；私聊进一步校验会话归属。`uid / player_uid`由服务端从登录态取得，客户端不提交该字段指定操作者。

| 请求头／凭据 | 用法 |
|---|---|
| `Authorization` | 沿用已有登录凭据，例如 `Bearer <token>` |
| `Cookie: AIUSS=<session>` | 沿用现有 Cookie 登录方式；Authorization 优先 |
| `Content-Type: application/json` | POST 必填 |
| `x-device-id / x-app-id / x-platform` | 沿用客户端现有公共请求头 |
| `x-app-version / x-app-version-code` | 客户端版本信息 |
| `x-system-language / x-app-timezone` | 系统语言及客户端时区 |

认证方式依据当前 Chat 的 [Auth 中间件](/Users/cun/work/aitown-chat/middleware/auth.go)。普通客户端无需携带服务间 token。

### 1.2 响应包装

HTTP 业务响应沿用 Chat 的 `err_no / err_msg / data`：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

`err_no=0`表示本次接口操作成功；发送成功仅表示已接收消息，不表示 AI 已完成回复。失败时 `err_no`非 0，`err_msg`使用英文。以下各接口的“响应”均指 `data`内部结构；dm/send 成功仅返回 data={}，不提供消息或任务状态供展示。

当前 Chat 常规成功、业务失败和登录失败均通过 HTTP 200 的业务包装返回；未登录错误码为 `10001`。客户端必须同时检查 HTTP／网络结果与 `err_no`，不能仅以 HTTP 200 判断成功。新手机接口具体业务错误码需在实施契约中分配，本稿不编造数字编码。依据：[响应实现](/Users/cun/work/aitown-chat/pkg/base/render.go)、[认证失败实现](/Users/cun/work/aitown-chat/middleware/auth_response.go)。

### 1.3 字段、时间与分页

| 项目 | 对接约定 |
|---|---|
| 64 位业务 ID | `post_id / message_id / dm_session_id / comment_id / asset_id / like_id`使用 bigint/int64；JSON 为 integer（int64），数据库为 BIGINT，均为正整数；reply_to_comment_id 为同型引用字段，可空 |
| 其他业务 ID | `world_id / char_id / event_id`保持字符串，客户端按不透明 ID 保存 |
| `like_id` | bigint/int64；来源为点赞行 id，通知无点赞来源时为 null |
| 金额 | `*_cent`为整数 Gem cent，`100 cent = 1 Gem` |
| 剧情时间 | 统一 `current_time`，例如 `Day 2/10:00`；完整文本由服务端返回 |
| 真实时间 | `created_at / delivered_at / published_at / read_at`；本稿建议使用 RFC3339 UTC，如 `2026-10-12T08:00:00Z` |
| 分页（独立列表） | `pn`从 1 开始；`rn`为每页条数。默认 `pn=1 / rn=10`、上限 100 为本稿补充建议，实施时落实／复用 Chat 公共分页常量 |
| 列表响应 | 统一 `list / total / pn / rn`，空列表返回 `[]` |
| `total` | 当前筛选条件的总数；列表及 total 使用同一读取快照，不承诺不同请求之间数值不变 |

独立列表响应（Home 为固定 20 条未读聚合，见第 4.1 节）：

```json
{
  "list": [],
  "total": 0,
  "pn": 1,
  "rn": 10
}
```

`current_time`不是设备时间。已送达 A／E2 消息和 F 帖子保存校验后的模型时间；世界时间由既有世界状态／通知提供，Home 只查询未读。内容中的剧情时间不随刷新或世界推进改变。DM 以 message_id 排序，Post 以实际发布时间及帖子 ID 排序，不能按剧情时间自行重排。

**【鲁棒性 R25：64 位 ID 精度】** post_id／message_id／dm_session_id／comment_id／asset_id／like_id 及其引用字段（含 reply_to_comment_id）在存储、请求、响应和 WebSocket 中保留完整 int64 精度，不使用 32 位整数或浮点数进行有损转换。客户端使用支持 64 位整数的解析与存储方式；若使用 JavaScript，需采用能保留大整数精度的 JSON 解析方式。

### 1.4 写请求去重

`POST /dm/send`、`POST /post/create`、`POST /comment/create`均携带 `client_request_id`，建议使用 UUID。

同一业务操作发生断网、超时或重试时，使用原 ID 和原请求内容；真正的新操作使用新 ID。同一 ID 对应不同请求内容时，服务端返回幂等冲突。查询不创建写请求幂等记录。点赞／取消点赞不适用本节请求幂等规则，不提交 client_request_id，不保存请求回执或校验请求摘要。

**【鲁棒性 R02：写请求幂等】** 相同写请求不重复扣费、不重复创建内容，也不重复增加通知或触发次数。dm/send、post/create 和 comment/create 重复成功响应均为 data={}，不返回原业务对象、不重复创建展示内容。

## 2. 接口总表

下表 16 个路径与技术设计第 11 节一致；本次按用户要求补充点赞与取消点赞。删除和重生成入口仍见第 11 节的契约缺口。

| 序号 | 方法 | 路径 | 用途 |
|---|---|---|---|
| 1 | GET | `/home` | dms／posts 各自未读数及最近最多 20 条列表 |
| 2 | GET | `/dm_sessions` | 会话列表／未读会话列表 |
| 3 | GET | `/messages` | 会话消息列表 |
| 4 | POST | `/dm/send` | 发送玩家私聊 |
| 5 | POST | `/dm_session/read` | 仅传会话 ID，将该会话全部 DM 标为已读 |
| 6 | GET | `/unread` | DM 与 Post 合计未读数及最新未读内容的作者 |
| 7 | GET | `/post/notifications` | Post 通知／未读列表 |
| 8 | POST | `/post/notifications/read` | 仅传 world_id，将当前用户在该世界的 Post 未读全部标为已读 |
| 9 | GET | `/posts` | 世界 Feed |
| 10 | GET | `/post/detail` | 帖子详情 |
| 11 | POST | `/post/create` | 玩家发帖 |
| 12 | POST | `/post/like` | 当前玩家点赞；其他用户为作者时通知作者 |
| 13 | POST | `/post/unlike` | 取消当前玩家自己的点赞 |
| 14 | GET | `/comments` | 评论／回复列表 |
| 15 | POST | `/comment/create` | 玩家评论／回复 |
| 16 | GET | `/album` | 可访问图片列表 |

## 3. 公共响应对象【补充建议】

### 3.1 PhoneMessage：私聊消息

| 字段 | 类型 | 含义 |
|---|---|---|
| `message_id` | bigint/int64 | 单条消息 ID |
| `world_id` | string | 世界归属 |
| `dm_session_id` | bigint/int64 | 会话归属 |
| `sender_type` | string | `user / char`：用户／角色 |
| `sender_id` | string | user 时为 UID；char 时为角色 ID |
| `type` | string | 本期固定 `text`，用于 WebSocket 消息及列表查询 |
| `content` | string | 文字正文 |
| `current_time` | string | 该条消息保存的剧情时间 |
| `delivered_at` | string | 已进入可见消息列表的真实时间 |
| `client_request_id` | string/null | 玩家写请求 ID；AI 气泡为空 |

消息中不增加 reply_status；phone.reply.updated 仅通知本次发送失败，成功回复通过 phone.messages.delivered 展示。消息按 message_id 去重并升序排列，不返回来源关联或气泡下标。本稿使用 type 表达内容类型，sender_type 区分发送者。

**【用户已确定：消息 ID 排序】** HTTP、Home、会话最近消息和 WebSocket 消息对象均不提供独立消息序号；送达 payload 也不提供批次序号。GET /messages 和 Home 的 DM 明细按 message_id DESC 取最新消息，聊天气泡与推送 messages 数组按 message_id ASC 排列；排序使用完整 int64 数值。已读独立记录在消息表 read_at，不通过消息 ID 推断已读，本次不增加 PhoneMessage 展示字段。

### 3.2 DMSession：私聊会话

| 字段 | 类型 | 含义 |
|---|---|---|
| `dm_session_id` | bigint/int64 | 会话 ID |
| `world_id / char_id` | string | 所属世界及聊天对象 |
| `char_name / char_avatar_url` | string | 会话列表展示信息 |
| `unread_count` | integer | 从消息表实时 COUNT 此会话已送达、sender_type=char 且 read_at IS NULL 的消息；不保存为会话表字段 |
| `last_message` | PhoneMessage/null | 最近一条可见消息，供列表摘要使用 |
| `updated_at` | string | 会话最近变化的真实时间 |

会话由 `world_id + 当前登录 UID + char_id`唯一确定。本稿不增加会话 `version`。用户确认会话响应仅提供展示所需字段，客户端无需接收会话最新消息 ID 或已读边界。会话表不保存 unread_count，响应保留该字段作为实时统计结果；没有未读角色消息时返回 0。

### 3.3 PhonePost：帖子

| 字段 | 类型 | 含义 |
|---|---|---|
| `post_id` | bigint/int64 | 帖子 ID |
| `world_id` | string | 所属世界 |
| `author_type` | tinyint | 1 玩家，2 角色；JSON 为 integer |
| `author_id` | string | 作者 ID：author_type=1 时为 UID，=2 时为角色 ID |
| `author_name / author_avatar_url` | string | 作者展示信息 |
| `text` | string | 帖子正文 |
| `current_time` | string | 保存的剧情时间 |
| `published_at` | string | 实际公开时间 |
| `image` | string | 图片 URL；无配图或角色生图失败时为空字符串 |
| `like_count` | integer | 当前有效点赞数量，包含玩家和角色 |
| `is_liked` | boolean | 当前登录玩家是否已点赞；Feed 与详情均返回 |
| `comment_count` | integer | 评论及回复的总条数 |

PhonePost 用于 Feed 和发帖响应；帖子详情使用第 6.2 节的 PostDetail 展示结构，image 同样为 URL 字符串。角色自动发帖先根据正文调用图片 Prompt，图片成功并保存时发布图文，图片生成失败时发布纯文字（image 为空字符串）。Post 未读以通知明细为单位。

**【用户已确定】** 帖子表仅保存图片 URL，不额外保存发布序号、图片状态、描述、出镜人物或图片资产关联字段。生成状态与图片元数据由生成记录／相册资产维护，不作为 PhonePost 字段。

### 3.4 PhoneComment：扁平评论／回复

| 字段 | 类型 | 含义 |
|---|---|---|
| `comment_id` | bigint/int64 | 评论／回复 ID |
| `post_id` | bigint/int64 | 所属帖子 ID |
| `author_type` | tinyint | 1 玩家，2 角色；JSON 为 integer |
| `author_id` | string | 作者 ID：author_type=1 时为 UID，=2 时为角色 ID |
| `author_name / author_avatar_url` | string | 作者展示信息 |
| `comment_type` | tinyint | 1 评论，2 回复；JSON 为 integer |
| `text` | string | 正文 |
| `reply_to_char_id` | string/null | 被回复角色；F 的角色 ID 引用保存在这里 |
| `reply_to_comment_id` | bigint/int64/null | 可定位的目标评论 ID；F 返回角色引用时允许为空 |
| `current_time / published_at` | string | 剧情时间／真实发布时间 |

回复仍是帖子下的一条扁平记录，不创建嵌套楼层。客户端不能将 `reply_to_char_id`误当成评论 ID。可展示的被回复者名称建议由 Chat 额外提供 `reply_to_name`，其具体字段在 DTO 评审时确认。

PhoneComment 不返回独立角色 ID 或评论顺序号；详情内的 PostDetailComment 展示项仍按第 6.2 节返回 char_id／char_name／content。

### 3.5 AlbumAsset：可展示图片

| 字段 | 类型 | 含义 |
|---|---|---|
| `asset_id` | bigint/int64 | 图片 ID |
| `world_id` | string | 所属世界 |
| `image_url / thumbnail_url` | string/null | 当前用户有权访问的图片／缩略图交付地址 |
| `desc` | string | 保存的原始图片描述 |
| `created_at` | string | 真实创建时间 |

相册列表仅返回已生成完成、当前用户有访问权的图片，不返回状态、尺寸、出镜人物或来源字段。发帖选择使用条目的 image_url，提交为 /post/create 的 image 字符串，由服务端再次校验图片是否可用及访问权限；asset_id 仅用于相册条目标识与去重。角色帖图片各展示入口无水印；其他照片使用 Chat 提供的交付版本，水印样式待产品确认。Post 的 image 与相册使用同一张图片的 URL。

### 3.6 PostNotification：玩家通知

| 字段 | 类型 | 含义 |
|---|---|---|
| `world_id` | string | 所属世界 |
| `event_type` | string | `post / like / comment / reply` |
| `post_id` | bigint/int64 | 通知跳转的帖子 |
| `actor_type` | tinyint | 1 玩家，2 角色；JSON 为 integer |
| `actor_id` | string | 操作者 ID：actor_type=1 时为 UID，=2 时为角色 ID |
| `current_time / published_at` | string | 事实的剧情时间／实际发布时间 |
| `read_at` | string/null | 当前玩家已读时间，空表示未读 |

通知点击后按 post_id 打开帖子详情；可见性及帖子是否存在由详情接口实时校验，失败使用标准错误响应。不复制评论正文，也不提供具体评论／点赞／图片定位信息。

客户端按接口返回的列表展示，刷新时整体替换当前列表或当前页，不依赖通知 ID 合并，也不按 post_id 合并多条通知；同一帖不同新增事实仍各占一条未读。服务端内部继续维护通知与来源事件的唯一性，全部已读仍只提交 world_id。

## 4. Home 与私聊接口

### 4.1 GET /home

返回当前登录玩家在指定世界的未读聚合：`dms`与`posts`各自包含`unread_count`和`list`。

Query 仅`world_id:string`，必填。两组列表均不分页，每组固定取最近最多 20 条；不足 20 条返回实际条数，无未读时返回空数组。客户端不传 pn／rn 或数量参数。

**【用户已确定，2026-10-12】** Home 只返回 dms／posts 各自的未读数和列表，不提供世界时钟／时分字段或跨类型总未读数。下面示例各有 1 条未读：

```json
{
  "dms": {
    "unread_count": 1,
    "list": [
      {
        "message_id": 20002,
        "world_id": "world_1",
        "dm_session_id": 30001,
        "sender_type": "char",
        "sender_id": "char_1",
        "type": "text",
        "content": "我在湖边。",
        "current_time": "Day 2/10:01",
        "delivered_at": "2026-10-12T08:00:05Z",
        "client_request_id": null
      }
    ]
  },
  "posts": {
    "unread_count": 1,
    "list": [
      {
        "world_id": "world_1",
        "event_type": "comment",
        "post_id": 10001,
        "actor_type": 2,
        "actor_id": "char_1",
        "current_time": "Day 2/10:02",
        "published_at": "2026-10-12T08:01:00Z",
        "read_at": null
      }
    ]
  }
}
```

| 响应字段 | 含义 |
|---|---|
| `dms.unread_count` | 从消息表直接 COUNT 当前世界／登录玩家已送达、sender_type=char 且 read_at IS NULL 的全量消息，不受 20 条列表上限影响 |
| `dms.list` | 未读私聊消息明细，元素为 PhoneMessage；已送达、sender_type=char，且消息表 read_at IS NULL；按 message_id DESC 取最近最多 20 条 |
| `posts.unread_count` | 从通知表直接 COUNT 当前世界／登录玩家下 read_at IS NULL 的全量通知，不保存独立计数，不受 20 条列表上限影响 |
| `posts.list` | read_at 为空的 PostNotification；包含新帖、点赞、评论、回复；最近最多 20 条 |

dms.list 是消息明细，不是会话摘要，跨会话统一按 message_id DESC 排序；posts.list 沿用`published_at DESC, 内部通知行 ID DESC`，同一帖子可有多条不同新增事件的通知。条目中的时间属于具体内容事实，不是 Home 的世界时钟。

`unread_count`为各自完整范围的未读数，不受 20 条列表上限影响，不能用 list.length 代替。查看更多私聊时进入`/dm_sessions`的未读会话列表，再按会话查询`/messages`；查看更多 Post 通知时查询`/post/notifications`。这些独立列表接口保留各自的分页约定。

### 4.2 GET /dm_sessions

| Query | 必填 | 说明 |
|---|---|---|
| `world_id` | 是 | 当前世界 |
| `unread_only` | 否 | 本稿建议默认 false；true 只查未读会话 |
| `pn / rn` | 否 | 公共分页 |

响应：`ListResponse<DMSession>`。本稿建议排序为 `updated_at DESC, dm_session_id DESC`，第二项仅作稳定排序。unread_count 是该会话未读角色消息的实时统计值；unread_only=true 时筛选存在未读角色消息的会话，然后计算 total 并分页。total 对应当前筛选的会话数，不等于未读气泡数量。

**【补充建议】首次会话处理**：本稿建议列表只返回已创建会话；选择新的 AI 角色后以 `world_id + char_id`发送，由 Chat 幂等创建／解析唯一会话，会话 ID 从 WebSocket 消息或恢复查询取得，发送响应仅为 data={}。首次发送前显示空消息区；该创建策略需在 Chat 实施前确认，不能假定已实现。

### 4.3 GET /messages

| Query | 必填 | 说明 |
|---|---|---|
| `world_id` | 是 | 当前世界 |
| `dm_session_id` | 是 | bigint/int64，当前玩家的目标会话 |
| `pn / rn` | 否 | 公共分页 |

响应：`ListResponse<PhoneMessage>`。服务端按 `message_id DESC`返回；客户端去重后按 `message_id ASC`显示聊天气泡。刷新首屏读取新消息；新增消息造成分页重复时按 `message_id`去重。

只返回已提交、已送达内容；自动私聊排队中的气泡不可见。查询消息本身不更新已读。

### 4.4 POST /dm/send

请求：

```json
{
  "world_id": "world_1",
  "char_id": "char_1",
  "client_request_id": "8da2f7d4-2f42-4f02-8ad9-3ad1aa710235",
  "content": "你现在在哪里？"
}
```

| Body | 必填 | 说明 |
|---|---|---|
| `world_id / char_id` | 是 | 当前世界与聊天角色 |
| `client_request_id` | 是 | 本次写请求唯一 ID |
| `content` | 是 | 玩家真实输入，仅文字 |

**【用户已确定】** 请求不包含金额上限；成功只返回统一包装，data={}：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

HTTP 成功表示请求已接受，不表示 AI 已回复或完成扣费；不返回消息、会话 ID、job_status 或价格。客户端在发送前保存 client_request_id，收到 phone.messages.delivered 后展示 payload.messages、按 message_id 去重并记录 dm_session_id。A 回复批次通过 payload.client_request_id 关联原发送，收到完整 AI 气泡后标记成功并结束等待；玩家消息批次仅展示用户消息。phone.reply.updated 仅携带失败结果，关联原发送并结束等待。

玩家消息提交后推送所属玩家的消息事件；AI 完整气泡在确认扣费并提交可见消息后推送。玩家消息自身不增加 DM 未读。消息事件可能先于 HTTP 成功响应到达，客户端以已收到的提交消息为准，成功响应不再插入一次消息。HTTP 验证失败仍返回标准错误包装；已接受请求最终失败时，仅通过 phone.reply.updated 通知失败，玩家消息保留。

发送时由 Chat 计算并固定本轮价格与定价快照，无独立价格预览。本期私聊费率为同条件主线价格的 40%；向上取整到 cent 仍为设计建议。后续模型设置变更不影响已接受请求的模型与价格。

**【设计建议】** 同一会话只允许一个未终结的 A 任务；等待完成期间禁止再次发送新业务请求，不同角色会话可并行。是否沿用此限制需在发布前确认。

**【鲁棒性 R04：消息事件恢复】** WebSocket 承载正常消息展示，发送响应不作为展示数据。消息按 message_id 去重并升序排列；断线／丢事件时通过 messages 恢复已提交内容。不以没有收到推送判断发送失败，也不使用新请求 ID 重发。

### 4.5 POST /dm_session/read

请求：

```json
{
  "dm_session_id": 30001
}
```

请求体只有必填的 dm_session_id（bigint/int64）。登录 UID 从认证上下文取得，服务端根据会话记录确定 world_id，校验会话属于当前玩家且仍具有世界访问权。

**【用户已确定，2026-10-12】** 本次操作将该会话下当前所有已提交、已送达的 DM 消息全部标为已读：消息表中空 read_at 设置为本次操作的服务端真实时间，包含玩家与角色消息，已有 read_at 不覆盖。不以客户端当前展示的条数或消息 ID 限制范围；客户端只传 dm_session_id，不传 world_id、消息 ID 或已读时间。

成功响应与 Post 已读接口一致，仅返回统一包装，data 为空；以下为完整 HTTP 响应：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

服务端在消息表记录逐消息 read_at，会话表不保存 unread_count、最新消息 ID 或已读边界。未读数查询直接统计已送达、sender_type=char 且 read_at IS NULL 的消息。本接口不返回会话 ID、世界 ID、更新条数或计数。客户端检查 err_no 判断操作结果，随后查询 Home／unread 和会话列表。

成功后进入统一未读刷新流程，重查 Home／unread 和会话列表，取得并发新消息到来后的最新状态。

## 5. 未读与 Post 通知接口

### 5.1 GET /unread

Query：`world_id:string`，必填；该参数限定查询及权限范围，响应不再重复返回 world_id。

```json
{
  "unread_count": 2,
  "char_id": "char_1"
}
```

**【用户已确定：未读总数】** 响应只包含 unread_count 和最新未读内容作者 char_id，不返回 DM／Post 分项计数或 world_id。unread_count 为 DM 未读消息数与 Post 未读通知数的总和：DM 从消息表直接 COUNT 当前世界／登录玩家已送达、sender_type=char 且 read_at IS NULL 的全量消息；Post 从通知表直接 COUNT 当前世界／登录玩家下 read_at IS NULL 的通知，两个结果相加。两类均不维护独立计数；Home 继续返回 dms／posts 各自的 unread_count 和列表，需要分项展示时查询 Home。查询不改变已读；客户端以发起请求时的账号／世界上下文处理响应。

| 字段 | 类型 | 含义 |
|---|---|---|
| `unread_count` | integer | 当前世界／玩家的全量未读角色 DM 消息数 + 未读 Post 通知数；无未读时为 0 |
| `char_id` | string/null | 跨 DM／Post 最新一条未读内容的作者角色 ID；玩家作者解析其在该世界的角色绑定 |

**【用户已确定：跨 DM／Post 的最新未读作者】** 最新内容从两类未读中共同选取，不限定为 DM，只返回该作者的 char_id。DM 候选按 message_id DESC 取一条，以 delivered_at 作为比较时间；Post 候选按 published_at DESC、内部通知行 id DESC 取一条，以 published_at 作为比较时间。比较两类候选的真实 UTC 时间，取较晚者；时间完全相同时固定优先 DM。DM 作者为 sender_id；Post 新帖作者及点赞／评论／回复操作者由该通知 actor_type／actor_id 取得，互动不返回原帖作者。角色作者直接返回角色 ID，玩家作者解析其在该世界的角色绑定。两类均无未读时 char_id=null；只有 Post 未读时也返回该 Post 通知的作者角色 ID。

DM 按消息表中未读角色气泡的实际行数统计，玩家自己的消息不计未读；会话表不保存计数。Post 按通知表中未读行数统计，每项新增公开事实产生一条通知；不建立独立未读状态表。

### 5.2 GET /post/notifications

| Query | 必填 | 说明 |
|---|---|---|
| `world_id` | 是 | 当前世界 |
| `unread_only` | 否 | 默认 true；false 查询全部通知 |
| `pn / rn` | 否 | 公共分页 |

响应：ListResponse<PostNotification>。按 published_at DESC、内部行 id DESC 排序；刷新时整体替换当前页，不按帖子或字段组合合并通知，各页独立展示，不跨页追加后尝试通知 ID 去重。

`total`为筛选结果总数，仅 unread_only=true 时才对应该次快照中的 Post 未读。列表查询、打开 Feed、打开手机均不自动清零。

### 5.3 POST /post/notifications/read

请求：

```json
{
  "world_id": "world_1"
}
```

请求体只有必填的`world_id`。用户身份从登录态取得，服务端校验当前用户具有该世界访问权。

**【用户已确定，2026-10-12】** 调用成功后，当前用户在该世界的全部 Post 未读通知均变为已读，包括新帖、点赞、评论、回复。范围不受 Home 最近 20 条、通知列表分页或客户端已展示内容限制；不影响其他玩家或其他世界。

成功响应只保留统一包装，data 为空；以下展示完整 HTTP 响应，不返回业务计数：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

客户端检查 err_no 判断本次操作结果，不读取更新条数或剩余未读数。无新增通知时重复请求不重复修改已读状态；如果期间已有新的未读通知，再次调用会将当次全部存量通知标为已读。

**【鲁棒性 R23：不额外加锁的全部已读】** 本接口不使用互斥锁、分布式锁或 SELECT FOR UPDATE。在一个短事务中按 world_id／登录 UID 将 read_at 为空的通知批量设置为本次服务端真实时间，保留已有已读时间，不增减或清零独立计数。已读操作不生成通知 outbox 或 WebSocket 推送。无并发新增时，后续 COUNT 返回 0；并发新增且未被本次更新覆盖的通知保持未读，下一次查询正常计入。未读数量与明细按相同条件在同一只读快照中读取；通知重放不重复插入，也不重置已有 read_at。成功响应不返回计数，客户端重新查询 Home／unread 刷新。

成功后统一刷新：Home 展示中重查`/home`，仅需总角标时查`/unread`；通知列表展示中也重新查询，更新 read_at。GET Home、Feed 或通知列表仍是只读操作；只有显式调用本接口才标记全部 Post 已读。

## 6. Post 与评论接口

### 6.1 GET /posts

Query：`world_id`必填；`pn / rn`可选。

响应：`ListResponse<PhonePost>`。按 published_at DESC、post_id DESC 排序，最新实际发布的帖子在前。生成中／待延迟发布的帖子不返回。

阅读 Feed 不自动确认通知已读。新增点赞、评论、回复可能只更新已有帖子；客户端收到对应事件时刷新相关帖子，不只刷新新帖列表。

### 6.2 GET /post/detail

Query：world_id（string）、post_id（bigint/int64）必填，不接收评论分页参数。

**【用户已确定】** data 直接返回 PostDetail，不嵌套 post 对象。作者使用 char_id／char_name；评论列表不分页，返回全部已发布、当前用户有权查看的评论及回复，空列表为 []。

| 字段 | 类型 | 含义 |
|---|---|---|
| `char_id` | string | 帖子作者在该世界中的角色 ID，包括玩家角色；不使用用户 UID 代替 |
| `char_name` | string | 发帖者的角色名 |
| `content` | string | 帖子内容，由存储的 text 映射 |
| `image` | string | 图片 URL，与 PhonePost 一致；无配图或角色生图失败时为空字符串 |
| `like_count` | integer | 当前有效点赞数，包含玩家与角色 |
| `comment_count` | integer | 全部可见已发布评论及回复的条数，与 comments 长度一致 |
| `is_liked` | boolean | 当前登录用户是否已点赞 |
| `comments` | PostDetailComment[] | 全部评论及回复，按 published_at ASC、内部行 id ASC 排序，不含分页包装 |
| `published_at` | string | 帖子实际发布时间，沿用公共真实时间格式 |

PostDetailComment 的评论元数据：

| 字段 | 类型 | 含义 |
|---|---|---|
| `char_id` | string | 评论者在该世界中的角色 ID，包括玩家角色 |
| `char_name` | string | 评论者的角色名 |
| `content` | string | 评论或回复内容，由存储的 text 映射 |

data 示例：

```json
{
  "char_id": "char_1",
  "char_name": "林舟",
  "content": "今天的湖边很安静。",
  "image": "",
  "like_count": 3,
  "comment_count": 1,
  "is_liked": true,
  "comments": [
    {
      "char_id": "char_2",
      "char_name": "阿澄",
      "content": "我也想去看看。"
    }
  ],
  "published_at": "2026-10-12T08:00:00Z"
}
```

详情不返回点赞者列表或评论的 pn／rn／total／has_more，不只取评论首屏，也不套用 Home 的 20 条限制。世界／帖子 ID 使用请求参数，详情不重复返回；author_type／author_id 仍用于服务端权限与作者通知，不作为详情展示字段。点赞与取消点赞见第 6.4、6.5 节。

**【鲁棒性 R24：详情读取一致性】** 正文、有效点赞数、当前用户点赞状态和全部可见评论在同一只读快照中获取，避免评论数量与列表不一致；char_id 从帖子／评论绑定的角色取得，不能把玩家 UID 或角色名当作角色 ID。

### 6.3 POST /post/create

请求（配图字段使用 image 地址）：

```json
{
  "world_id": "world_1",
  "client_request_id": "post-request-1",
  "content": "今天的湖边很安静。",
  "image": "https://cdn.example.com/phone/images/50001.png"
}
```

| Body | 必填 | 说明 |
|---|---|---|
| `world_id` | 是 | 当前世界 |
| `client_request_id` | 是 | 本次发帖写请求 ID |
| `content` | 是 | string；非空帖子正文，与帖子详情的 content 命名一致 |
| `image` | 否 | string；相册中有权引用的图片 URL，使用条目的 image_url；不配图时省略或传空字符串 |

成功响应使用统一包装，data={}，不返回帖子对象：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

失败返回统一错误包装，err_no 为对应错误码，err_msg 为英文错误说明；客户端按 err_no 判断结果。

玩家发帖实际保存并发布后返回成功空对象；客户端成功后主动刷新帖子列表，收到 phone.post.notification.created 时按既定流程刷新帖子与未读，随后角色公开点赞／评论异步到来。**【用户已确定】** 正文请求字段使用 content；配图直接提交 image URL，不提交图片资产 ID，未提供 image 时统一按空字符串保存。玩家从相册选图后将 image_url 作为 image 提交，服务端根据地址校验对应图片是否已就绪及当前玩家是否有引用权限，将校验后的 URL 保存到帖子 image；本接口不提交生图描述或发起新生图。T2 不直接触发角色私聊。

### 6.4 POST /post/like

将当前登录玩家对指定帖子的点赞状态设为已点赞。请求：

```json
{
  "world_id": "world_1",
  "post_id": 10001
}
```

world_id、post_id 均必填，不传 client_request_id、不做请求幂等性校验。操作者固定为登录玩家，客户端不传 actor_id／char_id／作者 UID。Chat 校验帖子已发布、属于指定世界且当前玩家有访问权；玩家可点赞玩家帖和角色帖，只能操作自己的点赞。

成功响应使用统一包装，data={}：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

实际从未点赞变为已点赞时新增一次点赞事实；已经点赞时成功返回，不重复增加点赞数或通知。成功后客户端刷新 post/detail 或对应 Feed 条目，取得权威 like_count／is_liked。

**【用户已确定】** 作者为其他用户时，需要向作者发送点赞通知：author_type=1（玩家）且 author_id 不等于当前 UID。复用 event_type=like 的持久 Post 通知及个人实时事件，离线作者也能在通知列表中查到。沿用此前确定的同世界全玩家通知口径，作者作为其中一位接收者只得到一条通知及一次未读增量，不再叠加第二条“作者通知”；接收与查询仍遵守世界访问权限。

**【补充建议】** 允许玩家点赞自己的帖子；此时不额外建立作者提醒，通用全玩家通知仍按既有规则分发。角色作者没有玩家 UID，不创建独立的用户作者提醒。点赞不触发 T2／T3 或角色模型反应。

### 6.5 POST /post/unlike

取消当前登录玩家自己的点赞。请求仅包含 world_id、post_id，均必填；不做请求幂等性校验：

```json
{
  "world_id": "world_1",
  "post_id": 10001
}
```

成功响应与点赞、两个已读接口一致：err_no=0、err_msg=succ、data={}。重复取消或本来未点赞均成功返回；不删除其他玩家或角色的点赞。成功后刷新帖子，读取最新 like_count／is_liked。

**【用户已确定：取消点赞不推送】** 取消仅改变当前点赞状态，不发送作者提醒或 WebSocket 事件，不创建新的 Post 通知或通知 outbox，不增加未读；此前已发送的点赞通知保留为历史事实，也不扣减已有未读。操作方在接口成功后主动刷新帖子；其他玩家在下次查询或刷新时取得最新点赞数。取消后再次调用点赞，实际恢复点赞时再产生一次点赞通知。

**【鲁棒性 R24：点赞状态与通知一致性】** 每次请求按执行时的当前状态处理：已点赞时再次点赞、未点赞时再次取消均成功返回，不重复增加点赞数或通知。状态切换与 history 同事务提交，仅新增／恢复点赞保存通知 outbox；作者通知与全玩家通知按同一来源事件去重。客户端同一帖的点赞／取消串行发送，超时后先查询帖子当前状态，再根据最新操作意图决定是否发送；取消后再次收到点赞请求会重新点赞，不识别它是否为旧请求重试。

### 6.6 GET /comments

Query：`world_id / post_id`必填；`pn / rn`可选。

响应：`ListResponse<PhoneComment>`。按 published_at ASC、内部行 id ASC 稳定排序，客户端保留服务端顺序并按 comment_id 去重。评论与回复均在同一列表，total 包含两者。

Post 通知仅定位帖子。需要对特定评论进行回复等操作时，从独立 comments 接口取得 comment_id；不可用目标由业务接口实时校验。

### 6.7 POST /comment/create

请求【补充建议】：

```json
{
  "world_id": "world_1",
  "post_id": 10001,
  "client_request_id": "comment-request-1",
  "content": "你看到什么了吗？",
  "reply_to_comment_id": null
}
```

| Body | 必填 | 说明 |
|---|---|---|
| `world_id / post_id` | 是 | 当前世界（string）及帖子（bigint/int64） |
| `client_request_id` | 是 | 本次评论写请求 ID |
| `content` | 是 | string；非空评论／回复正文，与帖子详情中的评论正文命名一致 |
| `reply_to_comment_id` | 否 | bigint/int64/null；为空为普通评论，非空为回复既有评论，由 Chat 校验其属于同一帖 |

成功响应使用统一包装，data={}，不返回评论对象：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

失败返回统一错误包装，err_no 为对应错误码，err_msg 为英文错误说明；客户端按 err_no 判断结果。类型及回复对象由 Chat 根据引用确定，客户端不提交 F 模型使用的 reply_to 角色引用。

评论／回复实际保存后返回成功；客户端成功后主动查询帖子详情或评论列表，收到 phone.post.notification.created 后按既定流程刷新帖子与未读。

保存评论成功不保证会生成 AI 反应。角色帖下，第一次成功评论触发公开回复；第二次另外触发作者私聊；第三次以后仍正常保存和通知，模型反应按技术设计不再触发。第二次私聊按本次评论真实提交时间 +2 分钟调度，客户端等待已送达事件／消息查询，不自行构造气泡。回复是否计入 T3 次数仍按原设计建议，见契约缺口。

## 7. 相册接口

### 7.1 GET /album

**【用户已确定：相册来源】** GET /album 合并以下两个来源，不新增客户端来源字段或筛选参数：

| 来源 | 内容 |
|---|---|
| 1 世界图片资源 | 当前 world 的角色头像、开场图片等已有图片资源 |
| 2 发帖图片 | 角色自动发帖生成的图片，以及用户已发布帖子使用的图片 |

用户发帖继续使用相册选图；复用已有图片不生成新图，两个来源集合引用同一 asset_id 时列表只返回一次。角色自动帖的准备图片在帖子发布前不进入相册。世界资源图片按世界访问权限展示，发帖图片按帖子／资源可见性展示。来源分类用于服务端取数，AlbumAsset 的返回字段保持第 3.5 节定义。

Query：`world_id`必填；`pn / rn`可选。

响应：`ListResponse<AlbumAsset>`。返回当前用户有访问权且 ready 的图片，按 `created_at DESC, asset_id DESC`稳定排序为本稿建议。列表条目提供 asset_id、world_id、图片地址、缩略图地址、描述与创建时间；客户端查看图片直接使用已取得的条目。

发帖选择条目的 image_url，作为 /post/create 的 image 提交，不提交 asset_id。是否允许引用仍由 /post/create 再次校验；客户端已有图片缓存不能替代实时权限检查。图片地址失效时重新查询相册列表，按 asset_id 更新对应条目的地址；地址有效期仍需在图片交付契约中确认。

## 8. Chat 实时事件【补充建议】

### 8.1 连接与事件形状

沿用现有 Chat WebSocket 建联：

```text
wss://{chat_host}/aitown-chat/ws?world_id=world_1
```

本稿增加的是手机事件，不新增手机 WS 建联接口。依据：[Chat Connect](/Users/cun/work/aitown-chat/controllers/http/ctr_ws/ws_handler.go)、[现有 V2 对象](/Users/cun/work/aitown-chat/components/dto/chat_message.go)。沿用现有连接管理，不设计多设备连接或已读同步；已读接口成功后由当前客户端主动刷新。

**【用户已确定】** 复用 Chat 现有 V2 的 dto.ChatMessage，不为手机新增独立消息封装。外层沿用 type、stream_type、ts、world_id（标准路由上下文）、trigger_uid、err_no、err_msg；全部手机业务字段放入 payload。非流式手机事件的 stream_type 为空字符串，无适用触发用户时 trigger_uid 为空字符串。其他 V2 可选元数据沿用既有规则，不将手机 message_id、post_id、dm_session_id、任务状态或通知内容提升到外层。

```json
{
  "type": "phone.messages.delivered",
  "stream_type": "",
  "ts": 1791782400000,
  "world_id": "world_1",
  "trigger_uid": "",
  "payload": {
    "event_id": "event_1",
    "dm_session_id": 30001,
    "client_request_id": null,
    "messages": [
      {
        "message_id": 20002,
        "world_id": "world_1",
        "dm_session_id": 30001,
        "sender_type": "char",
        "sender_id": "char_1",
        "type": "text",
        "content": "我在湖边。",
        "current_time": "Day 2/10:01",
        "delivered_at": "2026-10-12T08:00:05Z",
        "client_request_id": null
      }
    ]
  },
  "err_no": 0,
  "err_msg": ""
}
```

`ts`为真实时间的毫秒 Unix 时间戳；`event_id`在 payload 中，表示当前通知事件，用于去重。通用 WebSocket event_id 仅用于传输事件去重，不属于 PostNotification 展示对象。个人通知事件触发列表刷新，客户端不将推送次数当作新增通知数量。

事件 payload 结构均为本稿补充建议；事件名及定位要求来自技术设计。DM 的 phone.messages.delivered 携带完整消息供客户端直接展示；其他事件提供状态变化或定位信息。HTTP 查询用于首次加载和断线／漏事件后的恢复。

### 8.2 WebSocket V2 事件清单

下表的业务字段均位于 V2 payload，表中的 type 位于 V2 外层。复用标准 world_id 路由上下文；payload.event_id 为传输事件去重标识，既有 PostNotification 对象不包含该字段。所有事件中的 post_id、message_id、dm_session_id、comment_id、asset_id、like_id 及 reply_to_comment_id 均使用 bigint/int64（JSON integer），其余 ID 按第 1.3 节。

| type | payload 业务字段建议 | 投递范围 | 客户端处理 |
|---|---|---|---|
| `phone.reply.updated` | `dm_session_id, message_id, client_request_id, job_status=failed, failure`；message_id 为玩家触发消息 | 所属玩家 | 仅最终失败时推送；显示失败原因、结束等待并保留玩家消息 |
| `phone.messages.delivered` | `dm_session_id, messages: PhoneMessage[], client_request_id?`；A 批次关联原请求，自动私聊请求 ID 为空 | 所属玩家 | 直接展示完整消息，按 message_id 去重并升序排列；刷新会话列表及聚合未读 |
| `phone.post.notification.created` | PostNotification 展示字段放入 payload，world_id 同时沿用 V2 路由上下文；payload.event_id 仅作传输去重 | 该条通知所属玩家 | 刷新帖子列表和 home／unread；通知页或对应详情打开时同步刷新，不按推送次数追加通知或累加未读 |

**【用户已确定：复用世界展示能力】** 世界时间和角色位置的更新沿用现有接口与通知机制，不纳入本次新增手机事件；无需另行定义事件名称、payload 或转发流程。

**【用户已确定：DM 送达单事件】** 一次提交并送达的 DM 消息批次只生成一条 phone.messages.delivered，包含本批全部 messages；不按气泡拆成多个事件，也不另发会话或未读更新事件。向所属玩家的现有在线连接投递该批次事件；客户端展示消息后，合并刷新 GET /dm_sessions 与 GET /home（仅角标可用 GET /unread）。未读仍以查询结果为准，不按收到事件的次数本地累加。

此规则用于玩家消息提交、A 回复气泡送达以及 E2 自动私聊。phone.reply.updated 仅用于 A 最终失败通知，成功时只通过 phone.messages.delivered 展示；已读操作不推送，当前客户端在接口成功后主动刷新，Post 新增内容由单条个人通知承担刷新。重连／投递重试时按事件和消息 ID 去重。

**【用户已确定：Post 新增通知单事件】** 每项新帖、点赞、评论或回复向每位接收者只推送一条 phone.post.notification.created。该玩家的通知明细与个人通知 outbox 提交后发送，不写入未读计数；客户端收到即刷新 GET /posts 与 GET /home（仅角标可用 GET /unread）；通知列表或对应帖子详情正在展示时一并刷新。新增通知不额外发送未读更新事件，也不另发公开的新帖／评论／点赞广播。回复以 payload.event_type=reply 表达，不重复算作普通评论。

取消点赞不发送事件、不新增通知或未读，操作方在接口成功后主动刷新帖子；DM／Post 已读操作不发送状态事件，客户端在成功后主动查询刷新。离线玩家通知仍入库，重连通过 HTTP 查询恢复；客户端不根据推送次数累加未读。

phone.messages.delivered 的 messages 为完整 PhoneMessage 对象，包含消息 ID、正文、发送者（sender_type=user／char）、时间和 client_request_id 等字段；玩家消息提交和 AI 气泡完成提交分别发送事件，AI 气泡按本次完整批次推送。客户端用批次 client_request_id 关联原发送、按 message_id 去重并升序排列；A 的 AI 回复批次直接确认本次回复成功，无需额外完成通知。

**【用户已确定：仅失败推送】** phone.reply.updated 只在 A 任务进入最终 failed 时生成，payload.job_status 固定为 failed，failure 必填并提供英文原因（{message:string}）。排队、生成中、等待结算、取消处理中和完成状态仅由服务端内部维护，不发送这些状态事件；成功通过 phone.messages.delivered 展示，不附带扣费明细或位置结果。角色主动 DM 不发送 phone.reply.updated。

**【用户已确定：已读无需推送】** 本期不设计多设备同步，不提供会话更新或未读更新事件，也不保存已读变化通知 outbox。DM 已读成功后查询会话列表及 Home／unread；Post 已读成功后查询 Home／unread，通知列表展示中也重新查询。未读不使用 unread_version／会话 version，不根据事件次数推算计数。回复由 phone.post.notification.created 的 event_type=reply 表达，不再同时新增一次 comment 计数。

手机投递须以世界／玩家范围为准，DM 不能广播给其他玩家；手机事件不能要求玩家停留在某个主线地点才可接收。Post 新增内容仅通过个人通知触发帖子与未读刷新；多个通知到达时客户端合并刷新请求。

## 9. 客户端推荐对接顺序

### 9.1 打开手机与私聊发送

1. 查询 home，展示 dms／posts 各自未读数和最近最多 20 条明细；仅显示总角标时可查询 unread。
2. 打开 DM 列表，查询 dm_sessions；打开已有会话，查询 messages。
3. 输入完成后保存新 client_request_id 并调用 dm/send，仅提交世界、角色、请求 ID 和内容；成功响应 data={}。
4. 收到唯一的 phone.messages.delivered 送达事件时，使用 messages 展示消息、按消息 ID 去重并保存会话 ID；合并刷新 dm_sessions 及 home／unread，不等待其他会话或未读推送。发送响应不创建展示消息。
5. 收到 A 的 AI 回复批次后结束等待；收到 phone.reply.updated 则标记原发送失败并展示原因。恢复网络时通过 messages 查回已提交内容。
6. 需要将会话全部标为已读时，仅携带 dm_session_id 调 dm_session/read；成功后刷新聚合未读和会话列表。

首次选择尚无会话的角色按第 4.2 节建议处理。WebSocket 不可用时重建连接；消息查询只用于恢复已提交内容，不轮询任务结果，也不根据等待时间自动重发新业务。

### 9.2 Post、通知与评论

1. 打开 Feed 调 posts；查看帖子调 post/detail，一次取得全部展示评论。需要 comment_id 等额外业务元数据时，使用独立 comments 接口。
2. Home 的 posts.list 展示最近最多 20 条未读通知；查看更多或查询全部通知时调 post/notifications，默认 unread_only=true。
3. 通知跳转按 post_id 打开帖子详情；需要将当前世界的 Post 未读全部标为已读时，仅传 world_id 调 post/notifications/read。
4. 玩家发帖前从 album 选择可用图片，将 image_url 作为 image、正文作为 content，以新 client_request_id 调 post/create；纯文字帖子省略 image 或传空字符串。成功 data={} 后主动刷新帖子列表，失败按 err_no 展示错误。
5. 玩家评论／回复以新 client_request_id 和 content 调 comment/create；成功 data={} 后主动刷新帖子详情或评论列表，失败按 err_no 展示错误；随后等待公开互动及已送达私聊事件。
6. 点赞调用 post/like，取消调用 post/unlike；仅传 world_id／post_id，不传请求幂等键，成功后刷新帖子状态。
7. 收到 phone.post.notification.created 后，合并刷新 posts 及 home／unread；相关详情或通知页展示时同步刷新。已读接口成功后主动刷新未读及当前通知列表；取消点赞在 HTTP 成功后主动刷新帖子，不等待推送。

读取 Feed／帖子不自动清除未读；全部已读由 post/notifications/read 的显式调用完成，不需要取得通知 ID。通知与列表可能在分发后才出现；技术设计允许内容已发布到某玩家通知入库之间存在短暂延迟。

## 10. 客户端鲁棒性要求（单独标注）

| 编号 | 要求 |
|---|---|
| R02 | 网络重试沿用原 client_request_id 和内容；收到重复响应按业务 ID 合并，不重复插入气泡／帖子／评论 |
| R04 | 发送超时或断线后，用消息列表恢复已提交内容；A 任务继续执行，未收到回复不等于失败 |
| R21 | 不用设备时间覆盖 current_time，不用剧情时间计算现实延迟，不根据剧情时间重排消息／Feed |
| R22 | Post 每项新增事实通知同世界全部玩家，包含离线玩家与操作发起者；收到 WS 不是已读确认，发起者也通过仅传 world_id 的全部已读接口处理自己的通知 |
| R22 | Post 新增内容只发个人通知，重复／乱序按传输事件 ID 去重并合并帖子和未读查询；通知明细与投递 outbox 同事务提交，重放不重置 read_at，不按推送次数累加角标 |
| R23 | Post 全部已读仅传 world_id，不额外加锁；只更新空 read_at、保留已读时间，无计数增减；直接 COUNT 未读通知，计数／明细同条件同快照，保留并发新增未读 |
| R24 | 点赞／取消无请求幂等校验，按当前状态执行；同一帖串行发送，超时先查当前状态；状态与 history 同事务，仅点赞保存通知 outbox，取消无推送；作者通知与全玩家通知不重复 |
| R25 | 六类 bigint/int64 ID 及引用字段保持 64 位精度，HTTP／WebSocket／存储类型一致 |
| R26 | 相册合并两类来源，按 asset_id 去重，来源权限由服务端校验，准备图片不提前展示 |

Post：新帖、一次新增点赞、一条评论、一条回复分别各增加 1 条；回复不再按评论重复计数。角色自动帖的文字与图片同时发布，合计一次新帖通知，不另计图片未读；生图失败仍发布纯文字，正常产生一次新帖通知与未读增量。新加入世界的历史补发口径仍见技术设计建议。

Home、DM／Post 已读成功及实时事件触发客户端查询刷新未读展示。

## 11. 联调前需确认的契约缺口

本稿可用于客户端开发讨论；以下条目尚不能当成已发布契约。

| 项目 | 当前状态／需确认内容 |
|---|---|
| 字段形状 | 本稿为公共响应对象、Home 未读明细、WS payload 补齐了一版建议；post/create 和 comment/create 正文使用 content、成功 data={}、失败标准错误码已由用户确定，Chat 须据此确认 DTO 与 OpenAPI |
| Home | dms／posts 各自 unread_count／list、每组最多 20 条、不分页及取消世界时钟／总未读数已由用户确认；DM 按 message_id DESC 取最近消息，其他列表条目字段为本稿补充建议 |
| 首次 DM 会话 | 建议由 send 幂等创建，需确认；原设计没有独立“创建／打开会话”接口 |
| 消息／文本限制 | 私聊、玩家帖子、玩家评论的字符限制、空白规范和提交频率未给出；不能将 AI 生成目标长度直接套给玩家输入 |
| 分页 | 原设计规定 pn／rn，但本地 Chat 暂未找到通用 DefaultPageSize／MaxPageSize 常量；10／100 需落实到公共契约。会话、Feed、评论、相册排序为本稿补充建议 |
| 私聊费用 | 40% 已确定；cent 向上取整仍为建议。发送忙、余额不足、幂等冲突等业务错误码须分配 |
| DM 未读单位 | 本稿沿用原设计建议的 AI 气泡数，需最终确认；Post 每项新增事实计 1 已确定 |
| 评论／回复定位 | 详情内评论按用户要求只返回 char_id／char_name／content，没有 comment_id；需要指定评论定位或 UI 回复目标时，沿用独立 comments 接口取得业务元数据，精确定位体验仍需确认 |
| T3 回复计数 | 玩家扁平回复是否算成功评论次数仍是技术设计建议；实际第二次评论私聊由服务端执行 |
| 删除／重生成 | 原设计第 11 节未列客户端对应入口；需要时另补契约，不能套用主线操作 |
| 图片 | 地址有效期、水印样式及长列表选择策略待确认；AlbumAsset 不返回来源信息，没有独立上传／生图客户端入口 |
| Post 与生图计费 | 原技术设计仍待定义，接口成功不能被客户端理解为已确认免费，也不按私聊 40% 显示费用 |
| WS | 新事件 payload 为建议；连接管理沿用现有行为，本期不扩展多设备同步 |

## 12. 验收清单

- 16 个 HTTP 路径均挂登录校验，并校验 world_id 与业务对象归属。
- PostNotification 仅返回 world_id、event_type、post_id、actor_type、actor_id、current_time、published_at、read_at；Home、通知列表及个人通知推送的展示对象一致，点击进入帖子，刷新整体替换列表，同帖多条通知不合并。
- AlbumAsset 只返回 asset_id（bigint/int64）、world_id、image_url、thumbnail_url、desc、created_at；asset_id 用于相册条目标识，选图发帖提交 image_url 对应的 image 字符串，不提交资产 ID；不返回状态、尺寸、出镜人物或来源字段。验证图文及纯文字发帖、配图引用权限与相同请求去重，帖子 image 与已校验 URL 一致。
- PhoneMessage 的 sender_type 仅为 user／char；消息列表、Home、last_message 和 WebSocket 消息对象均不包含来源关联及气泡下标字段，按 message_id 展示，A 批次按 client_request_id 关联原请求。
- PhoneComment 与评论表不包含独立角色 ID／评论顺序号；author_type 为 1 玩家／2 角色、comment_type 为 1 评论／2 回复；评论及详情按发布时间／内部行 ID 稳定排序，详情展示评论的 char_id 按原契约保留。
- post_id／message_id／dm_session_id 及引用字段为 bigint/int64；PhonePost author_type=1 玩家／2 角色，image 为 URL 字符串；帖子表不保存已删除的发布序号与图片元数据字段，Feed 按 published_at／post_id 排序。
- send／post/create／comment/create 重试复用原业务，成功均为 data={}，不返回原业务对象。post/create 和 comment/create 正文为 content，失败返回标准错误码，客户端成功后查询刷新帖子／评论；不同内容复用 ID 返回冲突。点赞／取消不传 client_request_id、不做请求幂等校验；相同状态操作不产生新事件，取消后再到达的点赞请求按当前状态恢复点赞。
- 点赞其他用户的帖子时，作者在线／离线均收到一条持久通知、一次未读增量，与全玩家通知不重复；取消无 WebSocket 推送或通知 outbox，不产生新通知或修改已有通知未读，操作方成功后主动刷新，其他玩家下次查询取得最新状态。Feed／详情的 like_count、is_liked 与后台有效点赞状态一致；详情不返回点赞者名单。
- Post 详情直接返回 char_id、char_name、content、image、like_count、comment_count、is_liked、comments、published_at；评论项包含 char_id、char_name、content，返回全部可见评论及回复、不分页，comment_count 与数组长度一致。
- dm/send 请求无金额上限、成功 data={}；玩家消息及 AI 气泡通过 WebSocket 的完整 messages 展示，事件先于 HTTP 响应也不重复插入。phone.reply.updated 仅最终失败时推送，成功不另推完成状态；断线通过消息列表恢复已提交内容，无发送结果查询或轮询接口。内部 result_ready 不提前暴露气泡，completed 才交付完整回复；Chat 在发送时固定价格。
- Home 仅返回 dms／posts 各自 unread_count／list；每组最多 20 条且不分页，未读数为全量；unread 只返回两类未读之和 unread_count 及跨 DM／Post 最新未读内容的作者 char_id，不返回分项计数。DM 直接统计未读角色消息，Post 直接统计 read_at IS NULL 的通知；数据库不保存独立未读计数。验证仅 DM、仅 Post、两类都有及全无未读的合计和作者选择、时间并列及玩家角色绑定，内部 COUNT 与作者候选同快照；无未读时 unread_count=0、char_id=null。独立列表按约定分页、排序和业务 ID 去重。
- 每批 DM 送达只推 phone.messages.delivered，多个气泡在 messages 中整批返回；送达 outbox 不生成会话更新／未读更新事件，客户端收到后刷新会话列表及未读。
- DM 已读请求只有 dm_session_id，由服务端将当前会话全部玩家与角色消息的空 read_at 设置为操作时间，保留已有已读时间；会话不保存未读计数、最新消息 ID 或已读边界，未读直接 COUNT read_at IS NULL 的已送达角色消息。DMSession.unread_count 和 Home.dms.unread_count 为实时统计结果，DM 未读同时计入 unread.unread_count 总数；计数与明细使用同一读取快照，未读会话筛选先于分页。Post 已读请求只有 world_id，标记当前用户在该世界的全部未读通知。两个已读操作均无推送或已读通知 outbox，接口成功后客户端主动查询刷新。GET 不自动已读，两类已读提交后新到的内容仍正常计未读。
- 每项 Post 新增事实每位接收者仅一条 phone.post.notification.created，无额外公开事件或未读更新事件；收到后刷新帖子列表与未读。Post 新帖、点赞、评论、回复均通知同世界所有玩家；新增事实与未读分发延迟按服务器真实状态显示。
- WS 不携带未读计数，客户端收到对应事件后查询刷新。
- 内容时间统一 current_time；角色自动帖先按正文尝试生图，成功时发布图文、失败时发布纯文字；两种情况均正常新帖通知、消耗发帖配额并启动公开互动。相册同时包含世界图片资源及已发布的角色／用户帖图片。
