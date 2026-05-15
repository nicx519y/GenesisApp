# GenesisApp Agent 工作流

这个目录是一套项目内的 agent 工作流，用来把需求转成代码改动，并完成模拟器或真机 UI 校验。

这套工作流刻意拆成两层：

- Agent 角色和流程文档负责决定下一步做什么。
- Shell 脚本负责真正执行验证：Flutter 检查、构建、Maestro 流程和截图。

这样不管是在 Codex App、OMX team 模式，还是普通终端里，都能复用同一套验证入口。

## 目录结构

```text
agent_workflow/
  agents/                  # 项目内 agent 角色定义
  acceptance_tests/        # 功能验收测试用例
  docs/                    # 使用说明和流程文档
  maestro/                 # UI smoke 流程
  module_cases/            # 模块/页面历史回归用例
  references/              # UI 参考图、设计图、需求输入图
  scripts/                 # 可执行验证脚本
  reports/                 # 生成的报告
  screenshots/             # 生成的截图
```

## 快速开始

在项目根目录执行：

```bash
bash agent_workflow/scripts/check_env.sh
bash agent_workflow/scripts/start_feature_branch.sh feature <short-slug>
bash agent_workflow/scripts/run_static_verify.sh
bash agent_workflow/scripts/run_module_regression.sh <module>
```

## 完整工作流

```text
需求输入
  -> genesis-req-intake 整理验收标准和受影响模块/页面
  -> 创建 codex/<kind>-<short-slug> git 分支
  -> genesis-task-decomposer 拆任务
  -> genesis-acceptance-test-writer 生成功能验收测试用例
  -> genesis-workflow-planner 形成执行计划
  -> genesis-dev-implementer 实现，并更新受影响模块/页面历史用例
  -> 静态验证
  -> 受影响模块历史回归
  -> genesis-ui-regression-verifier 做模拟器/真机 UI 校验
  -> 失败时回流给 dev-implementer 修复
```

## 关键产物

```text
agent_workflow/requirements/<feature>.md             # 单次需求验收标准
agent_workflow/tasks/<feature>.md                    # 单次需求任务拆解
agent_workflow/acceptance_tests/<feature>.md         # 单次需求功能验收测试
agent_workflow/plans/<feature>.md                    # 单次需求执行计划
agent_workflow/references/<feature>/                 # UI 参考图/设计图
agent_workflow/module_cases/<module>/cases.md        # 模块/页面长期历史用例
agent_workflow/reports/                              # 验证报告
agent_workflow/screenshots/                          # 截图证据
```

## 模块/页面历史用例

每个长期模块或页面都应该维护自己的历史用例，例如：

```text
agent_workflow/module_cases/me/cases.md
agent_workflow/module_cases/messages/cases.md
agent_workflow/module_cases/search/cases.md
```

这些用例会跟着模块持续迭代。每次改动影响某个模块时，都要检查并更新对应 `cases.md`，最后跑该模块历史回归：

```bash
bash agent_workflow/scripts/run_module_regression.sh me
bash agent_workflow/scripts/run_module_regression.sh messages
bash agent_workflow/scripts/run_module_regression.sh search
```

如果改动包含用户可见 UI 或真实交互链路：

```bash
bash agent_workflow/scripts/run_module_regression.sh me --ui --install
```

## 功能测试和 UI 测试的分工

```text
功能需求 -> Given / When / Then -> unit/widget/API/Maestro 测试
样式需求 -> UI 参考图 -> 模拟器/真机截图 -> 视觉对比
历史风险 -> module_cases/<module>/cases.md -> 模块历史回归
```

截图只用于验证视觉和布局，不能替代功能测试。功能需求必须有行为、状态、存储、API、日志或自动交互证据。

如果要跑 Android 模拟器或真机 UI smoke 校验，先启动模拟器或连接真机，然后执行：

```bash
bash agent_workflow/scripts/run_ui_smoke.sh --platform android --install
```

如果要截取 iOS 模拟器截图，先启动 iOS 模拟器，然后执行：

```bash
bash agent_workflow/scripts/capture_ios.sh smoke-home
```

完整用法见 [docs/usage.md](docs/usage.md)，实现规范见 [docs/implementation-guidelines.md](docs/implementation-guidelines.md)。

更多文档：

- [docs/usage.md](docs/usage.md)：日常使用说明。
- [docs/workflow.md](docs/workflow.md)：状态机、产物和门禁。
- [docs/implementation-guidelines.md](docs/implementation-guidelines.md)：组件复用、新组件生成和模块用例维护规范。
- [module_cases/README.md](module_cases/README.md)：模块/页面历史用例库说明。
