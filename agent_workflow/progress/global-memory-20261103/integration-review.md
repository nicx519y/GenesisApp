# 全局记忆集成只读审查 · 2026-11-03

范围：当前未提交的 `world_memory_host`、World Sheet 接入、MiniPhone 三应用入口／导航、`app_router` 和 Developer 预览。只沿新增调用链读取必要的既有依赖，不对历史未改动代码另作审查；未运行 analyze、测试或构建，未修改产品代码。基线 HEAD：`8d0062581117513aeefe9dc507759e4347a4cd18`。以下为静态代码可确认的问题，复现场景尚未真机执行；Deluxe 正式数据／购买适配缺失不作为问题，后端范围仍待用户确认。

## 1. [P1] MiniPhone 的订阅跳转使用了没有命名路由处理器的内部 Navigator

位置：[world_memory_host.dart:177](C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/pages/world/world_memory_host.dart:177)（177–183）；接入：[mini_phone_page.dart:694](C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/pages/mini_phone/mini_phone_page.dart:694)。

在 Phone 的 Recap 锁定页、Cast 或 Bonds 点击 Subscribe／详情箭头，`WorldMemoryHost` 用自己的 `context` 执行 `Navigator.of(context).pushNamed(RouteNames.gemWallet)`。该宿主位于 MiniPhone 的内部 `Navigator(pages: …)` 下（同文件604–640），此 Navigator 没有 `onGenerateRoute`；命名路由不会自动向根 Navigator 委托，因此抛出路由错误，无法进入已经在 `AppRouter` 注册的钱包页面。World Sheet 路径正常不能覆盖此错误。

修正方向：由外层传入导航回调，或明确使用注册 `AppRouter` 的根 Navigator，保留 `showDeluxeInitially` 及订阅来源参数。

## 2. [P1] 宿主未挂载期间切号，共享 Summary 缓存仍会被新账号复用

位置：[world_memory_host.dart:48](C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/pages/world/world_memory_host.dart:48)、[world_memory_host.dart:91](C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/pages/world/world_memory_host.dart:91)（91–93）、[world_bottom_sheet.dart:750](C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/pages/world/world_bottom_sheet.dart:750)。

触发条件：账号A加载 Summary → 关闭 Sheet，使 `WorldMemoryHost` dispose → 保留同一 WorldPage 时发生账号／会话更换 → 账号B以有效 Premium 再打开同一 worldId 的 Recap。新宿主直接接受 WorldPage 长期持有的 `widget.recapCache`；它只在**自己挂载期间**监听 `sessionRevision` 并 clear，挂载时没有比较缓存所属账号／会话版本。当前缓存只记录 worldId，不记录账号；新 `_ensureSummary` 又因 `hasLoaded` 直接返回，随后152–159行把旧缓存正文交给新账号视图。即使 Host 的 Widget key 包含 currentUid，也只是重建 Widget，不会替换传入缓存或使旧异步请求失效。

依赖确认：现有 WorldPage 的会话变化回调不清该缓存；本次新增的 Host listener 不能覆盖关闭 Sheet 的窗口。因此这不是仅一次闪旧内容，而是可能在没有新更新事件时持续展示旧会话结果；旧账号尚未结束的缓存请求也未在这个窗口失效。

修正方向：缓存由长生命周期所有者按环境／账号／World及会话版本隔离、切号立即清空并废弃进行中响应；或在传给新宿主前校验缓存身份。不能只依赖临时页面的 session listener 或会员布尔值。

## 3. [P2] 新的“一次加载”条件使 Summary 丢失进入刷新和 Phone 实时更新

位置：[world_memory_host.dart:86](C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/pages/world/world_memory_host.dart:86)（86–97）、[mini_phone_page.dart:694](C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/pages/mini_phone/mini_phone_page.dart:694)（694–704）。

`_ensureSummary` 对同世界的任何 `hasLoaded` 缓存永久跳过请求；此次 World Sheet 改动同时删除了原来的 `_refreshRecapOnEntry`。若首次返回空摘要，之后更新推送因断线漏收，再次关闭／打开 Recap 仍复用空结果；已有正文同样不会在重新进入时校准。首次请求失败时 `refreshError` 也阻止重新进入自动重试，只能点原错误页按钮。

Phone 问题更直接：新增入口不传 `cache`，每个宿主创建自己的 `WorldRecapCache`，而现有 Summary 更新事件只刷新 WorldPage 的 `_recapCache`。用户停留在 Phone Summary 时，即使实际收到更新事件，这份独立缓存也不会更新；宿主没有更新事件订阅／刷新入口，仍显示最初的正文或空状态。

修正方向：保留缓存用于立即展示，但每次有效进入做去重刷新；Phone接入同一账号／World作用域的更新源或共享缓存，并保持退出／切号时的生命周期隔离。这里需要修复的是现有 Summary 链路，不涉及新增结构化记忆后端范围。

---

本轮共报告 **2项P1、1项P2**。未发现足以单独报告的 Developer 样例进入正式记忆视图或越权购买问题；此表述不代表端到端验收通过。未把取最新一份完整P5摘要当作历史数据删除，也未从示例推断生产权益。

## 追加复核与 Phone 修复记录 · 2026-11-03

以上 finding 保留为首次审查历史，其行号与“未运行测试”描述对应当时快照。本节记录后续修复及本次只读核验结果；本次追加仅修改本文档，不改产品代码，不重跑测试或构建。

### 原 3 项问题的当前状态

| 原 finding | 状态 | 修复与复核依据 |
| --- | --- | --- |
| 1 · P1 Phone 订阅导航 | **已解决（代码复核）** | `WorldMemoryHost.onSubscribe` 已使用 `Navigator.of(context, rootNavigator: true).pushNamed`，保留钱包订阅参数，绕过 Phone 内部无命名路由处理器的 Navigator。 |
| 2 · P1 关闭宿主期间切号复用缓存 | **已解决（代码复核）** | `WorldRecapCache.bindScope` 在 scope 变化时 clear 并使旧请求失效；WorldPage 在依赖绑定及 session 变化时同步绑定 `(services, services.sessionRevision.value)`，Host 挂载时以同一 tuple 再绑定。覆盖 Sheet 未挂载期间切号的窗口，同 scope 不重复清空。 |
| 3 · P2 进入刷新与 Phone 实时更新 | **已解决（静态接线闭环，非端到端验证）** | Host 已在 active entry、重新获得 Premium 时刷新，并先展示已有缓存；`summaryUpdates` 已绑定监听并调用 `refreshOnUpdate`。Phone Session 通知接口与页面传参已完成，3 项定向测试通过。最新只读复核确认 `world_page_chatroom_session.dart:36` 的 `_attachWorldChatroom` 在 `data?.attach(service)` 后调用 `bindSummaryUpdates(service.summaryUpdates)`，已有事件源 → Session 通知 → Phone Host → 缓存刷新静态链路已接通。 |

复核历史：上一轮仅确认 SummaryUpdates 接口，生产调用尚缺，故曾将 P2 标为部分解决。父任务随后补入接线；本轮已只读确认 `world_page_chatroom_session.dart` 的 `_attachWorldChatroom` 中紧接 `_miniPhoneSession.data?.attach(service)` 存在以下调用，后续经该方法重绑 service 时也会执行：

```dart
_miniPhoneSession.bindSummaryUpdates(service.summaryUpdates);
```

这是复用已有 WorldChatroomService 的事件投影，不新建 Socket、不 join 新链路。原 3 项 finding 现均已在静态代码复核层面解决，未发现新增具体问题；不代表真实 Socket 推送、设备表现或端到端验收通过。本轮遵守冻结及只文档要求，未修改产品代码，未重跑测试或构建。

### 已完成的 Phone 概要最小接入

- `mini_phone/session/mini_phone_session.dart` 暴露 `Listenable summaryUpdates` 与 `bindSummaryUpdates(Stream<ChatroomWorldSummaryUpdated>)`；只转发当前 world、当前已登录 uid 的概要更新，按账号 generation 重置事件 generation 去重。重新绑定取消旧订阅并以绑定版本丢弃旧回调；销毁取消订阅、释放通知器并忽略排队事件。
- `mini_phone/mini_phone_page.dart` 已向 `WorldMemoryHost` 传入 `summaryUpdates: _session.summaryUpdates`。Session 的通知转发本身不发 HTTP；读取及 Premium/active 门控仍归 Host。未改 Host/cache，未新增后端或购买契约。
- 新增测试文件：`genesis_app/test/pages/mini_phone/mini_phone_summary_updates_test.dart`。测试显式注入事件流，验证 Session 行为；World 生产调用已接入的依据为本轮静态代码复核，不是这 3 项单测。

### 实际验证记录

先前实现阶段执行：`flutter test --no-pub test/pages/mini_phone/mini_phone_summary_updates_test.dart --reporter expanded`（通过本机 Dart 执行 Flutter tools snapshot）。退出码 **0**，输出 **`00:02 +3: All tests passed!`**。

| 定向测试 | 结果与覆盖 |
| --- | --- |
| `only current world/account summary hints notify without HTTP work` | 通过；过滤其他世界及账号，去重同 generation，通知转发不增加 HTTP 请求。 |
| `account changes reject old user hints and reset generation deduplication` | 通过；切号丢弃旧账号排队事件，登出不通知，重新登录后同 generation 可以再次通知。 |
| `disposing a session cancels its listener and discards queued hints` | 通过；dispose 后取消事件监听，排队及后续事件不通知。 |

实现阶段相关文件 `git diff --check` 通过。父任务另报告 **41 项集成／原手机导航／缓存测试通过**，该结果来源为父任务报告，本审查未独立重跑。l10n check、最终 APK build 与真实设备/后端验收由父任务继续；本文不宣称其已完成，不从测试样例推断生产数据或权益。
