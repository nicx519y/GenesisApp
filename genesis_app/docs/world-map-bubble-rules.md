# World 地图气泡规则

## 目标

地图气泡用于在 World 地图上展示最近的 AI 角色对话。气泡跟随 AI 角色本身，而不是跟随消息记录里的 location。

## 消息来源

- 气泡只使用 `WorldChatroomState.messagesByLocation` 中已有的消息。
- 气泡不单独拉取消息。
- 气泡不单独订阅 websocket 事件。
- AI streaming 中的消息不进入气泡索引。

## 可展示消息

一条消息必须同时满足以下条件，才可以进入气泡候选集合：

- 消息属于当前 tick：`message.tickNo == currentWorldTickNo`。
- 消息发送者是 AI 控制的 character。
- 消息不是旁白、NPC/system、tick、用户/player 角色发出的。
- 消息发送者能匹配到当前 tick character-position 输出中的 AI character。

## 候选范围

- 先读取当前 tick 的 AI character-position 输出。
- 只需要检查当前 tick 中有 AI character 所在的 location。
- 对这些 location，读取其在 `messagesByLocation` 中的消息。
- 对每个相关 location，只取当前 tick 中最新的一个 conversation。
- 这个最新 conversation 中，所有符合条件的 AI character 消息都会进入气泡候选集合。

## 角色锚点

- 气泡的核心归属是 AI character：`message.senderId`。
- 气泡展示位置根据当前 tick 的 AI character position 决定。
- 如果消息记录中的 `locationId` 和角色当前位置不一致，气泡跟随角色当前位置。

## 可见性

- 各个地图层级都可以展示气泡。
- 只有当 AI character 在当前地图层级可见时，它的气泡才可以播放。
- 如果 AI character 在当前地图层级不可见，则不展示该角色的气泡。

## 播放规则

- 同一时刻，当前地图最多展示一个气泡。
- 当前地图可播放的气泡候选，按照消息创建时间升序排序。
- 气泡按照排序结果循环播放。
- 播放到最后一个候选后，继续从第一个候选开始。
- 如果只有一个可播放候选，则循环展示这一条气泡。
- 如果没有可播放候选，则不展示气泡。
