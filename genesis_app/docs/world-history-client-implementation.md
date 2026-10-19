# World History 客户端实现

接口依据 [2026-10-19 设计稿](world-history-client-guide.md)。Chat history 服务尚未实现；本客户端和受控测试不能证明线上权限、游标快照稳定性、完整历史或真机性能。

## 数据与展示边界

- `GenesisApi.getWorldHistory` → `ChatroomHttpApi.getWorldHistory`，复用 Chatroom 根地址 HTTP 客户端、登录 Header、Gateway 拦截器和取消 token。路径为 `/aitown-chat/api/v1/world/history`，不是主 API 的 `/api/v1/world`。默认 20 条，首次省略 cursor，其后原样传递，不传 user_id。
- `network/models/world_history.dart` 独立保存字符串消息 ID、服务端顺序、World 级游标。拒绝错误 World、非严格分页字段、未推进／循环游标；非零 err_no 保留原始错误。无旧消息接口回退。
- `WorldHistoryController` 只负责世界分页快照。同参数请求合并，不同操作串行；刷新成功原子替换窗口，失败保留原内容与游标。回载校验页边界、响应游标和 has_more，快照变化时报错，不拼接新旧快照。
- `WorldHistoryProjection` 仅逆转消息方向，保留每条 location_refs 顺序。字符串 ID 与地点 ID 构成无歧义显示标识；不按 ID、时间、轮次排序。客户端兼容顶层可选 `tick_no`、`sub_tick_no`（兼容 `subtick_no`）非负整数；仅服务器给出真实编号时复用聊天的 Tick 1-1 标签，否则保持无编号，不能按分页位置推算。目前正式 History 设计稿明确不返回这些编号，实际恢复需后端补字段。
- 每条 Tick 的字符串正文懒解码一次，缓存随原始消息释放。History 只在该 Tick 之后、下一条 Tick 之前存在 `type=user` 消息的地点展示这条 Tick，并与 Tick 自身 location_refs 取交集；不因为地点以前聊过就展示全部后续 Tick，不把 character/narrator 当用户消息。用户确认接受其他 Tick 内容在 History 中缺失。分页目录保留轻量 Tick/用户地点摘要，跨页、正文回收和回载后仍能判定。
- 符合条件的地点继续展示共享旁白／时间／世界状态及该地点事件；History 不展示 `characters_moved`，普通 Chatroom/Events 不受影响。未知 visibility 不丢弃，缺失／null 可选数组按空数组处理，旧 Tick 纯文本仍使用原始正文但同样执行地点过滤。
- 普通消息空关联只显示一次，不生成地点段或跳转；无关联 Tick 无法匹配参与地点而不展示。未知地点显示 ID，元数据到达后更新名称、路径和背景；只有已知地点提供“在这里继续”。新增地点不影响分页状态，也不会补入旧 Tick 的关联。

## 生命周期与窗口

- History 底部居中显示双下箭头置底按钮，距底12：离开底部或最新页已回收时出现，到底后消失。与 Location Chatroom 新消息提示复用 `_LocationChatFloatingNotice`，底色0xCC1E1E24、圆角16、水平12/垂直8内边距，无额外边框或阴影，保留24px白色双下箭头；无新增自定义文案，辅助提示复用 Material 本地化末页标签。点击复用共享滚动协调器，最新页被回收时先按原快照游标回载，成功后置底；失败保留原阅读内容。折叠选择不重置。

- 标签激活、当前路由可见、PagePresentationScope、TickerMode 和应用前台共同控制请求。暂停取消请求、待调度加载和滚动防抖；恢复只续接被取消的操作。错误没有自动重试计时器，通过公共 Toast 和手动 Retry 处理。
- 首次进入 History 使用静态骨架并加载首屏。`WorldPage` 持有 `WorldHistoryViewCache`，保留分页窗口、正文投影、折叠选择及共享列表的有界布局缓存和稳定消息阅读锚点；切换标签或关闭再打开 Sheet 不刷新、不跳到最新消息，首帧恢复阅读位置。覆盖恢复／前台恢复同样不刷新已完成快照，仅续接被取消的必要操作。退出 World 释放缓存，无磁盘缓存；账号 sessionRevision（包括 Sheet 关闭期间）、服务实例／环境和 World 切换清空旧状态，晚到响应不能提交。
- 每页保留请求游标、响应游标、has_more、首尾消息 ID；正文驻留预算为 1,000 条唯一消息或 8 MiB UTF-8 正文字节。按远离阅读位置的外侧整页回收，保持连续驻留区；可见区、共享滚动器锚点、展开定位页及相邻页暂时固定，超大单页不截断。
- 访问已回收的较新或较旧区段时使用原请求游标。两端分别判断已回收区段与服务器终点；稳定显示 ID 交给共享聊天滚动器恢复锚点。回载失败保留窗口，原游标可重试；失效时退出并重新进入 World 获取新快照。
- 元数据索引只依赖角色身份／头像和地点路径／图片字段。时间与 Tick 计数不重建索引；相关列表替换但展示值不变时保持版本。展示复用 LRU 默认 300，当前可见项可固定；额外弱引用只复用共享 viewport 仍持有的 VM，不延长正文存活。页移出、刷新或上下文切换清理派生引用。
- 地点连续段落只在数据／元数据投影变化后更新。折叠仅更新该段隐藏状态，记住用户操作的轻量 ID，使回载后保持选择。整页被版本过滤且还有下一页时显示手动加载入口，不自动遍历全历史。
- 普通 LocationChat 保持 `fcc6100b` 之前的列表排列与定位行为：直接使用回复投影，不接入跨地点历史排序；共享列表不会仅因 `active` 恢复就额外清空等待空间／阅读锚点或调用 `enter()`，实际进入／离开仍由页面原有生命周期处理。拖动开始时提前捕获锚点由 History 显式启用；吸顶标题布局仅在传入 History 标题构建器时使用。History 的折叠定位与阅读缓存继续保留。

## 验证入口

- `test/network/world_history_api_test.dart`：路径、认证拦截链、字符串大 ID、游标、业务和格式错误、mock 快照回载。
- `test/pages/world/history/`：控制器取消／重试／窗口／双向回载，Tick／元数据／LRU，页面前后台／覆盖／切换账号与 World，地点变化和版本过滤。
- `test/pages/chat/location_chat_history_navigation_test.dart`、`location_chat_history_folding_test.dart`、`location_chat_scroll_coordinator_test.dart`：共享滚动与折叠回归。
- 本地 mock 提供专用分页 fixture 和 Tick，最多保留 10 个 mock 快照，不模拟真实权限。

本次复用既有 `homeRetry`、`chatLoadEarlierMessages`、`loadMoreAction`、`worldHistoryEmpty`、折叠和继续地点文案；无新增翻译 key。2026-10-19 已通过飞书客户端更新多语言表第 160 行（`chatLoadEarlierMessages`）及第 541 行（`loadMoreAction`）的显示位置和翻译备注，回读确认内容及云端保存状态；英文和各语种译文未变更。

## 本次验证结果（2026-10-19）

- History 接口、控制器、投影、生命周期、双向回载锚点及共享聊天／World／MiniPhone 专项回归：61 项通过。
- 相关修改文件静态分析无问题；`./tool/l10n/check` 的 52 项检查通过。
- 既有 Chatroom／GenesisApi／本地 mock 网络回归：152 项通过，2 项登录埋点测试失败（Google 和 Apple 登录缺少 `login_first`）。在移除本次 History 改动、保留其他工作区改动的隔离副本中，两项失败同样复现，不属于本次迁移引入的问题。
- 真实 History 服务权限、游标回载稳定性、分页完整性以及真机内存／滚动表现，仍待服务可用后验收。

### History 视图缓存调整（2026-10-19）

- 首屏转圈改为静态地点标题、头像和正文骨架；没有新增用户文案。
- 缓存范围从单次 Sheet 扩大到当前 World 页面；保留阅读锚点、折叠选择、背景与应用版本过滤信息，重新打开无需请求或重新解码正文。共享聊天列表仅在显式提供缓存时恢复阅读锚点，普通聊天仍沿用原进入行为。
- 新增回归覆盖关闭／重开、首帧阅读位置、Tab 交接滚动控制器、折叠保留、隐藏期间账号变化、退出 World 释放以及面板高度改变；首次失败仍由用户手动重试。
- 本次 History、共享聊天、World 和 MiniPhone 回归共 62 项通过，8 个修改文件静态分析通过；未进行真机验收。

### History 下滑关闭保护（2026-10-19）

- 首屏未完成、请求进行中或仍有更早页可加载／回载时，History 锁定 Sheet 的下拉收起范围，并拦截标题拖动和松手甩动关闭。加载失败或版本过滤导致当前页为空不代表历史已经到底。
- 手势开始时若尚未加载完，即使最后一页在拖动过程中返回，本次手势仍不会关闭；后续手势恢复原有行为。关闭按钮、系统返回和其他标签页保留原有退出方式。
- 回归入口：`test/pages/world/history/world_history_sheet_gesture_test.dart`，使用实际 Sheet 验证内容下滑、标题甩动、分页失败、请求与手势交错及主动关闭。
- 本次 History 与标签页专项回归 28 项通过；未进行真机手势验收。

### LocationChat 定位行为回退（2026-10-19）

- 撤掉 `fcc6100b` 留在普通聊天列表中的重新激活定位重置；History 提前捕获拖动锚点改为显式启用，普通聊天不再包裹 History 吸顶布局。
- 聊天滚动、等待回复、历史导航／折叠及 History 页面共 109 项回归通过；页面级失败消息排列用例通过，4 个修改 Dart 文件静态分析及格式检查通过。
- 额外检查的 3 项首次进入页面用例在回复按钮 `idle`／`disabled` 断言上失败；保留原工作区其他改动、移除本次回退的临时副本中，同样 3 项以相同断言失败。未进行真机或真实后端验收。
