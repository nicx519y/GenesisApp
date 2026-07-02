# Apifox HTTP 接口文档与当前实现差异

来源：
- Apifox 分享页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/460308499e0
- Apifox Origin 模板列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/461433666e0
- Apifox Origin 热门标签页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/465715733e0
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
- Report 提交举报：`/Users/ionix/Downloads/report.md`
- Feedback 提交反馈：`/Users/ionix/Downloads/feedback.md`
- Apifox chatroom 获取角色位置列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/470909609e0
- Apifox chatroom 世界最近消息页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/465850374e0
- Apifox chatroom 历史消息页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446394e0
- Apifox chatroom tick lock 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446395e0
- Apifox chatroom tick progress 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446396e0
- Apifox chatroom tick unlock 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446397e0
- Apifox chatroom narrator write 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446399e0
- Apifox 获取 Origin 原始编辑数据页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/470977899e0
- App 版本升级检查：`/Users/ionix/Downloads/version_check.md`
- Apifox LLM 索引：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/llms.txt

提取时间：2026-06-15

本文档记录 Flutter 项目当前对齐或待替换的 Apifox HTTP 接口，并对比当前 Flutter 项目中的 `lib/network` HTTP 设计。字段后带 `*` 表示 Apifox 标记为必填。

## 总览

本文档当前覆盖 48 个接口，分为 `app`、`用户`、`origin`、`world`、`chatroom`、`search`、`discuss`、`direct_message`、`notify`、`report`、`feedback` 和 `upload` 十二组：

| 分组 | 方法 | 路径 | 名称 |
| --- | --- | --- | --- |
| app | POST | `/api/v1/app/version/check` | App 版本升级检查 |
| 用户 | POST | `/api/v1/user/oauth/google` | Google login |
| 用户 | POST | `/api/v1/user/logout` | Logout current session |
| 用户 | POST | `/api/v1/user/delete` | 删除当前账号 |
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
| chatroom | GET | `/aitown-chat/api/ulocation` | 获取角色位置列表 |
| chatroom | GET | `/aitown-chat/internal/world/messages` | 获取世界最近消息 |
| chatroom | GET | `/aitown-chat/api/messages` | 获取历史消息 |
| chatroom | POST | `/aitown-chat/internal/tick/lock` | 锁定 World |
| chatroom | GET | `/aitown-chat/internal/tick/progress` | 轮询 Tick 进度 |
| chatroom | POST | `/aitown-chat/internal/tick/unlock` | 解锁 World |
| chatroom | POST | `/aitown-chat/internal/narrator/write` | 写入旁白消息 |
| search | GET | `/api/v1/search` | 全局搜索 |
| origin | GET | `/api/v1/origin/list` | Origin 模板列表 |
| origin | GET | `/api/v1/origin/hot_tags` | Origin 热门标签 |
| origin | GET | `/api/v1/origin/detail` | Origin 模板详情 |
| origin | GET | `/api/v1/origin/foredit` | 获取 Origin 原始编辑数据 |
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
| report | POST | `/api/v1/report/create` | 提交举报 |
| feedback | POST | `/api/v1/feedback/create` | 提交反馈 |
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
- `origin_name*`: string，`notice_block=interaction` 时返回，对应评论所在 Origin 名称
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

### WorldMetric

- `mode`: string，例如 `qualitative` 或 `quantitative`
- `label`: string，进度指标名称
- `label_note`: string，指标说明，对应 Basics 表单里的 `Label note`
- `unit`: string，指标单位
- `range`: number[]，指标范围，例如 `[0, 100]`
- `default`: number 或 string，初始值

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

- `global_message_id`: integer，全局递增消息 ID
- `message_id`: integer，world 级别递增消息 ID
- `location_message_id`: integer，location 级别递增消息 ID
- `location_id`: string，地点 ID；世界级消息可能为空
- `conversation_round_id`: integer，对话轮次 ID
- `sender_type`: string，`user`、`character`、`narrator`、`npc` 或 `tick`
- `sender_id`: string，发送者 ID
- `sender_name`: string，发送者名称
- `user_id`: string，用户消息时非空
- `content`: string，消息内容
- `current_time`: string，世界时间，tick advance 时非空
- `tick_no`: integer，Tick 序号，仅 tick 相关消息时非零
- `created_at`: string，创建时间，格式为 `2006-01-02 15:04:05`

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

### POST `/api/v1/user/delete`

登录用户删除自己的账号。服务端会写入 delete_account 用户日志、删除该 uid 的三方身份绑定，将 `tbl_users.status` 标记为 `2 deleted`，并清理当前 session / active-session / cookie。不清空用户展示资料，不级联删除 origin / world / 评论 / 消息等业务内容。同一个 Google / Apple 账号下次登录时会创建全新的 uid。

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
- `scene`: string，场景；自有数据传 `mine`，指定用户传 `uid`，标签筛选传 `tag`
- `tag`: string，`scene=tag` 时传入标签名
- `origin_id`: string，仅查询基于该 origin 复制出的 world
- `uid`: string，`scene=uid` 时传入目标用户 uid；`scene=mine` 时不传
- `keyword`: string，模糊搜索 `world_name` / `brief`

响应 `data`：

- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `list*`: `{ info: WorldInfo, stats: WorldStats }[]`

### GET `/api/v1/world/summary/latest`

公开查询同一个 origin 下最新的非空 world summary。调用方可传 `origin_id` 或 `world_id`；传 `world_id` 时服务端先读取该 world 的 `origin_id`，再返回同 origin 下其他 world 的最新 summary，并排除当前 `world_id`。两者都传时，服务端校验 world 所属 origin 与 `origin_id` 一致。结果按 `tick_time DESC, id DESC` 排序，最多返回 5 条，且结果内 `world_id` 不重复。

Query：

- `origin_id`: string，与 `world_id` 至少传一个
- `world_id`: string，传入时会排除该 world 自身

响应 `data`：

- `list*`: `WorldSummaryItem[]`

`WorldSummaryItem`：

- `world_id*`: string
- `origin_id*`: string
- `tick_no*`: integer
- `summary*`: string
- `tick_time*`: integer，summary 对应 tick 的时间，Unix 秒
- `created_at*`: integer，summary 记录创建时间，Unix 秒

错误码：

- `4004`：`origin_id` / `world_id` 都缺失，或二者不匹配
- `20201`：`world_id` 不存在或已软删除

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

返回 origin 模板列表。origin 是 world 的模板，可被复制为 world。列表项默认返回 `info + stats`。默认 `scene=popular`；`scene=uid` / `scene=mine` 按 `origin.updated_at DESC` 排序，其他场景按 `copy_cnt DESC` 排序，`scene=foryou` 取所有 origin。`scene=popular` 时，每个列表项额外返回 `discusses`，包含该 origin 最新 2 条已审核通过的顶级评论。匿名可访问；仅 `scene=mine` 需要登录。

Query：

- `pn`: integer，页码，从 1 开始
- `rn`: integer，每页条数，默认 10，最大 100
- `tag_id`: integer，按 tag 过滤
- `keyword`: string，模糊搜索 `origin_name` / `brief`
- `scene`: string，场景；默认 `popular`，可用值包括 `popular`、`foryou`、`uid`、`mine`、`tag`
- `uid`: string，`scene=uid` 时传入目标用户 uid；`scene=mine` 时不传
- `tag`: string，`scene=tag` 时传入标签名

响应 `data`：

- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `list*`: `{ info: OriginInfo, stats: OriginStats, discusses?: DiscussItem[] }[]`；`discusses` 仅 `scene=popular` 返回，最多 2 条顶级评论

### GET `/api/v1/origin/hot_tags`

返回 origin 热门 tag。当前服务端固定返回 5 个 tag，后续可替换为 DB 聚合。匿名可访问，不需要登录。

请求参数：无。

响应 `data`：

- `list*`: string[]

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

### GET `/api/v1/origin/foredit`

返回 owner 编辑 origin 时需要的原始可编辑数据。接口需要登录，且当前用户必须是该 origin 的 owner。与 `origin/detail` 不同，响应 `data` 是平铺的编辑模型，不包含 `stats` 和 `ticks`。

Query：

- `origin_id*`: string

响应 `data`（`OriginForEditResp`）：

- `origin_id*`: string
- `origin_name*`: string
- `origin_version`: string
- `brief`: string
- `setting`: string
- `events`: string[]
- `tags`: string[]
- `metric`: `WorldMetric`
- `started_at`: string，故事内起始时间文本
- `tick_duration_time`: string，每个 tick 推进的故事时间跨度文本，例如 `1 day`
- `cover`: string 或 `ImageResource`
- `map_url`: string
- `characters`: `OriginCharacterUpsert[]`
- `locations`: `OriginLocationUpsert[]`

错误码：

- `10001`: ErrorUserNotLogin
- `10011`: ErrorUserNotAccess，当前用户不是该 origin 的 owner
- `20101`: ErrorOriginNotExist，`origin_id` 不存在或已软删除

### POST `/api/v1/origin/create`

登录用户基于完整的 `info + characters + locations` 创建新的 origin 模板。服务端生成 `origin_id`（前缀 `o_`），`owner_uid` 取自 session，不接受请求体覆盖；`tags` 会去除首尾空白、过滤空值、去重后写入 `tbl_origin.tags`，并同步 `tbl_tag` / `tbl_origin_tag`。

服务端行为：

- 批量插入 `tbl_world_character(world_id=origin_id)` 与 `tbl_world_location(world_id=origin_id)`。
- 同步 `character_cnt` / `location_cnt` 初值到主表。
- `locations` 作为用户平级编辑 location 入参；服务端忽略 `level` / `location_pid`，再调用 `origin_init_tags_locations` 生成入库用三级树。
- 按数组顺序将 `char_id` 重写为 `char_1...`，并同步重写 `character.initial_location_id` 中的临时 location 引用。
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
- `tick_duration_time`: string，每个 tick 推进的故事时间跨度文本；为空时服务端写默认 `1 day`
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
- `level`: integer，兼容字段；create/update 时服务端忽略
- `location_pid`: string，兼容字段；create/update 时服务端忽略，当前客户端不发送该字段，也不再为了提交强制补 root 或组织成树
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

### POST `/api/v1/origin/update`

登录用户更新自己创建的 origin 模板。服务端校验 `origin_id` 存在且 `owner_uid == session uid`；`origin_id` / `owner_uid` 不允许通过请求体变更。更新成功后服务端自动切到下一数字版本，并返回最新的 `info + stats + characters + locations + ticks`。

服务端行为：

- 使用 `origin_name` / `brief` / `setting` / `characters` / `locations.location_name` 调用 `origin_init_tags_locations`，在请求 `tags` 基础上追加生成 tags，再去空、去重、校验长度。
- `locations` 作为用户平级编辑 location 入参；服务端忽略 `level` / `location_pid` 并重新生成入库三级树。
- `characters` 只 upsert 请求列表中的项，不按缺失项推断删除；已有 `char_id` 保留，新增角色临时 id 会重写为下一个 `char_N`。
- `deleted_char_ids` / `deleted_location_ids` 显式软删命中的活跃角色或地点。
- `update_notes` 写入 `tbl_origin.update_notes`，后续生成版本快照时同步到 `tbl_origin_version.change_log`；客户端 publish 时要求用户填写。
- `tbl_origin.edit_data` 保存可编辑的平级原始数据，用于 `/api/v1/origin/foredit`。
- `ticks` 不在 update 范围内。

请求 body（`OriginUpdateReq`）：

- `origin_id*`: string
- `origin_name*`: string
- `origin_version`: string，服务端控制；每次更新成功自动进入下一数字版本
- `brief`: string
- `setting`: string
- `events`: string[]
- `tags`: string[]
- `metric`: `WorldMetric`
- `started_at`: string，故事内起始时间文本
- `tick_duration_time`: string，每个 tick 推进的故事时间跨度文本，例如 `1 day`
- `cover`: string
- `map_url`: string
- `characters`: `OriginCharacterUpsert[]`
- `locations`: `OriginLocationUpsert[]`
- `update_notes`: string，版本更新说明；客户端 publish 时必填
- `deleted_char_ids`: string[]，显式删除的角色 id
- `deleted_location_ids`: string[]，显式删除的 location id

响应 `data`：

- `info*`: `OriginInfo`
- `stats*`: `OriginStats`
- `characters*`: `Character[]`
- `locations*`: `Location[]`
- `ticks*`: `Tick[]`

错误码：

- `4004`
- `10001`
- `10011`
- `20101`

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

这些接口不在 `/api/v1` 下，而在 chatroom 服务前缀 `/aitown-chat` 下。当前 Flutter 侧通过 `GenesisApi.chatroomHttp` 使用独立 base URL，默认 `GENESIS_CHATROOM_HTTP_URL=https://api.worldo.ai/`；本地 mock 已覆盖这些路由。

### GET `/aitown-chat/api/ulocation`

获取指定世界内所有角色（AI + 真实用户）的位置信息，按地点分组返回。

数据来源：

- 所有角色从 `world.detail` 接口的 `characters` 字段获取
- 真实用户：`player_uid` 不为空，`location_id` 从在线 session 获取
- AI 角色：`player_uid` 为空，`location_id` 从 `world.detail` 获取

使用场景：

- 客户端收到 `world_change` 消息后，调用此接口刷新世界状态
- 客户端收到 `user_location_change` 消息后，调用此接口获取最新位置

Query：

- `world_id*`: string，世界实例 ID

响应 `data`：

- `world_id`: string，世界实例 ID
- `locations`: `{ location_id, characters: ChatroomLocationCharacter[] }[]`

`ChatroomLocationCharacter`：

- `char_id`: string，角色 ID
- `player_uid`: string，真实用户 UID；AI 角色为空字符串
- `player_username`: string，真实用户名；AI 角色为空字符串
- `name`: string，角色名称
- `location_id`: string，当前地点 ID

错误响应示例：

```json
{ "err_no": 400, "err_msg": "world_id 不能为空" }
```

### GET `/aitown-chat/internal/world/messages`

获取指定世界最近 50 条消息，并按 `location_id` 分组返回。

Query：

- `world_id*`: string，世界实例 ID

响应 `data`：

- `locations`: `{ location_id, messages: ChatroomMessageDTO[] }[]`

错误响应示例：

```json
{ "err_no": 1001, "err_msg": "参数错误: world_id is required" }
```

### GET `/aitown-chat/api/messages`

获取指定世界、指定地点的历史消息。`limit` 默认 20，最大 100。

Query：

- `world_id*`: string，世界实例 ID
- `location_id*`: string，地点 ID
- `since`: integer，起始消息 ID；`0` 表示获取最新
- `limit`: integer，默认 `20`，最大 `100`

响应 `data`：

- `messages`: `ChatroomMessageDTO[]`
- `has_more`: boolean，是否有更多消息
- `newest_message_id`: integer，最新消息 ID

### POST `/aitown-chat/internal/tick/lock`

Tick 服务锁定 world，chat 服务按 WebSocket 新协议广播 `tick_start`，阻止用户继续发送消息。

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

Tick 服务解锁 world，chat 服务按 WebSocket 新协议广播 `tick_done`，用户可以继续发送消息。

multipart form：

- `world_id`: string，世界实例 ID

响应 `data`：

- `unlocked`: boolean

### POST `/aitown-chat/internal/narrator/write`

旁白服务写入旁白消息，并按 WebSocket 新协议广播 `nar_new_message` 给对应 location 用户。

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

## Report 接口

### POST `/api/v1/report/create`

提交举报。登录或未登录用户均可提交；携带有效 session 时服务端记录 `reporter_uid`，未登录时保存为空字符串。

客户端运行时 header 会经 `GenesisApi` 自动注入。服务端读取并 trim / 截断这些客户端元数据：

- `device-id`：最长 128 字符
- `app-id`：最长 64 字符
- `app-version`：最长 64 字符
- `app-platform`：最长 32 字符

请求 body：

- `target_type*`: string，举报对象类型，枚举 `origin`、`world`、`tick`、`message`、`discuss`
- `target_id*`: string，举报对象业务 id；`message` 当前按 `message_id` 原样记录，不做存在性校验
- `content*`: string，举报内容；服务端 trim 后不能为空，最长 1000 字符

请求示例：

```json
{
  "target_type": "origin",
  "target_id": "o_A1B2C3",
  "content": "内容疑似违规"
}
```

响应 `data`：

- `report_id*`: string

响应示例：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "report_id": "rpt_X9KQ4M2A1B2C"
  }
}
```

错误码：

- `4004`：`target_id` 为空或 `content` 为空
- `20801`：`target_type` 不支持
- `20802`：`content` 超过 1000 字符

## Feedback 接口

### POST `/api/v1/feedback/create`

提交产品反馈。登录或未登录用户均可提交；携带有效 session 时服务端记录 `feedbacker_uid`，未登录时保存为空字符串。本接口没有 `target_type` / `target_id`。

客户端运行时 header 会经 `GenesisApi` 自动注入。服务端读取并 trim / 截断这些客户端元数据：

- `device-id`：最长 128 字符
- `app-id`：最长 64 字符
- `app-version`：最长 64 字符
- `app-platform`：最长 32 字符

请求 body：

- `content*`: string，反馈内容；服务端 trim 后不能为空，最长 1000 字符

请求示例：

```json
{
  "content": "希望增加夜间模式"
}
```

响应 `data`：

- `feedback_id*`: string

响应示例：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "feedback_id": "fbk_X9KQ4M2A1B2C"
  }
}
```

错误码：

- `4004`：`content` 为空
- `20901`：`content` 超过 1000 字符

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

截至 2026-06-18，本文档覆盖的 46 个接口已完成主要 HTTP 契约对齐；本次更新的 App 版本升级检查接口已按文档补齐当前封装、本地 mock 与测试：

| Apifox 接口 | 当前实现状态 |
| --- | --- |
| `POST /api/v1/app/version/check` | 已新增 `AppV1Api.versionCheck`，body 使用 `app_id/platform/channel/version_name/version_code/device_id/uid`，响应消费 `need_upgrade/force_upgrade/latest_version_name/latest_version_code/min_version_code/upgrade_type/title/content/download_url/store_url/package_size/package_md5/can_ignore`；`ForceUpgradeGate` 会在启动、回前台和登录态变化后检查，强更命中时阻断继续使用；本地 mock 默认返回无升级。 |
| `POST /api/v1/user/oauth/google` | `UserV1Api.googleAuth` 与 `GenesisApi.loginWithGoogle/loginWithIdentity` 已走 `/user/oauth/google`，body 使用 `id_token/nonce/name/avatar`。 |
| `POST /api/v1/user/oauth/apple` | `UserV1Api.appleAuth` 与 `GenesisApi.loginWithApple/loginWithIdentity` 已走 `/user/oauth/apple`，body 使用 `id_token/nonce/name/avatar`；不再向后端发送 `firebase_id_token`。 |
| `POST /api/v1/user/logout` | `GenesisApi.logout` 已走 `/user/logout`。 |
| `POST /api/v1/user/delete` | `UserV1Api.deleteAccount` 与 `GenesisApi.deleteAccount` 已走 `/user/delete`，Settings 确认后由 `BackendAuthCoordinator.deleteAccount` 用清理前 token 后台提交并立即清本地登录态。 |
| `GET /api/v1/user/info` | `UserV1Api.info` 支持可选 `uid` query；`bindDevice/hasAuthenticatedSession/getUser/getDisplayUserCode` 已切到该接口。 |
| `POST /api/v1/user/follow` | `FollowV1Api.follow` body 已改为 `target_uid`，响应按空对象处理。 |
| `POST /api/v1/user/unfollow` | `FollowV1Api.unfollow` body 已改为 `target_uid`，响应按空对象处理。 |
| `GET /api/v1/user/following` | 已新增 `FollowV1Api.following(uid,pn,rn)`。 |
| `GET /api/v1/user/followers` | 已新增 `FollowV1Api.followers(uid,pn,rn)`。 |
| `GET /api/v1/world/list` | `WorldV1Api.list` query 已使用 `scene/tag/origin_id/uid/keyword/pn/rn`；自有数据只传 `scene=mine`，指定用户数据传 `scene=uid&uid=...`，标签数据传 `scene=tag&tag=...`；首页和个人 world 列表可消费 `list[].info + stats`。 |
| `GET /api/v1/world/info` | 已新增 `WorldV1Api.info(worldId)` 与 `GenesisApi.getWorldInfo(wid)`，query 使用 `world_id`；响应消费 `info + stats`，不期待 `relation_status/characters/locations/ticks`。 |
| `GET /api/v1/world/detail` | `WorldV1Api.detail` query 只使用 `world_id`；详情 mapper 支持 `info.metric`、`relation_status`、`locations[].location_description/location_paragraph/location_timestamp/dialogue` 与 `ticks[].tick_no/tick_result.paragraphs/location_groups`，不再消费旧 `wid` / `tick_index` / 顶层 `narrator` / `character_details` 别名。 |
| `GET /api/v1/world/tick/list` | 已新增 `WorldV1Api.tickList(worldId,pn,rn)` 与 `GenesisApi.getWorldTicks(wid,limit,offset)`；query 使用 `world_id/pn/rn`，响应按 `Tick` 列表规范化并保持最新 tick 在前。 |
| `GET /api/v1/world/origin_progress` | 已新增 `WorldV1Api.originProgress(uid,originId)`，query 使用 `uid/origin_id`，响应消费 `world_id/tick_cnt`；origin discuss loader 会用该接口补齐每条评论作者在当前 origin 下的 world 与 tick 进度。 |
| `POST /api/v1/world/tick` | 新契约替代旧 progress 触发接口；客户端应提交 `{ "world_id": "<world_id>" }` 并消费 `world_id/tick_cnt/last_tick`。 |
| `GET /aitown-chat/api/ulocation` | `ChatroomHttpApi.getUserLocations(worldId)` query 使用 `world_id`，响应消费 `locations[].characters[]`，角色字段为 `char_id/player_uid/player_username/name/location_id`；`WorldChatroomService` 用 `player_uid` 识别真实用户并刷新所在 location，本地 mock 从 world detail 角色列表生成同形状响应。 |
| `GET /aitown-chat/internal/world/messages` | `ChatroomHttpApi.getWorldMessages(worldId)` query 使用 `world_id`，响应消费 `locations[].location_id/messages[]`；`ChatroomHttpMessage` 只按新 DTO 解析 `global_message_id/message_id/location_message_id/current_time/tick_no/created_at`。 |
| `GET /aitown-chat/api/messages` | `ChatroomHttpApi.getMessages(worldId,locationId,since,limit)` query 使用 `world_id/location_id/since/limit`，响应消费 `messages/has_more/newest_message_id`；本地 mock 返回新 `MessageDTO` 字段。 |
| `POST /aitown-chat/internal/tick/lock` | 已新增 `ChatroomHttpApi.lockWorld(worldId)`，按 Apifox 同时发送 query `world_id` 与 multipart form `world_id`，响应消费 `locked`。 |
| `GET /aitown-chat/internal/tick/progress` | 已新增 `ChatroomHttpApi.tickProgress(worldId)`，响应消费 `progress/pending_messages/active_llm_calls`。 |
| `POST /aitown-chat/internal/tick/unlock` | 已新增 `ChatroomHttpApi.unlockWorld(worldId)`，multipart form 发送 `world_id`，响应消费 `unlocked`。 |
| `POST /aitown-chat/internal/narrator/write` | 已新增 `ChatroomHttpApi.writeNarrator(worldId,tickId,locationGroups)`，body 使用 `world_id/tick_id/location_groups`，响应消费 `message_id`；本地 mock 会写入 narrator 消息。 |
| `GET /api/v1/search` | `SearchV1Api.search` 已改为发送 `keyword/type/pn/rn`；`type` 为空时不随 query 发送，表示全局搜索；`SearchPage` 已消费 `origins/worlds/users` 分类结果块。 |
| `GET /api/v1/origin/list` | `OriginV1Api.list` query 已使用 `scene/tag/tag_id/keyword/uid/pn/rn`；自有数据只传 `scene=mine`，指定用户数据传 `scene=uid&uid=...`，标签数据传 `scene=tag&tag=...`；origin 页面和主 `getOrigins/getMyLaunchedOrigins` 可消费 `list[].info + stats`；首页 popular 会优先消费 `list[].discusses` 作为最新 2 条讨论预览，本地 mock 仅默认/`popular` 场景返回该字段。 |
| `GET /api/v1/origin/hot_tags` | 已新增 `OriginV1Api.hotTags`，响应消费 `data.list` 字符串数组；`OriginPage` 固定首个 `For you` tab，其余 tabs 来自热门标签接口并缓存在本地，本地 mock 返回同形状数据。 |
| `GET /api/v1/origin/info` | 已新增 `OriginV1Api.info(originId)` 与 `GenesisApi.getOriginInfo(oid)`，query 使用 `origin_id`；响应消费 `info + stats`，不期待 `characters/locations/ticks`。 |
| `GET /api/v1/origin/detail` | `OriginV1Api.detail` query 已使用必填 `origin_id`；详情 mapper 支持 `info.metric`、`info.events`、`info.started_at`、`locations[].location_description` 与 `ticks[].tick_result`，local mock 返回 `info/stats/characters/locations/ticks`。 |
| `GET /api/v1/origin/foredit` | 已新增 `OriginV1Api.forEdit(originId)`，query 使用 `origin_id`，响应按平铺 `OriginForEditResp` 消费，包含当前 `origin_version`、`tick_duration_time` 与 `metric.label_note`；`EditOriginPage` 进入编辑流时使用该接口，本地 mock 返回同形状 `characters/locations` 且不返回 `stats/ticks`。 |
| `POST /api/v1/origin/create` | `OriginV1Api.create` body 已使用 `origin_name/origin_version/brief/setting/events/tags/metric/started_at/tick_duration_time/cover/map_url/characters/locations`，其中 Basics 的 `Label note` 写入 `metric.label_note`；`GenesisApi.createOrigin` 会把旧草稿里的 `tick_duration_days` 转为 Apifox 要求的文本，例如 `30 days`；本地 mock 兼容该字段并返回最新 `info/stats/characters/locations/ticks`。 |
| `POST /api/v1/origin/update` | `OriginV1Api.update` body 已使用 `origin_id/origin_name/origin_version/brief/setting/events/tags/metric/started_at/tick_duration_time/cover/map_url/characters/locations/update_notes/deleted_char_ids/deleted_location_ids`，其中 Basics 的 `Label note` 写入 `metric.label_note`；`GenesisApi.updateOrigin` 会把旧草稿里的 `tick_duration_days` 转为 Apifox 要求的文本，例如 `30 days`；`EditOriginPage` 基于初始 `foredit` draft 计算显式删除 id，本地 mock 返回最新 `info/stats/characters/locations/ticks`。 |
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
| `POST /api/v1/report/create` | 已新增 `ReportV1Api.create`，body 使用 `target_type/target_id/content`，响应消费 `report_id`；World、Worldo、用户详情页和 location chat 长按菜单已接入；通过共享 `GenesisApi` runtime header path 自动带上 `device-id/app-id/app-version/app-platform/authorization`；本地 mock 校验 `target_type`、空 `target_id/content` 与 1000 字符长度限制，并为用户详情页 report 补充接受 `target_type=user`。 |
| `POST /api/v1/feedback/create` | 已新增 `FeedbackV1Api.create`，body 使用 `content`，响应消费 `feedback_id`；通过共享 `GenesisApi` runtime header path 自动带上 `device-id/app-id/app-version/app-platform/authorization`；本地 mock 校验空 `content` 与 1000 字符长度限制。 |
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
- 多数 Apifox 页面未声明 headers/security；当前客户端仍按应用运行时注入 `app-id`、`app-version`、`app-platform`、`device-id`、`authorization: Bearer <token>`，其中 report 和 feedback 页面明确声明会读取这些客户端元数据 header。

### Apifox 未覆盖但当前 v1 已封装的接口

用户与关系：

- `POST /api/v1/user/update`
- `GET /api/v1/user/profile`
- `GET /api/v1/user/origins`
- `GET /api/v1/user/worlds`
- `GET /api/v1/user/relations`
- `POST /api/v1/users/relations/status`

Origin：

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
- `POST /api/session/set-player-scene`
- `GET /api/points/{pointId}/messages`
- `POST /api/points/{pointId}/messages/enqueue`
- `GET /health`
