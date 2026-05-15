# Search 模块历史用例

## 模块范围

- Search 页面
- 搜索输入占位文案
- 搜索结果列表

## 历史功能用例

### SEARCH-001 搜索占位文案单行截断

Given 搜索框 placeholder 文案很长
When 页面宽度不足
Then placeholder 保持单行
And 超出部分使用 ellipsis 截断

测试层级：
- Flutter widget test
- 截图/视觉对比

## 历史 UI/视觉用例

- placeholder 不能折行。
- placeholder 必须自动截断。

## 关联命令

```bash
bash agent_workflow/scripts/run_module_regression.sh search
```

