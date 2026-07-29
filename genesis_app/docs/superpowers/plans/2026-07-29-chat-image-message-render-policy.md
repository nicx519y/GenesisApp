# Chatroom 图片消息渲染白名单技术实施方案

日期：2026-07-29  
工程：`GenesisApp_2/genesis_app`  
状态：待审查，仅输出方案，尚未实施业务代码

## 1. 目标

在不丢失服务端消息、不破坏本地缓存、消息 ID、分页和补洞逻辑的前提下，按 `message_type + sender_id` 双条件决定消息是否渲染。

本次只支持：

- 文本消息
- `sender_id=nar_pic` 的旁白图片消息

其他图片发送方和未来未知消息类型全部只存储、不渲染。

## 2. 最终行为矩阵

客户端先区分 `message_type` 字段是否存在，再对字段值执行：

```text
trim
-> lowercase
-> 显式 null/空字符串归一化为 text
```

最终规则：

| `message_type` 状态 | `sender_id` | 存储后的类型 | UI 渲染 |
| --- | --- | --- | --- |
| 字段不存在 | `nar_pic` | `image`，旧数据兼容 | 展示现有纯图片样式 |
| 字段不存在 | 非 `nar_pic` | `text` | 按现有文字消息规则渲染 |
| 字段存在，值为 `null`、空字符串 | 任意 | `text` | 按现有文字消息规则渲染 |
| `text` | 任意 | `text` | 按现有文字消息规则渲染 |
| `image` | `nar_pic` | `image` | 展示现有纯图片样式 |
| `image` | 非 `nar_pic` | `image` | 不渲染 |
| 其他未定义非空类型 | 任意 | 归一化后的原值 | 不渲染 |

大小写和首尾空格不影响判断：

```text
" IMAGE " + " NAR_PIC "
-> image + nar_pic
-> 展示图片
```

## 3. 图片 UI 规则

以下两种情况进入同一个图片组件：

```text
message_type=image && sender_id=nar_pic

或者

message_type 字段不存在 && sender_id=nar_pic
```

第二条是旧数据兼容规则。解析时会把这种旧消息的 `messageType` 归一化为 `image`，后续缓存和 UI 不需要重复判断“字段是否曾经存在”。

展示保持当前样式：

- 只展示 `content` 对应的图片。
- 不展示发送方头像。
- 不展示发送方 name。
- 不展示时间。
- 不展示图片 URL 文字。
- 保留加载/失败占位。
- 保留点击查看大图。
- 保留长按能力。
- 多张图片继续支持大图浏览和当前图片定位。

本次不再修改共享图片消息布局。

## 4. 文本 UI 规则

以下情况按文本处理：

```text
message_type 字段不存在 && sender_id != nar_pic
message_type 字段存在且值为 null
message_type 字段存在且值为 ""
message_type = "text"
```

文本展示继续使用现有发送方规则：

- 普通角色文字：头像、name、时间和文字气泡。
- 旁白文字：现有全宽旁白区域、段落图标，无头像/name/时间。
- Tick/System：保持现有系统消息样式。

如果：

```text
message_type=text && sender_id=nar_pic
```

也必须按文本处理，不能因为 `sender_id=nar_pic` 自动转成图片。

## 5. 隐藏消息规则

以下消息不生成任何 Chat UI：

```text
message_type=image && sender_id != nar_pic
message_type=任意未知非空值
```

隐藏消息必须满足：

- Service 状态中保留。
- 本地缓存中保留。
- `message_type`、`sender_id`、`content` 和消息 ID 原样保留。
- 页面不生成 `ChatMessageVm`。
- 不显示文字、图片、空白气泡或占位图。
- 不弹 Toast。
- 不计入底部 `new message` 数量。
- 不触发图片预加载或大图浏览。
- 不影响它之后的有效消息。

## 6. 为什么只在渲染层隐藏

Chatroom 的以下行为依赖完整消息序列：

- `global_message_id`
- `message_id`
- `location_message_id`
- 历史分页
- 消息缺口识别
- 补洞请求
- 缓存恢复

如果在网络解析或 Service 层直接删除隐藏消息，例如：

```text
location_message_id=101 text
location_message_id=102 image + 非 nar_pic
location_message_id=103 text
```

客户端可能把 `102` 误判为缺口并重复请求。

因此正确链路是：

```text
WebSocket/HTTP 收到消息
-> 正常解析
-> 正常写入 Service
-> 正常写入缓存
-> 使用完整列表计算消息窗口和缺口
-> UI 投影时判断 render policy
-> hidden 不生成 ChatMessageVm
```

## 7. 技术设计

### 7.1 集中定义渲染策略

修改：

```text
lib/network/chatroom/chatroom_message_type.dart
```

新增图片常量和渲染分类：

```dart
const String chatroomTextMessageType = 'text';
const String chatroomImageMessageType = 'image';
const String chatroomNarratorPictureSenderId = 'nar_pic';

enum ChatroomMessageRenderKind {
  text,
  image,
  hidden,
}
```

新增统一判断方法：

```dart
ChatroomMessageRenderKind resolveChatroomMessageRenderKind({
  required Object? messageType,
  required Object? senderId,
}) {
  final normalizedType = normalizeChatroomMessageType(messageType);
  final normalizedSenderId =
      senderId?.toString().trim().toLowerCase() ?? '';

  if (normalizedType == chatroomTextMessageType) {
    return ChatroomMessageRenderKind.text;
  }
  if (normalizedType == chatroomImageMessageType &&
      normalizedSenderId == chatroomNarratorPictureSenderId) {
    return ChatroomMessageRenderKind.image;
  }
  return ChatroomMessageRenderKind.hidden;
}
```

这样所有页面使用同一张白名单，避免在 UI 中散落字符串条件。

同时新增入站兼容方法，用于区分“字段不存在”和“字段存在但为空”：

```dart
String resolveIncomingChatroomMessageType({
  required bool hasMessageTypeField,
  required Object? rawMessageType,
  required Object? senderId,
}) {
  final normalizedSenderId =
      senderId?.toString().trim().toLowerCase() ?? '';
  if (!hasMessageTypeField &&
      normalizedSenderId == chatroomNarratorPictureSenderId) {
    return chatroomImageMessageType;
  }
  return normalizeChatroomMessageType(rawMessageType);
}
```

规则：

- 字段不存在且 `sender_id=nar_pic`：合成为 `image`。
- 字段不存在且其他 sender：归一化为 `text`。
- 字段存在但值为 `null`/空字符串：归一化为 `text`，不走 legacy image。
- 字段明确为 `text`：始终是 `text`。

### 7.2 网络和缓存解析增加旧数据兼容

以下已有逻辑继续保留：

```text
nar_new_message.payload.message_type
ChatroomMessageDTO.message_type
trim + lowercase
未知字符串保留
```

相关文件：

```text
lib/network/chatroom/chatroom_models.dart
lib/network/chatroom/chatroom_http_models.dart
lib/network/chatroom/world_chatroom_models.dart
lib/network/chatroom/world_chatroom_world_projection.dart
```

以下三个入口改用 `resolveIncomingChatroomMessageType`：

```text
ChatroomNarratorMessage.fromEnvelope
ChatroomHttpMessage.fromJson
WorldChatroomMessage.fromStorageJson
```

判断字段存在性：

```dart
source.containsKey('message_type')
```

这样实时消息、HTTP 历史消息和旧本地缓存行为一致。

网络模型继续使用：

```dart
final String messageType;
```

不把 unknown 转成 `text`，也不删除 unknown。

旧 `nar_pic` 且字段缺失的消息会在解析阶段合成为 `image`。后续写入缓存时保存归一化后的 `message_type=image`，避免每次渲染重复推断。

### 7.3 Location Chat 生成 UI 前过滤

修改：

```text
lib/pages/chat/location_chat_page.dart
lib/pages/chat/location_chat_message_reconciler.dart
```

`location_chat_page.dart` 增加对统一类型策略文件的 import。

在 `_reconcileMessages` 中：

1. 先使用完整 `source` 调用 `_visibleLocationChatMessages`。
2. 先执行已有 gap fill 判断。
3. 再对 `renderWindow.messages` 计算 render kind。
4. `hidden` 不进入 `visibleSource`。
5. `changed` 和 previous/next 数量比较使用过滤后的列表。

示意代码：

```dart
final renderWindow = _visibleLocationChatMessages(source, ...);
_requestVisibleMessageGapFillIfNeeded(renderWindow.gaps, source);

final visibleSource = renderWindow.messages
    .where(
      (message) =>
          resolveChatroomMessageRenderKind(
            messageType: message.messageType,
            senderId: message.senderId,
          ) !=
          ChatroomMessageRenderKind.hidden,
    )
    .toList(growable: false);
```

### 7.4 图片内容映射

在单条消息转换时再次读取 render kind：

```dart
final renderKind = resolveChatroomMessageRenderKind(
  messageType: message.messageType,
  senderId: message.senderId,
);
```

处理：

```text
renderKind=text
-> senderType 使用现有发送方类型
-> text = content
-> imageUrl = ""

renderKind=image
-> senderType = image
-> text = content
-> imageUrl = content.trim()
```

`senderType=image` 是现有 Chat UI 内部选择 `ChatImageMessage` 的标记。

### 7.5 删除 `nar_pic` 单条件图片判断

当前代码中：

```dart
if (_senderIdIsNarratorPicture(message.senderId)) return 'image';
```

需要删除。

修改后 `_messageSenderType` 只负责发送方身份，不负责内容类型：

```text
sender_type=narrator + sender_id=nar_pic + message_type=text
-> narrator 文字样式

sender_type=narrator + sender_id=nar_pic + message_type=image
-> render kind 将内容转换为 image

sender_type=narrator + sender_id=nar_pic + message_type 字段缺失
-> 入站解析合成为 image
-> render kind 将内容转换为 image
```

这样才能保证：

```text
sender_id=nar_pic + 显式 message_type=text
```

单独存在时不会错误显示图片。

### 7.6 隐藏消息不计入新消息数

修改：

```text
lib/pages/chat/location_chat_message_window.dart
```

在 `_newIncomingTailMessageCount` 中，对新消息执行同一个 render policy：

```dart
if (resolveChatroomMessageRenderKind(
      messageType: message.messageType,
      senderId: message.senderId,
    ) ==
    ChatroomMessageRenderKind.hidden) {
  continue;
}
```

避免用户看到：

```text
1 new message
```

但聊天区域没有任何新内容。

### 7.7 缓存和分页不修改

以下模块不删除隐藏消息：

```text
WorldChatroomService
ChatroomMessageStorage
WorldChatroomMessage.fromStorageJson
HTTP history repository
WebSocket event reducer
```

现有 `message_type` 缓存字段继续保留。

## 8. 对正式协议文档的修改

实施时同步更新：

```text
docs/chatroom-websocket-api.md
docs/apifox-http-api-contract.md
```

当前文档中的：

```text
未知非空类型保留，但按文本内容处理
```

改为：

```text
未知非空类型保留在消息模型和缓存中，但不渲染。
```

图片说明改为：

```text
显式 message_type=image 且 sender_id=nar_pic 时渲染图片；
旧消息缺少 message_type 且 sender_id=nar_pic 时兼容为图片；
message_type=image 但 sender_id 不是 nar_pic 时保留消息但不渲染。
```

HTTP 正式字段继续使用：

```text
global_message_id
message_id
location_message_id
created_at
```

图片功能不改变 HTTP envelope、ID 字段或时间字段。

## 9. 测试方案

### 9.1 类型策略单元测试

增加以下矩阵：

| 输入 | 期望 |
| --- | --- |
| type 字段缺失 + `nar_pic` | image，legacy fallback |
| type 字段缺失 + 普通 sender | text |
| type 字段存在且为 `null` + `nar_pic` | text |
| type 空 + `nar_pic` | text |
| `text` + `nar_pic` | text |
| `text` + 普通 sender | text |
| `image` + `nar_pic` | image |
| `" IMAGE "` + `" NAR_PIC "` | image |
| `image` + `nar` | hidden |
| `image` + character ID | hidden |
| `video` + `nar_pic` | hidden |
| `future_format` + 任意 sender | hidden |

### 9.2 WebSocket 测试

文件：

```text
test/network/chatroom/chatroom_client_test.dart
test/network/chatroom/world_chatroom_service_test.dart
test/pages/chat/location_chat_page_test.dart
```

验证：

1. `image + nar_pic` 进入 Service、缓存并显示图片。
2. 字段缺失 + `nar_pic` 合成为 image，进入 Service、缓存并显示图片。
3. `image + nar` 进入 Service、缓存但页面不显示。
4. `unknown + nar_pic` 进入 Service、缓存但页面不显示。
5. `text + nar_pic` 显示旁白文字。
6. 隐藏消息之后的 text 消息正常展示。

### 9.3 HTTP 历史和缓存恢复

验证：

1. HTTP `image + nar_pic` 显示图片。
2. HTTP 字段缺失 + `nar_pic` 显示图片，并按 image 写入缓存。
3. 旧缓存字段缺失 + `nar_pic` 恢复后显示图片。
4. HTTP `image + other` 只存储不显示。
5. unknown 经过 SQLite/内存缓存恢复后仍不显示。
6. hidden 位于两个连续 ID 中间时不触发补洞循环。
7. hidden 是最新消息时不生成空白 UI。
8. hidden 不影响 older pagination 的 before ID。

### 9.4 UI 测试

保留并强化现有纯图片样式断言：

- 存在 `ChatImageMessage`。
- 不存在对应 `ChatMessageBubble`。
- 不显示图片 URL 文本。
- 不显示发送方头像。
- 不显示发送方 name。
- 不显示发送方时间。
- 点击打开大图。
- 加载失败显示占位。
- 长按回调正常。

### 9.5 新消息数量测试

验证：

- hidden 到达时 new-message count 不增加。
- image + nar_pic 到达时按正常可见消息计数。
- hidden 后紧跟 text 时只增加 1。
- 滚动到底部后状态正常清理。

## 10. 验收标准

全部满足后才算完成：

1. 字段缺失且 `sender_id=nar_pic` 按旧图片消息处理。
2. 字段缺失且 sender 不是 `nar_pic` 时按 `text`。
3. 字段存在但值为 null/空时按 `text`。
4. `message_type=text` 始终按文本展示。
5. `message_type=image && sender_id=nar_pic` 展示图片。
6. 图片保持当前纯图片样式，无头像、name、时间。
7. `message_type=image && sender_id!=nar_pic` 不展示。
8. 未知非空类型不论 sender 都不展示。
9. 所有隐藏消息仍保留在 Service 和缓存中。
10. 隐藏消息不产生 Toast、空白项或 new-message 数量。
11. 隐藏消息不破坏消息 ID、补洞、分页和缓存恢复。
12. 图片 URL 不作为文字显示。
13. WebSocket、HTTP 历史和缓存恢复测试全部通过。
14. 工程内正式 Chatroom 文档与代码一致。

## 11. 预计修改文件

业务代码：

```text
lib/network/chatroom/chatroom_message_type.dart
lib/network/chatroom/chatroom_models.dart
lib/network/chatroom/chatroom_http_models.dart
lib/network/chatroom/world_chatroom_models.dart
lib/pages/chat/location_chat_page.dart
lib/pages/chat/location_chat_message_reconciler.dart
lib/pages/chat/location_chat_message_window.dart
```

协议文档：

```text
docs/chatroom-websocket-api.md
docs/apifox-http-api-contract.md
```

测试：

```text
test/network/chatroom/chatroom_client_test.dart
test/network/chatroom_http_api_test.dart
test/network/chatroom/world_chatroom_service_test.dart
test/pages/chat/location_chat_page_test.dart
test/components/chat_ui_test.dart
```

图片组件本身原则上不改：

```text
lib/components/chat/shared/chat_ui_media.dart
lib/components/chat/shared/chat_ui_message_row.dart
```

## 12. 实施顺序

1. 增加入站 legacy fallback、统一 render policy 和矩阵单元测试。
2. WebSocket、HTTP 和缓存恢复统一保留字段存在性语义。
3. Location Chat 在 render window 之后过滤 hidden。
4. 使用 render kind 映射 text/image。
5. 删除 UI 层 `sender_id=nar_pic` 单条件图片判断。
6. hidden 排除 new-message 计数。
7. 增加 WebSocket、HTTP、缓存和分页回归测试。
8. 更新正式协议文档。
9. 执行格式化、相关测试和 analyze。

## 13. 风险

### 13.1 旧 `nar_pic` 消息

当前代码只要 `sender_id=nar_pic` 就显示图片。

实施后：

```text
sender_id=nar_pic + message_type 缺失
-> 入站兼容为 message_type=image
-> 继续按图片展示

sender_id=nar_pic + 显式 message_type=text
-> 按文字展示
```

因此旧图片消息兼容性保持不变，同时新协议可以用显式 `text` 覆盖旧 sender 含义。

### 13.2 过滤位置错误

如果在 Service 或窗口计算之前删除 hidden，可能产生消息缺口和重复请求。

必须坚持：

```text
先存储
-> 先计算完整消息窗口
-> 最后只过滤 UI
```

### 13.3 新消息提示

如果只过滤消息列表、不修改 `_newIncomingTailMessageCount`，会出现有新消息提示但没有可见内容的问题，因此两处必须同时修改。
