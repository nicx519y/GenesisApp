# Messages 模块历史用例

## 模块范围

- Messages tab
- 消息分类入口
- 空状态
- 聊天入口导航

## 历史功能用例

### MSG-001 无私信时展示空状态

Given 用户没有 private messages
When 用户进入 Messages 页面
Then 页面展示 `no private messages yet.`

测试层级：
- Flutter widget test
- Maestro flow

## 历史 UI/视觉用例

- 空状态文案必须保持 `no private messages yet.`。
- Messages tab 导航状态必须正确。

## 关联命令

```bash
bash agent_workflow/scripts/run_module_regression.sh messages
```

