# 从需求到 UI 校验的工作流

## 状态机

```text
NEW_REQUIREMENT
  -> REQUIREMENT_ACCEPTED
  -> TASKS_READY
  -> PLAN_READY
  -> CODE_READY
  -> STATIC_VERIFIED
  -> UI_VERIFIED
  -> COMPLETE
```

失败回流：

```text
STATIC_FAILED -> CODE_READY
UI_FAILED -> CODE_READY
ENV_BLOCKED -> WAITING_FOR_ENV
SCOPE_AMBIGUOUS -> REQUIREMENT_ACCEPTED
```

## 产物

```text
agent_workflow/requirements/<feature>.md
agent_workflow/tasks/<feature>.md
agent_workflow/plans/<feature>.md
agent_workflow/reports/<timestamp>.log
agent_workflow/screenshots/<timestamp>-<name>.png
```

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

## UI 校验规则

当需求包含视觉或交互验收时，UI verifier 不能只依赖“脚本通过”。它还需要结合截图证据，对照验收标准做复核。

这些验收点需要视觉证据：

- 文案完全正确。
- 文本必须是 English-only。
- placeholder 保持单行，并且超出时自动截断。
- 登录取消时不提示错误。
- 登录页不能阻塞整个 App。
- 导航返回到预期的 tab 或页面。
