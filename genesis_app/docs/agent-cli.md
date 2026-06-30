# Genesis Agent CLI 使用说明

Genesis Agent CLI 是一个本地控制接口，用来让 agent 或开发者直接操作正在运行的 Genesis App。

CLI 会连接 App 内部启动的本地 HTTP RPC 服务。这个服务只监听 `127.0.0.1`，默认关闭，只有通过 `./scripts/run` 或显式 dart-define 启动时才会开启。

## 快速开始

进入 Flutter App 目录：

```bash
cd /Users/ionix/Works/GenesisApp/genesis_app
```

启动 App：

```bash
./scripts/run
```

`./scripts/run` 可以理解为增强版 `flutter run`，它会自动处理：

- 创建或复用 `.agent-control.env`
- 开启 `GENESIS_AGENT_CONTROL_ENABLED=true`
- 把 CLI token 和 port 传给 App
- 如果本机有 `adb`，自动执行 `adb forward tcp:<port> tcp:<port>`
- 把其他参数原样透传给 `flutter run`

常用启动方式：

```bash
./scripts/run
./scripts/run -d <device-id>
./scripts/run --release
```

App 启动后，另开一个终端调用 CLI：

```bash
./scripts/ctl app ping
./scripts/ctl app state
./scripts/ctl world locations --wid <WID>
```

## Token 是什么

CLI 需要 `GENESIS_AGENT_CONTROL_TOKEN`。

这个 token 是本地控制口令，用来防止其他进程随便调用 App 控制接口。因为这个接口可以跳页面、清登录态、切 endpoint、清缓存，所以不能裸奔。

脚本会把 token 存在：

```text
.agent-control.env
```

这个文件已经加入 `.gitignore`，不会提交到仓库。

手动初始化 token：

```bash
./scripts/ctl init
```

正常情况下不需要手动执行，`./scripts/run` 会自动创建。

## App 命令

检查 App 是否连通：

```bash
./scripts/ctl app ping
```

查看当前 App 状态：

```bash
./scripts/ctl app state
```

返回上一页：

```bash
./scripts/ctl app back
```

跳转到某个 route：

```bash
./scripts/ctl app navigate /search
```

传 route 参数：

```bash
./scripts/ctl app navigate /search --arg q=alice
```

替换当前页面：

```bash
./scripts/ctl app navigate /search --arg q=alice --replace
```

清空页面栈后打开页面：

```bash
./scripts/ctl app navigate /home --clear-stack
```

## World 和 Location Chat

通过 `wid` 查询 location 列表：

```bash
./scripts/ctl world locations --wid <WID>
```

示例：

```bash
./scripts/ctl world locations --wid world_123
```

返回结果里重点看这些字段：

- `locations`: 当前 world 里所有可识别的 location chat 目标
- `locationId`: 进入 `/location_chat` 时要传的 location id
- `locationName`: location 显示名
- `isLeafLocation`: 是否叶子节点
- `firstLeafLocationId`: 第一个叶子 location id，适合只需要随便进入一个可聊天地点时使用

推荐流程是先用 `wid` 查 location id：

```bash
./scripts/ctl world locations --wid world_123
```

然后拿返回的 `locationId` 进入 location chat：

```bash
./scripts/ctl app navigate /location_chat \
  --arg wid=world_123 \
  --arg location_id=location_456
```

进入指定 WorldPage：

```bash
./scripts/ctl app navigate /world --arg wid=<WID> --clear-stack
```

示例：

```bash
./scripts/ctl app navigate /world --arg wid=world_123 --clear-stack
```

进入指定 LocationChatPage：

```bash
./scripts/ctl app navigate /location_chat \
  --arg wid=<WID> \
  --arg location_id=<LOCATION_ID>
```

示例：

```bash
./scripts/ctl app navigate /location_chat \
  --arg wid=world_123 \
  --arg location_id=location_456
```

可选参数：

```bash
./scripts/ctl app navigate /location_chat \
  --arg wid=world_123 \
  --arg location_id=location_456 \
  --arg worldName="My World" \
  --arg locationName="Town Square" \
  --arg isLeafLocation=true
```

注意：

- `/world` 需要 `wid`
- `/location_chat` 需要 `wid` 和 `location_id`
- 不知道 `location_id` 时，先执行 `./scripts/ctl world locations --wid <WID>`

## Agent World Chat

`agent world-chat` 用来让 agent 自动进入一个已 launch 的 world 的 location chat，并连续发送消息、等待 AI 回复、根据上一轮回复继续下一轮。

最常用命令：

```bash
./scripts/ctl agent world-chat --count 100
```

指定 world：

```bash
./scripts/ctl agent world-chat --wid <WID> --count 100
```

指定 world 和 location：

```bash
./scripts/ctl agent world-chat \
  --wid <WID> \
  --location-id <LOCATION_ID> \
  --count 100
```

指定第一条消息和回复等待超时：

```bash
./scripts/ctl agent world-chat \
  --count 100 \
  --reply-timeout-seconds 120 \
  --seed-message "I just arrived. What is happening here?"
```

### 实现方案

CLI 不直接持有 App 页面状态，也不直接连接业务 websocket。它通过 App 内置的 agent control RPC 让 App 自己执行页面跳转、API 调用和 chatroom 连接。

App 侧暴露了这些 RPC：

- `agent.world_chat.start`: 创建后台自动聊天任务，立即返回 `jobId`
- `agent.world_chat.status`: 查询任务状态和增量日志
- `agent.world_chat.cancel`: 标记任务取消
- `agent.world_chat`: 兼容旧同步调用；不推荐用于长任务，因为中间没有进度输出

`./scripts/ctl agent world-chat` 默认使用后台任务模式：

1. 调用 `agent.world_chat.start`
2. 每 2 秒调用 `agent.world_chat.status`
3. 把 App 返回的日志打印成 `目标: ...`
4. 任务完成时打印最终结果
5. 任务失败时打印错误 JSON

示例输出：

```text
目标: 启动后台自动聊天任务
任务: job-1782728203529757
[1] 目标: 准备自动聊天参数 {"messageCount":100,"replyTimeoutSeconds":120}
[5] 目标: 查询我的 world 列表 {"scene":"mine","limit":20}
[7] 目标: 先进入 WorldPage {"wid":"w_LJDH53"}
[11] 目标: 进入 LocationChatPage {"wid":"w_LJDH53","locationId":"loc_1_1_3","locationName":"Kessler's House"}
[16] 目标: 发送消息并等待 ack {"turn":1,"total":100}
[17] 目标: 等待同一轮 AI 回复 {"turn":1,"conversationRoundId":"903"}
```

### 执行顺序

当前实现严格按这个顺序执行：

1. 跳到 `/home`
2. 检查 auth token；如果为空，返回 `auth_required`
3. 如果传了 `--wid`，使用指定 world；否则读取已有 my world 列表并选择第一个可用 world
4. 先跳到 `/world`，也就是进入 `WorldPage`
5. 拉取 world 详情
6. 不执行 launch，不从热门 origin 创建 world
7. 检查 world 是否是 `owner` 或 `joined`
8. 从当前 world 的 location 树中选择叶子 location；如果传了 `--location-id`，使用指定 location
9. 跳到 `/location_chat`
10. 创建 `WorldChatroomService`，连接 world chatroom
11. join 指定 location
12. 刷新最近消息作为上下文
13. 发送消息并等待 ack
14. 根据 `conversationRoundId` 等待同一轮 AI 回复
15. 用上一轮回复生成下一条消息，直到达到 `--count`

### 约束

这个命令不会 launch world。

如果当前用户没有已有 my world，命令会失败：

```json
{
  "code": "world_not_found"
}
```

如果选中的 world 不是 `owner` 或 `joined`，命令会失败：

```json
{
  "code": "world_not_chat_ready"
}
```

如果 auth token 为空，命令会失败并提示先登录：

```json
{
  "code": "auth_required",
  "message": "Auth token is empty. Please log in in the app, then retry."
}
```

### 断线和限流

chatroom websocket 可能在多轮消息后断开。当前实现会在每轮发送前检查连接状态：

- 如果 chatroom 断开，会重新连接 world chatroom
- 如果还没 join 当前 location，会重新 join
- 如果发送消息时失败，会 disconnect 后重连并重试一次

如果后端返回 rate limit，CLI 会打印类似：

```text
目标: 发送失败，重连 chatroom 后重试一次 {"error":"ChatroomFailureEvent(send_message/ack 2010): Rate limit exceeded"}
```

如果重试仍失败，任务会失败并打印错误。

### 暂停和恢复

在终端按 `Ctrl+C` 可以停止 CLI 轮询。当前 CLI 进程停止后，不会继续打印进度。

注意：`Ctrl+C` 停止的是 CLI 进程，不一定能立刻取消 App 内已经启动的后台任务。要显式取消，需要调用内部 RPC `agent.world_chat.cancel` 并传入 `jobId`。目前 `./scripts/ctl` 没有暴露单独的取消子命令，后续可以补成：

```bash
./scripts/ctl agent world-chat-cancel --job-id <JOB_ID>
```

如果任务已经发送了部分消息，这些消息已经写入后端，不会回滚。

## 登录命令

查看登录状态：

```bash
./scripts/ctl auth state
```

清除登录状态：

```bash
./scripts/ctl auth clear
```

当前限制：还没有实现自动登录。需要 App 已经有有效登录态，才能正常进入需要登录的页面。

## Endpoint 命令

切换到测试环境：

```bash
./scripts/ctl config endpoint set \
  --api dev.hushie.ai \
  --gateway dev.hushie.ai \
  --chat-ws dev.hushie.ai
```

清除 endpoint override：

```bash
./scripts/ctl config endpoint clear
```

## 缓存命令

清图片缓存：

```bash
./scripts/ctl cache clear --target image
```

清私信缓存：

```bash
./scripts/ctl cache clear --target directMessage
```

清所有支持的缓存：

```bash
./scripts/ctl cache clear --target all
```

## 诊断命令

生成诊断快照：

```bash
./scripts/ctl diagnostics snapshot
```

## 支持的 Route

CLI 只允许跳转固定白名单里的 route：

```text
/
/home
/origin
/origin_world
/discuss
/world
/chat
/location_chat
/search
/create
/edit
/messages
/me
/message/notifications
/messages/new_followers
/messages/comments
/user_info
/follows
/legal
```

部分 route 需要参数：

- `/world`: `wid`
- `/location_chat`: `wid`, `location_id`
- `/chat`: `peer_uid` 或 `uid`
- `/user_info`: `uid`
- `/origin_world`: `oid` 或 `originId`

## 底层脚本

推荐使用短命令：

```bash
./scripts/run
./scripts/ctl app ping
```

底层实现脚本是：

```bash
./scripts/agent-run
./scripts/genesisctl app ping
```

正常使用不需要直接调用底层脚本。

Dart CLI 入口是：

```bash
dart run tool/genesisctl.dart app ping
```

正常开发只需要用 `./scripts/run` 和 `./scripts/ctl`。
