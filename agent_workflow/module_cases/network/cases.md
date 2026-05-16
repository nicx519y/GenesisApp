# Network 模块历史用例

## 模块范围

- API client
- 请求 header 注入
- transport 行为
- response parser / mock transport

## 历史功能用例

### NET-001 默认 header 和身份 header 正确合并

Given App 发起 API 请求
When 存在 device/session/auth 信息
Then 请求 header 包含默认 header 和运行时身份 header

测试层级：
- Dart unit test
- API contract/mock transport test

## 关联命令

```bash
bash agent_workflow/scripts/run_module_regression.sh network
```

