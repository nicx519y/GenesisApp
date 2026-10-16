# MiniPhone 模块维护指引

本文件指导 `lib/pages/mini_phone/` 及其子目录的开发与审查，补充 [工程指引](../../../AGENTS.md)。涉及网络、World 或共享组件等目录外文件时，同时遵循那些文件所属目录的指引。下文 `lib/`、`docs/`、`test/` 以 `genesis_app/` 为基准。

## 按任务阅读

- 修改前核对正式调用代码和接口契约；手机接口以 `docs/mini-phone-chat-client-api-2026-10-12.md` 的 2026-10-16 当前 dev 契约为准；它替代旧草案，日期增量稿只保留历史范围。源码契约对齐不等于真实账号端到端验收。
- [集成文档](../../../docs/mini-phone-client-integration.md) 保留待联调项目和历史验证；修改对应行为时按下表读取相关章节，不把客户端实现或受控测试解释为服务端已验收。

| 本次任务 | 集成文档中的阅读入口 |
| --- | --- |
| 定位模块职责 | [代码入口](../../../docs/mini-phone-client-integration.md#code-entry-points) |
| Messages／Posts／通知／相册 HTTP | [手机接口](../../../docs/mini-phone-client-integration.md#phone-http-routes)及当前 dev 手机接口相关章节 |
| 音乐、壁纸、上传、角色／用户资料、模型及采集 | [10 个复用接口](../../../docs/mini-phone-client-integration.md#reused-http-routes) |
| World 绑定、手机事件、恢复及未读刷新 | [世界连接与事件](../../../docs/mini-phone-client-integration.md#world-websocket-events) |
| 聊天、分页、点赞、通知或发帖交互 | [客户端行为](../../../docs/mini-phone-client-integration.md#required-client-behavior) |
| 后端联调或验收判断 | [契约边界](../../../docs/mini-phone-client-integration.md#backend-contract-boundaries)及该文档的 Backend dependencies before acceptance |
| 选择模块或跨模块回归用例 | [验证命令](../../../docs/mini-phone-client-integration.md#verification-commands) |

## 必须保持的约束

- 数据和写请求按环境、账号、世界隔离；上下文改变后丢弃旧请求结果，清除旧草稿和恢复页面引用。
- 保存写请求 ID 与原始正文、图片和回复目标；同一次操作重试复用原请求，不建立自动重发队列。超时／断线保持待确认状态，不能据此判定 AI 最终失败。
- DM 提交时立即显示独立的本地临时气泡并清空原输入，不等待 HTTP、不在 Send 上转圈；正式消息仍只来自送达事件或历史查询，按请求键替换临时气泡、按完整 int64 消息 ID 去重和升序展示。明确拒绝撤回临时气泡并恢复草稿，不覆盖新输入；超时／断线保留待确认气泡和原请求键。空成功响应只表示操作受理／成功。新收到的多条回复首条立即显示，其余每隔一秒逐条显示，已有历史和历史分页不延迟；自动补查和去重不得提前显示排队消息。
- HTTP 200 下非零 `err_no` 仍为业务错误；展示原始 `ApiException.message`／`err_msg`，失败保留草稿。区分 Feed 的 `text` 和详情／提交的 `content`。
- 复用现有签名 HTTP client 与 World 的 V2 Socket，不创建手机独立连接、不为手机事件加入地点；手机事件不得进入 LocationChat 时间线或地点队列，不在页面硬编码环境地址。
- 事件按 `event_id` 去重，未读以 HTTP 结果为准，不按事件次数增减；合并刷新保留刷新期间的新事件。手机关闭继续处理世界事件，退出世界释放订阅；初始化、重连及返回前台执行恢复查询。Home 使用世界时间。
- 聊天复用共享锚点列表、滚动协调器、`ChatMessageRow`、`ChatComposer` 和 `ChatKeyboardInsetLayout`，视觉采用 `kPrivateChatStyle`。发送保持键盘、不预留回复空白；阅读历史保留锚点和返回最新入口。
- “正在输入”是本地请求等待提示；仅 AI 会话等待期间允许编辑草稿、禁止再次发送，其他角色独立运行；按请求键查询历史中的 reply_status/failure，关联完整 AI 批次或服务端终态结束等待，终态不回退。peer_uid 非空的玩家互发不显示 AI 输入状态，气泡方向比较 sender_id 与当前 UID。
- Messages 仅用 `/dm_sessions` 返回的条目生成列表，不由 World／Home／消息缓存补齐；保持服务端顺序，按 world_id + char_id 合并分页。允许多个 dm_session_id=0 的虚拟条目；进入空聊天页，跳过消息和已读查询，仍按 char_id 发送，取得正数 ID 后替换对应条目。未读数量取服务端；保留既有标题和列表、下拉刷新及公共错误 Toast。
- Posts 作者仅取 `/post/authors` 的全世界发帖角色 ID，以角色资料补充名称与头像；筛选只传 `char_id`（玩家也用角色 ID），全部作者省略参数。切换作者重置分页并丢弃旧响应；通知刷新保留筛选并刷新作者列表。评论预览使用 Feed 返回值，不逐帖请求详情补齐；回复必须使用 `/comments` 的真实 ID。
- Posts Feed 使用按需构建的虚拟列表，只渲染视口附近；配图从加载前就固定占高 200，CDN 按高度和现有 DPR 上限缩放，预加载实际视口下方 5 条帖子的图片并与显示共用缓存。加载中／失败均留空，不显示占位图、错误图标或提示；点击时向通用大图浏览器传原图 URL 和当前缩略图 provider，立即复用缩略图缓存，待大图加载后替换；通过公共 `GenesisImageViewerSourceAnchor` 传入实际缩略图来源，实现通用打开放大动画，不在业务页复制动画；详情尺寸独立保持。
- 同帖点赞／取消点赞串行执行；结果不确定时查询详情，再处理最新操作意图。进入 Posts 的全部已读只在本次进入成功加载后执行，停留期间不自动清除新通知。
- 通知逐页替换，不按帖子合并、不制造通知 ID 或正文。Photos 保留网格和共享查看器，传当前缩略图 provider 与公共来源锚点实现放大动画；多图打开及翻页预加载前后各一张大图，预加载 URL／解码尺寸／fit 与实际显示共用缓存，空原图不影响选中下标；发帖选图只做统一预处理和预览，不显示处理进度；两端最长边 ≤4096、总像素 ≤1600 万、小图不放大，透明 PNG／不透明 JPEG 90%，超 10 MiB 继续等比缩小。点击 Post 才通过已有 upload/image 上传并发帖，按钮全程 loading；锁定正文和图片操作，返回／关闭仍可用，World 会话持有草稿及发送。失败保留草稿并复用已上传图片，保留完整 xl_url 及查询参数，允许纯文字。正文必填，按 65535 UTF-8 字节限制；上传不超过 10 MiB。未确认写请求重试保留原图片 URL，不重新上传替换已提交内容。
- 布局与样式以 `c6b7600e` 的 MiniPhone 为基准；接入真实数据不新增常驻操作栏、筛选按钮或分页按钮，不移动既有主按钮。Posts 重复点击当前作者取消筛选；Create 保留右上角 Post、作者信息和虚线选图区；评论保留原帖布局、分隔线与输入头像。动态分页由滚动触发，页面级首次加载只显示一个状态，有内容刷新不追加转圈；私聊首次加载与历史分页 loading 互斥；顶部历史加载占位仅用于向上翻页，自动补查和有内容刷新不触发。
- 手机桌面图标／通知卡片到应用的展开继续使用 `AppLaunchTransitionHost`；应用内会话、评论、发帖和模型等子页通过内部 Navigator 复用 `GenesisDarkPageRoute`，与手机外页面采用同一套平台进出动画。返回保留底层列表状态，关闭按钮退出整个 MiniPhone。
- 保持现有样式、导航、启动动画、音乐和壁纸行为；共享聊天修改回归 LocationChat。新增动态请求的错误统一使用公共 Toast，不向 Home、列表、发帖表单或聊天输入区插入错误段落和 Retry／Refresh 按钮；读操作保留下拉刷新，Post／评论／私聊使用原提交按钮重试未确认请求并复用原 ID 和原始内容；已受理 DM 仍禁止重复发送。演示数据仅用于明确的无世界预览。
- 当前模型和记忆 Token 选择仅更新本地 `MiniPhoneSession`；选择、折扣展示及采集事件不证明后端设置或计费生效。原生 Dart 保留 int64；JavaScript 目标需先解决无损 JSON ID 传输。

## 验证与维护

- 按改动选择集成文档的验证命令；Dart 修改只格式化涉及文件，静态检查包含实际修改的目录外文件。纯文档修改检查路径、接口表、Markdown 和 `git diff --check`。
- 重点覆盖重复／乱序推送、推送先于 HTTP、首次私聊、历史锚点、同请求重试、账号切换旧响应、快速点赞、通知分页和 Posts 进入已读。
- 受控测试、真实后端及 Android／iOS 真机结果分别报告。键盘、多行、窄屏、大字体、横屏和断线恢复需对应证据，历史通过记录不能代替本次验证。
- 接口或行为改变同步本文件及相关文档；不依赖离线事件重放；推送仅即时尝试，断线后以 HTTP 请求关联状态恢复。真实环境及设备待验收事项保持显式标记。
- 使用普通 Markdown 与目录级指令；长接口表、DTO、测试命令和运行记录留在文档中，不需要 YAML front matter 或自定义加载脚本。遵循 [OpenAI AGENTS.md 指南](https://learn.chatgpt.com/docs/agent-configuration/agents-md)，从工程根目录处理本模块时按入口读取本文件。
