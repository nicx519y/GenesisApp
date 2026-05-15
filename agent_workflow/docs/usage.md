# Agent 工作流使用说明

## 推荐流程

```text
需求
  -> genesis-req-intake
  -> genesis-task-decomposer
  -> genesis-workflow-planner
  -> genesis-dev-implementer
  -> 静态验证
  -> genesis-ui-regression-verifier
  -> 验证失败时回流给开发 agent
```

这套流程可以用 OMX 或 Codex 原生 subagents 做编排，但真正的验证动作由项目脚本完成。这样从普通终端、Codex App、OMX team 模式都能复现同一套结果。

## Agent 角色

- `genesis-req-intake`：把用户需求整理成可测试的验收标准。
- `genesis-task-decomposer`：把需求拆成可执行任务。
- `genesis-workflow-planner`：决定执行顺序、验证门禁、失败回流规则和完成标准。
- `genesis-dev-implementer`：实现明确范围内的代码改动，并运行代码级验证。
- `genesis-ui-regression-verifier`：运行模拟器或真机校验，并采集截图证据。

## 安装 Agent 定义

Agent 定义放在 `agent_workflow/agents/`。如果要安装到本项目的本地 Codex agent 目录，执行：

```bash
bash agent_workflow/scripts/install_agents.sh
```

这个脚本会把定义复制到项目根目录的 `.codex/agents/`。如果你的启动器可以直接读取其他路径，则以 `agent_workflow/agents/` 里的文件作为主版本即可。

## 静态验证

执行：

```bash
bash agent_workflow/scripts/run_static_verify.sh
```

默认门禁：

- `flutter analyze`
- `flutter test`

可选原生构建门禁：

```bash
bash agent_workflow/scripts/run_static_verify.sh --build-apk
bash agent_workflow/scripts/run_static_verify.sh --build-ios
bash agent_workflow/scripts/run_static_verify.sh --build-apk --build-ios
```

报告会写入 `agent_workflow/reports/static-verify-*.log`。

## UI 校验

### Android 模拟器或真机

先启动模拟器或连接真机，然后执行：

```bash
bash agent_workflow/scripts/run_ui_smoke.sh --platform android --install
```

这个命令会做这些事：

1. 传入 `--install` 时构建 debug APK。
2. 使用 `adb install -r` 安装 APK。
3. 运行 `agent_workflow/maestro/android/` 下的 Maestro 流程。
4. 截图并保存到 `agent_workflow/screenshots/`。
5. 将日志写入 `agent_workflow/reports/`。

如果 App 已经安装，只想直接跑 UI flow：

```bash
bash agent_workflow/scripts/run_ui_smoke.sh --platform android
```

### iOS 模拟器

第一版 iOS 支持截图；如果后续在 `agent_workflow/maestro/ios/` 下添加 Maestro flow，也可以运行 iOS UI flow。

先启动 iOS 模拟器，然后执行：

```bash
bash agent_workflow/scripts/capture_ios.sh smoke-home
```

如果已经添加 iOS Maestro flow：

```bash
bash agent_workflow/scripts/run_ui_smoke.sh --platform ios
```

## 环境检查

开始自动化工作流前先执行：

```bash
bash agent_workflow/scripts/check_env.sh
```

它会检查：

- Flutter SDK
- Dart
- Android SDK/adb
- Java 17+ runtime
- Xcode tools/simctl
- Maestro
- Flutter app 根目录

缺少 Maestro 不会影响静态验证，但会阻塞自动 UI smoke 流程。

## OMX 用法

把 OMX 当作编排层，而不是模拟器执行逻辑所在的地方。

建议交接方式：

```text
1. req-intake 写出验收标准。
2. task-decomposer 写出任务卡片。
3. workflow-planner 选择 solo、native-subagent 或 OMX-team 执行方式。
4. dev-implementer 修改代码并运行静态验证。
5. ui-regression-verifier 运行 agent_workflow/scripts/* 并采集证据。
6. UI 门禁失败时，带着失败标准和截图路径回流给 dev-implementer。
```

在 Codex App 且不在 tmux 内时，OMX team/hud/question 这类 runtime surface 可能没有挂载。这种情况下，用 Codex 原生 subagents 做角色拆分，并继续使用同一套脚本做验证。

## 完成规则

一个任务只有在满足这些条件后才能算完成：

- 需求验收标准已经映射到任务。
- 代码改动有新鲜的静态验证证据。
- UI 改动在需要时有模拟器或真机证据。
- 失败项要么已经修复，要么明确记录为 blocker。
- 最终报告里写清楚日志和截图路径。
