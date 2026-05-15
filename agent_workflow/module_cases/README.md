# 模块/页面历史用例库

这个目录存放每个模块或页面自己的长期回归用例。它不是单次需求产物，而是跟着模块持续迭代的测试资产。

推荐结构：

```text
module_cases/
  me/
    cases.md
    maestro/
      smoke_login_cancel.yaml
  messages/
    cases.md
    maestro/
      smoke_messages_empty.yaml
  search/
    cases.md
```

每个 `cases.md` 建议包含：

- 模块范围
- 历史功能用例
- 历史 UI/视觉用例
- 对应测试文件
- 对应 Maestro flow
- 最近一次更新原因

当某次需求改动影响模块行为时，必须同步更新该模块的 `cases.md`。最后验收时，除了跑新需求自己的 acceptance test，还要跑受影响模块的历史用例。

