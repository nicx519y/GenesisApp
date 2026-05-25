# Apifox HTTP 接口文档与当前实现差异

来源：
- Apifox 分享页：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/460308499e0
- Apifox LLM 索引：https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/llms.txt

提取时间：2026-05-22

本文档只记录 Apifox 分享文档当前公开的 HTTP 接口，并对比当前 Flutter 项目中的 `lib/network` HTTP 设计。字段后带 `*` 表示 Apifox 标记为必填。

## 总览

Apifox 当前公开 12 个接口，分为 `用户` 和 `origin` 两组：

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
| origin | GET | `/api/v1/world/list` | World 列表 |
| origin | GET | `/api/v1/world/detail` | World 详情 |
| origin | GET | `/api/v1/origin/list` | Origin 模板列表 |
| origin | GET | `/api/v1/origin/detail` | Origin 模板详情 |

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
- `map`: string
- `initial_dialogue`: `DialogueLine[]`

### Tick

- `narrator*`: string
- `paragraphs*`: `TickParagraph[]`

`TickParagraph`：

- `location_id*`: string
- `timestamp`: string
- `text*`: string
- `character_deltas`: `{ char_id, name, delta }[]`

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

## 当前代码对齐状态

截至 2026-05-22，客户端已按本文档公开的 12 个接口完成主要 HTTP 契约对齐：

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
| `GET /api/v1/origin/list` | `OriginV1Api.list` query 已使用 `tag_id/keyword/uid/tag_name/pn/rn`；origin 页面和主 `getOrigins/getMyLaunchedOrigins` 可消费 `list[].info + stats`。 |
| `GET /api/v1/origin/detail` | `OriginV1Api.detail` query 已使用 `origin_id`；详情 mapper 支持 `info/stats/characters/locations/ticks`。 |

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
- `POST /api/v1/world/progress`
- `POST /api/v1/world/synclastorigin`
- `POST /api/v1/world/close`
- `POST /api/v1/world/del`

消息、DM、讨论、搜索、首页、通用：

- `GET /api/v1/messages/unread-summary`
- `GET /api/v1/messages/notifications`
- `POST /api/v1/messages/notifications/read`
- `GET /api/v1/messages/followers`
- `GET /api/v1/dm/chatlist`
- `GET /api/v1/dm/messagelist`
- `POST /api/v1/dm/send`
- `POST /api/v1/dm/delchat`
- `POST /api/v1/dm/delmessage`
- `POST /api/v1/dm/read`
- `POST /api/v1/dm/inviteworldcard`
- `POST /api/v1/dm/respondworldcard`
- `GET /api/v1/discuss/list`
- `POST /api/v1/discuss/post`
- `GET /api/v1/discuss/detail`
- `POST /api/v1/discuss/reply`
- `POST /api/v1/discuss/like`
- `POST /api/v1/discuss/del`
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

这些接口不属于 Apifox 公开的 12 个 `/api/v1` 接口。当前代码只在对应功能尚无 Apifox 契约时继续保留，已不再用于本文档覆盖的登录、用户信息、origin/world 列表详情接口：

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
