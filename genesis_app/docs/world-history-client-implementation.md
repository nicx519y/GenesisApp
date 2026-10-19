# World History 客户端实现

接口依据 [2026-10-19 设计稿](world-history-client-guide.md)。Chat history 服务尚未实现；本客户端和受控测试不能证明线上权限、游标快照稳定性、完整历史或真机性能。

## 数据与展示边界

- `GenesisApi.getWorldHistory` → `ChatroomHttpApi.getWorldHistory`，复用 Chatroom 根地址 HTTP 客户端、登录 Header、Gateway 拦截器和取消 token。路径为 `/aitown-chat/api/v1/world/history`，不是主 API 的 `/api/v1/world`。默认 20 条，首次省略 cursor，其后原样传递，不传 user_id。
- `network/models/world_history.dart` 独立保存字符串消息 ID、服务端顺序、World 级游标。拒绝错误 World、非严格分页字段、未推进／循环游标；非零 err_no 保留原始错误。无旧消息接口回退。
- `WorldHistoryController` 只负责世界分页快照。同参数请求合并，不同操作串行；刷新成功原子替换窗口，失败保留原内容与游标。回载校验页边界、响应游标和 has_more，快照变化时报错，不拼接新旧快照。
- `WorldHistoryProjection` 仅逆转消息方向，保留每条 location_refs 顺序。字符串 ID 与地点 ID 构成无歧义显示标识；不按 ID、时间、轮次排序。不生成轮次或协议 Tick 编号，气泡使用现有“不显示编号”的显示约定。
- 每条 Tick 的字符串正文懒解码一次，缓存随原始消息释放。共享旁白／时间／世界状态在每个关联地点出现，事件按其 location_id 过滤；没有地点事件仍显示 Tick。移动只供显示，不更新实时角色位置，不补关联。未知 visibility 不丢弃，缺失／null 可选数组按空数组，解析失败或非 Tick JSON 显示原正文。
- 空关联只显示一次，不生成地点段或跳转。未知地点显示 ID，元数据到达后更新名称、路径和背景；只有已知地点提供“在这里继续”。新增地点不影响分页状态，也不会补入旧 Tick 的关联。

## 生命周期与窗口

- 标签激活、当前路由可见、PagePresentationScope、TickerMode 和应用前台共同控制请求。暂停取消请求、待调度加载和滚动防抖；恢复只续接被取消的操作。错误没有自动重试计时器，通过公共 Toast 和手动 Retry 处理。
- 每次重新进入 History 刷新首屏。刷新失败保留旧页；覆盖恢复／前台恢复不刷新已完成快照。账号 sessionRevision、服务实例／环境和 World 切换都销毁旧控制器，晚到响应不能提交。Sheet 销毁释放数据，无磁盘缓存。
- 每页保留请求游标、响应游标、has_more、首尾消息 ID；正文驻留预算为 1,000 条唯一消息或 8 MiB UTF-8 正文字节。按远离阅读位置的外侧整页回收，保持连续驻留区；可见区、共享滚动器锚点、展开定位页及相邻页暂时固定，超大单页不截断。
- 访问已回收的较新或较旧区段时使用原请求游标。两端分别判断已回收区段与服务器终点；稳定显示 ID 交给共享聊天滚动器恢复锚点。回载失败保留窗口，原游标可重试；失效时重新进入刷新。
- 元数据索引只依赖角色身份／头像和地点路径／图片字段。时间与 Tick 计数不重建索引；相关列表替换但展示值不变时保持版本。展示复用 LRU 默认 300，当前可见项可固定；额外弱引用只复用共享 viewport 仍持有的 VM，不延长正文存活。页移出、刷新或上下文切换清理派生引用。
- 地点连续段落只在数据／元数据投影变化后更新。折叠仅更新该段隐藏状态，记住用户操作的轻量 ID，使回载后保持选择。整页被版本过滤且还有下一页时显示手动加载入口，不自动遍历全历史。

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
