# 多语言检查记录（2026-10-10）

## 结论与范围

九种语言包各有 807 个消息 key。完整目录的 key、必需占位符、空译文、生成加载和复数渲染检查通过。审查了初始化、语言缓存、config/userInfo 优先级、手动保存、请求头、异步响应保护、退出登录和主要页面刷新链路，并修复下列遗漏。译文语义复查重点覆盖语言设置、删除、封锁、购买、订阅、续费、错误提示、动态名称和数量；这不等同于全部译文的母语审校。

接口枚举保持 `en / zh-TW / es / pt / fr / de / it / ja / ko`，ARB 内部繁中标识保持 `zh_TW`。地区风格保持拉美西语、巴西葡语、法国法语。

## 本次修复

1. 无 BuildContext 的文案在首帧绑定前，优先采用已恢复的缓存语言，系统语言采用与 App 相同的解析规则，避免独立回退规则把 zh-Hant 判成英语。
2. 个人资料页不再把内部捕获的 API 错误当作语言刷新成功。
3. Worldo 详情、讨论页、Gems 页按实际加载结果确认语言刷新；请求失败保留过期状态，之后返回页面可再次请求。
4. Location Chat 的模型名称回填在语言刷新失败时向刷新协调器报告失败，保留原有错误处理。
5. 帖子详情接入语言刷新，重新拉取根评论和回复，不重建页面实例或变更会清空回复状态的 session key。
6. Gems 购买提示测试改为检查本地化富文本渲染出的 Text，保留金额、颜色、图标和字号断言。

设置页语言名称此前已修复，并纳入本次九种语言回归。

## 验证

- 核心本地化、初始化、请求头、网络、缓存、用户语言、设置和讨论用例：220 项通过；新增帖子详情刷新用例单独复查通过。
- Gems 页面完整测试：39 项通过，包含新增的语言刷新失败后返回重试用例。
- 相关静态检查和 diff 空白检查通过。
- 曾扩大到 Worldo 页面及上述模块：初次 308 项通过、11 项失败。在 HEAD `88383f96` 的临时基线副本复现同样的 11 项失败。本次修正其中 2 项过时的富文本类型断言。
- 剩余 Worldo 9 项基线失败：7 项源码字符串断言仍依赖旧文案/旧实现；2 项是 opening preview 的位置和 info image DPR/尺寸断言。它们尚未完成独立诊断，不能声称整个相关页面套件全部通过。

执行命令包括 `flutter test test/l10n`、`test/pages/me/settings_page_test.dart`、`test/network/api_client_test.dart`、`test/network/genesis_api_test.dart`、`test/network/user_language_sync_test.dart`、`test/network/app_request_headers_test.dart`、`test/pages/home/home_feed_cache_store_test.dart`、`test/pages/origin/origin_feed_cache_store_test.dart`、`test/app/startup/startup_app_config_test.dart`、`test/components/discuss_page_test.dart`，以及完整 `test/pages/gems/gem_wallet_page_test.dart` 和 `test/pages/origin/origin_world_page_test.dart`。执行了涉及文件的 dart format、flutter analyze 及 git diff --check。

## 尚需验证的边界

- 尚未逐一在真机验证九种语言的全部页面，长文本截断、字体及放大字号需要真机验收。
- 七种新增译文仍需母语审校，特别是产品术语、每日签到表达和复杂动态名称句式。
- iOS 原生权限描述尚无对应 InfoPlist.strings；App 内切换语言不能证明原生权限弹窗已同步翻译。
- 后端返回内容、聊天历史和用户原文的翻译结果由服务端决定；客户端刷新和请求头正确不能证明这些内容均已翻译。

本次未修改 ARB 译文，已有飞书译文和地区风格无需重新回填。后续修订术语或译文应再次同步飞书并逐格比对。
