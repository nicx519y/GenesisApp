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
  docs/                    # 使用说明和流程文档
  maestro/                 # UI smoke 流程
  scripts/                 # 可执行验证脚本
  reports/                 # 生成的报告
  screenshots/             # 生成的截图
```

## 快速开始

在项目根目录执行：

```bash
bash agent_workflow/scripts/check_env.sh
bash agent_workflow/scripts/run_static_verify.sh
```

如果要跑 Android 模拟器或真机 UI smoke 校验，先启动模拟器或连接真机，然后执行：

```bash
bash agent_workflow/scripts/run_ui_smoke.sh --platform android --install
```

如果要截取 iOS 模拟器截图，先启动 iOS 模拟器，然后执行：

```bash
bash agent_workflow/scripts/capture_ios.sh smoke-home
```

完整用法见 [docs/usage.md](docs/usage.md)。
