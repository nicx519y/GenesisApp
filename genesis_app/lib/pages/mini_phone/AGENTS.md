# MiniPhone 模块维护指引

本文件指导 `lib/pages/mini_phone/` 及其子目录的开发与审查，补充 [工程指引](../../../AGENTS.md)。涉及网络、World 或共享组件等目录外文件时，同时遵循那些文件所属目录的指引。下文 `lib/`、`docs/`、`test/` 以 `genesis_app/` 为基准。

## 按任务阅读

- 修改前核对正式调用代码和接口契约；手机接口稿 `docs/mini-phone-chat-client-api-2026-10-12.md` 是草案。
- [集成文档](../../../docs/mini-phone-client-integration.md) 保留待联调项目和历史验证；修改对应行为时按下表读取相关章节，不把客户端实现或受控测试解释为服务端已验收。

| 本次任务 | 集成文档中的阅读入口 |
| --- | --- |
| 定位模块职责 | [代码入口](../../../docs/mini-phone-client-integration.md#code-entry-points) |
| Messages／Posts／通知／相册 HTTP | [16 个手机接口](../../../docs/mini-phone-client-integration.md#phone-http-routes)及手机接口草案相关章节 |
| 音乐、壁纸、上传、角色／用户资料、模型及采集 | [10 个复用接口](../../../docs/mini-phone-client-integration.md#reused-http-routes) |
| World 绑定、手机事件、恢复及未读刷新 | [世界连接与事件](../../../docs/mini-phone-client-integration.md#world-websocket-events) |
| 聊天、分页、点赞、通知或发帖交互 | [客户端行为](../../../docs/mini-phone-client-integration.md#required-client-behavior) |
| 后端联调或验收判断 | [契约边界](../../../docs/mini-phone-client-integration.md#backend-contract-boundaries)及该文档的 Backend dependencies before acceptance |
| 选择模块或跨模块回归用例 | [验证命令](../../../docs/mini-phone-client-integration.md#verification-commands) |

## 必须保持的约束

- 数据和写请求按环境、账号、世界隔离；上下文改变后丢弃旧请求结果，清除旧草稿和恢复页面引用。
- 保存写请求 ID 与原始正文、图片和回复目标；同一次操作重试复用原请求，不建立自动重发队列。超时／断线保持待确认状态，不能据此判定 AI 最终失败。
- DM 正式气泡只来自送达事件或历史查询；支持推送先于 HTTP 响应，按完整 int64 消息 ID 去重、升序展示。空成功响应只表示操作受理／成功。
- HTTP 200 下非零 `err_no` 仍为业务错误；展示原始 `ApiException.message`／`err_msg`，失败保留草稿。区分 Feed 的 `text` 和详情／提交的 `content`。
- 复用现有签名 HTTP client 与 World 的 V2 Socket，不创建手机独立连接、不为手机事件加入地点；手机事件不得进入 LocationChat 时间线或地点队列，不在页面硬编码环境地址。
- 事件按 `event_id` 去重，未读以 HTTP 结果为准，不按事件次数增减；合并刷新保留刷新期间的新事件。手机关闭继续处理世界事件，退出世界释放订阅；初始化、重连及返回前台执行恢复查询。Home 使用世界时间。
- 聊天复用共享锚点列表、滚动协调器、`ChatMessageRow`、`ChatComposer` 和 `ChatKeyboardInsetLayout`，视觉采用 `kPrivateChatStyle`。发送保持键盘、不预留回复空白；阅读历史保留锚点和返回最新入口。
- “正在输入”是本地请求等待提示；同一角色等待期间允许编辑草稿、禁止再次发送，其他角色独立运行；关联 AI 回复或最终失败结束等待。
- Posts 作者筛选先由服务端执行再分页，切换作者重置分页。评论预览使用 Feed 返回值，不逐帖请求详情补齐；回复必须使用 `/comments` 的真实 ID。
- 同帖点赞／取消点赞串行执行；结果不确定时查询详情，再处理最新操作意图。进入 Posts 的全部已读只在本次进入成功加载后执行，停留期间不自动清除新通知。
- 通知逐页替换，不按帖子合并、不制造通知 ID 或正文。Photos 保留网格和共享查看器；发帖只选择服务器图片，正文必填，不添加未确认的字数限制。
- 保持现有样式、导航、启动动画、音乐和壁纸行为；共享聊天修改回归 LocationChat。真实请求错误展示错误／重试，演示数据仅用于明确的无世界预览。
- 当前模型和记忆 Token 选择仅更新本地 `MiniPhoneSession`；选择、折扣展示及采集事件不证明后端设置或计费生效。原生 Dart 保留 int64；JavaScript 目标需先解决无损 JSON ID 传输。

## 验证与维护

- 按改动选择集成文档的验证命令；Dart 修改只格式化涉及文件，静态检查包含实际修改的目录外文件。纯文档修改检查路径、接口表、Markdown 和 `git diff --check`。
- 重点覆盖重复／乱序推送、推送先于 HTTP、首次私聊、历史锚点、同请求重试、账号切换旧响应、快速点赞、通知分页和 Posts 进入已读。
- 受控测试、真实后端及 Android／iOS 真机结果分别报告。键盘、多行、窄屏、大字体、横屏和断线恢复需对应证据，历史通过记录不能代替本次验证。
- 接口或行为改变同步本文件及相关文档；草案扩展、请求终态重放及最终 DTO 等待联调事项保持显式标记。
- 使用普通 Markdown 与目录级指令；长接口表、DTO、测试命令和运行记录留在文档中，不需要 YAML front matter 或自定义加载脚本。遵循 [OpenAI AGENTS.md 指南](https://learn.chatgpt.com/docs/agent-configuration/agents-md)，从工程根目录处理本模块时按入口读取本文件。
