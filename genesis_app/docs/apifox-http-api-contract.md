# Apifox HTTP 接口文档与当前实现差异

来源：
- Apifox 分享页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/460308499e0
- Apifox Origin 模板列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/461433666e0
- Apifox Origin 热门标签页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/465715733e0
- Origin detail 增量契约：`/Users/ionix/Downloads/origin_detail_new.md`
- Apifox world tick 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462798656e0
- Apifox world tick 列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/469083051e0
- World tick 列表增量契约：`/Users/ionix/Downloads/new_tick_list.md`
- Apifox discuss 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462474822e0
- Apifox discuss 回复分页页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/466619391e0
- Apifox direct_message 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462474827e0
- Apifox direct_message 会话列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462474828e0
- Apifox upload 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463764231e0
- Apifox notify 未读数页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463874827e0
- Apifox notify 通知列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463874828e0
- Apifox notify 标记已读页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/463874829e0
- Apifox search 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/465724653e0
- Collect 客户端批量上报协议：当前 Flutter 实现
- Report 提交举报：`/Users/ionix/Downloads/report.md`
- Feedback 提交反馈：`/Users/ionix/Downloads/feedback.md`
- Apifox chatroom 获取角色位置列表页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/470909609e0
- Apifox chatroom 世界最近消息页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/465850374e0
- Apifox chatroom 历史消息页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446394e0
- Apifox chatroom tick lock 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446395e0
- Apifox chatroom tick progress 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446396e0
- Apifox chatroom tick unlock 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446397e0
- Apifox chatroom narrator write 页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/462446399e0
- Chatroom 图片消息增量说明：`/Users/ionix/Downloads/2026-07-27-image-message-support.md`
- V2 Origin 完整编辑详情：`/Users/ionix/Downloads/foredit_v2.md`
- 查询我 launch 过的 preset 角色：`/Users/ionix/Downloads/launched.md`
- App 版本升级检查：`/Users/ionix/Downloads/version_check.md`
- Apifox LLM 索引：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/llms.txt

提取时间：2026-06-15

图片消息增量核对时间：2026-07-28

World tick 列表增量核对时间：2026-08-05

Origin detail 增量核对时间：2026-08-05

本文档记录 Flutter 项目当前对齐或待替换的 Apifox HTTP 接口，并对比当前 Flutter 项目中的 `lib/network` HTTP 设计。字段后带 `*` 表示 Apifox 标记为必填。

## 总览

本文档当前覆盖 58 个接口，分为 `app`、`用户`、`origin`、`world`、`chatroom`、`search`、`discuss`、`direct_message`、`notify`、`report`、`feedback`、`collect` 和 `upload` 十三组：

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
| 用户 | GET | `/api/v1/user/memory-settings` | 查询当前用户全局 Memory 预算及指定 Worldo 用量 |
| 用户 | POST | `/api/v1/user/memory-settings` | 保存全局 Memory 预算 |
| 用户 | GET | `/api/v1/user/world-history-settings` | 查询当前用户 World History 水位设置 |
| 用户 | PUT | `/api/v1/user/world-history-settings` | 原子更新当前用户 World History 水位设置 |
| 用户 | DELETE | `/api/v1/user/world-history-settings` | 重置当前用户 World History 水位设置 |
| world | GET | `/api/v1/world/list` | World 列表 |
| world | GET | `/api/v1/world/detail` | World 详情 |
| world | GET | `/api/v1/world/map` | 读取 World 2.5D 地图 |
| world | GET | `/api/v1/world/tick/list` | 分页获取 world 下的 tick 列表 |
| world | GET | `/api/v1/world/origin_progress` | 用户在某 origin 下的最大 world tick 进度 |
| world | POST | `/api/v1/world/tick` | world owner 触发一次 tick |
| chatroom | GET | `/aitown-chat/api/ulocation` | 获取角色位置列表 |
| chatroom | GET | `/aitown-chat/internal/world/messages` | 获取世界最近消息 |
| chatroom | GET | `/aitown-chat/api/messages` | 获取旧协议历史消息（兼容/诊断） |
| chatroom | GET | `/aitown-chat/api/v2/messages` | 获取 V2 地点历史消息 |
| chatroom | POST | `/aitown-chat/internal/tick/lock` | 锁定 World |
| chatroom | GET | `/aitown-chat/internal/tick/progress` | 轮询 Tick 进度 |
| chatroom | POST | `/aitown-chat/internal/tick/unlock` | 解锁 World |
| chatroom | POST | `/aitown-chat/internal/narrator/write` | 写入旁白消息 |
| search | GET | `/api/v2/search` | Meilisearch 全局搜索 |
| origin | GET | `/api/v1/origin/list` | Origin 模板列表 |
| origin | GET | `/api/v1/origin/feed` | 按设备去重的 For you 推荐流 |
| origin | POST | `/api/v1/origin/feed/exposure` | 上报 For you 可见项 |
| origin | GET | `/api/v1/origin/hot_tags` | Origin 热门标签 |
| origin | GET | `/api/v1/origin/my_launch_preset_characters` | 查询我 launch 过的 preset 角色 |
| app | GET | `/api/v1/app/config` | App 启动全局配置 |
| origin | GET | `/api/v1/origin/detail` | Origin 模板详情 |
| origin | GET | `/api/v1/origin/map` | 读取 Origin 2.5D 地图 |
| origin | GET | `/api/v2/origin/foredit` | 获取 V2 Origin 完整编辑详情 |
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
| collect | POST | `https://collect.worldo.ai/api/v1/collect` | 批量提交客户端行为事件 |
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

### ImageResource

- `sm_url*`: string，小尺寸图片 URL；旧字符串数据会与 `xl_url` 相同
- `xl_url*`: string，原尺寸图片 URL；旧字符串数据会与 `sm_url` 相同
- `object_key*`: string，原尺寸图片 OSS 对象 key；旧字符串数据为空串

### UserInfo

- `uid*`: string
- `name*`: string
- `avatar*`: string 或 `ImageResource`
- `deleted`: boolean，用户是否已软删除
- `gender`: string，未填写为 `""`；枚举 `Male` / `Female` / `Non_binary`
- `age`: string，未填写为 `""`；枚举 `18-24` / `25-34` / `35-44` / `45+`
- `membership_status`: integer，0 未开通或待付款未获得权益，1 当前有效，2 曾开通过但当前失效。所有返回 UserInfo 的接口使用同一语义；余额、是否自动续费不参与标识判断。
- `bio`: string
- `last_login_at`: integer，Unix 秒时间戳
- `create_at`: integer，Unix 秒时间戳
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
- `definition_version*`: integer，地图定义版本；`1` 为旧版地图，`2` 为新版 2.5D 地图
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

### OriginDetailInfo

`origin/detail` 使用的只读基本信息；它不同于 Create/Update 兼容链使用的 `OriginInfo`，不包含 `setting/events/started_at/tick_duration_days`。

- `origin_id*`: string
- `origin_name*`: string
- `origin_version*`: string
- `origin_version_time`: integer，版本时间 Unix 秒
- `definition_version*`: integer，`1` 为旧版地图，`2` 为新版 2.5D 地图
- `language*`: string，内容语言
- `current_time*`: string，最新 tick 的当前故事时间；尚未 tick 时为空串
- `owner_uid*`: string
- `owner_name*`: string
- `owner_user*`: `UserInfo`
- `brief*`: string
- `tags*`: string[]
- `metric*`: `WorldMetric`
- `created_at*`: integer，Unix 秒
- `cover*`: `ImageResource`
- `map_url*`: string
- `status*`: integer，`10` 正常，`20` 处理中

### WorldInfo

- `world_id*`: string
- `world_name*`: string
- `origin_id`: string
- `origin_version`: string
- `origin_version_time`: string
- `definition_version*`: integer，地图定义版本；`1` 为旧版地图，`2` 为新版 2.5D 地图
- `last_chat_location_id*`: string，`world/detail` 返回当前用户最后聊天的 location ID；没有记录时为空字符串，其他复用 `WorldInfo` 的端点不保证返回。客户端每次进入 World 时用该字段初始化地图和 Location List 的 Recent Message 标签；本次页面会话内发送成功后，再由内存中的临时记录即时覆盖
- `owner_uid`: string，创建者 uid，来自 `tbl_world.owner_uid`
- `owner_name`: string，创建者姓名；用户不存在时为空串
- `brief`: string
- `setting`: string
- `events`: string[]
- `metric`: `WorldMetric`
- `created_at`: integer，Unix 秒
- `last_active_at`: integer，Unix 秒；world 最近一次活跃时间，My Worlds 卡片使用此字段显示时间
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
- `player_uid*`: string；origin 模板中为空串
- `player_username*`: string
- `player_user*`: `UserInfo`
- `player_joined_at*`: integer，Unix 秒；未绑定玩家时为 `0`
- `name*`: string
- `identity*`: string
- `brief*`: string
- `goal*`: string
- `avatar*`: `ImageResource`
- `initial_location_id*`: string
- `location_id*`: string，当前 location
- `metric_value*`: integer
- `delta*`: integer

`OriginDetailCharacter` 在 `Character` 基础上增加：

- `is_recommend*`: integer，`0` 不推荐、`1` 推荐

### Location

- `location_id*`: string
- `level`: integer，顶层为 `1`
- `location_pid`: string
- `location_name*`: string
- `location_description`: string，仅 world detail 兼容使用；origin detail 不返回
- `location_paragraph`: string，最新段落，每次 tick P1 后可能变化
- `location_timestamp`: string，最新故事时间戳，每次 tick P1 后可能变化
- `location_summary`: string，地点当前摘要，地点列表优先展示
- `image`: string
- `x_percent`: integer
- `y_percent`: integer
- `map_url`: string，当前 location 的地图图片 URL
- `dialogue`: `DialogueLine[]`

### Tick

- `tick_id*`: string
- `tick_no*`: integer
- `sub_tick_no*`: integer，当前 tick 内的子 tick 序号
- `status*`: integer；`20` chat_running、`30` p1_running、`40` p1_done、`50` done、`90` failed，`45` p2_running 仅历史兼容；`GET /world/tick/list` 只返回 `50`
- `tick_result*`: `WorldTickResult`
- `created_at*`: integer，Unix 秒

`WorldTickResult`：

- `current_time*`: string，P1 返回的当前故事时间
- `narrator*`: string
- `paragraphs*`: `TickParagraph[]`
- `location_groups`: `LocationGroup[]`；world tick list 必填，origin detail 不返回

`TickParagraph`：

- `location_id*`: string
- `timestamp*`: string，故事内时间戳，例如 `Day 1, 19:10`
- `text*`: string
- `visibility*`: string，枚举为 `public` 或 `char_only`
- `visible_to*`: string[]；`char_only` 时为可见角色 ID，`public` 时为空数组
- `clue*`: string，为可见角色提供的行动线索或提示
- `character_deltas*`: `CharacterDelta[]`

`CharacterDelta`：

- `char_id*`: string
- `name`: string
- `delta*`: integer，指标增量；prompt 字符串结果由服务端归一为整数

`LocationGroup`（字段均可选）：

- `location_id`: string
- `location_name`: string
- `location_summary`: string
- `characters`: `{ char_id, name }[]`
- `initial_dialogue`: `{ char_id, char_name, name, content }[]`

### ChatroomMessageDTO（旧协议）

- `global_message_id`: integer，全局递增消息 ID
- `message_id`: integer，world 级别递增消息 ID
- `location_message_id`: integer，location 级别递增消息 ID；location 时间线记录可能返回正数或 `0`。正数与普通消息一样参与 location 连续性、补洞和 `since` 游标；零值记录没有 location cursor，必须按下述 legacy 兼容边界处理
- `location_id`: string，地点 ID；世界级消息可能为空
- `conversation_round_id`: integer，对话轮次 ID
- `sender_type`: string，`user`、`character`、`narrator`、`npc`、`tick`、`user_enter_location`、`story_events` 或 `characters_moved`
- `sender_id`: string，发送者 ID
- `sender_name`: string，发送者名称
- `user_id`: string 或 null，用户消息时非空
- `content`: string，普通消息为消息内容；`user_enter_location` 为纯文本入场文案；`story_events`、`characters_moved` 为对应 payload 的 JSON 编码字符串
- `message_type`: string，消息内容类型；`text` 表示文本，`image` 表示图片且 `content` 保存图片 URL。Flutter 读取时去除首尾空白并转为小写；字段缺失时，旧 `sender_id=nar_pic` 消息兼容为 `image`，其他发送方按 `text`；字段存在但为 `null` 或空字符串时按 `text`。只有 `image + nar_pic` 渲染图片，其他图片发送方和未知非空类型保留在消息模型和缓存中但不渲染
- `current_time`: string，世界时间，tick advance 时非空
- `tick_no`: integer，Tick 序号，仅 tick 相关消息时非零
- `sub_tick_no`: integer，可选的子 Tick 序号；正数时 UI 与 `tick_no` 组合显示为 `Tick {tick_no}-{sub_tick_no}`
- `created_at`: string，创建时间，格式为 `2006-01-02 15:04:05`

location 时间线 payload：

- `user_enter_location`: 新版记录直接使用顶层 `sender_id`、`location_id` 与纯文本 `content`；旧 `{ char_id, to_location_id, text }` JSON content 继续兼容
- `story_events` 兼容两种等价形态：
  - grouped：`{ location_id, location_name, paragraphs }`，其中 `paragraphs[]` 为 `{ timestamp, visibility, visible_to, text, clue }`
  - flat single-event：`{ location_id, timestamp, visibility, visible_to, text, clue }`；客户端将其归一化成 `location_name: ""` 且只包含这一项的 `paragraphs[]`
  - 两种形态中的 `visibility` 均为 `public` 或 `char_only`；`char_only` 必须提供非空 `visible_to`
- `characters_moved`: `{ movements }`，其中 `movements[]` 为 `{ char_id, to_loc_id }`

这些记录均可进入 location 本地消息队列。任何带正数 `location_message_id` 的记录都按地点游标维护连续窗口、补洞、`since` 分页、本地 key 和去重。只有遗留零游标 `tick`（`tick_advance` 投影）按 world `message_id` 插入时间线，并在本地分页/旧区段删除时使用配套 world cursor；零游标 `user_enter_location/story_events/characters_moved` 仅作为可展示的兼容记录保留，并可按 `message_id` 后备去重，但不参与 location 连续性、gap、分页边界或 gap 区段删除。服务端单地点响应中的 `location_id` 为空时，客户端使用请求的 `location_id` 分桶。

合法的 `characters_moved` 使用独立人物去向气泡，逐行显示“角色名 has gone to 地点名”；角色或地点名称无法从本地 world 缓存解析时回退到对应 ID。地点名可以点击：目标与当前地点不同时切换到目标地点聊天；V2 Tilemap 同步登记目标地点，使退出聊天后恢复到承载目标地点的父级地图。HTTP 与 WebSocket 来源使用完全相同的 VM、气泡和点击规则。

旧版 WebSocket `characters_moved` envelope 若缺少 `msg_id`，客户端仍会先生成仅存在于内存的临时正式消息并立即加入所有叶子地点队列；随后对有地点的通知请求该地点的 V2 messages，对无地点通知限并发刷新当前世界的叶子地点，并用相同 movements payload 的 canonical `message_id/location_id` 原位替换、持久化该临时项。V2 地点聊天运行时不调用 internal world messages 或 legacy messages 接口。HTTP 暂时失败不会阻止本次 WSS 气泡显示。

旧 `/aitown-chat/api/messages` 返回的 `user_enter_location` 会进入队列、缓存并复用现有入场系统气泡；只有正数 `location_message_id` 参与地点连续性，零游标记录仅展示。其他用户的新入场记录计入新消息提示，当前用户自己的记录仍按通用 self-message 规则排除。

### ChatroomV2MessageDTO

- `type*`: string，业务类型；持久化消息从 `sender_type` 派生。`sender_type=narrator` 时仅 `sender_id=nar/nar_pic` 保持 `narrator`，其他 sender 降级为 `character`；P1/P1I 地点内容为 `tick`
- `stream_type*`: string，非流式消息为空；流式消息为 `llm_stream_start`、`llm_chunk` 或 `llm_stream_end`，与业务 `type` 独立
- `ts*`: integer，毫秒时间戳
- `world_id`、`location_id`、`session_id`: string，消息上下文 ID
- `global_message_id`、`message_id`、`location_message_id`、`conversation_round_id`: integer，完整消息 ID；V2 不使用旧 WS 的缩写 ID 字段
- `sender_type`、`sender_id`、`sender_name`、`user_id`: string，发送者元数据
- `client_msg_id`: string，ACK 关联 ID，位于顶层
- `message_type`: string，`text` 或 `image`
- `min_app_version`: integer，消息最低客户端版本
- `created_at`: string，服务端创建时间
- `payload*`: object，业务字段容器；普通消息内容为 `payload.content`
- `err_no*`: integer，业务错误码；成功为 `0`
- `err_msg*`: string，业务错误信息

`type=tick` 的合法 `payload` 使用 `{ current_time, tick_no, sub_tick_no, global, story_events, characters_moved }`。`story_events[]` 使用 `{ location_id, timestamp, visibility, visible_to, text, clue }`，`characters_moved[]` 使用 `{ char_id, old_loc_id, to_loc_id }`。历史纯文本或服务端无法结构化的 Tick 回退为 `{ content }`。客户端完整保留原始 `payload`，同时解析 typed Tick payload；一个 canonical Tick 只占用自己正数 `location_message_id` 对应的缓存/分页行，派生的 global、story 和 movement 气泡不再各自写入 SQLite 或推进游标。

V2 WebSocket 额外支持 `type=waiting_conversation_round` 控制事件：`stream_type=""`，顶层携带 `world_id/location_id/conversation_round_id`，`payload={}`。客户端按地点禁用 Send 按钮和发送/重试入口，直到 `sender_type=character`、同地点、同 round 且 `streaming=false` 的完整消息到达；流式 start/chunk、其他 sender type、其他地点或其他 round 均不解锁。用户主动发送后建立的 conversation 等待锁使用相同解锁规则。该控制事件不渲染、不落库、无超时和独立 unlock；自动重连期间保留，显式断开时清除。该事件只向最终握手 `x-app-version` 为有效语义版本且 `>0.3.3` 的 V2 客户端发送。

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

客户端不使用本接口反查或恢复 UID。当前账号查询前会先校验本地 UID；UID 缺失或为 `guest_` UID 时，直接清除 UID、Token 和缓存用户资料并按未登录处理。启动和会话校验还会同时检查 `auth token`，登录态不完整时同样清理。查看公开用户资料时继续显式传 `uid`。

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

### GET `/api/v1/user/memory-settings`

查询当前登录用户的全局 Memory 预算；传 Worldo 时同时返回其实际用量。可选 query：

- `world_id`: string；省略或空白只返回全局预算，非空时额外返回指定 Worldo 的实际用量。

响应 `data`：

- `memory_tokens*`: integer，全局 Memory 预算
- `min_memory_tokens*`: integer，允许提交的正值下限
- `max_memory_tokens*`: integer，允许提交的上限
- `world_id`: string，仅 Worldo 查询返回
- `memory_used_tokens`: integer，仅 Worldo 查询返回；当前 Worldo 的实际用量，允许为 `0`，且不超过当前全局预算

Memory & Model 页面从响应的 `min_memory_tokens` / `max_memory_tokens` 读取滑杆上下限，已保存预算读取 `memory_tokens`；显示、映射和保存结果校验均使用接口范围。当前滑杆按对数映射、1K 步长取整，接口上下边界即使不足整 K 也保持原值且可达。`memory_used_tokens` 展示实际用量，本页数字向上取整至整数 K，1000K 显示为 1M。

### POST `/api/v1/user/memory-settings`

保存全局 Memory 预算。JSON body：

- `memory_tokens*`: integer；必须位于接口返回范围内

客户端不得发送 `world_id`，成功响应为全局设置且允许缺少 `world_id/memory_used_tokens`。仅 `err_no=0` 表示成功；旧 PUT 路由不再使用。系统错误、超时或连接中断属于不确定结果，客户端应对全局 GET 核对，不自动重试或将核对结果改判为保存成功。Memory 保存失败（含不确定结果）时，滑杆恢复最近一次成功预算，清除待提交操作，退出页面不重发失败请求。

### GET `/api/v1/user/world-history-settings`

查询当前登录用户的 World History 水位。响应 `data`：

- `high_watermark*`: integer，当前生效高水位
- `low_watermark*`: integer，当前生效低水位
- `stored_high_watermark*`: integer，持久化高水位；使用默认值时为 `0`
- `stored_low_watermark*`: integer，持久化低水位；使用默认值时为 `0`
- `source*`: string，例如 `default`
- `degraded*`: boolean

### PUT `/api/v1/user/world-history-settings`

原子更新当前登录用户的两个 World History 水位。JSON body 两个字段都必填：

- `high_watermark*`: integer，范围 `20..30`
- `low_watermark*`: integer，范围 `10..20`

响应 `data` 与 GET 相同。

### DELETE `/api/v1/user/world-history-settings`

删除当前用户保存的水位值并恢复服务端默认值。请求 body：无。响应 `data` 与 GET 相同。

## Origin / World 接口

### GET `/api/v1/world/list`

返回 world 列表。world 由 origin 复制而来，列表项只返回 `info + stats`，详情接口返回角色、location、ticks。

Query：

- `pn`: integer，默认 1
- `rn`: integer，默认 10
- `scene`: string，场景；自有数据传 `mine`，指定用户传 `uid`，标签筛选传 `tag`
- `tag`: string，`scene=tag` 时传入标签名
- `gender`: string，可选，枚举 `Male` / `Female` / `Non_binary`；默认不传，未传或空表示未指定
- `origin_id`: string，仅查询基于该 origin 复制出的 world
- `uid`: string，`scene=uid` 时传入目标用户 uid；`scene=mine` 时不传
- `keyword`: string，模糊搜索 `world_name` / `brief`

响应 `data`：

- `total*`: integer
- `pn*`: integer
- `rn*`: integer
- `list*`: `{ info: WorldInfo, stats: WorldStats }[]`

每个 `list[].info` 额外明确包含：

- `definition_version*`: integer，地图定义版本；`1` 为旧版地图，`2` 为新版 2.5D 地图
- `default_map_location_id*`: string，默认展示地图的 location id；`root` 表示根地图

Me 页 Playing 使用 `getMyWorldsPage` 保留响应 `total`；Worldo 使用 `getMyLaunchedOrigins` 的 `total`。两个 Tab 的 count 均显示接口总数，不使用已加载列表长度。列表独立按 `scene=mine`、`rn=30`、`pn=1,2,...` 分页；下一页追加并按实体 ID 去重，达到总数或返回空页后停止。切换 Tab 保留已加载分页，下拉刷新重新请求第一页；分页失败保留内容并支持重试。原 `getMyWorlds` 列表返回形式继续供其他调用方使用。

其中 `info.last_active_at` 为 world 最近一次活跃时间（Unix 秒）；My Worlds 卡片时间以该字段为准，不读取 `last_tick.created_at`。

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

返回单个 world 的完整详情：基本信息、统计信息、角色列表和 location。`info` 返回 `definition_version` 和当前用户的 `last_chat_location_id`，后者用于客户端进入 World 时初始化 Recent Message 标签；不返回 `tile_types`。主地图及 location 不返回 `map_json`，需要时调用 `/api/v1/world/map`。完整 tick 列表使用 `/api/v1/world/tick/list`。

Query：

- `world_id*`: string

响应 `data`：

- `info*`: `WorldInfo`
- `stats*`: `WorldStats`
- `relation_status*`: string，当前登录用户与该 world 的关系状态；可为 `anonymous` / `owner` / `joined` / `pending` / `approved` / `rejected`
- `characters*`: `Character[]`
- `locations*`: `Location[]`

### GET `/api/v1/world/map`

读取 world 的 2.5D 地图。匿名可访问并沿用 world 公开可见性规则。`definition_version != 2` 时成功返回空对象 `data={}`。

Query：

- `world_id*`: string
- `location_id*`: string；`root` 返回 world 主地图，其他值返回对应 location 地图

响应 `data`：

- 2.5D 地图：

  ```json
  {
    "tile_types": {
      "L3_classroom__modern_v4": "https://cdn-001.worldo.ai/predata/tiles/tile_d_1/L1/tiles/L3_classroom__modern_v4.png"
    },
    "map_json": {
      "width": 5,
      "height": 5,
      "tiles": [
        {
          "x": 0,
          "y": 0,
          "type": "L3_classroom__modern_v4",
          "shadow": 1,
          "location_id": "loc_1"
        }
      ]
    }
  }
  ```

  - `tile_types`: `object|null`，key 为瓦片类型，value 为该类型对应的线上图片 URL
  - `map_json`: `object|null`
  - `map_json.width`: integer，地图横向瓦片总数
  - `map_json.height`: integer，地图纵向瓦片总数
  - `map_json.tiles`: `MapTile[]`，地图中的瓦片列表
  - `MapTile.x`: integer，瓦片横坐标
  - `MapTile.y`: integer，瓦片纵坐标
  - `MapTile.type`: string，对应 `tile_types` 中的 key
  - `MapTile.shadow`: integer，`0` 表示保持原始亮度并参与组成明亮地块边界，`1` 表示处于边界外的迷雾图层区域；迷雾覆盖整个可见网格，从边界透明开始，随距离增加逐渐变暗，远端达到纯黑
  - `MapTile.location_id`: string，可选；瓦片关联的 location ID
- 旧版地图：`{}`

错误码：

- `1404`：world 不存在、不可见，或指定 location 不存在
- `4004`：缺少 `world_id` 或 `location_id`

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

按 `world_id` 分页读取 `tbl_world_tick` 中 `status=50 (p2_done)` 的 tick。列表按 `tick_no DESC, id DESC` 排序，最新已完成 tick 在前。

接口公开可访问。pending、approved world 对所有人可见；rejected world 仅 owner 可见，其他调用方返回 `ErrorWorldNotExist`。

Query：

- `world_id*`: string
- `pn`: integer，页码，从 1 开始
- `rn`: integer，每页条数，默认 10

Apifox 可选 Header：

- `x-debug-uid`: string
- `x-app-version`: string；正式 App 由共享 Gateway 请求链注入 `X-App-Version`，接口 resource 不单独拼装公共 Header

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

每个 `list[].info` 额外明确包含：

- `definition_version*`: integer，地图定义版本；`1` 为旧版地图，`2` 为新版 2.5D 地图
- `default_map_location_id*`: string，默认展示地图的 location id；`root` 表示根地图

### GET `/api/v1/origin/feed`

客户端按账号持久保存 `origin_feed_gender` 筛选偏好，匿名设备单独保存。每次进入 App 加载 Worldo 时优先读取该身份的缓存（已有手动选择优先，包括 All）；没有缓存时使用本次启动 `GET /api/v1/device/personalization` 返回的 `origin_feed_gender`，不从个人 `gender` 或 userInfo 反推。读取本地缓存期间不提前展示默认 All。

按设备返回去重后的 Origin For you 推荐流。请求统一通过 Gateway 链路携带必填 `X-Device-ID`。`start_score` 是不包含自身的 Redis ZSET 位置游标；刷新传 `0`，分页传上一次响应的 `next_score`。

Query：

- `start_score`: int64，默认 `0`，最小值 `0`
- `rn`: integer，默认 `10`，范围 `1..100`
- `gender`: string，可选，枚举 `Male` / `Female` / `Non_binary`；默认不传，未传或空表示未指定

有缓存时直接按缓存请求列表，不等待 personalization，后续 GET 也不覆盖该缓存。没有缓存时，已登录和未登录用户均复用当前身份的 `PersonalizationStore`；等待启动 GET 完成后再发第一次列表请求，避免先 All 再定向请求。`origin_feed_gender=Male/Female/Non_binary` 原值传入 feed/list 的 `gender`；`All` 或未设置（空串）不传 gender。明确的服务端偏好存入缓存；读取失败或未设置可按 All 加载，但不写成一份持久的 All 偏好。填表开关关闭且没有可复用 GET 数据时，Worldo 仍通过同一 store 加载一次偏好，不因此打开资料弹窗。首屏、下拉刷新和分页保持相同条件；账号或手动筛选变化后从首屏重新加载，不沿用旧游标。For you 首屏缓存按账号及请求的 gender 区分，迟到的旧身份、旧筛选响应不写入当前列表。其他 origin/list 调用默认不传，不影响 Me 自有列表。

Worldo 搜索栏右侧的现有性别筛选 UI、箭头、菜单位置和样式不变。点击选择时立即应用并保存当前身份的缓存，同时调用 `POST /api/v1/device/personalization/update_origin_feed_gender`，body 仅 `{origin_feed_gender: "Male" | "Female" | "Non_binary" | "All"}`。该接口使用正常认证和 `X-Device-ID`，不传 uid，不修改用户 gender/age。只打开、点击窗外或返回关闭菜单不发上报。连续选择按顺序上报，切换账号后跳过旧会话的排队请求；上报失败保留本地选择并提示重试，用户可再次选择上报。客户端手动 All 缓存为空字符串，缓存缺失为 null；上报 All 时显式传 `"All"`，列表查询仍省略 gender。

响应 `data`：

- `list*`: `{ info: OriginInfo, stats: OriginStats }[]`
- `rn*`: integer
- `next_score*`: int64，服务端本次最后检查的位置；被曝光记录过滤的成员仍会推进该游标
- `has_more*`: boolean，`next_score` 之后是否仍有成员

每个 `list[].info` 额外明确包含：

- `definition_version*`: integer，地图定义版本；`1` 为旧版地图，`2` 为新版 2.5D 地图
- `default_map_location_id*`: string，默认展示地图的 location id；可直接作为 `/api/v1/origin/map` 的 `location_id`，`root` 表示根地图

客户端检测到 `next_score` 未前进时必须停止继续分页，防止异常响应造成重复请求。

### POST `/api/v1/origin/feed/exposure`

上报当前设备实际看到的 Origin。请求统一通过 Gateway 链路携带必填 `X-Device-ID`；服务端对请求内 ID 和同设备重复请求幂等，并按上海自然日保存曝光集合。

JSON body：

- `origin_ids*`: string[]，数量 `1..100`

响应 `data`：

- `recorded_count*`: integer

客户端只统计封面图片已成功渲染、在列表真实内容视口内可见面积至少 30% 且连续可见满 1.5 秒的卡片；占位图、图片加载中或加载失败时不开始计时。可见面积低于 30% 时取消本次计时，重新进入后重新计时。快速经过的卡片不采集，当前页面生命周期内按 OID 去重。服务端 `5000` 或可重试网络错误最多尝试 3 次，参数错误 `4004` 不重试。

### GET `/api/v1/origin/hot_tags`

返回 origin 热门 tag。当前服务端固定返回 5 个 tag，后续可替换为 DB 聚合。匿名可访问，不需要登录。

请求参数：无。

响应 `data`：

- `list*`: string[]

### GET `/api/v1/origin/my_launch_preset_characters`

根据当前登录用户与 `origin_id`，返回该用户过去作为 world owner launch 该 origin 时选择过的 preset 角色。

custom 角色和后续通过 `world/join` 绑定的角色不返回。结果由服务端先按 `last_active_at` 倒序排列，再应用 `limit`。已软删除的 world 仍属于 launch 历史；但只返回当前 origin 中仍未软删除的角色，角色展示字段取当前 origin 的角色定义，不取历史 world 副本。

接口需要登录。origin 可见性与 `/api/v1/origin/detail` 一致：approved 对所有登录用户可见，pending/rejected 仅 origin owner 可见。

客户端通过共享 `GenesisApi` / `ApiClient` 请求链路发送，不声明接口私有 header；统一复用公共 runtime header、登录态 `Authorization` 以及配置的 Gateway `X-*` 签名 header。旧公共 `device-id/app-id/app-version/app-platform` header 仍按客户端全局规则过滤，不在本接口单独恢复。

Query：

- `origin_id*`: string，要查询 launch 历史的 origin 业务 id
- `limit*`: integer，返回数量；Opening Sheet 固定传 `5`

服务端先按 `last_active_at DESC` 排序，再应用 `limit`，因此
`limit=5` 返回最近活跃的 5 个 World；客户端直接按响应顺序展示。

响应 `data`：

- `list*`: `OriginMyLaunchPresetCharacter[]`；没有匹配历史时返回空数组

`OriginMyLaunchPresetCharacter`：

- `char_id*`: string，当前 origin 中的 preset 角色 id，也是去重键
- `type*`: string，固定为 `ai`
- `name*`: string
- `identity*`: string
- `brief*`: string，当前 origin 角色的 personality
- `goal*`: string
- `avatar*`: `ImageResource`
- `initial_location_id*`: string，当前 origin 角色的初始地点 id
- `last_launched_at*`: integer，最近一次使用该角色 launch 的 Unix 秒
- `world_id*`: string，最近一次使用该角色 launch 的 World 业务 id
- `tick_no*`: integer，该 World 当前 Tick 数
- `sub_tick_no*`: integer，该 World 当前子 Tick 数
- `connect_cnt*`: integer，该 World 当前累计 Message 数
- `current_time*`: string，该 World 当前时间
- `last_active_at*`: integer，该 World 最近活跃时间，Unix 秒

错误码：

- `4004`：缺少 `origin_id`，或 `limit` 非法
- `10001`：未登录或 session 过期
- `20101`：origin 不存在、已软删除或当前调用方不可见

### GET `/api/v1/app/config`

App 启动时尽早请求的全局配置。客户端在首个 Flutter 页面展示前完成一次有超时兜底的加载；失败或超时使用默认值。

Query：

- `uid`: string，可选；客户端完成本地登录 UID 读取后传入真实非 guest UID，未登录、读取失败或读取超时时不传。该字段用于用户维度的配置判断，不替代 `Authorization` 身份校验。

响应 `data`：

- `show_opening_sheet`: boolean；决定进入 Origin Detail 时 Opening Sheet 的首帧状态。`true` 时首次构建即完全展开，`false` 时首次构建即保持收起；不等待 `/api/v1/origin/detail` 返回后再改变 Sheet 高度。
- `show_personalization_form`: boolean；控制新用户填表入口。默认 `false`，启动时仅成功获取 boolean `true` 才请求 `/api/v1/device/personalization`，按当前身份的 `completed` 判断是否弹出表单；获取失败、字段缺失、`null` 或类型错误均不查询、不弹表单。未绑定支付的强制登录独立保留。该字段不控制 Continue 后的订阅引导，仍沿用当前会员判断逻辑。
- `apiTraceSamplingRate`: float，范围 `[0,1]`；普通业务接口请求监控的启动级采样率。客户端本地默认值为 `0`，服务端当前返回 `1`。配置接口以及 `/apix/v1/time`、`/apix/v1/app/device/challenge`、`/apix/v1/app/device/register` 固定独立监控；轮询接口和 `/api/v1/collect` 不参与接口请求监控。

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "show_opening_sheet": false,
    "show_personalization_form": true,
    "apiTraceSamplingRate": 1.0
  }
}
```

### GET `/api/v1/origin/detail`

返回单个 origin 模板的完整详情：基本信息、统计信息、初始地点对白、初始角色、初始 location、模板 ticks。`info` 返回 `definition_version`，不返回 `tile_types`；location 不返回 `location_description`；主地图及 location 均不返回 `map_json`，需要时调用 `/api/v1/origin/map`。

匿名可访问。已审核通过（`review_status=20`）的 origin 对所有人可见；pending/rejected 仅 owner 可见，其他调用方统一收到 `ErrorOriginNotExist`。

Query：

- `origin_id*`: string

Apifox 可选 Header：

- `x-debug-uid`: string
- `x-app-version`: string；正式 App 由共享 Gateway 请求链注入 `X-App-Version`

响应 `data`：

- `info*`: `OriginDetailInfo`
- `stats*`: `OriginStats`
- `init_location_group*`: `OriginInitLocationGroup|null`
- `characters*`: `OriginDetailCharacter[]`
- `locations*`: `Location[]`，本接口不包含 `location_description`
- `ticks*`: `Tick[]`

`OriginInitLocationGroup`：

- `location_id*`: string
- `initial_dialogue*`: `OriginInitialDialogueLine[]`
- 服务端优先返回 `edit_data` 配置的可用目标；目标不可用时，按 `location_id` 升序选择第一条具有有效非空 `dialogue` 的 location；均不存在时返回 `null`

`OriginInitialDialogueLine`：

- `char_id*`: string，角色 id 或 `nar`、`nar_pic`、兼容旧值 `image`
- `char_name*`: string，只读；`nar/nar_pic` 为 `Narrator`，角色 id 使用最终角色名
- `content*`: string，对白、旁白或图片 URL

`Character`：

- `char_id/type/player_uid/player_username/player_user/player_joined_at*`
- `name/identity/brief/goal/avatar*`
- `initial_location_id/location_id/metric_value/delta*`
- `is_recommend*`: integer，`0` 不推荐、`1` 推荐
- origin 模板中的角色 `type=ai`、`player_uid=""`、`player_joined_at=0`；`initial_location_id` 与运行态 `location_id` 是两个独立字段

`Location`：

- `location_id/level/location_pid/location_name*`
- `location_paragraph/location_timestamp/location_summary*`；不返回 `location_description`
- `image/x_percent/y_percent/x/y/map_url/dialogue*`
- `x/y` 是 2.5D 地图坐标，旧版地图为 `0`；`dialogue` 行为 `{char_id,char_name,content}`

`Tick`：

- `tick_id/tick_no/sub_tick_no/status/created_at*`
- `tick_result*`: `{current_time,narrator,paragraphs}`，不返回 `location_groups`
- `paragraphs[]*`: `{location_id,timestamp,text,visibility,visible_to,clue,character_deltas}`；`visibility` 为 `public` 或 `char_only`，P1 v2 的 `character_deltas` 为空数组

错误码：

- `4004`：缺少 `origin_id`
- `20101`：origin 不存在、已软删除或当前调用方不可见

### GET `/api/v1/origin/map`

读取 origin 模板的 2.5D 地图。匿名可访问并沿用 origin 公开可见性规则。`definition_version != 2` 时成功返回空对象 `data={}`。

Query：

- `origin_id*`: string
- `location_id*`: string；`root` 返回 origin 主地图，其他值返回对应 location 地图

响应 `data`：

- 2.5D 地图：

  ```json
  {
    "tile_types": {
      "L3_classroom__modern_v4": "https://cdn-001.worldo.ai/predata/tiles/tile_d_1/L1/tiles/L3_classroom__modern_v4.png"
    },
    "map_json": {
      "width": 5,
      "height": 5,
      "tiles": [
        {
          "x": 0,
          "y": 0,
          "type": "L3_classroom__modern_v4",
          "shadow": 1,
          "location_id": "loc_1"
        }
      ]
    }
  }
  ```

  - `tile_types`: `object|null`，key 为瓦片类型，value 为该类型对应的线上图片 URL
  - `map_json`: `object|null`
  - `map_json.width`: integer，地图横向瓦片总数
  - `map_json.height`: integer，地图纵向瓦片总数
  - `map_json.tiles`: `MapTile[]`，地图中的瓦片列表
  - `MapTile.x`: integer，瓦片横坐标
  - `MapTile.y`: integer，瓦片纵坐标
  - `MapTile.type`: string，对应 `tile_types` 中的 key
  - `MapTile.shadow`: integer，`0` 表示保持原始亮度并参与组成明亮地块边界，`1` 表示处于边界外的迷雾图层区域；迷雾覆盖整个可见网格，从边界透明开始，随距离增加逐渐变暗，远端达到纯黑
  - `MapTile.location_id`: string，可选；瓦片关联的 location ID
- 旧版地图：`{}`

错误码：

- `1404`：origin 不存在、不可见，或指定 location 不存在
- `4004`：缺少 `origin_id` 或 `location_id`

### GET `/api/v2/origin/foredit`

登录用户读取自己创建的 Origin 完整详情，用于 V2 地图编辑。服务端先校验 `tbl_origin.owner_uid` 等于当前登录 uid，再返回与 `GET /api/v1/origin/detail` 完全相同的 `OriginDetail`。

本接口不再返回 V1 foredit 的平级 `edit_data` 形态；客户端必须从嵌套的 `data.info` 读取基本信息，并从顶层 `init_location_group`、`characters`、`locations`、`ticks` 读取对应编辑数据。

Query：

- `origin_id*`: string

响应 `data`（`OriginDetail`）：

- `info*`: `OriginDetailInfo`
- `stats*`: `OriginStats`
- `init_location_group*`: `OriginInitLocationGroup`
- `characters*`: `Character[]`
- `locations*`: `Location[]`
- `ticks*`: `Tick[]`

字段定义与上方 `GET /api/v1/origin/detail` 相同，其中 `characters[].is_recommend` 为 integer：`0` 不推荐、`1` 推荐。`info` 包含 `origin_id/origin_name/origin_version/origin_version_time/definition_version/language/current_time/owner_uid/owner_name/owner_user/brief/tags/metric/created_at/cover/map_url/status`。特别注意：新契约没有旧平级 foredit 的 `setting/events/started_at/tick_duration_time/tile_types` 字段。

错误码：

- `4004`: ErrorParamInvalid，缺少 `origin_id`
- `10001`: ErrorUserNotLogin
- `10011`: ErrorUserNotAccess，当前用户不是该 origin 的 owner
- `20101`: ErrorOriginNotExist，`origin_id` 不存在或已软删除

### POST `/api/v1/origin/create`

登录用户基于 info、characters 和平级 locations 创建新的 origin 模板。同步阶段写入主表并立即返回轻量 `OriginUpsertResp`；`owner_uid` 取自 session，不接受请求体覆盖，初始 `origin_version=1`、`review_status=10`、`status=20 processing`。

服务端行为：

- characters/locations 中重复的 `char_id` / `location_id` 按首次出现保留。
- `language` 来自 `x-system-language` header；`current_time` 优先使用 trim 后的 `started_at`，空值写 `Day 1`。
- 后台调用 `origin_init_tags_locations` 补全 tags 和三级 location 树；成功后批量写角色/location、回填计数，并切回 `status=10 normal`。
- prompt 失败或没有可用地点时，若请求 locations 非空，会用请求地点名构造最小三级树。
- V2 编辑回显通过 `/api/v2/origin/foredit` 读取当前完整 `OriginDetail`，不消费旧平级 `edit_data` 响应。
- `ticks` 不在 create 范围内。

请求 body（`OriginCreateReq`）：

- `origin_name*`: string
- `origin_version`: string，create 时服务端默认写 `1`
- `definition_version`: integer，`1` 或 `2`；V1 未传时写 `1`
- `brief`: string
- `setting`: string
- `events`: string[]
- `tags`: string[]
- `metric`: `WorldMetric`
- `started_at`: string，故事内起始时间文本
- `tick_duration_time`: string，每个 tick 推进的故事时间跨度文本；为空时服务端写默认 `1 day`
- `cover`: string 或 `ImageResource`
- `map_url`: string
- `tile_types`: object 或 null
- `characters`: `OriginCharacterUpsert[]`
- `locations`: `OriginLocationUpsert[]`

`OriginCharacterUpsert`：

- `char_id`: string，请求内临时引用 id；服务端按数组顺序重写
- `name*`: string
- `identity`: string
- `personality`: string，详情接口中以 `character.brief` 返回
- `bio`: string，详情接口中以 `character.description` 返回
- `goal`: string
- `avatar`: string 或 `ImageResource`
- `initial_location_id`: string，角色初始地点 id；`location_id` / `metric_value` 属于 tick 运行态，不在 create 入参中提供

`OriginLocationUpsert`：

- `location_id`: string，最长 32 字符，请求内临时引用 id；客户端新建节点使用 32 位、无连字符的小写 UUID v4，编辑已有节点时保留服务端原 ID
- `level`: integer，兼容字段；create/update 时服务端忽略
- `location_pid`: string，兼容字段；当前客户端会按表单树发送该关联，V2 foredit 通过完整 `Location` 返回服务端当前层级关系
- `location_name*`: string
- `location_description`: string，固定描述，tick 不会修改
- `location_summary`: string，兼容旧请求；当 `location_description` 为空时用于回填固定描述
- `image`: string 或 `ImageResource`
- `x_percent`: integer，`0-100`
- `y_percent`: integer，`0-100`
- `map_url`: string

响应 `data`：

- `origin_id*`: string
- `origin_version*`: string
- `origin_version_time*`: integer，Unix 秒
- `origin_name*`: string

错误码：

- `4004`
- `10001`

### POST `/api/v1/origin/update`

登录用户更新自己创建的 origin 模板。同步阶段校验 owner、更新主表、自动递增数字版本、清理当前主态 active ticks、写入 `status=20 processing`，随后立即返回轻量 `OriginUpsertResp`。

服务端行为：

- 后台使用 `origin_init_tags_locations` 补全 tags 和三级 location 树；旧异步任务通过 `origin_id + origin_version` 检查自动跳过。
- `locations` 作为用户平级编辑 location 入参；服务端忽略 `level` / `location_pid` 并重新生成入库三级树，成功后切回 `status=10 normal`。
- `characters` 只 upsert 请求列表中的项，不按缺失项推断删除；已有 `char_id` 保留，新增角色临时 id 会重写为下一个 `char_N`。
- `deleted_char_ids` / `deleted_location_ids` 显式软删；与本次提交项冲突时以提交项为准。
- `update_notes` 写入 `tbl_origin.update_notes`，后续生成版本快照时同步到 `tbl_origin_version.change_log`；客户端 publish 时要求用户填写。
- V2 编辑回显通过 `/api/v2/origin/foredit` 读取当前完整 `OriginDetail`，不消费旧平级 `edit_data` 响应。
- 不重置审核状态。

请求 body（`OriginUpdateReq`）：

- `origin_id*`: string
- `origin_name*`: string
- `origin_version`: string，服务端控制；每次更新成功自动进入下一数字版本
- `definition_version`: integer，`1` 或 `2`；V1 未传时保留当前值
- `brief`: string
- `setting`: string
- `events`: string[]
- `tags`: string[]
- `metric`: `WorldMetric`
- `started_at`: string，故事内起始时间文本
- `tick_duration_time`: string，每个 tick 推进的故事时间跨度文本，例如 `1 day`
- `cover`: string 或 `ImageResource`
- `map_url`: string
- `tile_types`: object 或 null
- `characters`: `OriginCharacterUpsert[]`
- `locations`: `OriginLocationUpsert[]`
- `update_notes`: string，版本更新说明；客户端 publish 时必填
- `deleted_char_ids`: string[]，显式删除的角色 id
- `deleted_location_ids`: string[]，显式删除的 location id

响应 `data`：

- `origin_id*`: string
- `origin_version*`: string
- `origin_version_time*`: integer，Unix 秒
- `origin_name*`: string

错误码：

- `4004`
- `10001`
- `10011`
- `20101`

### POST `/api/v2/origin/create`

使用自动地图流程创建 Origin。请求复用 `OriginCreateReq`（包括 `characters[].is_recommend`）并增加可选 `init_location_group`；服务端忽略客户端的 `definition_version` / `tile_types`，固定写入 `definition_version=2`、`status=20 processing`，同步返回与 V1 相同的轻量 `OriginUpsertResp`。

后台并发调用 `origin_init_tags` 与 `origin_create_map`，生成完整三级 location 树、root/location `map_json` 和实际使用的 CDN WebP `tile_types`。完整地图原子落库后切回 `status=10 normal`；失败时保持 processing，不发布半成品。

额外请求字段：

- `characters[].is_recommend`: integer，`0` 不推荐、`1` 推荐；同一个 Origin 最多一个角色为 `1`
- `init_location_group`: object，可选
  - `location_id*`: string，必须命中最终生成的 location
  - `initial_dialogue*`: `{char_id, content}[]`
  - `char_id` 可为角色 id，也可为 `nar`、`nar_pic` 等展示消息类型

错误码：`4004`、`10001`。

### POST `/api/v2/origin/update`

更新 owned Origin 并重新生成完整 2.5D 地图。请求复用 `OriginUpdateReq`（包括 `characters[].is_recommend`）并增加可选 `init_location_group`；服务端固定 `definition_version=2`，同步复用 owner 校验、版本递增、active tick 清理和 `deleted_*` 处理，返回轻量 `OriginUpsertResp`。

生成期间保留上一版 `map_json` / `tile_types`，成功后原子替换；旧异步任务按 `origin_version` 自动跳过。省略 `init_location_group` 表示清空旧初始对白，传入时完整替换；其 `location_id` 与 `deleted_location_ids` 冲突会同步返回参数错误。

错误码：`4004`、`10001`、`10011`、`20101`。

### POST `/api/v1/origin/launch`

登录用户基于一个 origin 模板创建新的 world 实例；接口只创建 world，不触发 tick。

客户端 Opening Sheet 发送：登录检查通过后立即进入聊天界面，先显示当前地点的开场内容，再显示原消息和消息左侧的发送 loading，并在后台调用本接口。开场内容复用 Origin 的 `init_location_group`，缺失时回退到 ticks 的初始对白；角色对白使用真实聊天的气泡、角色名和头像组件，旁白和图片保留各自的聊天样式。

取得 `world_id` 时保留同一个 World 页面、聊天列表和滚动状态，启动 World 数据加载、WebSocket 连接及目标地点 join，随后通过 `send_message` 提交同一条消息；消息正文不随 Launch 请求发送。预览持续保留到当前地点真实历史和分页信息加载成功，再原位替换为服务端记录；匹配的开场消息沿用显示锚点，正文、身份和消息 ID 则以真实数据为准。初始历史请求按开场条数扩大 limit（20–100），避免默认 20 条截断开场；空缓存和失败请求不能触发清空预览。发送 ACK 和新对话可独立继续，预览不会写入真实消息队列或数据库。收到发送 ACK 后结束消息 loading。Launch 失败时保留开场内容和失败气泡，点击重试重新 Launch；已有 World 的消息发送失败则走聊天室重试，不再 Launch。等待 Launch 时退出页面，迟到的结果不会重新打开页面或发送消息。

请求 body（`OriginLaunchReq`）：

- `origin_id*`: string，待 launch 的 origin 业务 id
- `preset_character_id`: string，origin 角色列表中的 `char_id`
- `preset_character_override`: object，可选；服务端支持 `name/identity/personality/bio/goal/avatar`，用于覆盖新 world 中绑定原 `char_id` 的角色副本
- `custom_role`: `WorldCustomRole`

`preset_character_id` 与 `custom_role` 必须二选一；两者都为空或都非空会返回 `4004`。
`preset_character_override` 只能用于 preset 模式，并且至少包含一个允许覆盖的字段；custom 模式携带时服务端忽略。

`WorldCustomRole`：

- `char_id`: string，可空；为空时服务端按 `char_<uid>` 兜底
- `name*`: string
- `identity`: string
- `personality`: string，角色 Personality
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

### GET `/aitown-chat/api/v1/feature-quotas`

2026-09-11：依据 `inspiration-edit-client-guide.md`。查询当前登录账号的两项独立额度，无业务参数，不按世界、地点、轮次或卡片区分。接口只读且返回 `Cache-Control: no-store`；耗尽仍为 `err_no=0`。

非会员（`membership_status=0`）和会员已失效（`2`）的 Inspiration、Conversation Edit 各有账号累计 3 次，不按天重置；有效会员（`1`、`is_member=true`）两项均无限次。会员使用单独累计 `used`，不会消耗非会员试用次数，失效后沿用原试用剩余次数。

成功响应 `data`：

```json
{
  "membership_status": 0,
  "is_member": false,
  "inspiration": {
    "scope": "trial_lifetime", "unlimited": false,
    "limit": 3, "used": 1, "remaining": 2, "reset_at": null
  },
  "conversation_edit": {
    "scope": "trial_lifetime", "unlimited": false,
    "limit": 3, "used": 2, "remaining": 1, "reset_at": null
  }
}
```

会员两项均返回 `scope=member_unlimited`、`unlimited=true`，`limit/remaining/reset_at=null`，`used` 保留成功用量。客户端先判断 `unlimited`，不能将 null 解释成 0。当前没有每日限额；解析器保留旧 `member_daily` 枚举以兼容已保存结构。

Flutter 入口 `ChatroomHttpApi.getFeatureQuotas` 返回 `ChatroomFeatureQuotas`，解析 `membership_status`、`is_member` 及两项完整 summary；缺必填字段、类型错误、未知 scope 或负数额度属于响应格式异常。`ChatroomFeatureQuotaStore` 在账号范围内保留服务端快照并合并并发请求，切换账号清理状态并忽略旧响应，不推导或本地扣减次数。

Location Chat 按产品约定在点击 Edit 或 idle 状态的 Inspiration 时先检查本地会员状态：确认有效会员直接使用，否则请求本接口；进入页面、按钮出现、收起 Inspiration 均不发起次数查询。免费次数提示显示后，再次点击 idle 状态的 Inspiration 保持展开，并重新执行次数检查；次数允许时请求灵感接口，不因本地已有结果而跳过请求。请求期间 busy 状态不接受重复点击。Inspiration 即使缓存次数为 0，也会在再次点击时刷新次数，最新次数仍为 0 时不请求生成接口。查询失败保留之前已知次数与草稿。购买/恢复会员后刷新状态，失败操作不自动重发。

| 错误号 | 含义 |
| --- | --- |
| 10001 | 未登录，沿用全局登录失效流程 |
| 5002 | 使用量查询失败 |
| 5003 | 当前会员数据无效 |

业务错误不生成额度对象，也不将现有余额清零。

### 操作响应的公共 `quota`

Inspiration 及正式/候选 batch 在 HTTP 200 envelope 的 `data` 同级返回可选 `quota`，成功和 `2030` 都可携带：

```json
{
  "feature": "conversation_edit",
  "membership_status": 0, "is_member": false,
  "scope": "trial_lifetime", "unlimited": false,
  "limit": 3, "used": 3, "remaining": 0, "reset_at": null,
  "consumed": 1
}
```

`feature` 为 `inspiration` 或 `conversation_edit`，`consumed` 是本次消费：新灵感及成功 batch 为 1，复用灵感及额度耗尽为 0。一次 batch 包含多条编辑/删除仍只计 1 次，提交相同正文也计次；失败不计次。

成功结果模型提供可选 `ChatroomFeatureQuota quota`。`remaining=0` 的最后一次操作仍已成功，不撤销正文或灵感；缺失、格式错误或功能不匹配的可选 quota 不把已提交成功改成失败。真实 POST 开始时捕获 `ChatroomHttpApi.onFeatureQuotaRequest` 回调，在合法成功/2030 响应中更新对应额度；GET 和灵感缓存复用不调用该回调，缓存序列化也不保存旧 quota。

`err_no=2030` 抛出 `ChatroomFeatureQuotaException`（保留可选 quota），英文文案为 `Feature quota exhausted`。仅 Inspiration 和 batch 的 2030 绕开通用业务 Toast：入口显示内联次数提示，Edit 保存由页面显示一次 Toast 并保留文字/删除草稿；其他业务错误和鉴权继续原有通路。

### POST `/aitown-chat/api/v1/worlds/{world_id}/locations/{location_id}/inspiration`

请求 `{"conversation_round_id":7358}`；来源轮次必须为正整数，可选正数 `card_id` 指定候选，省略/null 表示正式来源，不能传 0。`refresh` 不用于强制换一组。客户端 timeout 为 120 秒，不自动重试请求。

成功示例：

```json
{
  "err_no": 0, "err_msg": "succ",
  "data": {
    "conversation_round_id": 7358, "card_id": 0, "source_card_id": 0,
    "messages": ["我想再听听刚才的事。", "一起去附近走走？", "坐下来慢慢聊吧。"],
    "gateway_request_id": "request_example"
  },
  "quota": {
    "feature": "inspiration", "membership_status": 0, "is_member": false,
    "scope": "trial_lifetime", "unlimited": false,
    "limit": 3, "used": 3, "remaining": 0, "reset_at": null, "consumed": 1
  }
}
```

相同账号、世界、地点、轮次及来源卡片的已有灵感直接复用，`consumed=0`；原文编辑不使保存结果失效。即使 remaining 为 0 仍允许读取相同来源，只有需要新生成时才返回 `2030`、`data={}`。成功响应中的消息为非空字符串数组，按服务端顺序展示；新生成 3 条，历史保存结果保留原数量。

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

该接口保留给旧协议的 world 级恢复/诊断链路；location chat 页的 initial、older 和 gap 请求不直接依赖它，V2 地点历史统一走下述 per-location 接口。

Query：

- `world_id*`: string，世界实例 ID

响应 `data`：

- `locations`: `{ location_id, messages: ChatroomMessageDTO[] }[]`

错误响应示例：

```json
{ "err_no": 1001, "err_msg": "参数错误: world_id is required" }
```

### GET `/aitown-chat/api/messages`

旧协议兼容/诊断接口。获取指定世界、指定地点的扁平历史消息；新 location chat 运行时不再以它作为 initial、older 或 gap 数据源。`limit` 默认 20，最大 100。

Query：

- `world_id*`: string，世界实例 ID
- `location_id*`: string，地点 ID
- `since`: integer，起始消息 ID；`0` 表示获取最新
- `limit`: integer，默认 `20`，最大 `100`

响应 `data`：

- `messages`: `ChatroomMessageDTO[]`
- `has_more`: boolean，是否有更多消息
- `newest_message_id`: integer，最新消息 ID

`data` 为上述扁平对象，单地点接口不返回 world 级接口使用的 `locations[]` 包装。`messages[]` 可同时包含普通 location 消息及三类时间线记录；时间线记录的 `location_message_id` 既可能为正数，也可能为 `0`。

每条消息还可返回顶层 `conversation_type`，并始终返回字符串 `trigger_uid`。同轮的用户消息、角色回复和旁白回复复用同一个触发 UID；opening、Tick 或无法识别触发者时为 `""`。旧服务/旧缓存缺失字段，或字段类型不是字符串时，客户端统一解析为空字符串，不使用 `user_id`、`sender_id`、消息类型或轮次 ID 补推。

图片消息仅在单条 `ChatroomMessageDTO` 中新增 `message_type`，不改变现有响应 envelope、消息 ID 字段或时间字段。例如：

```json
{
  "global_message_id": 90003,
  "message_id": 1003,
  "location_message_id": 103,
  "location_id": "loc_001",
  "conversation_round_id": 7003,
  "sender_type": "narrator",
  "sender_id": "nar_pic",
  "sender_name": "Narrator",
  "user_id": "",
  "content": "https://example.com/images/scene.jpg",
  "message_type": "image",
  "current_time": "Day 1, 08:05",
  "tick_no": 3,
  "created_at": "2026-07-27 10:05:00"
}
```

### POST `/aitown-chat/api/v1/worlds/{world_id}/locations/{location_id}/llm-messages/batch`

2026-09-08：依据批量接口设计 `PLAN.md`，本接口替代旧的单条 PATCH / DELETE；客户端已移除旧请求入口。前后端需要协调切换。
一次请求仅修改同一世界、地点、轮次内的 1～100 条已完成角色/旁白回复，整批原子提交。操作人必须是该轮发起人，普通聊天和 Go on 均适用，不限最新轮次。用户消息、Tick、隐藏 Go on 触发记录、生成中消息不可操作。复用现有 Bearer 登录凭证和 Gateway 签名。

```json
{"conversation_round_id":7358,"operations":[{"action":"edit","global_message_id":8701,"content":"修改后的完整回复"},{"action":"delete","global_message_id":8702}]}
```

- 轮次与全局消息 ID 使用正整数 int64；不经过浮点转换。
- `operations` 为 1～100 项，ID 不得重复；操作只能为 `edit` / `delete`。
- 编辑的 `content` 必填且不能全空白，首尾空格及换行原样发送；删除不携带 `content`。
- 操作数组顺序不改变消息排列；任一目标校验失败时整批不生效。纯编辑不受删除开关限制。

成功响应（不再返回布尔值）：

```json
{"err_no":0,"err_msg":"succ","data":{"start_conversation_round_id":7358,"end_conversation_round_id":7362,"newest_message_id":84}}
```

起止轮次是需要完整刷新的闭区间。纯编辑只刷新提交轮次；含删除时可能扩大到序号实际变化的后续轮次。`newest_message_id` 为整个地点最新序号，允许降低至 0。客户端严格校验响应范围及整数类型；HTTP 200 本身不代表成功。

错误响应：`{"err_no":2013,"err_msg":"LLM reply already deleted","data":false}`。

| 错误号 | 含义 |
| --- | --- |
| 10001 | 未登录，沿用全局登录失效流程 |
| 1001 | 参数非法（空批次、超限、重复 ID、非法 action 等） |
| 1009 | 编辑内容缺失或全空白 |
| 2011 | 目标不存在、世界/地点/轮次不匹配或不可操作 |
| 2012 | 非轮次发起人 |
| 2013 | 批次存在已删除目标 |
| 2014 | 含删除操作但环境未启用删除 |
| 2030 | Conversation Edit 试用次数耗尽；data=false，顶层 quota.consumed=0 |
| 2004 | 存储或地点锁操作失败 |

除 `10001` 和 `2030` 外，非零业务错误通过全局 Toast 显示服务端 `err_msg`，同时抛出保留错误码的异常；调用方保留草稿、不重复弹提示。2030 由功能层处理，规则见上方公共 quota。成功 batch 的顶层 quota 更新 Conversation Edit 的服务器快照，免费最后一次 remaining=0 仍正常提交。
`ChatroomHttpApi.batchMutateLlmMessages` 返回 `ChatroomMessageMutationResult`；`WorldChatroomService` 同名入口只阻止同轮在途重复提交，不使用 HTTP 返回范围修改或刷新正式历史。`isMutatingLlmMessages` 可用于提交状态判断。
网络超时、中断或响应格式异常时保持结果不确定，等待 `conversation_range_updated` 或后续连接级同步确认；所有批量写入均不自动重发（包含 Gateway 返回验签错误的情况）。
Location Chat 编辑页直接使用 batch API：合法成功响应即结束本次编辑，不在 Reply Action 内修改、等待或主动刷新正式历史；
后续 `conversation_range_updated` 是更新正式历史的唯一入口。编辑页中的空白文字改动转换为 `delete`，不发送空白 `edit`；
但编辑页和提交层都会保证至少保留一个气泡，不向服务端提交全删 batch。

后端事务、地点锁和 MySQL 原子性需在服务端工程验证，本地 mock 仅用于客户端契约与整批校验回归。

### LLM 轮次卡片查询、候选修改与最终选择

2026-09-08：依据 `llm-round-cards-client-guide.md` 1.1 版。本地仅提供协议入口，不启用候选业务或交互；服务端部署状态另行联调确认。

| 方法与路径 | 客户端入口 |
| --- | --- |
| GET `/aitown-chat/api/v1/worlds/{world_id}/locations/{location_id}/llm-messages/cards` | `ChatroomHttpApi.getLlmCards` |
| POST `/aitown-chat/api/v1/worlds/{world_id}/locations/{location_id}/llm-messages/select` | `ChatroomHttpApi.selectLlmCard` |
| POST 同基础路径 `/batch`，带正数 `card_id` | `ChatroomHttpApi.batchMutateLlmCardMessages` |

不提供 HTTP `/regenerate` 或 Go On；分别通过已认证 V2 WS 的 `regenerate_llm_card` 和 `go_on`。
复用 Bearer / 现有 Gateway 签名，不发送操作者 UID。GET query 仅 `conversation_round_id`（正整数 int64），无 `pn/rn`，支持取消令牌。

GET 不创建卡组。响应 data 包含 `conversation_round_id`、`original_card_id`、`selected_card_id`、`active_card_id`、`confirmed`、`can_regenerate`、`can_confirm`、`list`、`total`。无卡组为空列表及 0 值卡片 ID，全部卡片按 `card_index` 升序一次返回，`total=list.length`，最多 10 条（包含成功、失败和在途尝试）。
`ChatroomLlmCardsResponse.list` 为类型化 `ChatroomLlmCard` 列表。每张卡包含 cardId/cardIndex/isOriginal/generationState/canEdit/canDelete/messages/billing/createdAt/error，并保留 rawJson。查询验证返回轮次与请求一致。
客户端为协议兼容继续解析和缓存 `can_regenerate`、`can_confirm`、`can_edit`、`can_delete`，但这些服务端 capability hint 不参与 Reply Actions、候选确认或编辑/删除的可用性判断。
`ChatroomLlmCardMessage.message` 复用 `ChatroomV2Message`，正文为 `payload.content`；外加固定 cardId/cardMessageIndex/globalMessageId，保留原始 JSON。候选查询不返回 message_id/location_message_id，连原卡也不例外；未成功卡 messages 为空。删除后索引可以为 1、3，不补位。数字 ID 严格按 Dart int 解析，拒绝字符串或浮点数；移动端大于 2^53 的 ID 保持无损。

候选编辑复用 `/batch`：

```json
{"conversation_round_id":7358,"card_id":9902,"operations":[{"action":"edit","global_message_id":8701,"content":"修改后的正文"},{"action":"delete","global_message_id":8702}]}
```

仅 body 是否提供 card_id 决定分支：省略为正式消息，正整数为候选；null、0、负数、字符串不能回退。公开正式入口 `batchMutateLlmMessages` 及返回类型保持不变，候选入口要求正数 cardId，两者共享 1～100 个操作的校验及发送逻辑。edit 原样保存，delete 不带 content，目标 ID 不重复。

候选成功 data 为 `{conversation_round_id, card}`，card 与 GET 卡片结构相同；顶层 quota 与正式 batch 相同，共享 Conversation Edit 额度。采用候选不再次消耗编辑次数。返回 `ChatroomCardMutationResult` 并验证轮次/卡片匹配；不返回正式刷新范围，不修改缓存、不选卡或触发正式历史刷新。至少保留一条消息、权限及 confirmed 状态由后端校验，2020/2021/2025 等错误码按现有业务异常透传。

候选批量写没有持久化请求幂等，不自动重试，包括 Gateway 响应后的重试；结果不明须由后续业务先 GET /cards 核对。重生成可显式复用请求 ID 恢复同一尝试；选卡可显式复用同卡及请求记录；Go On 不具备业务幂等，不能盲目重发。

选卡请求：

```json
{"conversation_round_id":7358,"card_id":9902,"client_msg_id":"select-7358-1"}
```

轮次/卡片 ID 必须是正整数，`client_msg_id` 非空且最多 128 字符，重试由调用方复用同一 ID、同一卡。请求不自动重发（包括 Gateway 错误后的重发）。
成功 `err_no=0` 的 data 与 WS `ack.payload.selection` 相同：

```json
{"conversation_round_id":7358,"selected_card_id":9902,"confirmed":true,"start_conversation_round_id":7358,"end_conversation_round_id":7359,"newest_message_id":14}
```

返回 `ChatroomCardSelection`，包含完整闭区间与整个地点最新序号，允许最新序号为 0；HTTP 层校验确认结果与请求轮次/卡片匹配。这里只返回结果，不自动确认其他卡、不修改历史或安排范围刷新。Location Chat 仅据此完成本地选卡状态并解除操作锁，不使用响应范围主动刷新；正式历史只由后续 `conversation_range_updated` 更新。

已在指南中明确的业务码：2020 已固定其他卡；2021 卡组未确认时尝试批量编辑/删除；2023 重生成次数达到上限。完整错误码表在未附的 OpenAPI 中，客户端不猜测，所有非零码保留原始 code/message。
HTTP 10001 沿用全局登录失效流程，其余非零业务错误通过现有全局 Toast 显示 err_msg。响应形状异常不能视为确认成功。

本地 HTTP mock 的卡片查询返回带轮次的空组；选卡和任何带 card_id 的 batch 返回 HTTP 501，明确未模拟生成/候选修改/选卡后端，不伪造确认或计费成功。协议成功响应使用隔离 transport 测试验证。

### GET `/aitown-chat/api/v2/messages`

获取指定世界、指定地点的 V2 历史消息。HTTP V2 不读取 `x-app-version`，始终返回完整 V2 DTO；`limit` 默认 20，最大 100。

Query：

- `world_id*`: string，世界实例 ID
- `location_id*`: string，地点 ID
- `since`: integer，严格使用 `location_message_id` 的向前分页游标；`0` 表示获取最新页
- `limit`: integer，默认 `20`，最大 `100`
- `start_conversation_round_id` / `end_conversation_round_id`: 配对的 int64 闭区间。省略或均为 0 表示不限范围，否则必须均为正数且结束不小于起始。

范围过滤先于分页；首请求 `since=0, limit=100`，后续使用本页最小正 `location_message_id`，保留同一轮次范围，直到 `has_more=false`。`newest_message_id` 始终表示整个地点最新序号，允许降低为 0；不能把它或轮次 ID 用作分页游标。

响应 `data`：

- `messages`: `ChatroomV2MessageDTO[]`，按 `location_message_id` 倒序
- `has_more`: boolean，是否还有更早的地点消息
- `newest_message_id`: integer，当前请求地点最新的 `location_message_id`，不受 `since` 当前页影响

下一页 `since` 必须使用本页最小正 `location_message_id`，不得改用 world `message_id`。示例：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "messages": [
      {
        "type": "tick",
        "stream_type": "",
        "ts": 1786340797000,
        "world_id": "world_001",
        "location_id": "loc_2_2_2",
        "global_message_id": 8702,
        "message_id": 101,
        "location_message_id": 29,
        "conversation_round_id": 7359,
        "conversation_type": "tick",
        "trigger_uid": "",
        "sender_type": "tick",
        "sender_id": "tick",
        "sender_name": "SubTick",
        "message_type": "text",
        "min_app_version": 0,
        "created_at": "2026-08-10 11:06:37",
        "payload": {
          "current_time": "Day 1, 13:50",
          "tick_no": 1,
          "sub_tick_no": 2,
          "global": "The promise-shaped key pulses.",
          "story_events": [],
          "characters_moved": []
        },
        "err_no": 0,
        "err_msg": ""
      }
    ],
    "has_more": false,
    "newest_message_id": 29
  }
}
```

### 轮次元数据与回复按钮资格

`GET /aitown-chat/api/messages` 和 `GET /aitown-chat/api/v2/messages` 的消息在顶层返回 `conversation_type` 与 `trigger_uid`；候选卡查询的 `data.list[].messages[]` 使用相同解析规则。客户端请求体、query、鉴权和订阅不新增 `trigger_uid`。

UID 原字符串保存并精确比较；空字符串永远不匹配当前用户。Location Chat 只按最新 conversation 的服务端元数据决定业务资格，并继续叠加最新轮次、已完成且有正式 AI 回复、连接就绪、Tick 锁定、busy/frozen、候选卡完整性和生成数量等既有安全条件：

| 最新 conversation | Regenerate | Go On | Edit | 灵感回复 |
| --- | ---: | ---: | ---: | ---: |
| `trigger_uid == 当前 UID` 且 `conversation_type=user_message` | ✓ | ✓ | ✓ | ✓ |
| `trigger_uid == 当前 UID` 且 `conversation_type=go_on` | ✓ | ✓ | ✓ | ✓ |
| `conversation_type=opening`，不限触发者 | — | ✓ | ✓ | ✓ |
| `conversation_type=user_enter_location`，不限触发者 | — | ✓ | ✓ | ✓ |
| `conversation_type=tick`，不限触发者 | — | ✓ | — | ✓ |
| 其他用户触发的正常对话、缺失/未知/冲突字段 | — | — | — | — |

候选卡读取与切换、Regenerate 仍仅用于本人触发的正常对话；Enter、Tick、Opening 的灵感请求使用正式轮次，不传候选 `card_id`。Regenerate 保留每轮最多 10 张回复卡（含原卡）的限制；Edit 和 Inspiration 的会员／额度检查仅在用户点击相应入口时发生，Regenerate、Go On 的 Gems 余额由服务端在请求时判断。

实时 WS 当前只为 opening 下发 `conversation_type`。只有非空 `trigger_uid`、尚无 `conversation_type` 的实时轮次严格保持四个按钮不可用，直到正常历史刷新提供类型；客户端不主动为此查询历史，也不从 WS `type` 或本地动作推断。

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

本次图片消息增量只更新 `nar_new_message` 下行事件和历史消息返回 DTO；没有修改该接口的请求结构。

响应 `data`：

- `message_id`: integer，写入消息 ID

## Search 接口

### GET `/api/v2/search`

Meilisearch 全局搜索。请求参数和响应 envelope 沿用 v1；`type` 为空字符串时表示同时搜索 origin、world、user 三类。

相较 `/api/v1/search`：

- 在线请求完全使用 Meilisearch，不再回查 MySQL。
- Origin 搜索范围包含名称、brief、人物姓名和 Tag；World 搜索名称和 Tag；User 搜索姓名。Tag 优先级最低，支持完整词、词项和前缀命中，但不允许 typo。
- `keyword` trim 后少于 3 个 Unicode 字符仍返回空结果。
- 当 `keyword` 以小写 `o_`、`w_`、`u_` 开头且 Unicode 长度恰好为 8 时，只在对应索引做 ID 精确匹配；其他长度按普通文本搜索。
- ID 精确匹配时，显式 `type` 与 ID 前缀不一致会返回成功 envelope 和三类空结果；不支持的 `type` 也按相同方式返回空结果。
- `keyword/type/pn/rn`、`x-system-language`、`SearchEnvelope` 以及 `origins/worlds/users` 三段响应结构保持不变。

Query：

- `keyword`: string
- `type`: string，空字符串表示三类都搜；可传 `origin`、`world`、`user`
- `pn`: integer，页码，从 1 开始
- `rn`: integer，每页条数

响应是 `SearchV2Envelope`，HTTP 状态始终为 200，通过 `err_no` 区分结果：

- 成功 `SearchV2SuccessEnvelope`：`err_no*=0`、`err_msg*`、`data*: SearchV2Resp`
- 失败 `SearchV2ErrorEnvelope`：`err_no*!=0`、`err_msg*`、`data*={}`；`data` 不允许额外字段

`SearchV2Resp`：

- `keyword*`: string，回显搜索词
- `type*`: string，回显搜索类型；空字符串表示三类各以 `pn=1/rn=3` 返回预览
- `origins*`: `SearchV2OriginResult`
- `worlds*`: `SearchV2WorldResult`
- `users*`: `SearchV2UserResult`

三个 Result 都完整保留 `list/total/pn/rn`：`total` 是 int64、最大 20；`pn` 最小 1；`rn` 最小 1、最大 20。`type` 为空时忽略请求 `pn/rn` 并分别返回三类最多 3 条；显式指定类型时只有选中类型返回 list，但三类都返回实际 total。`list` 的 item 类型分别为 `SearchV2OriginItem`、`SearchV2WorldItem`、`SearchV2UserItem`。

`SearchV2OriginItem`（全部必填）：

- `origin_id/origin_name/origin_version/brief/language`: string；`origin_version` 与 `origin_name` 同级
- `cover`: `ImageResource`
- `tags`: string[]
- `characters`: `SearchV2OriginCharacter[]`
- `owner`: `SearchV2Owner`
- `stats`: `SearchV2OriginStats`
- `matches`: `SearchV2Match[]`，包含名称、brief、最多 5 个人物及所有 Tag 命中
- `matches_truncated`: boolean；只表示人物姓名命中超过 5 项被截断，不表示 `origin_name` 或 `brief` 被截断

`SearchV2WorldItem`（全部必填）：

- `world_id/world_name/origin_id/language`: string
- `cover`: `ImageResource`
- `tags`: string[]
- `owner`: `SearchV2Owner`
- `stats`: `SearchV2WorldStats`
- `created_at`: int64
- `matches`: `SearchV2WorldMatch[]`，包含 World 名称及所有 Tag 命中

`SearchV2UserItem`（全部必填）：

- `uid/name`: string
- `avatar`: `ImageResource`
- `matches`: `SearchV2UserNameMatch[]`，最多 1 项

共享子模型：

- `ImageResource`: `sm_url* / xl_url* / object_key*`，均为 string
- `SearchV2Owner`: `uid* / name* / avatar*`；契约中没有 `deleted`
- `SearchV2OriginCharacter`: `character_id* / name*`
- `SearchV2OriginStats`: `copy_cnt* / discuss_cnt* / character_cnt* / connect_cnt* / location_cnt* / max_tick_cnt*`，均为 integer
- `SearchV2WorldStats`: `tick_cnt* / sub_tick_no* / connect_cnt* / character_cnt* / player_cnt*`，均为 integer；依次表示当前主线 Tick 序号、当前子 Tick 序号、累计 Connect 数、当前 Character 数和当前 Player 数
- `SearchV2TagMatch`: `field*=tag`、`tag_index*`、`highlight_ranges*`；`tag_index` 定位当前 item 的完整 `tags[]` 元素
- `SearchV2HighlightRange`: `start*` 最小 0，`length*` 最小 1；二者均以 UTF-16 code unit 为单位，例如 `A😀B` 中 `B` 的 `start=3`

Origin 的 `SearchV2Match` 是严格的 `oneOf`：

- `SearchV2TextMatch`: `field*=origin_name | brief`、`highlight_ranges*`，没有 `character_id`
- `SearchV2CharacterMatch`: `field*=character_name`、`character_id*`、`highlight_ranges*`
- `SearchV2TagMatch`: `field*=tag`、`tag_index*`、`highlight_ranges*`
- 每个 `highlight_ranges` 至少 1 项并按 `start` 升序；`origin_name`、`brief` 和 `character_name` 的范围分别作用于完整 `origin_name`、完整 `brief`、`character_id` 对应人物的完整 `name`
- Origin 最多返回 1 个 `origin_name`、5 个 `character_name`、1 个 `brief`，同时返回所有 Tag 命中；`matches_truncated` 只表示人物姓名被截断

World 与 User 使用独立命中模型，二者都没有 `character_id`：

- `SearchV2WorldNameMatch`: `field*=world_name`，范围作用于完整 `world_name`
- `SearchV2WorldMatch`: `SearchV2WorldNameMatch | SearchV2TagMatch`
- `SearchV2UserNameMatch`: `field*=user_name`，范围作用于 User item 的完整 `name`
- 所有模型都有必填 `highlight_ranges`，至少 1 项并按 `start` 升序

所有 match 都不返回原文或 HTML。客户端保留目标原始字符串和 UTF-16 范围，后续自行渲染高亮。

实现状态：保留 `SearchV1Api.search({query, type, pn, rn})` 调用入口，请求实际发送到 `/api/v2/search`。公共 envelope 仍由 `handleV1ResponseErrNo` 统一消费：成功时把 `data` 解析为 typed `SearchV2Response`（对应文档的 `SearchV2Resp`），失败时抛出带 `err_no/err_msg` 的业务异常。页面展示模型同时持有三类原始 typed item，不丢弃 `matches`。

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
- `target_id*`: string，举报对象业务 id；`message` 当前按 `global_message_id` 原样记录，不做存在性校验
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

## Collect 接口

### POST `https://collect.worldo.ai/api/v1/collect`

批量提交客户端行为事件。客户端在事件发生时先写入独立 SQLite 队列；冷启动的 `startup_first_report` 和 `launch_startup` 在 Collect recorder 准备完成后立即记录，早于 Firebase/Telemetry 完整初始化；页面不等待后台 config，若首帧先于 recorder 就绪，启动事件保留发生时耗时，待哨兵记录后依序写入队列。Telemetry 初始化完成后再由独立上传器消费；每次按 FIFO 最多领取 100 条，客户端批次同时限制为 256 KiB。只有收到 2xx、有效 JSON 对象且 `err_no=0` 后才删除；所有未确认成功的事件保留原 `event_id` 和内容并恢复待发送。HTTP 400/413/422 可拆批重试，失败单条和超限单条仍保留；不再写入会被清理的内存 dead letter。失败记录移到队尾，给后续未尝试事件发送机会。

请求 header 在实际上传时按事件入队时保存的身份和环境快照生成；不同上下文分批，重新登录不改写旧事件的 UID：

- `X-Platform`: `android` 或 `ios`
- `X-App-Version`: 事件发生时的 App version name
- `x-app-environment`: `production` 或 `test`
- `X-Device-ID`: 当前设备 ID；允许匿名事件明确省略
- `X-UID`: 事件发生时已登录用户 uid；未登录或允许匿名事件不传

请求 body：

- `events*`: array，本批事件，按本地入队顺序排列；客户端默认最多 100 条，接口原约定上限为 500 条
- `events[].event_id*`: string，客户端生成的 UUID v4；重试保持不变，供服务端幂等去重
- `events[].action_type*`: string，事件类型，例如 `pageview`、`event`、`monitor`、`pay_event`；`api_req_start`、`api_req_success`、`api_req_fail_tech`、`api_req_fail_biz` 使用 `monitor`
- `events[].action*`: string，页面名或事件名
- `events[].app_timestamp*`: integer，事件发生时的本地 Unix 毫秒时间戳，不是上传时间
- `events[].object1*`: string，第一个业务对象；无值传 `""`
- `events[].object2*`: string，第二个业务对象；无值传 `""`。接口监控使用同一逻辑请求的 `request_id` 关联 start 与终态
- `events[].object3*`: string，第三个业务对象；无值传 `""`
- `events[].object4*`: string，第四个业务对象；无值传 `""`。接口监控 start 传 `"0"`，终态使用不带单位后缀的整数毫秒字符串记录最终一次实际 transport send 的耗时
- `events[].ext_data*`: string，扩展信息；无值传 `""`。接口失败传脱敏后的 JSON 字符串，可包含 `reason`、`message`、`native_code`、`upstream_status`、`upstream_path`、`retry_count`；不得包含请求 header、query、body、完整响应 body 或 stack trace
- App 生命周期事件使用 `action_type: "event"`：`app_background.object1` 为空；与其配对的 `app_foreground.object1` 为本次后台停留时长，使用不带单位后缀的非负整数毫秒字符串。冷启动不产生 `app_foreground`
- 客户端接口监控使用 `api_req_start`、`api_req_success`、`api_req_fail_tech`、`api_req_fail_biz`。持续后台轮询接口不产生接口监控事件：`GET /api/v1/message/unread`、`GET /api/v1/direct_message/conversations`、`GET /api/v1/direct_message/list`；`/api/v1/collect` 永久排除。`/api/v1/app/config` 及三个启动关键 Gateway 接口固定上报，其他普通业务接口按启动级采样开关决定。

请求示例：

```json
{
  "events": [
    {
      "event_id": "813b862f-e8c7-44a5-92ea-5fe5cb4df9ab",
      "action_type": "pageview",
      "action": "home_my_worlds",
      "app_timestamp": 1784692855123,
      "object1": "",
      "object2": "",
      "object3": "",
      "object4": "",
      "ext_data": ""
    }
  ]
}
```

成功判定：HTTP 状态码为 2xx，且 JSON 响应中的 `err_no` 为数值 `0` 或字符串 `"0"`。非 2xx、超时、网络异常、无效 JSON 或非零 `err_no` 都视为该次请求失败，不支持在一个响应内确认部分事件。客户端因大小限制或请求被拒绝而拆成多个子请求时，每个成功子批次会按 `event_id` 独立确认，只重试尚未成功的部分；本地删除失败的已成功事件保持 in-flight。写库超时后的迟到记录会与内存副本按同一 ID 归并，避免两个队列再次发送。 内存备用队列不再按原 300 条阈值淘汰未确认数据；数据库恢复后补写入库。若数据库始终不可写且进程退出，内存记录仍有丢失风险，详见 [失败保留策略](/Users/long/Project/GenesisApp_2/genesis_app/docs/collect-failure-retention.md)。

响应示例：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {}
}
```

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

截至 2026-09-11，本文档覆盖的 55 个接口已完成主要 HTTP 契约对齐；Collect 已切换为 SQLite 持久化队列和 `events[]` 批量协议，其余接口继续按各自文档维护当前封装、本地 mock 与测试：

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
| `GET /api/v1/user/memory-settings` | 已新增 `UserV1Api.memorySettings(worldId)`；首次进入 Memory & Model 时请求，缓存属于 WorldPage 生命周期；主动 Retry、下拉刷新及保存后的实际用量刷新仍请求服务端。卡片 Memory 区间使用实际用量至已保存预算，详见 `gem-cent-app-contract.md`。 |
| `POST /api/v1/user/memory-settings` | 已新增全局预算接口 `UserV1Api.updateMemorySettings(memoryTokens)`，body 仅发送 `memory_tokens`；页面滑杆交互 500ms 防抖自动保存，成功后同批刷新 Worldo 实际用量和模型报价，不确定结果只做全局 GET 核对且不自动重试。 |
| `GET /api/v1/user/world-history-settings` | 已新增 `UserV1Api.worldHistorySettings`，解析当前生效值、持久化值、来源和降级状态；Developer Page 仅在测试环境且存在完整登录 session 时显示入口。 |
| `PUT /api/v1/user/world-history-settings` | 已新增 `UserV1Api.updateWorldHistorySettings`，JSON body 原子提交 `high_watermark/low_watermark`，Developer Page 在提交前校验 Apifox 范围。 |
| `DELETE /api/v1/user/world-history-settings` | 已新增 `UserV1Api.resetWorldHistorySettings`，无 body，成功后用服务端返回的默认生效值刷新输入框。 |
| `GET /api/v1/world/list` | `WorldV1Api.list` query 已使用 `scene/tag/origin_id/uid/keyword/pn/rn`；自有数据只传 `scene=mine`，指定用户数据传 `scene=uid&uid=...`，标签数据传 `scene=tag&tag=...`；首页和个人 world 列表可消费 `list[].info + stats`；详情入口使用 `info.definition_version/default_map_location_id` 立即挂载不可交互的 Tilemap，地图返回后即可渲染，detail 返回后再补齐 location tree 与交互。 |
| `GET /api/v1/world/info` | 已新增 `WorldV1Api.info(worldId)` 与 `GenesisApi.getWorldInfo(wid)`，query 使用 `world_id`；响应消费 `info + stats`，不期待 `relation_status/characters/locations/ticks`。 |
| `GET /api/v1/world/detail` | `WorldV1Api.detail` query 只使用 `world_id`；详情 mapper 消费 `info.definition_version`、`info.last_chat_location_id`、`info.metric`、`relation_status` 与 `locations[].location_description/location_paragraph/location_timestamp/dialogue`；`last_chat_location_id` 用于进入 World 时初始化地图和 Location List 的 Recent Message 标签，本次页面会话内再由发送成功后的内存临时记录覆盖；地图 JSON 按需通过 `/world/map` 获取，完整 tick 列表通过 `/world/tick/list` 获取。 |
| `GET /api/v1/world/map` | 已新增 `WorldV1Api.map(worldId,locationId)` 与 `GenesisApi.getWorldMap(...)`，query 使用 `world_id/location_id`；响应映射为 `TilemapDefinition`，其中 `tile_types` 为瓦片类型到线上图片 URL 的映射，`map_json` 使用 `width/height` 描述网格尺寸，`tiles[]` 使用 `x/y/type/shadow/location_id?` 描述瓦片；并明确支持旧地图的空对象 `data={}`。 |
| `GET /api/v1/world/tick/list` | `WorldV1Api.tickList(worldId,pn,rn)` 与 `GenesisApi.getWorldTicks(wid,limit,offset)` 使用 `world_id/pn/rn`；服务端只返回 `status=50 (p2_done)` 的最新完成 tick，客户端完整保留 `sub_tick_no`、`tick_result.current_time`、段落可见性/线索/整数指标增量及 location groups。 |
| `GET /api/v1/world/origin_progress` | 已新增 `WorldV1Api.originProgress(uid,originId)`，query 使用 `uid/origin_id`，响应消费 `world_id/tick_cnt`；origin discuss loader 会用该接口补齐每条评论作者在当前 origin 下的 world 与 tick 进度。 |
| `POST /api/v1/world/tick` | 新契约替代旧 progress 触发接口；客户端应提交 `{ "world_id": "<world_id>" }` 并消费 `world_id/tick_cnt/last_tick`。 |
| `GET /aitown-chat/api/ulocation` | `ChatroomHttpApi.getUserLocations(worldId)` query 使用 `world_id`，响应消费 `locations[].characters[]`，角色字段为 `char_id/player_uid/player_username/name/location_id`；`WorldChatroomService` 用 `player_uid` 识别真实用户并刷新所在 location，本地 mock 从 world detail 角色列表生成同形状响应。 |
| `GET /aitown-chat/internal/world/messages` | `ChatroomHttpApi.getWorldMessages(worldId)` 保留旧 world 级恢复/诊断能力，响应消费 `locations[].location_id/messages[]`；location chat 页的 initial、older 和 gap 不直接依赖该接口。旧 DTO 继续解析 `global_message_id/message_id/location_message_id/message_type/current_time/tick_no/created_at`。 |
| `GET /aitown-chat/api/messages` | `ChatroomHttpApi.getLegacyMessages(worldId,locationId,since,limit)` 显式保留旧扁平消息接口，供兼容/诊断使用；旧 typed JSON timeline payload 和图片规则不变。零游标记录中仅 `tick` 保留 world-message 排序/双游标语义，`user_enter_location/story_events/characters_moved` 只兼容入队、展示与后备去重。 |
| `GET /aitown-chat/api/v2/messages` | `ChatroomHttpApi.getMessages(worldId,locationId,since,limit)` 已切换 V2 per-location 路径；共享 `ChatroomV2Message` 保留 `type/stream_type/ts`、完整 ID、sender、`client_msg_id/message_type/min_app_version/created_at`、原始 `payload` 和数字 `err_no`。`ChatroomHttpMessage` 额外暴露 `businessType/streamType/clientMsgId/minAppVersion/payload/v2TickPayload`。分页和 `newest_message_id` 均严格使用当前地点 `location_message_id`。合法/回退 Tick 均保留正游标；SQLite v4 定向清除旧的游标零 `tick/story_events/characters_moved` 行，新的 canonical Tick 只写一条缓存行。Local mock 支持相同路由、字段、倒序分页和地点 newest 语义。 |
| `POST /aitown-chat/internal/tick/lock` | 已新增 `ChatroomHttpApi.lockWorld(worldId)`，按 Apifox 同时发送 query `world_id` 与 multipart form `world_id`，响应消费 `locked`。 |
| `GET /aitown-chat/internal/tick/progress` | 已新增 `ChatroomHttpApi.tickProgress(worldId)`，响应消费 `progress/pending_messages/active_llm_calls`。 |
| `POST /aitown-chat/internal/tick/unlock` | 已新增 `ChatroomHttpApi.unlockWorld(worldId)`，multipart form 发送 `world_id`，响应消费 `unlocked`。 |
| `POST /aitown-chat/internal/narrator/write` | 已新增 `ChatroomHttpApi.writeNarrator(worldId,tickId,locationGroups)`，body 使用 `world_id/tick_id/location_groups`，响应消费 `message_id`；本地 mock 会写入 narrator 消息。 |
| `GET /api/v2/search` | `SearchV1Api.search` 保留调用入口但返回完整 `SearchV2Response`；继续发送 `keyword/type/pn/rn`，完整消费三类分页块及所有 item 字段；三类都保留 `matches[].field/highlight_ranges`，只有 Origin 的 `character_name` 命中带 `character_id`，Origin 额外保留 `characters` 和 `matches_truncated`；范围使用 UTF-16 code unit。 |
| `GET /api/v1/origin/list` | `OriginV1Api.list` query 已使用 `scene/tag/tag_id/keyword/uid/pn/rn`；自有数据只传 `scene=mine`，指定用户数据传 `scene=uid&uid=...`，标签数据传 `scene=tag&tag=...`；origin 页面和主 `getOrigins/getMyLaunchedOrigins` 可消费 `list[].info + stats`；详情入口使用 `info.definition_version/default_map_location_id` 立即挂载不可交互的 Tilemap，地图返回后即可渲染，detail 返回后再补齐 location tree 与交互；首页 popular 会优先消费 `list[].discusses` 作为最新 2 条讨论预览，本地 mock 仅默认/`popular` 场景返回该字段。 |
| `GET /api/v1/origin/feed` | `OriginV1Api.feed` 使用 `start_score/rn`；Origin 页仅 For you 使用该接口，刷新传 `0`，分页严格复用响应 `next_score`，并以 `has_more` 和游标前进共同决定是否继续；`list[].info` 保留 `definition_version/default_map_location_id`，详情 loading 阶段据此直接挂载不可交互的默认 2.5D Tilemap，地图渲染不等待 detail。 |
| `POST /api/v1/origin/feed/exposure` | `OriginV1Api.reportFeedExposure` 提交 `origin_ids`；Origin 页仅在封面成功渲染后，按列表真实内容视口内 30% 可见面积和连续 1.5 秒可见时长采集；占位、加载中、加载失败、低于阈值或快速经过均不采集，本地按页面生命周期去重。 |
| `GET /api/v1/origin/hot_tags` | 已新增 `OriginV1Api.hotTags`，响应消费 `data.list` 字符串数组；`OriginPage` 固定首个 `For you` tab，其余 tabs 来自热门标签接口并缓存在本地，本地 mock 返回同形状数据。 |
| `GET /api/v1/origin/my_launch_preset_characters` | `OriginV1Api.myLaunchPresetCharacters(originId,limit)` 与 `GenesisApi.getMyLaunchPresetCharacters(originId,limit)` 的 query 使用 `origin_id/limit`；Opening Sheet 固定请求 `limit=5`，服务端先按 `last_active_at DESC` 排序再限制数量，客户端按响应顺序展示；响应映射为 `OriginMyLaunchPresetCharacter` 列表并保留 `ImageResource`。 |
| `GET /api/v1/origin/info` | 已新增 `OriginV1Api.info(originId)` 与 `GenesisApi.getOriginInfo(oid)`，query 使用 `origin_id`；响应消费 `info + stats`，不期待 `characters/locations/ticks`。 |
| `GET /api/v1/app/config` | iOS 启动先用独立的 URLSession HEAD 探测等待联网，网络权限弹窗停留期间不计入超时；连通且 App 恢复前台后，再创建启动服务并请求 config。拒绝或持续断网时，恢复前台后最多等待 8 秒，再沿用原失败流程。`AppV1Api.config` 在读取本地登录 UID 后请求，有真实非 guest UID 时传可选 query `uid`，未登录、读取失败或超时时不传。网关校时 → config 仍按签名依赖串行，但整条链路与页面启动并行，不再以 3 秒等待阻塞 `runApp`；网络层超时仍生效，成功后更新配置和采样率。首次请求未完成或失败时开关默认 false，只有确认 `show_personalization_form=true` 才进入填表流程。`show_opening_sheet` 按进入 Origin Detail 时已获得的配置决定 Opening Sheet 首帧展开状态。 |
| `GET /api/v1/origin/detail` | `OriginV1Api.detail` query 使用必填 `origin_id`；详情 mapper 保留新版 `OriginDetailInfo`、完整 stats、nullable 顶层 `init_location_group`、`characters[].is_recommend`、location 层级/时间/总结/2.5D `x/y`、ImageResource sidecar，以及 tick 的 `sub_tick_no/current_time/visibility/visible_to/clue/character_deltas`。本接口不再承载 Opening Sheet 展示配置，不依赖 `location_description`，也不为新版 tick 人工补 `location_groups`；旧响应实际携带这些字段时仍可兼容读取。详情 Opening、location chat 预览和 launch 初始地点优先使用顶层 group；`nar_pic/image` 作为图片消息展示。 |
| `GET /api/v1/origin/map` | 已新增 `OriginV1Api.map(originId,locationId)` 与 `GenesisApi.getOriginMap(...)`，query 使用 `origin_id/location_id`；响应映射为 `TilemapDefinition`，其中 `tile_types` 为瓦片类型到线上图片 URL 的映射，`map_json` 使用 `width/height` 描述网格尺寸，`tiles[]` 使用 `x/y/type/shadow/location_id?` 描述瓦片；并明确支持旧地图的空对象 `data={}`。 |
| `GET /api/v2/origin/foredit` | `OriginV2Api.forEdit(originId)` 使用 `origin_id` query，并按嵌套 `OriginDetail` 消费；`characters[].is_recommend` 以 `0/1` integer 回填角色推荐状态。`EditOriginPage` 直接从该响应回填 Basics、Characters、Locations、Opening 和兼容 tick Opening，不再追加请求 `/api/v1/origin/detail`。新契约未返回的旧平级 `setting/events` 仅在响应实际包含或用户明确修改时随 V2 update 提交；`Character` 未返回旧 `bio/description` 时，未编辑的空 Biography 也不随 update 回写，避免普通编辑把服务端已有值清空。 |
| `POST /api/v1/origin/create` | 当前 `OriginV1Api.create` 已发送 `origin_name/origin_version/brief/setting/events/tags/metric/started_at/tick_duration_time/cover/characters/locations`，但尚未暴露新契约中的 `definition_version/map_url/tile_types`；高层 `GenesisApi.createOrigin` 已兼容轻量 `OriginUpsertResp`。 |
| `POST /api/v1/origin/update` | 当前 `OriginV1Api.update` 已发送 `origin_id/origin_name/origin_version/brief/setting/events/tags/metric/started_at/tick_duration_time/cover/characters/locations/update_notes/deleted_char_ids/deleted_location_ids`，但尚未暴露新契约中的 `definition_version/map_url/tile_types`；高层 `GenesisApi.updateOrigin` 已兼容轻量 `OriginUpsertResp`。 |
| `POST /api/v2/origin/create` | 已新增 `OriginV2Api.create` / `GenesisApi.createOriginV2`，完整支持含 `characters[].is_recommend` 的 V1 create body 与 `init_location_group`。Create 页面在同步成功且返回非空 `origin_id` 后立即展示创建成功，不等待异步地图状态；本地 mock 覆盖 definition version 2、Opening 保存与 processing 状态。 |
| `POST /api/v2/origin/update` | 已新增 `OriginV2Api.update` / `GenesisApi.updateOriginV2`，完整支持含 `characters[].is_recommend` 的 V1 update body、删除列表和完整 `init_location_group`；Edit 页面继续通过 V1 info 等待状态 10。本地 mock 返回递增版本、回显 Opening，并在 info 轮询中确定性模拟 `20 -> 10`。 |
| `POST /api/v1/origin/launch` | `OriginV1Api.launch` body 使用 `origin_id/preset_character_id/custom_role`；详情页发送 preset 或 custom 二选一 payload，不提供 preset 编辑或 override 调用链，并消费响应 `world_id`。 |
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
| `POST /api/v1/report/create` | 已新增 `ReportV1Api.create`，body 使用 `target_type/target_id/content`，响应消费 `report_id`；World、Worldo、用户详情页和 location chat 长按菜单已接入，其中 message report 的 `target_id` 使用 `global_message_id`；通过共享 `GenesisApi` runtime header path 自动带上 `device-id/app-id/app-version/app-platform/authorization`；本地 mock 校验 `target_type`、空 `target_id/content` 与 1000 字符长度限制，并为用户详情页 report 补充接受 `target_type=user`。 |
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
- `GET /api/points/{pointId}/messages`
- `POST /api/points/{pointId}/messages/enqueue`
- `GET /health`


## Gems 购买等待时限（2026-09-09 调整）

- Android、iOS 均采用两段超时：点击购买进入 `purchaseGem` 时启动 90 秒准备计时，覆盖商店初始化、购买 UUID、商品查询和调起支付；准备阶段切换不重置截止时间。Google 在 SDK 返回成功调起支付后停表；Apple 在原生商品查询和未完成交易检查结束、正式调用 StoreKit `Product.purchase` 前通知 Dart 停表。Apple 没有独立的支付页可见回调，此处以交给 StoreKit 为边界。用户在系统支付页操作或停留期间不计时。
- 截止前尚未发起支付时，超时关闭等待弹窗并提示重试；迟到的初始化、UUID 或商品查询结果不能继续拉起系统支付，也不能修改下一次购买状态。
- SDK 调起调用尚未确认接管时仍受准备时限约束；超时沿用待确认提示并保留购买上下文。iOS 原生查询迟到时再次检查本次请求是否仍有效，过期则不调用 `Product.purchase`。`store_no_callback` 保留为准备/调起等待超时的埋点标记，不代表用户付款失败或服务端收到商店通知；迟到的真实购买回调继续按原流程上报和恢复。
- 收到本次购买结果后按原有状态处理：取消/错误结束等待；pending 进入原待确认流程；成功持久化凭据并上报。第二段 report 只发送一次，使用 HTTP 请求自身的超时且不重试，不再复用 90 秒准备计时，正常上报期间保留原等待弹窗。超时不删除未确认的付款凭据。
- iOS 通过本地 `third_party/in_app_purchase_storekit` 补充与请求关联的原生通知；使用当前 StoreKit 2 路径，详见其 `WORLDO_PATCH.md`。更新这部分需要重新构建原生 App，热重载不能更新 Swift 代码。

## Pro 会员商品列表（2026-09-11 客户端契约）

来源：[Apifox 会员商品列表](https://app.apifox.com/link/project/8297783/apis/api-512137864)。2026-09-17 按用户确认增加 has_subscription_order；本次不编辑在线 Apifox。

- 商品响应为 `{err_no, err_msg, data: {list: [...], last_account_uuid: "...", has_subscription_order: false}}`，不携带客户端使用的会员状态；成功但无配置时 `list=[]`。业务错误沿用统一处理。
- 每项提供 `title`、`benefits`、`plan_code`（`pro_monthly`/`pro_yearly`）、`provider`、`store_product_id`、`billing_months`（1/12）、`monthly_gems_cent`、`price_currency_code`、`price_amount`。Google 还必含 `base_plan_id`，可选 `offer_id`；Apple 不返回 base plan。标题、权益、价格继续按当前契约解析，不填默认商品。
- `last_account_uuid` 与 list 平级；非空时是所有套餐优先使用的购买身份，空/null 时游客 prepare、登录用户读取本人 UUID。商品项不再解析 can_purchase、purchase_block_reason、purchase_action、account_uuid、purchase_token。该 UUID 不表示会员权益。
- `has_subscription_order` 为与 `list`、`last_account_uuid` 平级的布尔值。未登录用户点击购买时，当前商品响应中该值为 true 则结束本次购买并弹出已有登录弹窗，不获取购买 UUID、不调用 prepare、不调起商店、不 report；登录成功或关闭弹窗均不自动购买。已登录用户继续原购买流程。旧响应缺失/null 按 false 兼容，非布尔值视为契约错误。页面加载、商品预热和套餐切换不会因此弹登录窗。
- `GemWalletStore` 保存当前账号钱包及会员数据；`MembershipAccessStore` 统一从 `/api/v1/gem/wallet` 的 `membership` 推导当前账号权益。`membership_status=0` 为未开通，2 为已失效；1 时必须有有效到期时间及服务端校准时间，且 `expires_at > now` 才有效，等于或早于 now 为已过期。会员数据、有效状态所需时间缺失时为未知。`auto_renew` 和宝石余额不参与有效性判断。
- 全局 `checkVip(callback)` 保持一次异步回调；true 有效、false 非有效、null 未知。wallet 没有在途刷新且最近请求未失败时，有效缓存可直接使用；如页面或购买/绑定流程已发起 wallet 刷新（含读取登录身份阶段），先等待同一请求完成再判断，不提前返回旧缓存、不重复发请求。请求失败或超时返回未知，不把旧的非会员缓存用于签到订阅入口；缺失或过期缓存按原去重/冷却策略刷新。退出及切换账号清空旧状态并忽略迟到结果。
- 已登录用户每次打开完整支付页面或购买底部弹层，先展示当前账号缓存并请求 wallet 刷新，商品请求并行；在途 wallet 请求复用。同一次打开不因组件重建或切换 TAB 重复触发会员刷新。商品初始仍只加载当前 TAB，另一个 TAB 首次访问才加载，Gems 原有请求逻辑不变。
- Subscription 按全局 wallet 状态展示。同套餐且自动续订时显示 Subscribed，其余显示金额。点击月付时复用全局 checkVip（缓存有效直接用，刷新中等待同一请求），仅有效年会员拦截降级；月升年、同套餐、过期、未知均交给平台。点击不强制刷新 wallet，也不重复请求 products；等待本次页面商品加载，没有有效商品配置时不能调起。
- Me 当前账号会员卡片和徽章读取同一全局状态；状态 2 或状态 1 且已到期使用已有失效样式。只调整数据绑定，不调整 UI 尺寸、布局、颜色或文案。
- 未登录用户不请求 wallet、不按游客月年会员类型做客户端购买拦截。游客继续依据 `/membership/guest/purchase/check` 的 `has_unbound_order` 触发登录绑定；该字段不是会员有效状态。启动时优先用已购买缓存中的 UUID 调用 check，不查询商店；没有已购买缓存时才只读查询当前 App 的 Google SUBS / Apple 有效订阅，排除待付款及已过期订单，按购买时间选择最新一笔取得原 UUID，只查这一笔。仅 prepare 的临时身份不参与 check；false 是正常结果，不触发退避重试。平台交易校验、归属校验、购买成功后的 report、成功弹窗 OK、强制登录及 claim 退避重试保持原链路。
- 商品展示缓存为 v3，按账号、平台和环境隔离，仅存展示与选中套餐配置。last_account_uuid 和 has_subscription_order 仅保留本次响应的内存下单快照，不写商品磁盘缓存；重新进入或切换账号后使用新响应。report/claim 状态变化继续使快照失效并刷新商品。
- 年付卡片展示完整年价除以 `billing_months` 的月均金额，底部按钮展示完整周期价格；币种及月额度相同才按月价乘 12 与年价计算 Save。实际扣款由商店确认。展示列表不查询平台，点击购买才查询匹配 store product/base plan/offer。
- `report=completed` 后登录用户刷新 wallet，游客保留待绑定证明；accepted 提示确认中，rejected 提示失败。任一业务状态都结束 report，不再补报；claim 独立处理，完成后刷新 wallet，不重新触发 report。
- 商品权益仍由服务端返回并按当前套餐展示；title 保持现有固定页面标题行为，价格及权益不补本地数据。`enhanced/locked/included`、图标映射和加载表现保持现有样式。未登录仍隐藏 Buy Gems 和购买历史入口。
- 普通 Gems 使用 `wallet.balance_cent`，会员 Blue Gems 使用 `membership.blue_gems_cent`，互不替换；原 Gems 购买、签到、补报逻辑不变。
- 签到确认弹窗通过全局 `checkVip(callback)` 区分会员：有效会员把原 `Get 100` 按钮替换为 `Cancel`（去掉宝石图标），点击只关闭弹窗；`Check in` 保持原来的第二行位置、样式和签到行为，不展示订阅入口；明确非会员（含过期会员）的未签到弹窗保留 `Get 100` / `Check in`。签到入口（登录后自动弹出与 Buy Gems 手动入口共用）先等待当前账号的游客 claim 本轮处理及其完成后的 wallet 刷新，再调用全局 checkVip；不能用登录后、绑定前返回的非会员缓存提前选定弹窗按钮。claim 仍 accepted、失败或等待超时，以及绑定后 wallet 刷新失败时，都按会员状态暂不可确认处理。会员信息暂不可用时保留普通签到和取消，不引导重复订阅。会员待领奖按钮也使用 `Check in` 文案，底层仍按任务状态调用原 report/claim；已领取的禁用状态和奖励展示不变。登录后自动签到和 Buy Gems 签到入口共用此处理。
- 2026-09-18 登录后的自动签到先等待当前账号游客 claim 及绑定后的 wallet 刷新完成，再请求 `gem/tasks` 获取签到金额与任务状态；不能提前保存绑定前的 `reward_gems_cent` 后仅刷新会员按钮。金额完全使用任务接口返回值，不在客户端按会员身份翻倍或写死 100。绑定仍未确认、等待超时或请求失败时跳过本次自动提示，避免显示未确认奖励及主 Tab 立即重复调度；切换账号、离开可展示页面后忽略迟到结果。
- 本地 mock 返回 `{data: {list: [], last_account_uuid: "", has_subscription_order: false}}`，不伪造商品、标题、价格和权益。
- 仅 Debug 包在 Subscription 购买按钮上方原有间距内显示 `debug 订单 id：…`。读取当前会话最近一次主动购买回调的 `transactionId`（Google 商店订单号／Apple 交易 ID），取得前显示 `暂无`；不使用本地 request_id、report_id、商品 ID 或 purchase_token 代替。新购买及切换账号清空显示，旧订单的后台补报不覆盖新购买。只观察现有购买状态，不增加网络或商店查询，Profile/Release 不显示该行且保留原布局。


## 个性化资料（2026-09-16 核对）

- `GET /api/v1/device/personalization`：有登录 UID 时读取本人，否则读取设备；通过现有认证和 `X-Device-ID` 传递身份，不使用文档调试 header。返回 `gender`、`age`、`origin_feed_gender`、`completed`、有序 `form`；每项有 `name`、`label`、`required=true`、`options: [{value,label}]`。两类选项数量可变，客户端保留 value 原值提交。
- `POST /api/v1/device/personalization`：body 仅 `{gender, age}`；返回 `{gender,age,origin_feed_gender,completed}`，必须业务成功且 completed=true 才算保存完成。游客写设备、登录用户写本人；GET 不复制设备资料至 UID。
- `origin_feed_gender` 为独立的推荐偏好，枚举空串（未设置）、Male、Female、Non_binary、All，不参与 completed 判断。保存 gender/age 时，服务端仅在偏好未设置时初始化偏好；客户端保持响应原值。新接口 `POST /api/v1/device/personalization/update_origin_feed_gender` 单独更新偏好，响应同 PersonalizationInfo，只有 err_no=0 表示保存成功，不要求 completed=true。
- 每次启动检查；completed=false 展示已有不可取消的 PersonalizationSheet。动态 item 沿用原样式，不增加关闭或跳过入口。读取失败按未知重试，保存失败保留选项，不提前进入订阅或释放登录拦截。
- 优先级：资料检查/填写 > 游客 VIP 强制登录。Continue 保存成功后，待绑定订单的游客关闭资料弹窗进入原强制登录；其他情况继续原 Subscription。登录后重读当前 UID，清除跨身份状态；迟到的读写结果不得完成另一账号的引导。登录签到等待资料流程结束。
- 正式选项与预览数据分离；`PersonalizationStore` 管理当前身份与在途请求，`PersonalizationGate` 管理启动弹窗，VIP report/claim 和 Gems 购买、余额及奖励规则不变。

## Pro 会员购买与上报（2026-09-16 更新）


来源：[Apifox 项目](https://app.apifox.com/project/8297783)及本次用户明确的字段变更。以下为客户端契约，未修改在线 Apifox。

- 月付升年付：复用当前页面商品列表的 `last_account_uuid`，查询目标平台商品后发起购买。Google 月/年是同一订阅商品下的 base plan，按目标 `base_plan_id/offer_id` 取得 offerToken，以普通订阅购买交给商店切换，不再使用商品接口中的旧 token 或本地旧订单资格拦截；扣款/生效规则采用 Play Console 配置的默认替换模式，客户端不再硬编码 CHARGE_FULL_PRICE。Apple 继续按目标商品和原 UUID 购买，由订阅组配置决定切换。参考 [Google 同订阅 base plan 切换](https://developer.android.com/google/play/billing/subscriptions)。
- 支付成功继续从 SDK 回调取得真实 token/交易号走统一 report 及 wallet 刷新；技术失败直接结束，不重试。商品列表不再携带旧 token；历史恢复回调不能绑定到刚准备的新购买。旧版本待处理记录中已有的 token 摘要仍可读取用于排除旧回调。

- 游客身份及绑定队列以规范化的 `account_uuid` 关联；启动读取旧安全缓存时，序列化迁移删除旧 guest_id/claim_token，保留原 request_id、交易凭据、订单状态和已选择的 ownerUid。迁移写入失败不清空订单，下次继续尝试。
- Apple 签名 JWS 随待 claim 的游客购买凭据保存在现有安全存储中，claim 完成并清理成功后删除；同次运行和重启后均复用原 report 的完整凭据，不写普通日志。仅旧版本缺少 JWS 的缓存按原 transaction_id、商品 ID 从 StoreKit 交易历史读取对应的已验证签名，不用另一笔续订交易替代。Apple 请求 account_uuid 与交易 appAccountToken 不一致时客户端仍提交原请求 UUID 和完整 JWS，由服务端验签后使用签名 UUID 并记录告警；Google 仍严格匹配。缺少有效购买凭据时保留缓存并继续恢复，不发起 UUID-only claim。

- 购买身份取当前列表响应与 `list` 平级的 `last_account_uuid`：非空优先使用；空值时游客请求 prepare 获取临时 UUID，登录用户读取 `/user/info.uuid`。游客沿用该 UUID 进行支付、report 和 claim，登录后绑定不替换商店身份。购买请求中的实际凭据字段保持原样。
- `MembershipPurchaseService` 保存所选套餐的 `provider/plan_code/store_product_id/base_plan_id/offer_id` 和本次 `request_id`，订单快照不保存展示价格、权益或购买资格；`StoreMembershipCheckoutPlatform` 精确匹配 SDK 商品，使用 `buyNonConsumable` 调起订阅购买。Google 必须命中配置的 base plan / offer，不擅自替换方案，也不 consume 订阅。
- 点击 VIP 购买按钮立即复用 Gems 购买弹窗，保持原有尺寸、样式、动画和不可点击遮罩/返回关闭的交互，等待文案为 `Purchasing Premium`；商店准备、付款和服务端确认期间持续显示。`completed` 后显示 `Purchase successful!`、`Your Worldo Premium subscription is now active.`（正文居中换行，成功弹窗高度随内容适配），点击 `Continue` 后关闭成功浮层：完整 Subscription 购买页返回购买前的上一页，购买 Sheet 同时关闭。游客继续原有强制登录及绑定流程。取消、失败、待付款、已接管待确认或延迟确认时关闭等待弹窗并显示对应 VIP 提示，保留购买页面。
- VIP 弹窗按本次 `request_id` 订阅状态，后台恢复或其他订单不能改变当前弹窗。Android、iOS 的两段超时与 Gems 对齐：点击进入购买立即开始 90 秒准备计时，覆盖本地加载、身份/资格检查、商店商品查询、游客 prepare、UUID 获取和发起支付；阶段切换不重置。Google 成功调起后停表，Apple 在原生准备完成、正式调用 `Product.purchase` 前通知 Dart 校验请求并停表，用户在系统支付页停留不计时。收到本次 SDK 购买结果后进入对应处理，后续 report 使用 HTTP 请求自身的超时，技术失败不重试，正常上报期间继续显示原等待弹窗。准备超时后结束等待，尚未发起的支付不得被迟到结果继续拉起，旧查询/发起结果不得覆盖后续购买或已收到的购买回调；已发起订单保留凭据和原请求键，迟到的真实回调可发起尚未执行的 report 及游客绑定。商店回调流异常、账号切换和页面销毁仍释放弹窗，包括正在 report 的弹窗。Gems 弹窗默认文案及原有 GEMS 上报、发货和恢复处理不变。
- 登录购买上报 `POST /api/v1/membership/purchase/report`；游客上报 `POST /api/v1/membership/guest/purchase/report`，游客请求额外携带平级 `account_uuid`。共同字段为 `provider`、`store_product_id`；Google 额外传 `purchase_token`；Apple 额外传 `transaction_id`，游客 report/claim 还必须传 `signed_transaction`（StoreKit 签名交易 JWS）。2026-09-10 按用户最新要求，Android / iOS 登录 report、游客 report 及独立 claim 的请求均不发送 plan_code、request_id；两种 HTTP 请求模型已删除 requestId 字段及其校验。Google base_plan_id 也继续省略；商品目录及本地 checkout 保留套餐、base plan 与 offer 用于选择和匹配。prepare/check 原本就不传 plan_code 或 request_id。不传金额、uid、任意 payload 或客户端猜测的生产环境。
- 游客购买成功后，由本次支付回调确定待 claim 订单；同 UUID 的旧未绑定记录不能替换它。登录后直接复用本次 report 的完整购买参数（包括 Apple JWS）请求 claim；完整凭据保存在安全存储中，重启也不重新查询 Apple。对于旧版本尚未绑定账号、未提交 claim、缺少 JWS 且误指向较早 completed report 的记录，启动时按本地付款凭据的持久化顺序修正为该 UUID 最近一笔 completed report，再按其原交易读取签名；已绑定账号或已收到 claim 状态的凭据不替换。本地 request_id 仅用于关联回调、弹窗、内存去重及游客绑定证明，不进入 HTTP 请求、查询参数或请求头。2026-09-17 已核对最新 Apifox claim 文档：明确不接收 request_id，plan_code 可省略；当前 claim 请求与此一致。
- report 响应必须有合法业务 envelope 和 `data.status`，模型读取 status 及可选的 reason，不读取 report_id、membership_id。允许 completed、accepted、rejected；缺失或未知状态结束本次上报并提示 `Report failed.`，不重试。2026-09-17 按用户要求，rejected 的 Toast 使用可读文案：`account_mismatch` 与 Google 身份不一致错误共用 `Account identifiers don't match the previous subscription.`；其他原因（包括 `subscription_superseded`、缺失、空白或非字符串 reason）统一显示 `We couldn’t verify your subscription. Please contact support.`。不直接展示错误码，不表示 Apple 刚发生订阅变更。原始 reason 保留在本次记录中用于排查，不参与 UUID 比较或购买拦截。
- report 的 completed 才表示官方校验及同步完成，随后刷新 wallet 并显示成功；accepted 提示确认中，rejected 显示上述 reason 文案。任一业务状态都结束本次 report，重复回调不重报。不创建持久化报告队列，不在启动、前台或定时器中恢复 report。仅平台 purchased 回调携带有效凭据时发送一次 report；pending、restored、取消及失败回调均不上报。连接异常、超时、HTTP 408/429/5xx、Gateway 错误、业务错误、无效响应及未知状态均不重试；report 异常提示 `Report failed.`。
- Apple 自动续订购买直接调用 StoreKit `Product.purchase`，不扫描或拦截历史未完成订阅，不用本地到期时间、会员状态或旧订单替代平台结果；保留两端共有的有效年会员转月套餐弹窗及账号/商品/并发保护。Gems 等非订阅商品保留原未完成交易检查。
- 2026-09-17 按用户要求统一商店收尾职责：Android / iOS 客户端上报真实购买凭据，不调用 acknowledge、consume 或 finish。服务端验单并持久化权益后，Google 初次订阅调用 acknowledge，Apple 调用 [App Store Server API Finish Transaction](https://developer.apple.com/documentation/appstoreserverapi/finish-transaction)，失败由服务端持久化任务重试。Apple 的 finish 不能用成功接收 report 或验单代替。这里约定职责，不代表已验证线上服务端实现。所有 report 状态均停止客户端报告；旧缓存只清理，不发起网络补报。游客购买证明独立留给 claim，旧 finished 字段仅作格式兼容。
- Apple `Product.purchase` Future 已返回后，若 10 秒内仍未收到能关联本次购买的回调，结束前台等待并提示确认延迟，保留原身份与迟到回调处理。该计时不包含用户停留在 Apple 付款页的时间；正常回调收到后停止计时，report 沿用原 HTTP 超时。历史或其他账号回调不冒充本次成功，不自动重扣款或 finish。Android 调起后的等待行为不变。
- Apple 本次 `Product.purchase` 的直接结果通过原生桥接回传本地 `checkoutAttemptId`，用于关联对应点击，不进入 Apple 购买参数、HTTP 或持久化。本次成功回调携带有效凭据后直接执行 report；即使回调商品与点击套餐不同，也按 checkoutAttemptId 接收，report/claim 使用回调商品 ID 和对应交易凭据，清除不适用的所选商品价格，不额外查询商品或等待 10 秒。不查找或比较本地历史 transactionId，不复用历史 report 状态，不生成本地“已拥有”提示。同一次购买按 requestId 去重，不比较 transactionId；同一交易的成功埋点仍去重。后台续费、恢复及未完成交易查询不携带该标识，只能继续唯一的待处理回调，不能占用刚发起的购买；迟到的直接结果仍按原点击处理。游客 claim 保留原始购买证明，该证明不用于拦截新购买。
- VIP 本地持久化只用于游客购买身份/认领，不保存 report 重试队列。准备、取消、调起失败及无凭据回调不保存历史订单；登录购买任何 report 结果均不生成持久化记录，不另存成功订单归档。游客在调起支付前先单独持久化本次 UUID，保存失败不调起支付；仅身份缓存不表示已付款，不触发 check、登录或购买拦截。明确取消或平台拒绝调起时删除该次未成交 UUID；若同 UUID 仍有已付款凭据、待付款记录或已绑定归属，则保留。超时及未知网络错误不作为取消。付款后保存绑定所需凭据与购买时间；claim completed 且钱包刷新及本地清理成功后删除 UUID 和购买凭据，商店收尾由服务端负责，不留已绑定身份缓存。
- iOS 历史交易查询从 `Transaction.all` 保留每笔已验证交易的 JWS，包括已 finish 的原订单；重启后的游客 claim 优先复用安全保存的原签名；仅旧缓存缺签名时按原交易 ID、商品恢复已验证签名，不因 UUID 差异丢弃 JWS，最终归属由服务端按签名判断；不用最新续费交易替换原凭据。重装后无本地 report 的认领在 `claim=completed` 后清理本地认领凭据，Apple finish 也由服务端按已验证交易处理。客户端本地清理失败保留 completed claim 及原凭据，重启后只重试清理，不重复 claim；`accepted/rejected` 保留对应凭据与原有重试/归属处理。客户端不批量 finish 订阅链中的历史交易。
- `purchased/restored` 回调缺少凭据时不发送 report，也不生成旧订单恢复记录或阻止新购买；本次操作在内存中保留，迟到的真实回调仍可按原套餐上报。客户端不再通过旧缓存判定 purchase_processing，除 wallet 有效年转月限制外由平台处理购买资格，当前正在发起的支付仍防重复点击。
- GEMS 回调与商店恢复入口增加会员分流，已知 GEMS 操作和持久记录沿用原处理。VIP 不进入 Gem 上报、发货弹窗或 Gem 埋点路径；互相购买期间拦截重复调起。普通 GEMS 请求和 TAB 按需加载保持原逻辑。
- 会员接口继续排除 App 持久化网络捕获和原生 body 采集，使用支持按请求排除采集的 HTTP/2 传输。按产品要求，Debug 包的 Flutter DevTools 对 products、prepare、report、check、claim 显示原始 URI/header/body/响应及错误，不替换 UUID、token 或 JWS；非 Debug 的 products/report/check 保持脱敏，prepare/claim 不创建 profile。普通日志仍只记状态、错误类型及结构化错误码。
- Subscription 页只加载商品，不自动查询并保存商店已购记录。启动、回前台和定时任务只维护游客身份/claim，不发起 report；无法关联当前购买的商店历史回调不创建报告记录。
- 升级时清理旧 report/restore 缓存，无论失败、accepted 或终态，都不迁入新补报队列、不调用 report。已付款游客凭据仅保留为 claim 证明；清理存储失败只重试清理，不恢复报告。
- Android、Apple 均不再因启动或进入 Subscription 而生成旧订单队列。已取得服务端最终状态但本地清理尚未完成时只重试本地清理，不重复 report；这类短暂清理重试不阻止新购买。
- 补报复用实际购买时的 store_product_id 和凭据，HTTP 请求不发送 plan_code、request_id 或 base_plan_id；本地快照的套餐及记录编号不会重新注入上报参数。未知套餐的商店历史不猜测、不落入补报队列。已登录升级继续使用最新商品列表返回的原订阅 UUID/token 和目标 base plan，不依赖本地成功订单历史。
- 本地 mock 对 prepare/report 返回 `5000`，不伪造购买身份、商店验单或会员发放。

## 游客会员订单启动检查（2026-09-14）

- App 主界面首次显示后（包括默认进入 Worldo 标签、尚未构建 Home），优先使用已购买缓存中的最新 UUID 调用 `POST /api/v1/membership/guest/purchase/check`。没有已购买缓存才用会员专用只读查询发现当前 App 的 Google SUBS / Apple 有效订阅，排除 pending 及过期订单，选择购买时间最新的一笔，用其 `obfuscatedAccountId` / `appAccountToken` 调用 check；不逐个检查历史 UUID，包括无缓存重装场景。已登录跳过；并发入口调用共用一个任务，登录或切账号使迟到结果失效。
- 商店发现不要求先打开 VIP 页面或加载商品套餐；check=true 且已选定最新购买证明时，单独缓存 UUID、原商品 ID、Google token / Apple transaction ID 和新建后固定的认领 request_id，触发强制登录。此缓存不创建旧订单/补报记录，不调用 prepare/report。登录成功后，使用缓存购买证明直接进入 claim 及其失败/accepted 重试；Apple JWS 随该证明保存到安全存储，重启后直接复用；旧缓存缺签名时才按原交易读取。若不同交易证明的购买时间相同、无法确定最新一笔，则保留待处理，不任意选链认领。
- 2026-09-10 按用户最新要求，Android / iOS 登录 report、游客 report、claim 均不发送 plan_code 和 request_id，新购买、已有套餐缓存、无缓存重装及失败重试均适用。两端都使用原 UUID、商品 ID 和平台购买证明，认领流程不加载商品目录判断套餐。Apple 仍必须携带原 transaction_id 和对应 JWS。旧认领缓存的套餐字段读取时忽略，凭据和本地记录编号保留；本地编号不会进入 MembershipClaimRequest 或 MembershipPurchaseRequest。后端契约同步边界见上节。
- 请求仅传原 account_uuid，不重新 prepare。`has_unbound_order=true` 触发强制登录，false 不弹；check 不用于设置 VIP 权益。接口失败保留缓存，不把失败当成 false。商店/check 请求各有 15 秒超时；查询失败、已付款但缺身份/凭据或无法确定最新订单时，最多自动退避重试 3 次（默认 15/30/60 秒）。pending 不参与 check，等实际付款回调后重新检查；check=false 正常结束，不发起重试。成功结果在 30 秒内复用，回前台不清空结果或重置重试；会话变化和新的购买状态才使其失效，重复交易回调去重。首页重入及回前台不能绕过已排定的退避；正常无订阅结束本轮，不无限轮询。两种布尔结果本身均不删除 UUID。
- 本次游客购买的成功弹窗 → OK → 强制登录顺序保留。付款后缓存原 UUID、套餐、request_id、Google token 或 Apple transaction_id，供登录后按原凭据 claim。Apple JWS 随原交易凭据写入安全存储，重启后直接用于 claim，完成后一起清理。
- 绑定 completed 且钱包刷新及本地清理成功后，删除对应游客 UUID、归属和认领缓存、购买凭据及终态 report 残留，停止自动 claim；旧版已绑定 UUID 缓存也在恢复时清理。之后退出登录由平台重新发现身份并交由 check 判断。失败/accepted 的 claim 仍固定原 owner_uid 重试，不能转给另一个账号。新游客购买复用同一 UUID 时建立新的待绑定缓存，不沿用上一次绑定账号。
- report 不做退避、持久化或重启补报；技术失败也只发送一次，不重试，所有业务状态结束报告。Gems 购买和恢复流程不变。
- check 原始请求仍排除 App 持久化网络捕获及原生 body 采集；Debug DevTools profile 显示原始 account_uuid、header 和响应，非 Debug profile 仅展示 HTTP 状态、err_no 和 has_unbound_order，不展示 UUID 或认证凭据。

- Google/Apple 的缺身份候选保留到恢复层，记录候选数和跳过原因；缺 UUID 只允许按已保存的相同平台、商品与精确 token/交易 ID 找回身份，不能按商品猜测，也不能重新 prepare 替代原身份。本地和商店都无 UUID 时需要后端凭真实交易恢复身份，当前 check 不支持 token-only 查询。
- 若 check=true 时商店暂不可用，登录后仍可凭缓存原 UUID 查询唯一有效商店证明并继续 claim；首次登录账号在查询证明前固定，最多尝试找回证明 3 次，禁止换账号认领。

## 游客 Pro 购买与购买后强制登录（2026-09-08）

来源：[Apifox 游客购买身份](https://app.apifox.com/link/project/8297783/apis/api-512243338)、[登录后认领游客购买](https://app.apifox.com/link/project/8297783/apis/api-512243340)，同时核对最新 OpenAPI 的游客购买上报及响应模型。

- 首页皇冠直接进入 Subscription，未登录也能浏览商品和购买。点击购买时复用本次页面加载的商品列表并查询商店商品；列表顶层有 `last_account_uuid` 就直接作为游客购买身份，没有时才调用公开的 `POST /api/v1/membership/guest/prepare`，请求仅包含 `provider/device_id`。选定的 UUID 随本次购买记录关联，传给平台支付并用于后续上报及绑定。prepare 不创建真实用户、钱包或可用会员权益，也不把游客身份写进登录会话。
- 所有 VIP 入口（首页皇冠、会员卡、签到订阅操作、聊天订阅提示）直接打开购买页或购买弹层，不预先要求登录。完整购买页和订阅购买弹层先读取本地登录状态：游客仅显示 Subscription，不构建 Buy Gems 内容，也不加载 Gems 商品、余额和任务；已登录保留双 Tab 和原有 Gems 行为。登录、退出或切换账号后重新确定可见 Tab。
- 游客付款仍走 `POST /api/v1/membership/guest/purchase/report`。`completed` 表示购买验证与暂存完成，先显示现有带皇冠的 VIP 购买成功弹窗；点击 OK 后才弹出登录弹窗。该登录弹窗隐藏关闭按钮，遮罩点击、下滑、系统返回均不能退出；取消平台授权或登录失败后保留弹窗，只有登录成功才能继续。普通登录弹窗保持原来的可关闭行为。
- 当次购买继续按成功弹窗 → OK → 强制登录处理；重启进入首页按上节执行订单检查及选择，不重放购买成功弹窗，只有选中的有效未绑定订单触发登录。购买取消、失败或仍待付款不会触发购买成功后的登录流程。
- Debug Page 的 Premium 面板及手动设置会员功能已移除。Debug、Profile、Release 均按正常未绑定订单规则执行强制登录，不读取或应用旧的调试开关值。
- 游客购买后的强制登录成功时，根导航栈切换到 Me 并移除购买页面及其上层弹窗，返回键不能再次回到已完成的购买流程；完整购买页、购买弹层及重启恢复的登录拦截共用此处理。跳转不等待 claim 或 wallet 请求完成，绑定及原退避重试继续由全局会员服务处理；只有绑定完成后的原清理流程才删除游客缓存。取消/失败仍停留强制登录，普通登录和 Gems 购买不变。
- 登录成功后独立调用 `POST /api/v1/membership/claim`，有本地游客 report 时复用其 `account_uuid/provider/store_product_id` 和平台凭据（Google `purchase_token`；Apple `transaction_id/signed_transaction`）。重装无 report 时使用商店原证明；Android / iOS 无论套餐是否已知均不传 plan_code、request_id。归属由真实登录会话决定，不发送 uid、device_id、guest_id 或 claim_token；禁止仅凭 UUID 认领。首次认领前安全保存所选登录账号，超时、失败和重启后保持该账号，切换到其他账号时不重新认领。认领失败不撤销登录成功。
- 客户端 claim 成功响应模型按产品要求只保留 `status`，不解析响应中的 account_uuid、reason、membership。`completed` 后重新请求 `GET /api/v1/gem/wallet`，会员状态和 Blue Gems 只读取该接口，普通 Gems 仍使用 wallet 字段；不把 claim 状态直接当作会员有效。VIP 刷新会等待正在进行的旧 wallet 请求结束，再发起新请求，避免把绑定前的数据当作绑定后的结果；原 Gems 刷新行为不变。
- claim 网络失败、业务错误、缺失或非法 status，以及 `accepted` 未完成状态，在本轮首次请求后按 15、30、60、120、240 秒最多退避重试 5 次。前后台切换、订单恢复和重复 recover 不绕过间隔或追加次数。`completed` 和 `rejected` 停止绑定重试；`rejected` 保留原归属，不转给其他账号。重试耗尽保留游客缓存，当前会话不再自动请求；下次启动或新的登录会话重新开启有上限的一轮重试，仍只能由已锁定的账号认领。
- claim 的 accepted 只沿用独立绑定重试，不重置或重新发送购买 report；绑定处理中仍保留原身份与证明，不猜测订单。
- 游客认领缓存独立安全持久化，保存原 UUID、购买确认状态、关联请求与凭据、归属和认领结果。登录成功本身不清缓存；claim completed 且收尾结束后删除认领所需交易凭据及 UUID 缓存，不保留登录用户的成功订单历史。此缓存只用于绑定，不用来恢复 report。
- 先持久化绑定 completed 并刷新当前账号 wallet，再清理购买凭据，将 UUID 缓存压缩为已绑定身份。清理失败继续剩余步骤，不重复 claim，也不刷新其他账号权益。以后未登录启动仍对 UUID 调用 check，由结果决定登录弹窗；原始 claim body 继续排除捕获，mock 不伪造绑定。
- VIP 服务监听统一 sessionRevision：普通登录、退出及接口触发的会话失效都会更新登录拦截与重试状态。账号变化会立即检查游客强制登录状态，不等待正在进行的网络恢复；已有恢复任务结束后再按新会话补跑，避免漏认领。登录购买 report 在发送前及异步获取凭据后再次检查账号，防止切换期间把旧订单作为新账号请求发送。

## Me 会员卡片状态（2026-09-08）

来源：[Apifox 钱包及会员摘要](https://app.apifox.com/link/project/8297783/apis/api-484992736)，最新接口为 `GET /api/v1/gem/wallet`。`data.wallet` 与 `data.membership` 分别解析、分别展示。

- 按本次明确的产品要求，普通 Gems 继续原样使用 `wallet.balance_cent`；会员卡片仅使用 `membership.blue_gems_cent`。客户端不对两个余额相加、相减或互相覆盖，原 GEMS 购买、消费判断和余额组件保持原逻辑。
- `membership_status=1` 显示一张有效 Pro 卡片；`0`（未购买）及 `2`（失效）显示一张 Subscribe 卡片，替换两张固定预览。余额为零、关闭自动续费不改变有效状态；套餐类型和未来到期日不能覆盖服务端状态判断。
- 有效卡片的日期读取 `membership.expires_at`（Unix 秒，转换为本地日期）；蓝宝石余额读取 `blue_gems_cent`，沿用现有金额格式。用户名旁 Pro 标识仅在会员有效时显示。
- 会员数据跟随当前账号的钱包请求刷新，切换账号清空旧会员状态；无会员字段的旧响应仍兼容，会员字段解析异常不会阻断原钱包余额读取。当前卡片既有颜色、字号、间距保留。

## 用户名旁会员徽章（2026-09-15）

- 按产品要求，各接口的用户对象（user、owner_user、owner、author、sender、peer、player_user 等）透传 `gender`、`age`、`membership_status`，搜索用户项也包含这三个字段。
- 客户端从当前名称对应的用户模型直接读取整数 `membership_status`，仅 1 显示皇冠；0、2、缺失、非法值或 deleted=true 都不显示。gender、age 保留服务端值，本次不新增页面展示。
- 已移除按 UID 单独查询会员标识的服务及 30 秒缓存/轮询；搜索、分页、滚动、前后台切换不会因为徽章请求 `user/info`。资料页本身所需的 user/info 请求继续保留。
- 覆盖 Me / Profile、关注/粉丝、黑名单、搜索、私信列表、通知、Worldo Creator、评论作者/回复者和 Profile Playing Owner。World 和 Chat（含 Location Chat）不显示用户名会员徽章。
- 回复目标只有 `reply_to_uid` / `reply_to_username` 时没有足够状态，不补查、不借用作者状态；有目标用户对象或点击回复时已有该作者数据才显示对应徽章。
- 名字徽章仅用于展示。购买、钱包、会员卡及权限校验继续使用各自现有状态服务，不改授权或计费逻辑。
