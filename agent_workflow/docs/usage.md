# Agent 工作流使用说明

## 推荐流程

```text
需求
  -> genesis-req-intake
  -> 创建 git 分支
  -> 初始化 progress checkpoint
  -> genesis-task-decomposer
  -> genesis-acceptance-test-writer
  -> genesis-workflow-planner
  -> genesis-dev-implementer
  -> 更新受影响模块/页面历史用例
  -> 静态验证
  -> 受影响模块历史回归
  -> genesis-ui-regression-verifier
  -> 验证失败时回流给开发 agent
```

这套流程可以用 OMX 或 Codex 原生 subagents 做编排，但真正的验证动作由项目脚本完成。这样从普通终端、Codex App、OMX team 模式都能复现同一套结果。

## Agent 角色

- `genesis-req-intake`：把用户需求整理成可测试的验收标准。
- `genesis-task-decomposer`：把需求拆成可执行任务。
- `genesis-acceptance-test-writer`：在 coding 前生成功能验收测试用例和测试层级建议。
- `genesis-workflow-planner`：决定执行顺序、验证门禁、失败回流规则和完成标准。
- `genesis-dev-implementer`：实现明确范围内的代码改动，并运行代码级验证。
- `genesis-ui-regression-verifier`：运行模拟器或真机校验，并采集截图证据。

## 新需求分支

每次输入一个新需求，建议在 `req-intake` 初步确认需求类型后创建独立分支：

```bash
bash agent_workflow/scripts/start_feature_branch.sh feature login-cancel-silent
bash agent_workflow/scripts/start_feature_branch.sh fix message-empty-state
bash agent_workflow/scripts/start_feature_branch.sh ui me-tab-login-sheet
```

脚本会创建或切换到：

```text
codex/feature-<short-slug>
codex/fix-<short-slug>
codex/ui-<short-slug>
```

不要把多个无关需求混在同一个分支里。

## 长任务 Checkpoint

新需求创建分支后，建议立即初始化 checkpoint：

```bash
bash agent_workflow/scripts/init_checkpoint.sh login-flow
```

长任务过程中用 `update_checkpoint.sh` 持续记录状态：

```bash
bash agent_workflow/scripts/update_checkpoint.sh login-flow \
  --stage CODE_READY \
  --done "完成登录 cancel 实现" \
  --next "运行 Me 模块历史回归"
```

查看当前状态：

```bash
bash agent_workflow/scripts/show_checkpoint.sh login-flow
```

Checkpoint 文件位置：

```text
agent_workflow/progress/<feature>/checkpoint.md
```

必须更新 checkpoint 的时机：

- 完成一个阶段后。
- 开始 coding 前。
- 测试失败或遇到 blocker 时。
- 交给另一个 agent 前。
- 上下文可能不足或即将压缩前。
- 最终完成前。

如果上下文不够或换 agent，新 agent 应先读 checkpoint，再读该文件列出的关键产物。

## 功能验收测试用例

任务拆解完成后、coding 前，需要由 `genesis-acceptance-test-writer` 生成验收测试用例：

```text
agent_workflow/acceptance_tests/<feature>.md
```

验收用例建议使用 Given / When / Then：

```md
## AC-001 Cancel 不提示错误

Given 用户未登录
And 登录弹窗已显示
When 用户点击 Cancel
Then 登录弹窗关闭
And 不出现 "Sign in failed"
And 当前页面仍可继续操作

验证方式：
- widget test: 登录弹窗 cancel 路径
- Maestro: tap Me -> tap Cancel -> assertNotVisible "Sign in failed"
- screenshot: cancel 后页面截图
```

测试层级选择：

```text
纯逻辑 -> Dart unit test
组件状态 -> Flutter widget test
真实交互 -> Maestro / integration_test
网络契约 -> API mock/contract test
视觉样式 -> 截图对比
稳定组件视觉 -> Flutter golden test
```

截图主要验证视觉和布局，不能替代功能测试。

## API Contract 用例

如果功能需求涉及网络请求、header、response parser 或错误码，需要补充 API contract 用例：

```text
agent_workflow/api_contract_cases/<area>.md
```

这些用例用于说明：

- 请求路径和方法。
- query/body 参数。
- 默认 header 和身份 header。
- response 字段和 parser 行为。
- 错误码映射。
- 对应 mock transport 或 API test。

网络功能不能只靠 UI 截图验收，至少需要 unit/API mock/contract 级别证据。

## Golden Test 建议

稳定的共享组件、弹窗、卡片、空状态、列表项，优先补 Flutter golden test：

```text
组件级视觉回归 -> golden test
整页/真机效果 -> Maestro + screenshot
```

Golden test 适合锁住组件视觉；Maestro 截图适合验证真实设备上的整页状态。

## 模块/页面历史用例

每个长期模块或页面应该有自己的历史用例库：

```text
agent_workflow/module_cases/<module>/cases.md
```

例如：

```text
agent_workflow/module_cases/me/cases.md
agent_workflow/module_cases/messages/cases.md
agent_workflow/module_cases/search/cases.md
```

这些文件不是一次性需求文档，而是跟着模块迭代持续维护的回归资产。每次改动影响某个模块时，必须检查并更新对应 `cases.md`：

```text
改 Me tab -> 更新 module_cases/me/cases.md
改 Messages -> 更新 module_cases/messages/cases.md
改 Search -> 更新 module_cases/search/cases.md
```

最后验收时，除了新需求自己的 `acceptance_tests/<feature>.md`，还要跑受影响模块的历史用例：

```bash
bash agent_workflow/scripts/run_module_regression.sh me
bash agent_workflow/scripts/run_module_regression.sh messages
bash agent_workflow/scripts/run_module_regression.sh search
```

每个模块可以通过 `manifest.yaml` 定义可执行清单：

```text
agent_workflow/module_cases/<module>/manifest.yaml
```

它用于声明模块专属 test、Maestro flow 和截图要求。`run_module_regression.sh` 会优先读取 manifest 中的测试；如果没有声明测试，则回退到静态验证。

也可以根据 `git diff` 自动识别受影响模块：

```bash
bash agent_workflow/scripts/list_impacted_modules.sh
bash agent_workflow/scripts/run_impacted_regression.sh
bash agent_workflow/scripts/run_impacted_regression.sh --ui --install
```

如果需要连同 UI flow 一起跑：

```bash
bash agent_workflow/scripts/run_module_regression.sh me --ui --install
```

## UI 参考图输入

如果需求有设计图或参考图，放到：

```text
agent_workflow/references/<feature>/
```

例如：

```text
agent_workflow/references/login-flow/target-01.png
agent_workflow/references/login-flow/notes.md
```

`req-intake` 会从参考图和说明中提取视觉验收标准，`ui-regression-verifier` 会用模拟器/真机截图和参考图做对比。

推荐参考图命名：

```text
target-android.png
target-ios.png
target-dark.png
target-small-screen.png
notes.md
```

Android/iOS、深色模式、小屏样式有差异时，不要混用同一张参考图。

## 实现规范

开发前必须检查是否已有可复用组件。顺序是：

```text
设计图/参考图
  -> 查找现有页面和共享组件
  -> 优先复用已有组件
  -> 找不到可复用组件时，评估是否抽取新组件
  -> 新组件必须有清晰边界和验收方式
```

详细规则见 [implementation-guidelines.md](implementation-guidelines.md)。

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

如果只需要补一张 Android 当前屏幕截图：

```bash
bash agent_workflow/scripts/capture_android.sh smoke-home
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

如果 `flutter test` 出现：

```text
Unable to connect to flutter_tester process: WebSocketException: Invalid WebSocket upgrade request
```

通常是本机代理拦截了 localhost WebSocket。终端需要配置：

```bash
export NO_PROXY="localhost,127.0.0.1,::1,$NO_PROXY"
export no_proxy="localhost,127.0.0.1,::1,$no_proxy"
```

本项目的 workflow 脚本已经在 `scripts/common.sh` 内自动追加这两个变量；普通终端手动执行 Flutter 命令时，也需要确保这两个变量存在。

## 产物自检

进入 coding 前或最终验收前，运行：

```bash
bash agent_workflow/scripts/validate_workflow_artifacts.sh login-flow --module me
```

它会检查：

- `requirements/<feature>.md`
- `tasks/<feature>.md`
- `acceptance_tests/<feature>.md`
- `plans/<feature>.md`
- `progress/<feature>/checkpoint.md`
- `references/<feature>/`
- `module_cases/<module>/cases.md`
- `module_cases/<module>/manifest.yaml`

最终完成后建议按 [templates/final-report.md](../templates/final-report.md) 生成报告，记录需求、分支、改动文件、验收用例、模块历史回归、静态验证、UI 证据和未验证风险。

## 设备矩阵

默认验证顺序：

```text
默认门禁：Android emulator
补充门禁：iOS simulator
发布前门禁：Android 真机 + iOS 真机
```

日常 agent 自动化优先使用模拟器。真机验证适合作为发布前门禁，因为账号、证书、网络、锁屏和系统弹窗都可能影响稳定性。

## OMX 用法

把 OMX 当作编排层，而不是模拟器执行逻辑所在的地方。

建议交接方式：

```text
1. req-intake 写出验收标准。
2. 创建 `codex/<kind>-<short-slug>` 分支。
3. 初始化 `progress/<feature>/checkpoint.md`。
4. task-decomposer 写出任务卡片。
5. acceptance-test-writer 写出功能验收测试用例。
6. workflow-planner 选择 solo、native-subagent 或 OMX-team 执行方式。
7. dev-implementer 修改代码，并同步更新受影响模块/页面历史用例。
8. 每个阶段切换或失败时更新 checkpoint。
9. 运行静态验证和受影响模块历史回归。
10. ui-regression-verifier 运行 agent_workflow/scripts/* 并采集证据。
11. UI 或功能门禁失败时，带着失败标准、日志和截图路径回流给 dev-implementer。
```

在 Codex App 且不在 tmux 内时，OMX team/hud/question 这类 runtime surface 可能没有挂载。这种情况下，用 Codex 原生 subagents 做角色拆分，并继续使用同一套脚本做验证。

## 完成规则

一个任务只有在满足这些条件后才能算完成：

- 需求验收标准已经映射到任务。
- 功能验收测试用例已经生成，并映射到验证命令或手动证据。
- 受影响模块/页面的历史用例已经检查、必要时更新，并完成回归。
- checkpoint 已更新到最终状态，能支持后续 agent 恢复上下文。
- 代码改动有新鲜的静态验证证据。
- UI 改动在需要时有模拟器或真机证据。
- 失败项要么已经修复，要么明确记录为 blocker。
- 最终报告里写清楚日志和截图路径。
