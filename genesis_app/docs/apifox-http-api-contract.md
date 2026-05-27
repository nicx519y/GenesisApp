# Apifox HTTP 接口文档与当前实现差异

来源：
- Apifox 分享页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/460308499e0
- Apifox world tick 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462798656e0
- Apifox discuss 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462474822e0
- Apifox direct_message 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462474827e0
- Apifox upload 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463764231e0
- Apifox LLM 索引：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/llms.txt

提取时间：2026-05-27

本文档记录 Flutter 项目当前对齐或待替换的 Apifox HTTP 接口，并对比当前 Flutter 项目中的 `lib/network` HTTP 设计。字段后带 `*` 表示 Apifox 标记为必填。

## 总览

本文档当前覆盖 27 个接口，分为 `用户`、`origin`、`world`、`discuss`、`direct_message` 和 `upload` 六组：

| 分组 | 方法 | 路径 | 名称 |
| --- | --- | --- | --- |
| 用户 | POST | `/api/v1/user/oauth/google` | Google login |
| 用户 | POST | `/api/v1/user/logout` | Logout current session |
| 用户 | POST | `/api/v1/user/unfollow` | Unfollow a user |
| 用户 | POST | `/api/v1/user/follow` | Follow a user |
| 用户 | GET | `/api/v1/user/following` | 用户关注列表 |
| 用户 | GET | `/api/v1/user/followers` | 用户粉丝列表 |
| 用户 | GET | `/api/v1/user/info` | user Info |
| 用户 | POST | `/api/v1/user/oauth/apple` | Apple login |
| world | GET | `/api/v1/world/list` | World 列表 |
| world | GET | `/api/v1/world/detail` | World 详情 |
| world | POST | `/api/v1/world/tick` | world owner 触发一次 tick |
| origin | GET | `/api/v1/origin/list` | Origin 模板列表 |
| origin | GET | `/api/v1/origin/detail` | Origin 模板详情 |
| discuss | GET | `/api/v1/discuss/list` | 顶级评论分页列表 |
| discuss | POST | `/api/v1/discuss/post` | 发表评论或回复 |
| discuss | POST | `/api/v1/discuss/delete` | 删除自己的评论或回复 |
| discuss | POST | `/api/v1/discuss/like` | 点赞评论或回复 |
| discuss | POST | `/api/v1/discuss/unlike` | 取消点赞 |
| direct_message | POST | `/api/v1/direct_message/send` | 给指定用户发送私信 |
| direct_message | GET | `/api/v1/direct_message/conversations` | 拉取我的会话列表 |
| direct_message | GET | `/api/v1/direct_message/list` | 拉取与指定用户的消息列表 |
| direct_message | POST | `/api/v1/direct_message/read` | 把与某 peer 的会话标记为已读 |
| direct_message | GET | `/api/v1/direct_message/unread` | 获取我的私信未读总数 |
| direct_message | POST | `/api/v1/direct_message/block` | 拉黑指定用户 |
| direct_message | POST | `/api/v1/direct_message/unblock` | 取消拉黑 |
| direct_message | GET | `/api/v1/direct_message/blocks` | 拉取我的拉黑列表 |
| upload | POST | `/api/v1/upload/image` | 上传图片到阿里云 OSS |

所有 Apifox 200 响应都使用 envelope：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

## 共享模型

### UserInfo

- `uid*`: string
- `name*`: string
- `avatar*`: string
- `bio*`: string
- `last_login_at*`: string
- `create_at*`: string
- `follower_cnt*`: integer
- `following_cnt*`: integer
- `friend_cnt*`: integer
- `create_origin_cnt*`: integer
- `launch_world_cnt*`: integer
- `join_world_cnt*`: integer

### UserRelation

- `is_self*`: boolean
- `is_followed*`: boolean
- `followed_me*`: boolean
- `is_friend*`: boolean

### DirectMessage

- `msg_id*`: string
- `conv_id*`: string
- `sender_uid*`: string
- `receiver_uid*`: string
- `content*`: string，非空且长度不超过 1000 字符
- `created_at*`: string，示例 `2026-05-23 12:34:56`

### DirectMessageConversation

- `conv_id*`: string
- `peer*`: UserInfo，对话中的另一方
- `last_message*`: string
- `last_message_at*`: string
- `last_sender_uid*`: string
- `unread_cnt*`: integer，当前用户视角下该会话未读数
- `is_friend*`: boolean
- `i_blocked_peer*`: boolean，当前用户是否已拉黑 peer
- `peer_blocked_me*`: boolean，peer 是否已拉黑当前用户
- `can_send_next_message*`: boolean，是否允许当前用户继续发送下一条私信

### OriginInfo

- `origin_id*`: string
- `origin_name*`: string
- `origin_version*`: string
- `origin_version_time`: integer
- `brief`: string
- `setting`: string
- `events`: string[]
- `tags`: string[]
- `created_at`: integer，Unix 秒
- `started_at`: integer，Unix 秒
- `tick_duration_days`: integer
- `cover`: string
- `map_url`: string
- `status*`: integer，`10` 正常，`20` tick 中

### OriginStats

- `copy_cnt`: integer
- `discuss_cnt`: integer
- `character_cnt`: integer
- `connect_cnt`: integer
- `location_cnt`: integer
- `tick_cnt`: integer

### WorldInfo

- `world_id*`: string
- `world_name*`: string
- `origin_id`: string
- `origin_version`: string
- `origin_version_time`: string
- `brief`: string
- `setting`: string
- `events`: string[]
- `tags`: string[]
- `created_at`: integer，Unix 秒
- `started_at`: integer，Unix 秒
- `tick_duration_days`: integer
- `cover`: string
- `map_url`: string
- `status*`: integer，`10` 正常，`20` tick 中

### WorldStats

- `character_cnt`: integer
- `connect_cnt`: integer
- `location_cnt`: integer
- `tick_cnt`: integer
- `player_cnt`: integer

### Character

- `char_id*`: string
- `type*`: string，`npc` 或 `player`
- `player_uid`: string，`type=player` 时存在；origin 模板中为空
- `name*`: string
- `identity`: string
- `brief`: string
- `description`: string
- `goal`: string
- `avatar`: string
- `initial_location_id`: string
- `location_id`: string，当前 location
- `metric_value`: integer

### Location

- `location_id*`: string
- `location_pid`: string
- `location_name*`: string
- `location_summary`: string
- `image`: string
- `x_percent`: integer
- `y_percent`: integer
- `map_url`: string，当前 location 的地图图片 URL
- `initial_dialogue`: `DialogueLine[]`

### Tick

- `tick_no`: integer
- `narrator*`: string
- `created_at`: integer，Unix 秒
- `paragraphs*`: `TickParagraph[]`

`TickParagraph`：

- `location_id*`: string
- `timestamp`: string
- `text*`: string
- `character_deltas`: `{ char_id, name, delta }[]`

### DiscussItem

- `discuss_id`: string
- `biz_type`: integer，当前支持 `1` 表示 origin
- `biz_id`: string
- `author`: `UserInfo`
- `content`: string
- `images`: string[]，最多 9 张
- `root_discuss_id`: string，顶级评论为空字符串
- `parent_discuss_id`: string，直接回复目标；顶级评论为空字符串
- `reply_to_uid`: string
- `level`: integer，`1` 顶级评论，`2` 回复
- `reply_cnt`: integer
- `like_cnt`: integer
- `is_liked`: boolean，未登录或未点赞时为 `false`
- `created_at`: string

### UploadImageResult

- `url*`: string，对外可访问图片 URL
- `object_key*`: string，OSS object key，形如 `uploads/20260526/1234567890.jpg`

## 用户接口

### POST `/api/v1/user/oauth/google`

Google 登录。Apifox 未声明鉴权要求。

请求 body：

- `id_token*`: string
- `nonce`: string
- `name`: string，新用户创建时的昵称提示
- `avatar`: string，新用户创建时的头像提示

响应 `data`：

- `token*`: string，session id，同时会通过 `gotea_session` cookie 下发
- `user*`: `UserInfo`
- `relation*`: `UserRelation`

### POST `/api/v1/user/oauth/apple`

Apple 登录。请求和响应结构与 Google 登录一致。

请求 body：

- `id_token*`: string
- `nonce`: string
- `name`: string，新用户创建时的昵称提示
- `avatar`: string，新用户创建时的头像提示

响应 `data`：

- `token*`: string
- `user*`: `UserInfo`
- `relation*`: `UserRelation`

### POST `/api/v1/user/logout`

退出当前 session。

请求 body：无。

响应 `data`：空对象。

### GET `/api/v1/user/info`

查询用户信息。`uid` 不传时可理解为当前用户；传入时查询指定用户。

Query：

- `uid`: string

响应 `data`：

- `token*`: string
- `user*`: `UserInfo`
- `relation*`: `UserRelation`

### POST `/api/v1/user/follow`

关注用户，接口幂等。

请求 body：

- `target_uid*`: string，被关注用户 uid

响应 `data`：空对象。

### POST `/api/v1/user/unfollow`

取消关注用户，接口幂等。

请求 body：

- `target_uid*`: string，被取消关注用户 uid

响应 `data`：空对象。

### GET `/api/v1/user/following`

返回 `uid` 关注的用户列表。需登录；任意登录用户均可查询任意 `uid`。

Query：

- `uid*`: string，目标用户 uid
- `pn`: integer，页码，从 1 开始
- `rn`: integer，每页条数，默认 10，最大 100

响应 `data`：

- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `list*`: `{ user: UserInfo, relation: UserRelation }[]`

### GET `/api/v1/user/followers`

返回关注 `uid` 的粉丝列表。

Query：

- `uid*`: string，目标用户 uid
- `pn`: integer
- `rn`: integer

响应 `data`：

- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `list*`: `{ user: UserInfo, relation: UserRelation }[]`

## Origin / World 接口

### GET `/api/v1/world/list`

返回 world 列表。world 由 origin 复制而来，列表项只返回 `info + stats`，详情接口返回角色、location、ticks。

Query：

- `pn`: integer，默认 1
- `rn`: integer，默认 10
- `origin_id`: string，仅查询基于该 origin 复制出的 world
- `uid`: string，仅查询某个用户拥有或创建的 world
- `keyword`: string，模糊搜索 `world_name` / `brief`

响应 `data`：

- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `list*`: `{ info: WorldInfo, stats: WorldStats }[]`

### GET `/api/v1/world/detail`

返回单个 world 的完整详情：基本信息、统计信息、角色列表、location、ticks。

Query：

- `world_id*`: string

响应 `data`：

- `info*`: `WorldInfo`
- `stats*`: `WorldStats`
- `characters*`: `Character[]`
- `locations*`: `Location[]`
- `ticks*`: `Tick[]`

### POST `/api/v1/world/tick`

world owner 触发一次 tick。该接口替代旧的 progress 触发接口，不保留旧接口兼容；请求字段使用 `world_id`，不再使用 `wid`。

前置条件：

- 必须登录。
- 调用方必须等于 `world.owner_uid`，否则返回 `10011`。

服务端行为：

- 取当前 `max(tick_no) + 1` 作为新 `tick_no`。
- 写入 `tbl_ticks`，包括 `obj_type=2`、`obj_id=world_id`、`narrator`、`paragraphs`。
- 更新 `tbl_worlds.tick_cnt + 1`，刷新 `world_last_tick_time`，并将 `status` 置为 `20`（tick 中）。

请求 body：

- `world_id*`: string

响应 `data`：

- `world_id*`: string
- `tick_cnt*`: integer
- `last_tick*`: `Tick`

错误码：

- `4004`
- `10001`
- `10011`
- `20201`

### GET `/api/v1/origin/list`

返回 origin 模板列表。origin 是 world 的模板，可被复制为 world。列表项只返回 `info + stats`。

Query：

- `pn`: integer，页码，从 1 开始
- `rn`: integer，每页条数，默认 10，最大 100
- `tag_id`: integer，按 tag 过滤
- `keyword`: string，模糊搜索 `origin_name` / `brief`
- `uid`: string
- `tag_name`: string

响应 `data`：

- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `list*`: `{ info: OriginInfo, stats: OriginStats }[]`

### GET `/api/v1/origin/detail`

返回单个 origin 模板的完整详情：基本信息、统计信息、初始角色、初始 location、ticks。

Query：

- `origin_id*`: string

响应 `data`：

- `info*`: `OriginInfo`
- `stats*`: `OriginStats`
- `characters*`: `Character[]`
- `locations*`: `Location[]`
- `ticks*`: `Tick[]`

## Discuss 接口

Apifox 当前定义的 discuss 业务类型只覆盖 origin：`biz_type=1`。列表接口无需登录；其余写操作需要登录态，Apifox 安全定义为 cookie `AIUSS`。

### GET `/api/v1/discuss/list`

顶级评论分页列表，返回每条顶级评论下最新 3 条回复。无需登录可访问；登录态下会回填 `is_liked`。

服务端行为：

- 校验 `biz_type` 受支持，并校验 `biz_id` 对应业务实体存在。
- 顶级评论按 `(biz_type, biz_id, level=1, deleted_at IS NULL)` 过滤，按 `created_at DESC, id DESC` 分页。
- `top_total` 表示顶级评论数量；`total_all` 表示顶级评论加回复的全部未删数量。
- 每条顶级评论按 `root_discuss_id` 取最新 3 条未删回复。

Query：

- `biz_type*`: integer，当前 `1` 表示 origin
- `biz_id*`: string
- `pn`: integer，默认 1
- `rn`: integer，默认 10

响应 `data`：

- `list*`: `{ comment: DiscussItem, latest_replies: DiscussItem[] }[]`
- `top_total*`: integer，顶级评论数量
- `total_all*`: integer，顶级评论 + 回复全部未删数量
- `pn*`: integer
- `rn*`: integer

错误码：

- `4004`
- `20401`
- `20402`

### POST `/api/v1/discuss/post`

发表一条顶级评论或回复。`root_discuss_id` 为空时发表顶级评论；非空时发表回复。

服务端行为：

- 校验 `biz_type` 受支持，且 `biz_id` 对应实体存在、未软删除。
- `content` 与 `images` 至少其一非空；`images` 最多 9 张，单条 URL 长度不超过 512。
- 顶级评论写入 `level=1`，并递增 `tbl_origins.discuss_cnt`。
- 回复写入 `level=2`，`root_discuss_id` 必须命中同业务下的顶级评论；`parent_discuss_id` 未传时默认等于 `root_discuss_id`，并递增 root 的 `reply_cnt`。

请求 body：

- `biz_type*`: integer，当前 `1` 表示 origin
- `biz_id*`: string
- `content`: string，与 `images` 至少其一非空
- `images`: string[]，最多 9 张
- `root_discuss_id`: string，顶级评论为空，回复时为所属顶级评论 id
- `parent_discuss_id`: string，回复直接目标；回复时可选

响应 `data`：

- `discuss_id*`: string
- `root_discuss_id*`: string，顶级评论为空字符串，回复时为所属顶级评论 id
- `level*`: integer

错误码：

- `4004`
- `10001`
- `20401`
- `20402`
- `20403`
- `20404`
- `20405`

### POST `/api/v1/discuss/delete`

登录用户软删除自己的评论或回复。仅作者本人可删；查询路径默认过滤 `deleted_at IS NULL`。

服务端行为：

- 删除顶级评论时递减 `tbl_origins.discuss_cnt`，下界为 0。
- 删除回复时递减 root 的 `reply_cnt`，下界为 0。
- 不级联删除回复或点赞明细。

请求 body：

- `discuss_id*`: string

响应 `data`：空对象。

错误码：

- `10001`
- `20403`
- `20406`

### POST `/api/v1/discuss/like`

登录用户对一条评论或回复点赞，接口幂等。服务端使用插入冲突忽略；仅当本次确实新插入点赞行时，`like_cnt += 1`。

请求 body：

- `discuss_id*`: string

响应 `data`：空对象。

错误码：

- `10001`
- `20403`

### POST `/api/v1/discuss/unlike`

登录用户取消点赞，接口幂等。从未点赞时直接返回成功；仅当本次实际删除点赞行时，`like_cnt -= 1`，下界为 0。

请求 body：

- `discuss_id*`: string

响应 `data`：空对象。

错误码：

- `10001`

## Direct Message 接口

这些接口替换旧的 `/api/v1/dm/*` 封装。最新 Apifox 以 peer 为客户端主键：客户端发送、拉取列表和标记已读时都传 `peer_uid` 或 `target_uid`，不再传 `conversation_id`、`message_id`、`last_read_seq`、`client_msg_id`。

### POST `/api/v1/direct_message/send`

当前登录用户向 `peer_uid` 发送一条私信。sender 不能是 peer；任一方拉黑对方会拒绝；互关用户可自由发送，未互关时受 ping-pong 限制；`content` 非空且长度不超过 1000 字符。

请求 body：

- `peer_uid*`: string
- `content*`: string

响应 `data`：

- `message*`: DirectMessage
- `conversation*`: DirectMessageConversation

错误码：`10001`、`10002`、`20301`、`20302`、`20303`、`20304`、`20305`。

实现状态：已封装在 `DmV1Api.send({peerUid, content})`。

### GET `/api/v1/direct_message/conversations`

返回当前登录用户参与的全部 1 对 1 会话，按 `last_message_at` 倒序。默认 `pn=1`、`rn=20`，最大 `rn=100`。

query：

- `pn`: integer
- `rn`: integer

响应 `data`：

- `list*`: DirectMessageConversation[]
- `total*`: integer
- `pn*`: integer
- `rn*`: integer

错误码：`10001`。

实现状态：已封装在 `DmV1Api.conversations`。

### GET `/api/v1/direct_message/list`

分页返回当前登录用户与 `peer_uid` 之间的私信，按消息 id 倒序，最新在前；没有会话时返回空列表。默认 `pn=1`、`rn=20`，最大 `rn=100`。

query：

- `peer_uid*`: string
- `pn`: integer
- `rn`: integer

响应 `data`：

- `list*`: DirectMessage[]
- `total*`: integer
- `pn*`: integer
- `rn*`: integer

错误码：`10001`、`10002`。

实现状态：已封装在 `DmV1Api.list({peerUid, pn, rn})`。

### POST `/api/v1/direct_message/read`

将当前登录用户与 `peer_uid` 的会话未读数清零，并把 `last_read_message_id` 推到当前会话最新消息 id；会话不存在时幂等返回成功。

请求 body：

- `peer_uid*`: string

响应 `data`：空对象。

错误码：`10001`、`10002`。

实现状态：已封装在 `DmV1Api.markRead({peerUid})`。

### GET `/api/v1/direct_message/unread`

返回当前登录用户在所有会话中的未读消息总数。

响应 `data`：

- `unread_cnt*`: integer

错误码：`10001`。

实现状态：已封装在 `DmV1Api.unread`。

### POST `/api/v1/direct_message/block`

将 `target_uid` 拉黑，已拉黑时幂等成功；拉黑不会自动取消互相关注。

请求 body：

- `target_uid*`: string

响应 `data`：空对象。

错误码：`10001`、`10002`、`20301`。

实现状态：已封装在 `DmV1Api.block({targetUid})`。

### POST `/api/v1/direct_message/unblock`

取消对 `target_uid` 的拉黑，未拉黑时幂等成功。

请求 body：

- `target_uid*`: string

响应 `data`：空对象。

错误码：`10001`。

实现状态：已封装在 `DmV1Api.unblock({targetUid})`。

### GET `/api/v1/direct_message/blocks`

返回当前登录用户拉黑过的用户分页列表，按拉黑时间倒序。默认 `pn=1`、`rn=20`。

query：

- `pn`: integer
- `rn`: integer

响应 `data`：

- `list*`: UserInfo[]
- `total*`: integer
- `pn*`: integer
- `rn*`: integer

错误码：`10001`。

实现状态：已封装在 `DmV1Api.blocks`。

## Upload 接口

### POST `/api/v1/upload/image`

上传图片到阿里云 OSS。需登录态，Apifox 安全定义为 cookie `AIUSS`。请求体类型为 `multipart/form-data`，文件字段名为 `file`。

服务端行为：

- 将客户端上传的图片文件保存到阿里云 OSS，返回对外可访问 URL。
- 服务端限制文件体积 `<= 10MiB`。
- 扩展名仅支持 `jpg/jpeg/png/gif/webp`。
- `object_key` 形如 `<pathPrefix>/<yyyyMMdd>/<snowflake>.<ext>`。

请求 body：

- `file*`: binary，`multipart/form-data` 文件字段

响应 `data`：`UploadImageResult`。

响应示例：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "url": "https://cdn.example.com/uploads/20260526/1234567890.jpg",
    "object_key": "uploads/20260526/1234567890.jpg"
  }
}
```

错误码：

- `10001`
- `20501`
- `20502`
- `20503`
- `20504`

## 当前代码对齐状态

截至 2026-05-27，本文档覆盖的 27 个接口已完成主要 HTTP 契约对齐；本次新增记录的 direct_message 接口已按 Apifox 新契约调整当前封装与本地 mock：

| Apifox 接口 | 当前实现状态 |
| --- | --- |
| `POST /api/v1/user/oauth/google` | `UserV1Api.googleAuth` 与 `GenesisApi.loginWithGoogle/loginWithIdentity` 已走 `/user/oauth/google`，body 使用 `id_token/nonce/name/avatar`。 |
| `POST /api/v1/user/oauth/apple` | `UserV1Api.appleAuth` 与 `GenesisApi.loginWithApple/loginWithIdentity` 已走 `/user/oauth/apple`，body 使用 `id_token/nonce/name/avatar`；不再向后端发送 `firebase_id_token`。 |
| `POST /api/v1/user/logout` | `GenesisApi.logout` 已走 `/user/logout`。 |
| `GET /api/v1/user/info` | `UserV1Api.info` 支持可选 `uid` query；`bindDevice/hasAuthenticatedSession/getUser/getDisplayUserCode` 已切到该接口。 |
| `POST /api/v1/user/follow` | `FollowV1Api.follow` body 已改为 `target_uid`，响应按空对象处理。 |
| `POST /api/v1/user/unfollow` | `FollowV1Api.unfollow` body 已改为 `target_uid`，响应按空对象处理。 |
| `GET /api/v1/user/following` | 已新增 `FollowV1Api.following(uid,pn,rn)`。 |
| `GET /api/v1/user/followers` | 已新增 `FollowV1Api.followers(uid,pn,rn)`。 |
| `GET /api/v1/world/list` | `WorldV1Api.list` query 已使用 `origin_id/uid/keyword/pn/rn`；首页和个人 world 列表可消费 `list[].info + stats`。 |
| `GET /api/v1/world/detail` | `WorldV1Api.detail` query 已使用 `world_id`；详情 mapper 支持 `info/stats/characters/locations/ticks`。 |
| `POST /api/v1/world/tick` | 新契约替代旧 progress 触发接口；客户端应提交 `{ "world_id": "<world_id>" }` 并消费 `world_id/tick_cnt/last_tick`。 |
| `GET /api/v1/origin/list` | `OriginV1Api.list` query 已使用 `tag_id/keyword/uid/tag_name/pn/rn`；origin 页面和主 `getOrigins/getMyLaunchedOrigins` 可消费 `list[].info + stats`。 |
| `GET /api/v1/origin/detail` | `OriginV1Api.detail` query 已使用 `origin_id`；详情 mapper 支持 `info/stats/characters/locations/ticks`。 |
| `GET /api/v1/discuss/list` | `DiscussV1Api.list` 已使用 `biz_type=1`、`biz_id/pn/rn`，并消费 `list[].comment/latest_replies/top_total/total_all`；本地 mock 会按业务对象分页并为每条顶级评论返回最新 3 条回复。 |
| `POST /api/v1/discuss/post` | `DiscussV1Api.post` 已支持顶级评论与回复统一入口，body 使用 `biz_type/biz_id/content/images/root_discuss_id/parent_discuss_id`，响应消费 `discuss_id/root_discuss_id/level`。 |
| `POST /api/v1/discuss/delete` | `DiscussV1Api.delete` 已改为 `/discuss/delete` + `discuss_id`，响应按空对象处理。 |
| `POST /api/v1/discuss/like` | `DiscussV1Api.like` 已改为 `discuss_id`，响应按空对象处理；本地 mock 幂等维护 `is_liked/like_cnt`。 |
| `POST /api/v1/discuss/unlike` | `DiscussV1Api.unlike` 已新增 `/discuss/unlike` + `discuss_id`，响应按空对象处理；本地 mock 幂等维护 `is_liked/like_cnt`。 |
| `POST /api/v1/direct_message/send` | `DmV1Api.send` 已改为 `/direct_message/send`，body 使用 `peer_uid/content`，响应消费 `message/conversation`。 |
| `GET /api/v1/direct_message/conversations` | `DmV1Api.conversations` 已替代旧 `/dm/chatlist`，响应消费 `list/total/pn/rn`。 |
| `GET /api/v1/direct_message/list` | `DmV1Api.list` 已替代旧 `/dm/messagelist`，query 使用 `peer_uid/pn/rn`，响应消费 `list/total/pn/rn`。 |
| `POST /api/v1/direct_message/read` | `DmV1Api.markRead` 已改为使用 `peer_uid`，不再提交 `conversation_id/last_read_seq`。 |
| `GET /api/v1/direct_message/unread` | 已新增 `DmV1Api.unread`，响应消费 `unread_cnt`。 |
| `POST /api/v1/direct_message/block` | 已新增 `DmV1Api.block`，body 使用 `target_uid`。 |
| `POST /api/v1/direct_message/unblock` | 已新增 `DmV1Api.unblock`，body 使用 `target_uid`。 |
| `GET /api/v1/direct_message/blocks` | 已新增 `DmV1Api.blocks`，响应消费拉黑用户分页列表。 |
| `POST /api/v1/upload/image` | 已新增 `UploadV1Api.image`，multipart 字段名固定为 `file`，响应消费 `url/object_key`；头像上传已改用新接口，本地 mock 返回 `https://mock.local/uploads/...`。 |

当前 v1 响应处理：

- `handleV1ResponseErrNo` 识别 `err_no` / `errNo`。
- 成功时返回 `data`。
- 失败消息优先读取 Apifox 的 `err_msg`，并兼容旧的 `err_str` / `errStr`。
- 响应对象 key 仍会从 camelCase 规范化成 snake_case，用于兼容旧 mock 和历史接口。

为降低迁移风险，代码仍保留若干兼容能力：

- world 详情 mapper 只消费 Apifox 的 `info/stats/characters/locations/ticks`；origin 详情 mapper 暂保留旧字段兼容。
- 关系字段在 mock 中同时保留 `is_followed` 与历史 `i_followed`，但 Apifox 新接口按 `is_followed` 生成。
- Apifox 未声明 headers/security；当前客户端仍按应用运行时注入 `x-platform`、`x-device-id`、`x-user-id`、`authorization: Bearer <token>`。

### Apifox 未覆盖但当前 v1 已封装的接口

用户与关系：

- `POST /api/v1/user/update`
- `GET /api/v1/user/profile`
- `GET /api/v1/user/origins`
- `GET /api/v1/user/worlds`
- `GET /api/v1/user/relations`
- `POST /api/v1/users/relations/status`

Origin：

- `POST /api/v1/origin/create`
- `POST /api/v1/origin/update`
- `POST /api/v1/origin/launch`
- `GET /api/v1/origin/versionlist`
- `POST /api/v1/origin/publish`
- `POST /api/v1/origin/del`

World：

- `POST /api/v1/world/request`
- `POST /api/v1/world/request/audit`
- `POST /api/v1/world/join`
- `POST /api/v1/world/synclastorigin`
- `POST /api/v1/world/close`
- `POST /api/v1/world/del`

消息、搜索、首页、通用：

- `GET /api/v1/messages/unread-summary`
- `GET /api/v1/messages/notifications`
- `POST /api/v1/messages/notifications/read`
- `GET /api/v1/messages/followers`
- `GET /api/v1/search`
- `GET /api/v1/search/suggest`
- `GET /api/v1/home`
- `GET /api/v1/home/following`
- `POST /api/v1/common/upload`
- `POST /api/v1/common/drafts`
- `GET /api/v1/common/drafts`
- `POST /api/v1/common/drafts/del`
- `POST /api/v1/common/devices/register`

### Apifox 未覆盖但当前仍保留的旧 HTTP 接口

这些接口不属于本文档覆盖的 Apifox `/api/v1` 接口。当前代码只在对应功能尚无 Apifox 契约时继续保留，已不再用于本文档覆盖的登录、用户信息、origin/world 列表详情与 world tick 接口：

- `POST /api/origins`
- `POST /api/worlds/launch`
- `POST /api/worlds/{wid}/join-requests`
- `GET /api/search`
- `GET /api/characters`
- `POST /api/tick`
- `POST /api/session/set-world`
- `POST /api/session/set-player-scene`
- `GET /api/points/{pointId}/messages`
- `POST /api/points/{pointId}/messages/enqueue`
- `GET /health`
