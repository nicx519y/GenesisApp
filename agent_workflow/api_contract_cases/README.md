# API Contract 用例

这个目录存放客户端网络契约用例。它用于补足 UI 自动化测不到的功能行为。

适合放在这里的内容：

- 请求路径。
- query/body 参数。
- 默认 header 和身份 header。
- response parser 字段。
- 错误码和异常映射。
- mock transport / local backend 行为。

推荐结构：

```text
api_contract_cases/
  auth.md
  messages.md
  search.md
  profile.md
```

每个文件建议包含：

```text
接口/功能名
Given / When / Then
请求路径和方法
请求 header/body
响应字段
解析断言
错误路径
对应测试文件
```

功能需求如果涉及网络，不允许只用 UI 截图或页面状态作为完成证据，必须补充 API contract 或 mock transport 级别验证。

