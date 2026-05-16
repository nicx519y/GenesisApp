# UI 共享组件历史用例

## 模块范围

- `genesis_app/lib/ui/`
- `genesis_app/lib/components/`
- 共享主题、token、基础组件

## 历史功能用例

### UI-001 共享 UI 组件测试通过

Given 共享 UI 组件发生改动
When 运行 UI 模块回归
Then `test/ui/genesis_ui_test.dart` 通过

测试层级：
- Flutter widget test
- Golden test，适合稳定视觉组件

## 历史 UI/视觉用例

- 共享组件必须使用现有 theme/token。
- 不引入孤立的一次性颜色和字号体系。

## 关联命令

```bash
bash agent_workflow/scripts/run_module_regression.sh ui
```

