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


## 2026-11-05 照片接入后的性能回归修复

本轮以 `869740d1` 为实现前基线，保留该版本的消息布局、长按操作和图片查看器行为。正式回复仍允许无 card_id，候选照片仍绑定原卡片；没有更改接口、420ms 入场时长、费用或重试规则。

### 实现

- 页面按消息投影、内容版本和访问身份缓存实时照片任务；列表只在内容变化时建立照片索引。只读历史与无照片任务路径直接跳过；操作栏与展开队列只访问活动照片，不在滚动时扫描全部历史。显式内容版本兼容 VM 原地更新；未提供版本的独立调用方保留保守刷新。
- 活动动画、定位准备与已处理任务标识分离。完成或取消时先将行替换为固定完整高度、清理行缓存，在帧结束后销毁控制器；移出列表、暂停、切换访问及销毁均释放等待。轻量防重播标识保留至本次访问结束，不持有消息或图片。
- 同轮照片恢复合并持久日志和内存目标，只请求一次 cards。响应按各卡请求版本应用，旧 HTTP 不覆盖新 WS；只对有效响应清理终态任务日志。等值卡片不重新通知或持久化，失败保留任务。
- 灵感失败定位到 `_scheduleEntrySendWaitCheck` 的无条件整页刷新，而非灵感结果的正文变化。Send gate 的纯控件变化改为局部通知，Tick 等待行变化仍更新正文；输入区在局部刷新时读取当前 Tick 锁，避免捕获旧状态。

### 自动化验收

| 场景 | 实现前 | 本轮结果 |
| --- | --- | --- |
| 1200 条历史仅刷新装饰，消息读取 | 6038 次 | 恢复 `<200` 门槛 |
| 200／600／1200 条历史，三次小幅滚动 | 660／1860／3660 次 | 全部恢复 `<100` 门槛 |
| 200／600／1200 条消息，照片完成后滚动及父组件更新 | 未覆盖 | 照片索引扫描计数不增加；内容版本变化仍刷新 |
| 连续 8 次照片入场、淘汰及重新挂载 | 控制器保留至列表销毁 | 控制器、准备记录、待销毁资源均归零；同任务不重播 |
| 同轮两卡同时存在于日志和内存 | 重复请求 | 每轮一次；失败保留日志，成功校准后清理 |
| 灵感结果／loading 更新 | 列表身份复用失败 | 原列表身份、投影次数、解析次数断言通过 |

最终七份组件／性能／回复控制器测试 **284 项通过、1 项既有失败**；页面定向测试 **34 项通过、1 项既有失败**；照片服务定向测试 **10 项通过**，合计 **328 项通过、2 项既有失败**。两项失败在未修改 `869740d1` 源码的隔离副本中复现：

- `camera uses the latest reply toolbar callback without sending`：按钮右边界期望 304，实际 277.5。
- `ACK timeout retains unknown bubble without automatic resend`：等待 Send 可用超时。

未放宽上述断言或把失败计作通过。灵感原失败也在隔离基线复现，本轮已修复；Tick 超时解锁定向复查通过。修改范围静态检查无问题，差异检查通过。

执行范围：`location_chat_visibility_cost_test`、`location_chat_photo_navigation_test`、`location_chat_reply_card_switcher_test`、`location_chat_inspiration_height_cache_test`、`location_chat_waiting_scroll_test`、`location_chat_camera_action_test`、`chatroom_reply_actions_controller_test`；页面过滤覆盖 photo、camera、timeout、历史局部刷新、当前／目标卡解析和灵感投影；服务过滤 photo。

### Pixel 6 受控 profile 测量

使用独立测试包 `local.genesis.performance.location_chat_probe`，直接引用本轮工程组件，未覆盖正式应用；测完已移除测试包。使用本地构造文字与 generating 占位，未调用真实生图接口或请求 CDN 图片。滚动为 240 次、间隔约 16ms 的 3px 步进；连续加入 10 张照片，每张间隔 700ms。以下为单次测量，不是修改前后的设备对比。

| 场景 | 采样帧 | build P95 | raster P95 | build >16.7ms 帧数 | 进程 RSS 前→后 |
| --- | ---: | ---: | ---: | ---: | --- |
| 1200 条历史滚动 | 241 | 7.359ms | 10.360ms | 0 | 305.4→308.8 MiB |
| 200 条文字后连续 10 张照片入场 | 363 | 13.844ms | 10.561ms | 17 | 305.0→315.5 MiB |
| 照片完成后滚动 | 240 | 8.433ms | 11.321ms | 2 | 315.5→316.1 MiB |
| 列表 active 关闭／恢复后滚动 | 242 | 8.998ms | 11.064ms | 3 | 316.1→302.9 MiB |

RSS 包含整个进程与 GC 波动，不能据此单独证明无泄漏。连续入场仍有 17 个 build 超过 16.7ms 的帧，不能声称完全无卡顿；本轮未定位这些长帧。active 切换不等于 Android 真正后台恢复，真实后端、真实图片解码及完整应用后台恢复仍待验收。

日志：`/tmp/location-chat-implementation-regressions-final.log`、`/tmp/location-chat-implementation-page-final.log`、`/tmp/location-chat-implementation-service-final.log`、`/tmp/location-chat-final-baseline.log`、`/tmp/location-chat-timeout-baseline.log`、`/tmp/location-chat-profile-device-final.log`。临时测试工程与采样驱动位于 `/private/tmp/location-chat-profile-probe`。
