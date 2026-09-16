# 启动流程复查（2026-09-16）

范围：当前未提交的后台 config 改动、iOS 首次联网/ATT、启动打点和首屏。依据正式代码、当前看板解析代码及本地回归测试；未重装真实 iPhone 验证系统权限弹窗。

## 当前执行顺序

```text
点击 App
→ 原生启动页、引擎、插件与通信通道初始化
→ main：开始 Dart 启动计时，初始化 Flutter Binding
→ 并行读取本地域名配置、系统 UI、地图和 Debug 设置；设置竖屏不等待
→ 等待本地域名配置（最多 2 秒）
→ iOS：HEAD 联网探测，等待系统网络权限处理和回到前台
  · 收到响应且处于前台后继续
  · inactive/后台期间暂停等待预算
  · 拒绝或断网：前台等待最多 8 秒后继续离线启动
  · Android 跳过这一步
→ 创建服务，并行启动：
  ├─ Collect 准备 → Firebase 运行时配置
  ├─ 一次共享 UID 读取（最多 2 秒）→ Home/Worldo 本地缓存判定
  ├─ 后台 config：等 Collect（最多 2 秒）和共享 UID
  │  → Gateway 注册（缺密钥时）/校时 → config → 发布配置、采样率
  └─ 图片连接预热、支付监听
→ 等本地设置与落地页判定完成 → runApp（不等后台 config）
→ 首帧：记录 launch_page，启动后台运行时、支付恢复、消息轮询
→ 付费游客强制登录检查（不受填表配置开关限制）
→ 独立 ATT：首帧后 2 秒，前台且尚未决定授权时请求
→ config 确认填表开关为 true，且必须的游客登录完成后，继续填表流程
```

本次移除的是网关/config 对 `runApp` 的等待，iOS 首次联网探测仍在首帧前。无本地缓存、无已保存筛选值时，Worldo 内容刷新仍等配置/个人信息确定性别；出现页面不等于列表已加载完成。

## 已确认与修正

- config 可以在 ATT 前或后返回；非前台时不会立刻弹出填表，恢复前台后继续。首次 config 失败保持默认关闭。
- 复查用例复现了 ATT 原有竞态：查询授权状态期间 App 变成非前台，旧代码仍发起请求并消耗进程内请求标记。已在异步查询后重新检查前台/组件存活状态，将标记移至真正请求之前，并避免重复并发查询。
- 补齐 ATT 已发起后退后台的恢复：原生调用前再检查 active；回调为 `notDetermined` / `unknown` 或调用异常时释放请求标记，恢复前台后重新读取系统状态。若已先恢复前台，则等原回调结束再检查，不重叠请求；没有新的前台恢复事件时不循环重试。系统状态已为允许、拒绝或受限制时停止请求。
- config 后台请求保持已有网关签名顺序；首屏业务请求共用网关准备任务。HTTP 层仍有 15 秒请求总预算，移除了原先外层 3 秒启动等待。
- `launch_page`、`launch_req_*`、`launch_render` 早于 Collect 就绪时暂存，保留发生时的 `object3` 耗时和字段。就绪后先记启动哨兵，再依序入队；重复首帧/渲染通知仍去重。
- config/telemetry 晚于首帧时，不伪造它们的完成时间；首帧快照可以缺少这两个里程碑。看板 `startup.go` 的阶段解析只依赖本地准备、bootstrap 和 `launch_page.object3`，不要求这两个字段齐全。
- iOS 前后台统计来自 `sceneDidEnterBackground` / `sceneDidBecomeActive` 配对；单纯 inactive 的系统弹窗不等于一次退后台/重新启动。

## 原有边界与后续事项

**并行化相关的待处理项：Opening Sheet 早点击。** `lib/routers/app_router.dart:539` 在创建 Worldo 详情时只读取一次 `appGlobalConfig.value.showOpeningSheet`。当 config 仍在请求、用户先点击缓存卡片时，详情会按默认 false 进入；稍后的 true 不会触发该路由重建。这会改变慢配置下的首进展开行为，尚未修复。建议只让依赖此开关的详情入口等待配置结果，不恢复全局 `runApp` 等待，也不在用户已操作详情后突然展开 Sheet。

其余为原有边界：

1. **Debug 包仍有无超时的本地读取**：抓包、Worldo Sheet 和新内容 Debug 设置在 `main` 中被等待。若 SharedPreferences 一直不返回，仍可能挡住首帧；Release 不等待这些 Debug 项。
2. **首次联网授权与统计边界**：Dart 启动计时包含授权等待时间，但 Collect 在联网探测后才准备。如果用户在联网授权阶段杀进程，自定义 `launch_*` 链路可能没有样本。此行为早于本次改动。
3. **config 失败不自动随前台恢复重试**：这次失败不会再卡闪屏，但本进程填表开关可能保持默认关闭；目前没有新增自动重试策略。
4. **看板说明文字待同步**：`startup.go` 中“本地准备完成 → 启动依赖就绪”的描述仍写等待 App 配置链结束。数值解析兼容新流程，本次未修改看板仓库。

## 验证

已执行：

```sh
flutter test --no-pub test/app/startup test/app/config/app_global_config_test.dart test/components/personalization_gate_test.dart test/network/gateway_auth_test.dart test/app/telemetry/genesis_telemetry_test.dart test/platform/privacy/app_tracking_transparency_service_test.dart --reporter expanded
flutter test --no-pub test/widget_test.dart --plain-name 'AppShell iOS' --reporter expanded
flutter analyze --no-pub lib/main.dart lib/app/config/app_global_config.dart lib/app/startup lib/pages/app_shell_page.dart test/app/startup test/widget_test.dart
```

两组测试共 120 项通过；代码已格式化，本次实际修改文件的静态检查无问题。扩大静态检查到整个 startup 测试目录时，`startup_uid_resolution_test.dart` 有两条原有的相对导入风格提示；该文件未改动。iOS 系统权限弹窗的真实首次安装表现仍需真机验证，单元/组件测试不能替代这一步。

补充 ATT 请求发出后退后台的回归：修复前，未决结果在恢复前台之前／之后返回的 4 个用例失败；修复后全部通过。新增用例覆盖不重复并发请求、不循环重试，以及系统已允许／拒绝／限制时停止请求。以下测试共 33 项通过；Swift 仅验证语法，未执行 iOS 整包构建及真机权限测试。

```sh
flutter test --no-pub test/widget_test.dart --plain-name 'AppShell iOS' --reporter expanded
flutter test --no-pub test/app/startup/app_startup_coordinator_test.dart test/platform/privacy/app_tracking_transparency_service_test.dart --reporter expanded
flutter analyze --no-pub lib/pages/app_shell_page.dart lib/app/startup/app_startup_coordinator.dart test/widget_test.dart
xcrun swiftc -frontend -parse ios/Runner/AppDelegate.swift
```
