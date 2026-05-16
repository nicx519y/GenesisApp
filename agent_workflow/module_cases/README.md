# 模块/页面历史用例库

这个目录存放每个模块或页面自己的长期回归用例。它不是单次需求产物，而是跟着模块持续迭代的测试资产。

推荐结构：

```text
module_cases/
  module-map.yaml
  me/
    cases.md
    manifest.yaml
  messages/
    cases.md
    manifest.yaml
  search/
    cases.md
    manifest.yaml
```

`module-map.yaml` 用来把代码路径映射到模块。最终验收可以用它从 git diff 自动推导受影响模块：

```bash
bash agent_workflow/scripts/list_impacted_modules.sh
bash agent_workflow/scripts/run_impacted_regression.sh
bash agent_workflow/scripts/run_impacted_regression.sh --ui --install
```

每个模块目录至少包含两个文件。

## cases.md

`cases.md` 是长期维护的人工可读用例库，建议包含：

- 模块范围
- 历史功能用例
- 历史 UI/视觉用例
- 对应测试文件
- 对应 Maestro flow
- 最近一次更新原因

## manifest.yaml

`manifest.yaml` 是可执行回归清单，供脚本读取：

```yaml
module: me
description: Me tab, login entry, login sheet, session-facing states.
required:
  static: true
  ui: false
tests:
  - flutter test test/me/me_page_test.dart
maestro:
  android:
    - agent_workflow/maestro/android/smoke_login_cancel.yaml
screenshots:
  required: true
```

约定：

- `tests` 写模块专属 Dart/Flutter 测试命令。
- `maestro.android` 写 Android 模拟器或真机上的 Maestro flow。
- `screenshots.required` 表示最终报告需要附截图证据。
- 如果模块暂时没有专属测试，保留 `tests: []`，脚本会回退到静态验证。

当某次需求改动影响模块行为时，必须同步更新该模块的 `cases.md` 和 `manifest.yaml`。最后验收时，除了跑新需求自己的 acceptance test，还要跑受影响模块的历史用例。
