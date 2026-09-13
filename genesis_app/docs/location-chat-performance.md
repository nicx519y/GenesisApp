# LocationChat 性能改造与自动化验收

验证日期：2026-09-13。基于 `feature/message-vip` 的工作区；对比提交为
`cb8987a06d146a269b3c5c4c3e55163dd81f291f`。保留已有 ReplyController、storage
和订阅 UI 的未提交修改。本次不包含协议、数据库、提交或发布变更。

## 实现边界

- **地点通知**：`WorldChatroomService` 比较各地点消息对象序列、活动轮集合、历史代次，
  跳过重新包装但未变化的列表。ReplyController 的 `changesForLocation()` 与
  `batchChanges()` 在同步事务内合并通知，页面只订阅当前地点。连接和操作锁独立更新，
  控制器没有新增定时延迟；历史替换仍同步使灵感上下文失效。
- **内容版本**：地点和轮次区分结构、正文、操作区版本；候选卡与消息各有正文版本。
  `presentationRevision` 继续表达原有呈现切换。`messagesForCard()` 返回可复用列表，
  未变消息保持对象身份。普通 chunk 仅更新 dirty message；结构不变时不重排整卡。
  顺序分片追加，乱序分片读取时归并，重复分片不更新正文，end 正文权威覆盖。
- **页面投影**：只解析当前卡及实际请求的目标卡，复用身份索引和单条消息 VM。
  已解析卡片最多两张，离场后清理；正式历史晋升后的正文身份独立参与失效，避免 Edit
  或权威历史更新被候选卡缓存遮挡。操作区变化不重新投影消息列表。
- **局部动画**：切卡进度直接驱动 RenderObject；两张稳定正文 child 各有绘制边界。
  切卡保持 500 ms；Regenerate 保持 800 ms、渐隐和失败回弹，离场正文采用独立深快照。
- **同帧补偿**：布局桥捕获起始滚动位置和卡片实测高度，按绝对高度差生成
  `scrollOffsetCorrection`，在 paint 前校正，重复 layout 不累计偏移。
  末尾工具栏已布局时使用真实 Sliver 总高度，避免平均行高估算造成错误 clamp。
  切卡不再扩大为 10 亿像素缓存；原历史 prepend 路径保留。
  新滚动命令、竖向拖动、结构或布局环境变化使旧事务失效。
- **行与灵感缓存**：复用未变正文行；日期分隔、末行间距、当前／预览角色和样式变化
  参与失效。冻结值比较兼容现有 VM 原地修改。历史 Widget 缓存跟随挂载窗口清理。
  灵感测高仅保留最近结果，键含内容、实际文字宽度、有效文字样式、TextScaler、
  方向和 padding；换页、busy、quota 变化复用结果。

代码入口：

- `lib/network/chatroom/chatroom_reply_performance.dart`
- `lib/pages/chat/location_chat_reply_binding.dart`
- `lib/pages/chat/location_chat_reply_card_switcher.dart`
- `lib/pages/chat/location_chat_reply_layout_bridge.dart`
- `lib/pages/chat/location_chat_scroll_coordinator.dart`
- `lib/pages/chat/location_chat_reply_render_snapshot.dart`
- `lib/features/location_chat_reply/inspiration/src/location_chat_inspiration_replies.dart`

## 自动化计数结果

动画对比使用同一 Widget test fixture、同样的三张卡和尺寸；旧版本来自上述提交，
新版来自工作区。计数从当前／目标卡挂载完成后开始，按每次 16 ms 推进测试时钟。

| 场景 | 改造前 | 改造后 |
| --- | ---: | ---: |
| 固定正文切卡，30 帧中的正文 builder 调用 | 60 | 0 |
| 固定正文 Regenerate 收起，48 帧中的正文 builder 调用 | 48 | 0 |

完整动画、提交与后续帧另由几何回归覆盖，不能把上述计数窗口当作完整动画时长。
对比日志：`/tmp/location-chat-perf-comparison/result.log`；临时 fixture 同目录下的
`motion_benchmark_test.dart`，生产回归用例保留在 switcher test 内。

当前版本的额外断言：

| 场景 | 验收结果 |
| --- | --- |
| 100／1000 条历史，各切卡四次 | 挂载完成后累计历史行 build 少于 40；远处第 1 行在每帧均未挂载；卡片挂载范围仅当前／目标卡 |
| 短卡／长卡，首次目标卡，完整动画 | 每轮 36 帧覆盖提交和后续帧，工具栏位置误差 ≤ 1 逻辑像素 |
| 卡内 child 从 400 增高到 650 | 模拟图片异步完成布局；不重建卡片正文也能按实测高度补偿，误差 ≤ 1 像素 |
| 竖向拖动打断动画锚点 | 覆盖拖动后至提交后，不回拉可见历史行 |
| 10 张候选卡 | 初次只解析当前卡 1 条消息，切下一卡只新增目标卡 1 条消息解析 |
| 灵感 loading／结果刷新 | 消息投影与 VM 解析计数不增加，正文列表实例不变 |
| 灵感换页、busy、quota、等值内容 | 每条回复首次测量一次；后续不增加 TextPainter.layout 计数 |
| 灵感宽度、缩放、方向、样式、padding、内容改变 | 分别使最近测高结果失效；收起释放缓存 |
| 同步状态事务 | 变化地点与兼容全局各通知一次；其他地点不通知 |
| 重复／乱序／空 chunk 与 end | 重复不升正文版本；未变消息保持身份；空 chunk 不结束 loading；最终文本保持原规则 |
| 选卡晋升后正式正文改变 | 候选版本不变也能刷新同一个已挂载卡片组件 |
| 单条正文和邻接布局变化 | 比较实际 ChatMessageRow Widget 实例；未变行复用，日期分隔及卡末间距按需刷新 |

计数入口仅在 assert 中更新，分别为 `debugLocationChatReplyProjectionCount`、
`debugLocationChatReplyMessageParseCount` 和 `debugLocationChatInspirationTextLayoutCount`。
这些结果反映构建、转换和测量复用，**不是实际设备帧率或耗时测量**。

## 回归范围与已知失败

改造前首先执行 controller、service、page、switcher、scroll coordinator 五份
focused tests：**378 项通过**。

最终 12 份 focused 测试共 **440 项通过、2 项既有失败**，没有新增失败。
完整日志为 `/tmp/location-chat-perf-final.log`。验证范围如下，Flutter 命令串行执行：

```sh
flutter test --no-pub \
  test/network/chatroom/chatroom_reply_actions_controller_test.dart \
  test/network/chatroom/world_chatroom_service_test.dart \
  test/network/chatroom/chatroom_reply_action_storage_test.dart \
  test/pages/chat/location_chat_page_test.dart \
  test/pages/chat/location_chat_reply_card_switcher_test.dart \
  test/pages/chat/location_chat_scroll_coordinator_test.dart \
  test/pages/chat/location_chat_reply_actions_test.dart \
  test/pages/chat/location_chat_reply_presentation_test.dart \
  test/pages/chat/location_chat_edit_page_test.dart \
  test/pages/chat/location_chat_reply_render_snapshot_test.dart \
  test/pages/chat/location_chat_inspiration_height_cache_test.dart \
  test/features/location_chat_reply/location_chat_reply_feature_boundaries_test.dart
```

扩展操作区套件保留两项既有失败，未算作本次通过：

1. `inspiration survives recycling its message row`：程序 `jumpTo(0)` 后仍找到
   操作区。隔离副本中的旧 UI 同样失败；该测试没有退出跟随底部状态，不能稳定地模拟
   用户滚离底部。
2. `purchase tabs preserve the original header and close position`：测试期望关闭按钮
   `Rect(346,20,370,44)`，当前为 `Rect(342,18,370,46)`。
   隔离副本保留用户原有 subscription 修改，旧 UI 中同样失败。

隔离复现目录：`/tmp/location-chat-perf-actions-baseline`。复制依赖和资源后，仅将本轮
8 份 UI 改动替换为原提交版本；用户原有订阅修改保持字节一致，没有还原工作区。
`baseline-manifest.json` 记录替换清单，`result.log` 记录相同失败。

本轮对 22 个新增／修改 Dart 文件执行 file-scoped `flutter analyze --no-pub`：
**No issues found**；`git diff --check` 通过。
没有运行真机、全仓库 Flutter 测试或发布流程。

## 保留的首次排版成本

历史消息仍由 Sliver 懒加载；当前回复轮内部仍使用 `Column`。
一张包含 N 条正文的新卡首次挂载仍需构建／布局该卡的 N 行，复杂度仍随整轮长度增长。
本轮减少的是后续动画、控制区刷新和流式增量的重复构建，没有实现轮内逐条虚拟化。
超长轮的真实首次排版耗时和设备帧率尚未测量，作为后续独立性能任务保留。
