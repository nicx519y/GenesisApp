# 实现规范

## 设计图和组件复用

客户端需求如果包含设计图或截图，进入开发前必须先做组件复用判断。

推荐顺序：

```text
设计图/参考图
  -> 查找现有页面和共享组件
  -> 优先复用已有组件
  -> 找不到可复用组件时，评估是否抽取新组件
  -> 新组件必须有清晰边界和验收方式
```

## 组件复用规则

优先复用：

- `genesis_app/lib/` 下已有页面中的局部组件。
- `genesis_app/lib/widgets/`、`genesis_app/lib/components/`、`genesis_app/lib/pages/**/widgets/` 这类共享或页面内组件目录。
- 已有主题、颜色、字体、间距、按钮、输入框、弹窗、tab、列表项等样式约定。

在创建新组件前，必须回答：

- 是否已有组件能满足 80% 以上需求？
- 差异是内容/参数差异，还是结构差异？
- 通过传参、slot、builder 或小范围扩展是否能复用？
- 新组件会被多个页面复用，还是只是单页面局部结构？
- 新组件是否会让调用方更简单，而不是制造额外抽象？

## 新组件生成规则

只有满足下面任一条件时，才建议新增组件：

- 现有组件语义不匹配，强行复用会破坏原组件职责。
- 同一 UI 模式会在多个页面复用。
- 单个页面内重复结构明显，抽取后能降低复杂度。
- 设计图里的组件是稳定产品模式，例如统一卡片、统一列表项、统一操作栏。

新增组件时必须：

- 放在符合现有目录习惯的位置。
- 命名表达业务语义或 UI 语义，不使用泛泛的 `CommonBox`、`NiceCard`。
- 参数保持少而清晰。
- 使用项目现有主题和样式来源。
- 增加必要 widget test 或至少在验收用例里覆盖关键行为。

## 禁止事项

- 不为了单次样式差异创建大型通用组件。
- 不复制粘贴一份已有组件再改少量样式。
- 不绕开现有主题系统硬编码一套新的颜色/字号体系。
- 不用截图通过替代功能测试。

## Golden Test

稳定的组件级视觉应该优先使用 Flutter golden test：

```text
登录弹窗
搜索框
消息空状态
卡片/list item
按钮/输入框等共享组件
```

使用原则：

- 组件级视觉回归用 golden test。
- 整页真实设备状态用 Maestro + screenshot。
- Golden test 不替代交互、状态、API 行为测试。

## API Contract

涉及网络行为的改动，必须检查或补充：

```text
agent_workflow/api_contract_cases/<area>.md
```

需要覆盖：

- 请求路径和方法。
- query/body 参数。
- 默认 header 和身份 header。
- response parser 字段。
- 错误码和异常路径。
- mock transport / API test 文件。

## 模块用例维护

实现任何模块或页面改动时，都要检查对应历史用例：

```text
agent_workflow/module_cases/<module>/cases.md
```

需要更新的情况：

- 新增功能行为。
- 修改已有交互路径。
- 修改文案、空状态、错误提示或登录拦截策略。
- 修改 API 请求、状态缓存、session 行为。
- 修改页面导航、返回语义或 tab 状态。
- 修复了历史 bug，需要把 bug 场景固化成回归用例。

实现完成后，必须运行受影响模块历史回归：

```bash
bash agent_workflow/scripts/run_module_regression.sh <module>
```

如果改动包含用户可见 UI 或交互链路，追加：

```bash
bash agent_workflow/scripts/run_module_regression.sh <module> --ui --install
```

如果不确定影响了哪些模块，先运行：

```bash
bash agent_workflow/scripts/list_impacted_modules.sh
```

然后运行：

```bash
bash agent_workflow/scripts/run_impacted_regression.sh
```

模块的可执行回归清单写在：

```text
agent_workflow/module_cases/<module>/manifest.yaml
```

新增或修改模块测试时，也要同步更新 manifest。

## 长任务上下文维护

如果一个任务会持续很久，开发实现过程中必须维护 checkpoint：

```text
agent_workflow/progress/<feature>/checkpoint.md
```

推荐节奏：

```text
开始任务 -> init_checkpoint
阶段完成 -> update_checkpoint --stage ... --done ...
遇到失败 -> update_checkpoint --blocker ... --next ...
交接前 -> update_checkpoint --handoff ...
完成前 -> update_checkpoint --stage COMPLETE --evidence ...
```

不要只把关键状态写在聊天里。能恢复任务的最小上下文必须落到 checkpoint 和对应产物文件里。
