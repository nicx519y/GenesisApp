# 从需求到 UI 校验的工作流

## 状态机

```text
NEW_REQUIREMENT
  -> REQUIREMENT_ACCEPTED
  -> BRANCH_READY
  -> CHECKPOINT_READY
  -> TASKS_READY
  -> ACCEPTANCE_TESTS_READY
  -> PLAN_READY
  -> CODE_READY
  -> MODULE_CASES_UPDATED
  -> STATIC_VERIFIED
  -> MODULE_REGRESSION_VERIFIED
  -> UI_VERIFIED
  -> COMPLETE
```

失败回流：

```text
STATIC_FAILED -> CODE_READY
ACCEPTANCE_FAILED -> CODE_READY
MODULE_REGRESSION_FAILED -> CODE_READY
UI_FAILED -> CODE_READY
ENV_BLOCKED -> WAITING_FOR_ENV
SCOPE_AMBIGUOUS -> REQUIREMENT_ACCEPTED
BRANCH_CONFLICT -> REQUIREMENT_ACCEPTED
CHECKPOINT_STALE -> PLAN_READY
```

## 产物

```text
agent_workflow/requirements/<feature>.md
agent_workflow/tasks/<feature>.md
agent_workflow/acceptance_tests/<feature>.md
agent_workflow/api_contract_cases/<area>.md
agent_workflow/module_cases/<module>/cases.md
agent_workflow/module_cases/<module>/manifest.yaml
agent_workflow/module_cases/module-map.yaml
agent_workflow/plans/<feature>.md
agent_workflow/progress/<feature>/checkpoint.md
agent_workflow/references/<feature>/
agent_workflow/reports/<timestamp>.log
agent_workflow/screenshots/<timestamp>-<name>.png
```

## 分支规则

`req-intake` 初步确认需求类型后，进入实现前创建独立分支：

```text
codex/feature-<short-slug>
codex/fix-<short-slug>
codex/ui-<short-slug>
```

推荐命令：

```bash
bash agent_workflow/scripts/start_feature_branch.sh feature <short-slug>
```

分支创建完成后，再进入任务拆解和验收测试用例生成。

## Checkpoint 规则

长任务必须用 checkpoint 文件保存可恢复上下文：

```text
agent_workflow/progress/<feature>/checkpoint.md
```

初始化：

```bash
bash agent_workflow/scripts/init_checkpoint.sh <feature>
```

更新：

```bash
bash agent_workflow/scripts/update_checkpoint.sh <feature> --stage CODE_READY --done "..." --next "..."
```

查看：

```bash
bash agent_workflow/scripts/show_checkpoint.sh <feature>
```

必须更新 checkpoint 的时机：

- 完成一个阶段后。
- 开始 coding 前。
- 测试失败或遇到 blocker 时。
- 交给另一个 agent 前。
- 上下文可能不足或即将压缩前。
- 最终完成前。

新 agent 接手时，先读 checkpoint，再读其中列出的 requirements、tasks、acceptance_tests、plans、module_cases 和 reports。

## 功能验收测试规则

`task-decomposer` 拆完任务后，`genesis-acceptance-test-writer` 必须在 coding 前生成验收用例：

```text
agent_workflow/acceptance_tests/<feature>.md
```

每条功能验收用例必须包含：

```text
Given 前置条件
When 用户动作或系统事件
Then 预期行为
And 状态/API/存储/日志/视觉证据
```

测试层级选择：

```text
Dart unit test：纯逻辑、parser、session、API 参数组装
Flutter widget test：组件状态、弹窗、输入、路由局部行为
Maestro/integration_test：真实 App 交互链路
API mock/contract test：请求路径、header、body、响应解析、错误码
Flutter golden test：稳定组件视觉回归
截图/视觉对比：样式、布局、文案、截断、设计图还原
```

## API Contract 规则

涉及网络能力时，必须补充 API contract 证据：

```text
agent_workflow/api_contract_cases/<area>.md
```

至少说明：

- 请求路径和方法。
- query/body 参数。
- 默认 header 和身份 header。
- response parser 字段。
- 错误码和异常路径。
- 对应测试文件或 mock transport 验证方式。

## Golden Test 规则

稳定组件建议用 Flutter golden test 锁视觉：

```text
登录弹窗
搜索框
消息空状态
卡片/list item
按钮/输入框等共享组件
```

组件级视觉回归优先 golden test；真实设备或整页视觉再交给 Maestro + screenshot。

## 模块/页面历史用例规则

每个模块或页面维护自己的历史用例：

```text
agent_workflow/module_cases/<module>/cases.md
```

每个模块还应该维护可执行清单：

```text
agent_workflow/module_cases/<module>/manifest.yaml
```

`manifest.yaml` 用来声明：

```text
module 名称
模块专属 flutter test 命令
模块专属 Maestro flow
截图是否必需
```

这些用例跟随模块长期演进，不是单次需求结束后就丢弃的临时文档。

改动影响某个模块时，必须做三件事：

1. 读取该模块现有 `cases.md`。
2. 判断本次改动是否需要新增、删除或更新历史用例。
3. 最终验收时运行该模块历史回归。

推荐命令：

```bash
bash agent_workflow/scripts/run_module_regression.sh <module>
bash agent_workflow/scripts/run_module_regression.sh <module> --ui --install
```

根据 `git diff` 自动识别和回归：

```bash
bash agent_workflow/scripts/list_impacted_modules.sh
bash agent_workflow/scripts/run_impacted_regression.sh
```

如果一个需求影响多个模块，要分别更新和回归这些模块。

## 默认门禁

小型纯代码改动：

```text
flutter analyze
flutter test
```

涉及原生能力、登录或 session 的改动：

```text
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

涉及 UI 行为的改动：

```text
flutter analyze
flutter test
Maestro smoke flow
adb 或 simctl 截图
verifier 视觉复核
```

功能行为改动：

```text
Given / When / Then 验收用例
对应单元/组件/API/交互测试
flutter analyze
flutter test
必要时 Maestro flow
必要时日志或截图证据
```

模块历史回归：

```text
读取 module_cases/<module>/cases.md
读取 module_cases/<module>/manifest.yaml
运行受影响模块对应单元/组件/API/交互测试
必要时运行 manifest.yaml 中声明的 Maestro flow
生成 module regression report
```

产物自检：

```text
validate_workflow_artifacts.sh <feature> --module <module>
检查 requirements/tasks/acceptance_tests/plans/progress/references/module_cases 是否齐全
```

最终报告：

```text
templates/final-report.md
记录需求、分支、改动文件、验收用例、模块历史回归、静态验证、UI 验证、未验证项和风险
```

## UI 校验规则

当需求包含视觉或交互验收时，UI verifier 不能只依赖“脚本通过”。它还需要结合截图证据，对照验收标准做复核。

这些验收点需要视觉证据：

- 文案完全正确。
- 文本必须是 English-only。
- placeholder 保持单行，并且超出时自动截断。
- 登录取消时不提示错误。
- 登录页不能阻塞整个 App。
- 导航返回到预期的 tab 或页面。

参考图推荐命名：

```text
references/<feature>/target-android.png
references/<feature>/target-ios.png
references/<feature>/target-dark.png
references/<feature>/target-small-screen.png
references/<feature>/notes.md
```

## 设备矩阵

```text
默认门禁：Android emulator
补充门禁：iOS simulator
发布前门禁：Android 真机 + iOS 真机
```

## 组件实现规则

设计图里出现组件时，实现前必须先找可复用组件：

```text
查找现有组件
  -> 能复用则优先复用
  -> 能通过参数扩展则小范围扩展
  -> 不能复用时再评估新增组件
```

新增组件前必须说明：

- 为什么现有组件不适合。
- 新组件放在哪个目录。
- 新组件服务单页面还是多页面复用。
- 需要哪些参数。
- 如何测试关键行为和视觉要求。

详细规范见 [implementation-guidelines.md](implementation-guidelines.md)。
