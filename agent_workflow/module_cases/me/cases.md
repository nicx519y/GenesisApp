# Me 模块历史用例

## 模块范围

- Me tab
- 登录入口
- 登录弹窗
- 登录取消路径
- logout 入口和本地 session 展示

## 历史功能用例

### ME-001 未登录点击 Me 显示登录入口或登录弹窗

Given 用户未登录
When 用户进入 Me tab
Then 用户可以看到登录入口或登录弹窗

测试层级：
- Flutter widget test
- Maestro flow

### ME-002 登录 Cancel 不提示错误

Given 用户未登录
And 登录弹窗已显示
When 用户点击 Cancel
Then 登录弹窗关闭
And 不出现错误 toast/snackbar
And App 仍可继续操作

测试层级：
- Flutter widget test
- Maestro flow: `agent_workflow/maestro/android/smoke_login_cancel.yaml`

## 历史 UI/视觉用例

- 登录相关文案保持 English-only。
- Cancel 路径不展示失败提示。
- 登录弹窗不能永久阻塞整个 App。

## 关联命令

```bash
bash agent_workflow/scripts/run_module_regression.sh me
```

