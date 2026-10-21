# MiniPhone

MiniPhone 是 World 持有的手机会话。正式页面使用 `GenesisApi.miniPhone` 和既有 World Socket；关闭手机保留世界会话，退出世界释放订阅与路由，暂停并保存音乐进度；正式播放器由 AppServices 常驻持有，供下一个 World 复用，账号或环境切换时释放。2026-10-22 已移除 Developer 预览、演示数据及配套图片；正式页面仅展示真实手机数据。默认壁纸为保持原尺寸、WebP 质量 85 的 `assets/mini_phone/wallpaper-01.webp`。

## 调用入口

模块外只导入 `mini_phone.dart`：

- `showMiniPhone`：World / LocationChat 打开手机。
- `MiniPhoneSession` / `MiniPhoneSessionScope`：World 会话所有权与作用域。
- `MiniPhoneEntry` / `MiniPhoneEdgeDock`：手机入口与可拖动 Dock。
- 两个入口组件均接受 `style: MiniPhoneEntryStyle.arcaneGrimoire`；省略时根据 World Detail 的 `map_style.era` 自动选择，缺失或未知时回退 `classicHandset`。两套都使用交付 SVG，由同一 `MiniPhoneEntryArtwork` 渲染、同一 `EntryMotion` 播放关键帧；`mini_phone_entry_style.dart` 仅配置资源、坐标与动效。状态、点击、音乐控制、拖动及会话保持共用。动态时间、未读数字和头像绑定运行数据；资源授权位于 `assets/mini_phone/entry-icons-LICENSES.txt`。
- `MiniPhoneScreen`、`MiniPhonePage`：指定初始页面及页面装配。

Dock 位置保留旧的本地存储键，避免整理命名后丢失已有位置。路由名为 `mini-phone`。

## 目录职责

| 目录 / 文件 | 职责 |
| --- | --- |
| `mini_phone.dart` | 显式导出正式业务 API，不导出业务控制器 |
| `mini_phone_page.dart` | 手机外壳、内部 Navigator、页面组合与可见页面错误反馈 |
| `session/` | World 会话、服务装配、路由释放、恢复状态及页面枚举 |
| `state/mini_phone_store.dart` | 兼容业务入口、账号初始化、聚合校准、事件分发、写请求日志与恢复调度 |
| `state/mini_phone_requests.dart` | 各功能共用的账号代次、请求版本、进行中请求合并、分页及错误状态 |
| `state/mini_phone_write.dart` | 待确认写请求的数据模型与序列化 |
| `entry/` | 手机入口、Dock、设备本地位置持久化 |
| `home/` | 桌面、世界时钟、通知卡片、展开布局与 Home 自身滚动状态 |
| `messages/` | 会话列表、私聊 UI、消息投影、历史分页、回复状态及持久化已读 |
| `posts/` | `mini_phone_posts_page.dart` 仅装配；Feed、评论、创建使用独立页面，共用帖子内容组件；作者栏按需构建，草稿继续归 Session |
| `photos/` | 相册页面、请求控制器、按相册/封面变化缓存的展示投影和缩略图策略 |
| `music/` | 音乐页面、Home 卡片、播放器、点赞、播放进度及公共音乐组件 |
| `settings/` | 设置页、AI 模型设置页面与会话内模型设置控制器 |
| `settings/wallpaper/` | 壁纸加载、编辑、保存、缓存与展示 |
| `shared/` | 模块内视觉组件、Panel；列表请求辅助只依赖请求状态及调用方回调，不导入 Store |

HTTP、DTO 和 SQLite 继续位于 `lib/network/mini_phone/`；通用聊天组件、图片查看器和 `lib/ui/animations/app_launch_transition/` 保留公共模块归属。

## 依赖与状态边界

- 正式页面是独立 Widget，不读取手机外壳的私有 State。表单、滚动与回复选择归对应页面；正在发送的帖子草稿归 World Session。
- Session 不导入页面、Dock 或 Home。基础 UI 不反向依赖 Session、入口或手机外壳。
- Messages / Posts / Photos 控制器通过同一个 `MiniPhoneRequests` 做账号隔离与请求去重，不依赖 `MiniPhoneStore` 或具体页面。
- `MiniPhoneStore` 保留既有业务方法，统一处理写请求身份、事件、生命周期及恢复顺序。重构不改变接口、数据库、缓存键、请求退避和已读语义。
- 普通内容变化由页面自身监听；外壳只因导航、身份变化和自身生命周期更新，不因每次列表数据变动重建整套 Navigator。
- 模型目录查询带 `biz=phone_dm`；模型选择与记忆长度复用 LocationChat 的公共页面和相同提交参数，不给提交接口传 `biz`。报价直接来自手机业务目录，实际用量与预算范围来自 memory-settings 接口；真实后端及计费仍需联调验收。

## 验证与文档

从 `genesis_app/` 执行：

```sh
flutter test --no-pub test/network/mini_phone test/pages/mini_phone
flutter analyze --no-pub lib/pages/mini_phone lib/network/mini_phone
```

结构约束由 `test/pages/mini_phone/mini_phone_module_boundary_test.dart` 检查；跨模块变动还需检查实际调用方。

- [模块指引](AGENTS.md)
- [当前接口契约](../../../docs/mini-phone-chat-client-api-2026-10-12.md)
- [集成与验收边界](../../../docs/mini-phone-client-integration.md)
- [历史开发记录](../../../docs/history/mini-phone-development-notes.md)

受控测试、真实后端联调、Android / iOS 真机验收分别记录；历史验证结果不能替代本次验收。
