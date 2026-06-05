# Apifox HTTP 接口文档与当前实现差异

来源：
- Apifox 分享页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/460308499e0
- Apifox world tick 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462798656e0
- Apifox world tick 列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/469083051e0
- Apifox discuss 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462474822e0
- Apifox discuss 回复分页页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/466619391e0
- Apifox direct_message 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462474827e0
- Apifox direct_message 会话列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462474828e0
- Apifox upload 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463764231e0
- Apifox notify 未读数页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463874827e0
- Apifox notify 通知列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463874828e0
- Apifox notify 标记已读页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463874829e0
- Apifox search 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/465724653e0
- Apifox chatroom 世界最近消息页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/465850374e0
- Apifox chatroom 历史消息页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446394e0
- Apifox chatroom tick lock 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446395e0
- Apifox chatroom tick progress 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446396e0
- Apifox chatroom tick unlock 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446397e0
- Apifox chatroom narrator write 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446399e0
- Apifox LLM 索引：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/llms.txt

提取时间：2026-06-05

本文档记录 Flutter 项目当前对齐或待替换的 Apifox HTTP 接口，并对比当前 Flutter 项目中的 `lib/network` HTTP 设计。字段后带 `*` 表示 Apifox 标记为必填。

## 总览

本文档当前覆盖 41 个接口，分为 `用户`、`origin`、`world`、`chatroom`、`search`、`discuss`、`direct_message`、`notify` 和 `upload` 九组：

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
| world | GET | `/api/v1/world/tick/list` | 分页获取 world 下的 tick 列表 |
| world | GET | `/api/v1/world/origin_progress` | 用户在某 origin 下的最大 world tick 进度 |
| world | POST | `/api/v1/world/tick` | world owner 触发一次 tick |
| chatroom | GET | `/aitown-chat/internal/world/messages` | 获取世界最近消息 |
| chatroom | GET | `/aitown-chat/api/messages` | 获取历史消息 |
| chatroom | POST | `/aitown-chat/internal/tick/lock` | 锁定 World |
| chatroom | GET | `/aitown-chat/internal/tick/progress` | 轮询 Tick 进度 |
| chatroom | POST | `/aitown-chat/internal/tick/unlock` | 解锁 World |
| chatroom | POST | `/aitown-chat/internal/narrator/write` | 写入旁白消息 |
| search | GET | `/api/v1/search` | 全局搜索 |
| origin | GET | `/api/v1/origin/list` | Origin 模板列表 |
| origin | GET | `/api/v1/origin/detail` | Origin 模板详情 |
| origin | POST | `/api/v1/origin/launch` | 基于 origin 创建 world |
| discuss | GET | `/api/v1/discuss/list` | 顶级评论分页列表 |
| discuss | GET | `/api/v1/discuss/replies` | 顶级评论下的回复分页列表 |
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
| notify | GET | `/api/v1/message/unread` | 获取消息页未读数 |
| notify | GET | `/api/v1/message/notifications` | 按消息块拉取通知列表 |
| notify | POST | `/api/v1/message/read` | 标记非私信通知已读 |
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
- `last_login_at*`: integer，Unix 秒时间戳
- `create_at*`: integer，Unix 秒时间戳
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
- `created_at*`: integer，Unix 秒时间戳，示例 `1779539696`

### DirectMessageConversation

- `conv_id*`: string
- `peer*`: UserInfo，对话中的另一方；其中 `last_login_at`、`create_at` 等时间字段均为 Unix 秒时间戳
- `last_message_id*`: string，当前会话最后一条消息 id
- `last_message*`: string
- `last_message_at*`: integer，Unix 秒时间戳，示例 `1797731760`
- `last_sender_uid*`: string
- `unread_cnt*`: integer，当前用户视角下该会话未读数
- `is_friend*`: boolean
- `i_blocked_peer*`: boolean，当前用户是否已拉黑 peer
- `peer_blocked_me*`: boolean，peer 是否已拉黑当前用户
- `can_send_next_message*`: boolean，是否允许当前用户继续发送下一条私信

### MessageNotificationItem

- `notification_id*`: string
- `notice_block*`: string，`world_apply`、`follow` 或 `interaction`
- `notice_type*`: string，`world_apply`、`world_apply_review`、`follow`、`discuss_comment`、`discuss_reply` 或 `discuss_like`
- `sender*`: `UserInfo`
- `biz_type*`: integer
- `biz_id*`: string
- `obj_id*`: string
- `content*`: string
- `is_read*`: boolean
- `created_at*`: integer，Unix 秒时间戳

### OriginInfo

- `origin_id*`: string
- `origin_name*`: string
- `origin_version*`: string
- `origin_version_time*`: integer，Unix 秒时间戳
- `owner_uid`: string，创建者 uid，来自登录 session，不接受创建请求覆盖
- `owner_name`: string，创建者昵称
- `brief`: string
- `setting`: string
- `events`: string[]
- `tags`: string[]
- `metric*`: `WorldMetric`
- `created_at`: integer，Unix 秒
- `started_at`: string，故事内起始时间文本
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
- `max_tick_cnt`: integer

### WorldInfo

- `world_id*`: string
- `world_name*`: string
- `origin_id`: string
- `origin_version`: string
- `origin_version_time`: string
- `owner_uid`: string，创建者 uid，来自 `tbl_world.owner_uid`
- `owner_name`: string，创建者姓名；用户不存在时为空串
- `brief`: string
- `setting`: string
- `events`: string[]
- `metric`: `WorldMetric`
- `created_at`: integer，Unix 秒
- `started_at`: string，故事内起始时间文本
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

### WorldOriginProgressResp

- `world_id*`: string，tick 数最大的 world_id；无匹配时为空字符串
- `tick_cnt*`: integer，该 world 的 `current_tick_no`；无匹配时为 0

### Character

- `char_id*`: string
- `type*`: string，`ai` 或 `custom`；origin 模板中固定为 `ai`
- `player_uid`: string，`type=custom` 时存在；origin 模板中为空
- `player_username`: string
- `name*`: string
- `identity`: string
- `brief`: string
- `description`: string
- `goal`: string
- `avatar`: string
- `initial_location_id`: string
- `location_id`: string，当前 location
- `metric_value`: integer
- `delta`: integer

### Location

- `location_id*`: string
- `level`: integer，顶层为 `1`
- `location_pid`: string
- `location_name*`: string
- `location_description`: string，地点基础描述；当 `location_summary` 为空时，地点列表用它兜底展示
- `location_paragraph`: string，最新段落，每次 tick P1 后可能变化
- `location_timestamp`: string，最新故事时间戳，每次 tick P1 后可能变化
- `location_summary`: string，地点当前摘要，地点列表优先展示
- `image`: string
- `x_percent`: integer
- `y_percent`: integer
- `map_url`: string，当前 location 的地图图片 URL
- `dialogue`: `DialogueLine[]`

### Tick

- `tick_id`: string
- `tick_no`: integer
- `status`: integer
- `tick_result*`: `WorldTickResult`
- `created_at`: integer，Unix 秒

`WorldTickResult`：

- `narrator*`: string
- `paragraphs*`: `TickParagraph[]`
- `location_groups*`: `LocationGroup[]`

`TickParagraph`：

- `location_id*`: string
- `timestamp`: string
- `text*`: string
- `character_deltas`: `{ char_id, name, delta }[]`

### ChatroomMessageDTO

- `message_id`: integer，全局递增消息 ID
- `location_id`: string，地点 ID；`/aitown-chat/api/messages` 的 `MessageDTO` 不带该字段，调用方已知 location
- `conversation_round_id`: integer，对话轮次 ID
- `round_order`: integer，轮次内序号
- `sender_type`: string，`user`、`character` 或 `narrator`
- `sender_id`: string，发送者 ID
- `sender_name`: string，发送者名称
- `user_id`: string，用户消息时非空
- `content`: string，消息内容
- `created_at`: string，创建时间

### ChatroomNarratorLocationGroup

- `location_id*`: string
- `location_name*`: string
- `location_summary*`: string
- `characters*`: `{ char_id, name }[]`
- `initial_dialogue*`: `{ char_id, char_name, content }[]`

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
- `owner_uid`: string，仅查询某个用户拥有或创建的 world
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
- `relation_status*`: string，当前登录用户与该 world 的关系状态；可为 `anonymous` / `owner` / `joined` / `pending` / `approved` / `rejected`
- `characters*`: `Character[]`
- `locations*`: `Location[]`
- `ticks*`: `Tick[]`

### GET `/api/v1/world/origin_progress`

根据 `uid + origin_id` 查询该用户创建或加入过的 active world 成员关系，返回 `current_tick_no` 最大的一条 world 及 tick 数。无匹配时返回 `world_id=""`、`tick_cnt=0`。

Query：

- `uid*`: string，用户 uid
- `origin_id*`: string，origin 业务 id

响应 `data`：

- `world_id*`: string
- `tick_cnt*`: integer

错误码：

- `4004`

### POST `/api/v1/world/apply`

玩家发起加入 world 的申请；同一 `(world_id, applicant_uid)` 不能存在 pending/approved 的活跃申请。

请求 body：

- `world_id*`: string
- `message`: string

响应 `data`：

- `apply_id*`: string
- `status*`: integer，`10` 表示 pending

错误码：

- `20101`：`origin_id` 不存在或已软删除
- `20201`
- `20203`
- `20204`
- `20205`

### GET `/api/v1/world/apply/list`

查询 world 加入申请列表。`world_id` 为空时表示申请人视角，仅列出当前登录用户发起过的申请；传入 `world_id` 时用于 owner 审批列表。

Query：

- `pn`: integer
- `rn`: integer
- `world_id`: string
- `status`: integer

响应 `data`：

- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `list*`: `WorldApply[]`

`WorldApply`：

- `apply_id*`: string
- `world_id*`: string
- `applicant_uid*`: string
- `message`: string
- `status*`: integer
- `reviewer_uid`: string
- `review_msg`: string
- `reviewed_at`: integer
- `joined_at`: integer
- `created_at`: integer

错误码：

- `10001`
- `10003`
- `20201`

### POST `/api/v1/world/apply/review`

world owner 审批一条 pending 申请。`action=approve` 流转到 approved；`action=reject` 流转到 rejected（终态）。被拒绝的申请允许同一申请人重新发起新的 apply。

请求 body：

- `apply_id*`: string
- `action*`: string，`approve` 或 `reject`
- `review_msg`: string

响应 `data`：

- `apply_id*`: string
- `status*`: integer，`20` 表示 approved

错误码：

- `4004`
- `10001`
- `10003`
- `20202`
- `20206`

### POST `/api/v1/world/join`

申请通过后玩家正式加入 world。语义与 `origin/launch` 一致：`preset_character_id` 与 `custom_role` 二选一互斥。

请求 body：

- `world_id*`: string
- `preset_character_id`: string，必须命中该 world 中 `type=ai` 且 `player_uid` 为空的角色
- `custom_role`: `WorldCustomRole`

响应 `data`：

- `world_id*`: string
- `char_id*`: string

错误码：

- `4004`
- `10001`
- `10003`
- `20201`
- `20202`
- `20204`
- `20206`
- `20207`

### GET `/api/v1/world/tick/list`

按 `world_id` 分页读取 `tbl_world_tick`。列表按 `tick_no DESC, id DESC` 排序，最新 tick 在前。公开可访问；未审核通过的 world 仅 owner 可见，其他调用方返回 `ErrorWorldNotExist`。

Query：

- `world_id*`: string
- `pn`: integer，页码，从 1 开始
- `rn`: integer，每页条数，默认 10

响应 `data`：

- `list*`: `Tick[]`
- `total*`: integer
- `pn*`: integer
- `rn*`: integer

错误码：

- `4004`
- `20201`

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

返回单个 origin 模板的完整详情：基本信息、统计信息、初始角色、初始 location、ticks。匿名可访问，不需要登录。

Query：

- `origin_id*`: string

响应 `data`：

- `info*`: `OriginInfo`
- `stats*`: `OriginStats`
- `characters*`: `Character[]`
- `locations*`: `Location[]`
- `ticks*`: `Tick[]`

### POST `/api/v1/origin/create`

登录用户基于完整的 `info + characters + locations` 创建新的 origin 模板。服务端生成 `origin_id`（前缀 `o_`），`owner_uid` 取自 session，不接受请求体覆盖；`tags` 会去除首尾空白、过滤空值、去重后写入 `tbl_origin.tags`，并同步 `tbl_tag` / `tbl_origin_tag`。

服务端行为：

- 批量插入 `tbl_world_character(world_id=origin_id)` 与 `tbl_world_location(world_id=origin_id)`。
- 同步 `character_cnt` / `location_cnt` 初值到主表。
- 按 `location_pid` 树形重写 location id：一级 `loc_1`，二级 `loc_1_1`，三级 `loc_1_1_1`。
- 按数组顺序将 `char_id` 重写为 `char_1...`，并同步重写 `character.initial_location_id` 与 `location.location_pid` 中的临时引用。
- `ticks` 不在 create 范围内。

请求 body（`OriginCreateReq`）：

- `origin_name*`: string
- `origin_version`: string，create 时服务端默认写 `1`
- `brief`: string
- `setting`: string
- `events`: string[]
- `tags`: string[]
- `metric`: `WorldMetric`
- `started_at`: string，故事内起始时间文本
- `tick_duration_days`: integer
- `cover`: string
- `map_url`: string
- `characters`: `OriginCharacterUpsert[]`
- `locations`: `OriginLocationUpsert[]`

`OriginCharacterUpsert`：

- `char_id`: string，请求内临时引用 id；服务端按数组顺序重写
- `name*`: string
- `identity`: string
- `personality`: string，详情接口中以 `character.brief` 返回
- `bio`: string，详情接口中以 `character.description` 返回
- `goal`: string
- `avatar`: string
- `initial_location_id`: string，角色初始地点 id；`location_id` / `metric_value` 属于 tick 运行态，不在 create 入参中提供

`OriginLocationUpsert`：

- `location_id`: string，请求内临时引用 id
- `level`: integer，不传时服务端会根据 `location_id` 粗略推断，兜底为 `1`
- `location_pid`: string，父 location id；顶层为空字符串
- `location_name*`: string
- `location_description`: string，固定描述，tick 不会修改
- `location_summary`: string，兼容旧请求；当 `location_description` 为空时用于回填固定描述
- `image`: string
- `x_percent`: integer，`0-100`
- `y_percent`: integer，`0-100`
- `map_url`: string

响应 `data`：

- `info*`: `OriginInfo`
- `stats*`: `OriginStats`
- `characters*`: `Character[]`
- `locations*`: `Location[]`
- `ticks*`: `Tick[]`

错误码：

- `4004`
- `10001`

### POST `/api/v1/origin/launch`

登录用户基于一个 origin 模板创建新的 world 实例；接口只创建 world，不触发 tick。

请求 body（`OriginLaunchReq`）：

- `origin_id*`: string，待 launch 的 origin 业务 id
- `preset_character_id`: string，origin 角色列表中的 `char_id`
- `custom_role`: `WorldCustomRole`

`preset_character_id` 与 `custom_role` 必须二选一；两者都为空或都非空会返回 `4004`。

`WorldCustomRole`：

- `char_id`: string，可空；为空时服务端按 `char_<uid>` 兜底
- `name*`: string
- `identity`: string
- `personality`: string
- `bio`: string
- `goal`: string
- `avatar`: string
- `initial_location_id`: string，玩家进入 world 时的初始地点；服务端同时作为当前 `location_id` 写入

响应 `data`：

- `world_id*`: string

错误码：

- `4004`
- `10001`
- `20101`
- `20102`

## Chatroom HTTP 接口

这些接口不在 `/api/v1` 下，而在 chatroom 服务前缀 `/aitown-chat` 下。当前 Flutter 侧通过 `GenesisApi.chatroomHttp` 使用独立 base URL，默认 `GENESIS_CHATROOM_HTTP_URL=https://dev.hushie.ai/`；本地 mock 已覆盖这些路由。

### GET `/aitown-chat/api/ulocation`

获取世界内所有已加入 location 的玩家位置信息，按地点分组返回。未加入任何 location 的用户不会出现在结果中。

Query：

- `world_id*`: string，世界实例 ID

响应 `data`：

- `world_id`: string，世界实例 ID
- `locations`: `{ location_id, users: { user_id, user_name, avatar }[] }[]`

### GET `/aitown-chat/internal/world/messages`

获取指定世界最近 50 条消息，按 `conversation_round_id` 倒排、`round_order` 正排，并按 `location_id` 分组返回。

Query：

- `world_id*`: string，世界实例 ID

响应 `data`：

- `locations`: `{ location_id, messages: ChatroomMessageDTO[] }[]`

错误响应示例：

```json
{ "err_no": 1001, "err_msg": "参数错误: world_id is required" }
```

### GET `/aitown-chat/api/messages`

分页获取指定 location 的历史消息。

Query：

- `world_id*`: string，世界实例 ID
- `location_id*`: string，地点 ID
- `since`: integer，起始消息 ID；`0` 表示获取最新
- `limit`: integer，默认 `20`

响应 `data`：

- `messages`: `ChatroomMessageDTO[]`；新 WebSocket 文档中的响应示例使用 `msg_id` 和毫秒级 `ts`，Flutter DTO 同时兼容旧 `message_id` / `created_at`
- `has_more`: boolean，是否有更多消息
- `newest_message_id`: integer，最新消息 ID

### POST `/aitown-chat/internal/tick/lock`

Tick 服务锁定 world，chat 服务广播 `input_blocked`，阻止用户继续发送消息。

Query / multipart form：

- `world_id*`: string，世界实例 ID；Apifox 同时声明 query 与 `multipart/form-data` body

响应 `data`：

- `locked`: boolean

### GET `/aitown-chat/internal/tick/progress`

Tick 服务轮询 world 处理进度。

Query：

- `world_id*`: string，世界实例 ID

响应 `data`：

- `progress`: integer，`1` 表示完成，`0` 表示进行中
- `pending_messages`: integer，待消费消息数
- `active_llm_calls`: integer，活跃 LLM 调用数

### POST `/aitown-chat/internal/tick/unlock`

Tick 服务解锁 world，chat 服务广播 `input_ready`，用户可以继续发送消息。

multipart form：

- `world_id`: string，世界实例 ID

响应 `data`：

- `unlocked`: boolean

### POST `/aitown-chat/internal/narrator/write`

旁白服务写入旁白消息，并广播 `narrator_message` 给对应 location 用户。

JSON body：

- `world_id*`: string
- `tick_id*`: string
- `location_groups*`: `ChatroomNarratorLocationGroup[]`

响应 `data`：

- `message_id`: integer，写入消息 ID

## Search 接口

### GET `/api/v1/search`

全局搜索。新契约使用 `keyword` 作为搜索词，不再使用旧实现里的 `query`；`type` 为空字符串时表示同时搜索 origin、world、user 三类。

Query：

- `keyword`: string
- `type`: string，空字符串表示三类都搜；可传 `origin`、`world`、`user`
- `pn`: integer，页码，从 1 开始
- `rn`: integer，每页条数

响应 `data`：

- `keyword*`: string，回显搜索词
- `type*`: string，回显搜索类型；空字符串表示三类都搜
- `origins*`: `SearchOriginResult`
- `worlds*`: `SearchWorldResult`
- `users*`: `SearchUserResult`

`SearchOriginResult`：

- `list*`: `{ info: OriginInfo, stats: OriginStats }[]`
- `total*`: integer
- `pn*`: integer
- `rn*`: integer

`SearchWorldResult`：

- `list*`: `{ info: WorldInfo, stats: WorldStats, last_tick: Tick }[]`
- `total*`: integer
- `pn*`: integer
- `rn*`: integer

`SearchUserResult`：

- `list*`: `{ user: UserInfo, relation: UserRelation }[]`
- `total*`: integer
- `pn*`: integer
- `rn*`: integer

实现状态：`SearchV1Api.search({query, type, pn, rn})` 保留 Dart 层 `query` 参数名，但请求已改为发送 `keyword`；`SearchPage` 已消费 `origins/worlds/users` 三段结果，并兼容旧 mock 的 `groups` 结构作为过渡兜底。

## Discuss 接口

Apifox 当前定义的 discuss 业务类型只覆盖 origin：`biz_type=1`。列表和回复分页接口无需登录；其余写操作需要登录态，Apifox 安全定义为 cookie `AIUSS`。

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

### GET `/api/v1/discuss/replies`

顶级评论下的回复分页列表。无需登录可访问；登录态下会回填 `is_liked`。

服务端行为：

- 加载 `root_discuss_id` 对应的未删除 discuss 行。
- root 不存在返回 `ErrorDiscussNotExist`；root 不是 `level=1` 顶级评论返回 `ErrorDiscussRootNotTop`。
- 按 `(root_discuss_id, level=2, deleted_at IS NULL)` 过滤，按 `created_at DESC, id DESC` 分页。
- 批量加载作者用户信息与当前 viewer 的点赞集合，避免 N+1。

Query：

- `root_discuss_id*`: string
- `pn`: integer，默认 1
- `rn`: integer，默认 20

响应 `data`：

- `list*`: `DiscussItem[]`
- `total*`: integer，回复数量
- `pn*`: integer
- `rn*`: integer

错误码：

- `4004`
- `20403`
- `20404`

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

实现状态：已封装在 `DmV1Api.send({peerUid, content})`。`chat_page.dart` 发送私信时先写入本地 DB 并以 `sending` 状态渲染；接口成功后用返回的 `message` 替换本地临时消息并 merge 返回的 `conversation`，接口失败则从本地 DB 删除该临时消息，但当前页面保留一条临时失败行并显示红色感叹号。

### GET `/api/v1/direct_message/conversations`

返回当前登录用户参与的 1 对 1 会话，按 `last_message_at` 倒序。无 `after_message_id` 时为全量分页模式，默认 `pn=1`、`rn=20`，最大 `rn=100`；有 `after_message_id` 时为增量同步模式，服务端返回该游标之后变更过的会话。

query：

- `pn`: integer，全量分页时使用
- `rn`: integer，全量分页时使用；客户端全量同步固定传 `100`
- `after_message_id`: string，客户端上次保存的 `next_after_message_id`；增量同步时只传该字段，不传 `pn/rn`

响应 `data`：

- `list*`: DirectMessageConversation[]
- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `next_after_message_id*`: string，下次增量同步要提交的游标

错误码：`10001`。

实现状态：已封装在 `DmV1Api.conversations({pn, rn, afterMessageId})`；传 `afterMessageId` 时客户端只发送 `after_message_id`。`DirectMessageConversationStore.syncConversations()` 会在无本地游标时循环请求 `pn=1/rn=100`、`pn=2/rn=100`，直到返回不足 100 条；有本地游标时只请求增量并按 `conv_id` merge 到本地 DB。`messages_page.dart` 订阅本地 store 渲染，不直接暴露全量分页细节。

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

实现状态：已封装在 `DmV1Api.list({peerUid, pn, rn})`。`chat_page.dart` 进入后先加载本地 DB，再请求 `pn=1/rn=20`；停留期间每 5 秒请求第一页并按 `msg_id` merge，滚动到顶部时按 `pn=2,3.../rn=20` 拉取本地没有的旧消息。DB 内消息状态为 `sending/sent`，发送失败消息不持久化，仅作为当前页面临时失败行展示。

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

## Notify 接口

### GET `/api/v1/message/unread`

获取消息页未读统计。需登录态，Apifox 安全定义为 cookie `AIUSS`。

响应 `data`：

- `total_unread*`: integer
- `world_apply_unread*`: integer
- `follow_unread*`: integer
- `interaction_unread*`: integer
- `direct_message_unread*`: integer

实现状态：已封装在 `MessagesV1Api.unreadSummary()`。

### GET `/api/v1/message/notifications`

按消息块拉取非私信通知列表。需登录态，Apifox 安全定义为 cookie `AIUSS`。私信列表继续使用 `/api/v1/direct_message/conversations`。

请求 query：

- `block*`: string，枚举 `world_apply`、`follow`、`interaction`
- `pn`: integer，最小 `1`，默认 `1`
- `rn`: integer，最小 `1`，最大 `100`，默认 `20`

响应 `data`：

- `list*`: `MessageNotificationItem[]`
- `total*`: integer
- `pn*`: integer
- `rn*`: integer

错误码：

- `4004`：`block` 非法
- `10001`：用户未登录

实现状态：已封装在 `MessagesV1Api.notifications(block,pn,rn)`；消息页三个入口分别传 `world_apply`、`follow`、`interaction`，不再发送旧的 `category=system/follower/comment`。

### POST `/api/v1/message/read`

标记消息中心中的非私信通知已读。需登录态，Apifox 安全定义为 cookie `AIUSS`。传 `notification_id` 时只标记单条；否则按 `block` 标记。私信会话已读继续使用 `/api/v1/direct_message/read`。

请求 body：

- `notification_id`: string，单条通知 id；传入后优先按单条标记已读
- `block`: string，未传 `notification_id` 时生效，枚举 `world_apply`、`follow`、`interaction`、`all`

响应 `data`：空对象。

错误码：

- `4004`：`block` 非法
- `10001`：用户未登录

实现状态：已封装在 `MessagesV1Api.markNotificationsRead(block,notificationId)`；页面进入通知分组时按对应 `block` 标记已读，不再调用旧的 `/api/v1/message/notifications/read`。

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

截至 2026-06-01，本文档覆盖的 40 个接口已完成主要 HTTP 契约对齐；本次新增记录的 chatroom HTTP 接口已按 Apifox 新契约补齐当前封装、本地 mock 与测试：

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
| `GET /api/v1/world/list` | `WorldV1Api.list` query 已使用 `origin_id/owner_uid/keyword/pn/rn`；首页和个人 world 列表可消费 `list[].info + stats`。 |
| `GET /api/v1/world/detail` | `WorldV1Api.detail` query 只使用 `world_id`；详情 mapper 支持 `info.metric`、`relation_status`、`locations[].location_description/location_paragraph/location_timestamp/dialogue` 与 `ticks[].tick_no/tick_result.paragraphs/location_groups`，不再消费旧 `wid` / `tick_index` / 顶层 `narrator` / `character_details` 别名。 |
| `GET /api/v1/world/tick/list` | 已新增 `WorldV1Api.tickList(worldId,pn,rn)` 与 `GenesisApi.getWorldTicks(wid,limit,offset)`；query 使用 `world_id/pn/rn`，响应按 `Tick` 列表规范化并保持最新 tick 在前。 |
| `GET /api/v1/world/origin_progress` | 已新增 `WorldV1Api.originProgress(uid,originId)`，query 使用 `uid/origin_id`，响应消费 `world_id/tick_cnt`；origin discuss loader 会用该接口补齐每条评论作者在当前 origin 下的 world 与 tick 进度。 |
| `POST /api/v1/world/tick` | 新契约替代旧 progress 触发接口；客户端应提交 `{ "world_id": "<world_id>" }` 并消费 `world_id/tick_cnt/last_tick`。 |
| `GET /aitown-chat/internal/world/messages` | 已新增 `ChatroomHttpApi.getWorldMessages(worldId)`，query 使用 `world_id`，响应消费 `locations[].location_id/messages[]`；本地 mock 按 location 分组返回最近消息。 |
| `GET /aitown-chat/api/messages` | 已新增 `ChatroomHttpApi.getMessages(worldInstanceId,locationId,since,limit)`，query 使用 `world_instance_id/location_id/since/limit`，响应消费 `messages/has_more/newest_message_id`。 |
| `POST /aitown-chat/internal/tick/lock` | 已新增 `ChatroomHttpApi.lockWorld(worldId)`，按 Apifox 同时发送 query `world_id` 与 multipart form `world_id`，响应消费 `locked`。 |
| `GET /aitown-chat/internal/tick/progress` | 已新增 `ChatroomHttpApi.tickProgress(worldId)`，响应消费 `progress/pending_messages/active_llm_calls`。 |
| `POST /aitown-chat/internal/tick/unlock` | 已新增 `ChatroomHttpApi.unlockWorld(worldId)`，multipart form 发送 `world_id`，响应消费 `unlocked`。 |
| `POST /aitown-chat/internal/narrator/write` | 已新增 `ChatroomHttpApi.writeNarrator(worldId,tickId,locationGroups)`，body 使用 `world_id/tick_id/location_groups`，响应消费 `message_id`；本地 mock 会写入 narrator 消息。 |
| `GET /api/v1/search` | `SearchV1Api.search` 已改为发送 `keyword/type/pn/rn`；`type` 为空时不随 query 发送，表示全局搜索；`SearchPage` 已消费 `origins/worlds/users` 分类结果块。 |
| `GET /api/v1/origin/list` | `OriginV1Api.list` query 已使用 `tag_id/keyword/uid/tag_name/pn/rn`；origin 页面和主 `getOrigins/getMyLaunchedOrigins` 可消费 `list[].info + stats`。 |
| `GET /api/v1/origin/detail` | `OriginV1Api.detail` query 已使用必填 `origin_id`；详情 mapper 支持 `info.metric`、`info.events`、`info.started_at`、`locations[].location_description` 与 `ticks[].tick_result`，local mock 返回 `info/stats/characters/locations/ticks`。 |
| `POST /api/v1/origin/launch` | `OriginV1Api.launch` body 已使用 `origin_id/preset_character_id/custom_role`；详情页 launch 发送 preset 或 custom 二选一 payload，并消费响应 `world_id`。 |
| `GET /api/v1/discuss/list` | `DiscussV1Api.list` 已使用 `biz_type=1`、`biz_id/pn/rn`，并消费 `list[].comment/latest_replies/top_total/total_all`；本地 mock 会按业务对象分页并为每条顶级评论返回最新 3 条回复。 |
| `GET /api/v1/discuss/replies` | 已新增 `DiscussV1Api.replies(rootDiscussId,pn,rn)`，query 使用 `root_discuss_id/pn/rn`，响应消费 `list/total/pn/rn`；本地 mock 会按 `root_discuss_id` 过滤并按创建时间倒序分页。 |
| `POST /api/v1/discuss/post` | `DiscussV1Api.post` 已支持顶级评论与回复统一入口，body 使用 `biz_type/biz_id/content/images/root_discuss_id/parent_discuss_id`，响应消费 `discuss_id/root_discuss_id/level`。 |
| `POST /api/v1/discuss/delete` | `DiscussV1Api.delete` 已改为 `/discuss/delete` + `discuss_id`，响应按空对象处理。 |
| `POST /api/v1/discuss/like` | `DiscussV1Api.like` 已改为 `discuss_id`，响应按空对象处理；本地 mock 幂等维护 `is_liked/like_cnt`。 |
| `POST /api/v1/discuss/unlike` | `DiscussV1Api.unlike` 已新增 `/discuss/unlike` + `discuss_id`，响应按空对象处理；本地 mock 幂等维护 `is_liked/like_cnt`。 |
| `POST /api/v1/direct_message/send` | `DmV1Api.send` 已改为 `/direct_message/send`，body 使用 `peer_uid/content`，响应消费 `message/conversation`。 |
| `GET /api/v1/direct_message/conversations` | `DmV1Api.conversations` 已替代旧 `/dm/chatlist`，query 支持全量 `pn/rn` 或增量 `after_message_id`；响应消费 `list/total/pn/rn/next_after_message_id`；本地 mock 支持全量分页、增量更新、增量插入和空增量。 |
| `GET /api/v1/direct_message/list` | `DmV1Api.list` 已替代旧 `/dm/messagelist`，query 使用 `peer_uid/pn/rn`，响应消费 `list/total/pn/rn`；`ChatPage` 已接本地 DB、5 秒轮询 merge、顶部滚动分页和行级渲染。 |
| `POST /api/v1/direct_message/read` | `DmV1Api.markRead` 已改为使用 `peer_uid`，不再提交 `conversation_id/last_read_seq`。 |
| `GET /api/v1/direct_message/unread` | 已新增 `DmV1Api.unread`，响应消费 `unread_cnt`。 |
| `GET /api/v1/message/unread` | `MessagesV1Api.unreadSummary` 已改用消息页未读统计接口，响应消费 `world_apply_unread/follow_unread/interaction_unread/direct_message_unread/total_unread`。 |
| `GET /api/v1/message/notifications` | `MessagesV1Api.notifications` 已改为必传 `block` query，枚举 `world_apply/follow/interaction`；页面入口已从旧 `system/follower/comment` 映射为 Apifox 的三个 block。 |
| `POST /api/v1/message/read` | `MessagesV1Api.markNotificationsRead` 已改为 `/message/read`，body 使用 `block` 或 `notification_id`，不再提交旧 `category/notification_ids`。 |
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
- Apifox 未声明 headers/security；当前客户端仍按应用运行时注入 `x-platform`、`device-id`、`authorization: Bearer <token>`。

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
- `GET /api/v1/origin/versionlist`
- `POST /api/v1/origin/publish`
- `POST /api/v1/origin/del`

World：

- `POST /api/v1/world/apply`
- `GET /api/v1/world/apply/list`
- `POST /api/v1/world/apply/review`
- `POST /api/v1/world/join`
- `POST /api/v1/world/synclastorigin`
- `POST /api/v1/world/close`
- `POST /api/v1/world/del`

消息、首页、通用：

- `GET /api/v1/messages/followers`
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
