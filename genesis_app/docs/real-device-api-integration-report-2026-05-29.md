# 真机接口联调报告 - 2026-05-29

## 结论摘要

- 真机设备：Pixel 6，包名 `com.genesis.ai`，当前登录用户 `U_730NIE`，接口环境 `https://dev.hushie.ai`。
- 抓包方式：Flutter VM Service / DevTools Network，`ext.dart.io.getHttpProfile` 可读取真机 Dart `HttpClient` 请求。
- UI 自动点击未完整执行：测试中设备进入安全锁屏，ADB 无法越过指纹/PIN；后续真机 UI 路径需要先保持屏幕解锁。
- 服务端核心阻塞：`origin` 和 `world` 相关接口大面积返回 `err_no=3103`，错误为 MySQL 表不存在：`aitown_dev.tbl_origins`、`aitown_dev.tbl_worlds`。这是服务端库表/迁移问题，不是客户端字段问题。
- 客户端明确契约问题：当前 App 代码仍调用复数路径 `GET /api/v1/message/notifications`、`POST /api/v1/message/notifications/read`、`GET /api/v1/messages/followers`，但 Apifox 当前文档和服务端可用接口是单数路径 `GET /api/v1/message/notifications`、`POST /api/v1/message/read`，并且查询字段从 `category` 变为 `block`。复数路径实测 404。
- 真机运行时抓包发现：App 后台轮询 `GET /api/v1/direct_message/conversations?after_message_id=0` 时，Dart `HttpClient` 报 `SocketException: Failed host lookup: 'dev.hushie.ai'`；但同设备 Wi-Fi 在 ADB shell 可 ping 通该域名，Mac 端用同一 session 直连该接口返回成功。因此这更像 App 进程/锁屏后台状态下的解析或网络状态问题，而不是接口本身不可用。

## 验证方法

- Apifox 文档源：`https://s.apifox.cn/5e96cda4-384c-445a-8cd8-e102f28814ba/llms.txt` 及各接口 `.md` OpenAPI 页面。
- 真机 session：从真机 App 私有 SharedPreferences 读取现有登录态，仅用于本次请求头对照；报告不记录 token。
- 抓包窗口：
  - `clearHttpProfile` 清空。
  - 等待 App 自动轮询。
  - `getHttpProfile` 读取请求、错误、响应状态。
- 服务端对照：使用同一真机 session token，以 `Authorization: Bearer <token>`、`x-platform: android` 请求 `https://dev.hushie.ai`。
- 副作用控制：
  - 没有调用 logout，避免破坏当前登录态。
  - 写接口优先用无效 id 或空 payload 验证路由/字段校验，不做业务数据破坏。
  - `upload/image` 使用 1x1 PNG 做真实 multipart 上传，已成功生成 OSS URL。

## 真机抓包证据

| 场景 | App 实际请求 | 抓包结果 | 判断 |
| --- | --- | --- | --- |
| 消息页 DM 轮询 | `GET /api/v1/direct_message/conversations?after_message_id=0` | 84 次同类请求，均无 HTTP status，错误为 `SocketException: Failed host lookup: 'dev.hushie.ai'` | 真机 App 运行态 DNS/网络解析失败；服务端对照同接口成功，所以不是接口字段问题 |
| 首页/Origin 列表 | `GET /api/v1/origin/list?pn=1&rn=20` | DevTools 截图显示 HTTP 200，但响应 `err_no=3103`，`tbl_origins` 不存在 | 服务端 DB 迁移/库表问题 |

补充：ADB shell 网络状态显示 Wi-Fi `AIsphere-guest` 已连接、网络 validated，DNS 为 `202.106.0.20`、`119.29.29.29`；`adb shell ping dev.hushie.ai` 成功。

## 服务端对照结果

### 可用接口

| 接口 | 结果 |
| --- | --- |
| `GET /api/v1/heartbeat` | HTTP 200，`err_no=0` |
| `GET /api/v1/user/info` | HTTP 200，`err_no=0`，返回当前用户信息 |
| `GET /api/v1/message/unread` | HTTP 200，`err_no=0` |
| `GET /api/v1/message/notifications?block=world_apply` | HTTP 200，`err_no=0` |
| `GET /api/v1/message/notifications?block=follow` | HTTP 200，`err_no=0` |
| `GET /api/v1/message/notifications?block=interaction` | HTTP 200，`err_no=0` |
| `GET /api/v1/direct_message/conversations?after_message_id=0` | HTTP 200，`err_no=0`，空列表 |
| `GET /api/v1/direct_message/conversations?pn=1&rn=20` | HTTP 200，`err_no=0`，空列表 |
| `GET /api/v1/direct_message/unread` | HTTP 200，`err_no=0` |
| `GET /api/v1/direct_message/blocks?pn=1&rn=20` | HTTP 200，`err_no=0` |
| `GET /api/v1/user/following?uid=U_730NIE` | HTTP 200，`err_no=0` |
| `GET /api/v1/user/followers?uid=U_730NIE` | HTTP 200，`err_no=0` |
| `GET /api/v1/world/apply/list?pn=1&rn=20` | HTTP 200，`err_no=0` |
| `POST /api/v1/upload/image` | HTTP 200，`err_no=0`，返回 `url` 和 `object_key` |

### 服务端 DB 阻塞

| 接口 | 结果 | 判断 |
| --- | --- | --- |
| `GET /api/v1/origin/list?pn=1&rn=20` | HTTP 200，`err_no=3103`，`Table 'aitown_dev.tbl_origins' doesn't exist` | 服务端库表缺失 |
| `GET /api/v1/world/list?pn=1&rn=20` | HTTP 200，`err_no=3103`，`Table 'aitown_dev.tbl_worlds' doesn't exist` | 服务端库表缺失 |
| `POST /api/v1/world/apply` | HTTP 200，`err_no=3103`，`tbl_worlds` 不存在 | 服务端库表缺失 |
| `POST /api/v1/world/tick` | HTTP 200，`err_no=3103`，`tbl_worlds` 不存在 | 服务端库表缺失 |
| `POST /api/v1/discuss/post` | HTTP 200，`err_no=3103`，`tbl_origins` 不存在 | 服务端库表缺失 |

受影响的后续接口：`origin/detail`、`world/detail`、`discuss/list`、`/api/messages` 没有可用 `origin_id/world_id/location_id`，无法通过真实数据继续验证。

### 客户端路径/字段不一致

| App 当前调用 | 服务端结果 | Apifox 当前接口 | 判断 |
| --- | --- | --- | --- |
| `GET /api/v1/message/notifications?category=system` | HTTP 404 | `GET /api/v1/message/notifications?block=world_apply|follow|interaction` | 客户端路径和字段都旧 |
| `POST /api/v1/message/notifications/read` | 未直接破坏性验证；代码仍使用该路径 | `POST /api/v1/message/read` | 客户端路径旧 |
| `GET /api/v1/messages/followers` | HTTP 404 | 当前 Apifox 无此接口；关注列表使用 `GET /api/v1/user/followers` | 客户端保留了旧消息页 follower 接口 |

相关代码位置：

- `genesis_app/lib/network/v1/messages_api.dart`
  - `notifications()` 走 `message/notifications`
  - `markNotificationsRead()` 走 `message/notifications/read`
  - `followers()` 走 `messages/followers`
- `genesis_app/lib/pages/messages/message_category_list_page.dart`
  - 页面入口按 `category=system/follower/comment` 拉取通知；需要映射为 Apifox 的 `block=world_apply/follow/interaction`。

### 路由可达但只做了安全校验

| 接口 | 测试方式 | 结果 | 说明 |
| --- | --- | --- | --- |
| `POST /api/v1/user/oauth/google` | 无效 `id_token` | `err_no=4005`，invalid id_token | 路由可达；完整验证需真实 Google 登录 |
| `POST /api/v1/user/oauth/apple` | 无效 `id_token` | `err_no=4005`，invalid id_token | 路由可达；完整验证需真实 Apple 登录 |
| `POST /api/v1/user/update` | 空 body | curl 8s 超时 | 需要后端排查空 patch 是否阻塞；未做真实资料修改 |
| `POST /api/v1/user/follow` | `target_uid` 为自己 | `err_no=10104`，不能关注自己 | 路由和字段可达 |
| `POST /api/v1/user/unfollow` | `target_uid` 为自己 | `err_no=10104`，不能关注自己 | 路由和字段可达 |
| `POST /api/v1/origin/create` | 空 body | `err_no=4004` | 路由可达；未创建数据 |
| `POST /api/v1/origin/update` | 无效 `origin_id` | `err_no=4004` | 路由可达；未更新数据 |
| `POST /api/v1/origin/launch` | 无效 `origin_id` | `err_no=4004` | 路由可达；真实创建 world 受 origin 表缺失影响 |
| `POST /api/v1/world/apply/review` | 无效 `apply_id` | `err_no=20202`，申请不存在 | 路由可达 |
| `POST /api/v1/world/join` | 无效 `world_id` | `err_no=4004` | 路由可达 |
| `POST /api/v1/discuss/delete` | 无效 `discuss_id` | `err_no=20403` | 路由可达 |
| `POST /api/v1/discuss/like` | 无效 `discuss_id` | `err_no=20403` | 路由可达 |
| `POST /api/v1/discuss/unlike` | 无效 `discuss_id` | `err_no=0` | 幂等成功 |
| `POST /api/v1/direct_message/send` | 无效 `peer_uid` | `err_no=10002`，用户不存在 | 路由可达 |
| `POST /api/v1/direct_message/read` | 无效 `peer_uid` | `err_no=0` | 幂等成功 |
| `POST /api/v1/direct_message/block` | 无效 `target_uid` | `err_no=10002` | 路由可达 |
| `POST /api/v1/direct_message/unblock` | 无效 `target_uid` | `err_no=0` | 幂等成功 |
| `POST /api/v1/message/read` | 无效 notification id | `err_no=0` | 幂等成功 |

### Chatroom / internal 接口

| 接口 | 结果 | 判断 |
| --- | --- | --- |
| `GET /api/messages` | 未测真实数据；缺少可用 `world_id/location_id` | 依赖 world/detail 或可用 world 数据 |
| `POST /internal/tick/lock` | `https://dev.hushie.ai` 返回 nginx 404 | 该类接口不是当前 dev HTTP 网关公开路由 |
| `GET /internal/tick/progress` | `https://dev.hushie.ai` 返回 nginx 404 | 需要对应 chat/tick 内网服务地址 |
| `POST /internal/tick/unlock` | `https://dev.hushie.ai` 返回 nginx 404 | 需要对应 chat/tick 内网服务地址 |
| `GET /internal/tick/is_locked` | `https://dev.hushie.ai` 返回 nginx 404 | 需要对应 chat/tick 内网服务地址 |
| `POST /internal/narrator/write` | `https://dev.hushie.ai` 返回 nginx 404 | 需要对应 narrator 内网服务地址 |
| `ws://localhost:8082/aitown-chat/ws` | 未在真机 UI 中完整验证 | 文档地址为 localhost，不是 Android 真机可直接访问的服务端地址；App 代码默认配置是 `ws://47.77.195.140:5002/aitown-chat/ws` |

## 建议修复顺序

1. 后端先补齐或迁移 `aitown_dev.tbl_origins`、`aitown_dev.tbl_worlds`。这会解除 `origin/list`、`world/list`、`world/tick`、`world/apply`、`discuss/post` 的主阻塞。
2. 客户端把消息通知接口从旧复数契约改到 Apifox 当前契约：
   - `message/notifications` -> `message/notifications`
   - `message/notifications/read` -> `message/read`
   - `category=system/follower/comment` -> `block=world_apply/follow/interaction`
   - 移除或重映射 `messages/followers`
3. 排查 `POST /api/v1/user/update` 空 patch 超时；至少应快速返回成功或明确 `4004`。
4. 真机解锁并保持屏幕常亮后，重新跑 UI 触发链路：
   - Home/Origin：列表 -> 详情。
   - Messages：未读 -> 通知块 -> 标记已读 -> DM 会话。
   - Me：关注/粉丝 -> 关注/取消关注。
   - Create/Edit：上传图片 -> 创建 origin -> 编辑 origin。
5. 如果要验证 chatroom/internal 接口，需要提供 Android 真机可访问的 chat/tick/narrator 服务地址；当前 Apifox 的 `localhost:8082` 和 `/internal/*` 不能直接用 `https://dev.hushie.ai` 验证。

## 原始证据位置

- DevTools HTTP profile 临时文件：`/tmp/genesis_http_profile_recent.json`
- 服务端读接口探测结果：`/tmp/genesis_api_probe_output.json`
- 服务端写/校验接口探测结果：`/tmp/genesis_api_probe_posts.json`
- 上传探测响应：`/tmp/genesis_upload_probe.txt`
