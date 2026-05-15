# 从需求到 UI 校验的工作流

## 状态机

```text
NEW_REQUIREMENT
  -> REQUIREMENT_ACCEPTED
  -> BRANCH_READY
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
```

## 产物

```text
agent_workflow/requirements/<feature>.md
agent_workflow/tasks/<feature>.md
agent_workflow/acceptance_tests/<feature>.md
agent_workflow/module_cases/<module>/cases.md
agent_workflow/plans/<feature>.md
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
截图/视觉对比：样式、布局、文案、截断、设计图还原
```

## 模块/页面历史用例规则

每个模块或页面维护自己的历史用例：

```text
agent_workflow/module_cases/<module>/cases.md
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
运行受影响模块对应单元/组件/API/交互测试
必要时运行 module_cases/<module>/maestro/
生成 module regression report
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
