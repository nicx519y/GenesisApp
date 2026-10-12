# 客户端错误 Toast 排查与优化建议

日期：2026-10-08  
范围：当前 `genesis_app` 客户端正式代码中的错误 Toast。  
状态：已完成代码静态排查；本文是研发优化交接文档，尚未修改客户端实现。

## 1. 用户已反馈的问题

后端登录接口返回：

```json
{"data":{},"err_msg":"user banned","err_no":10013}
```

用户截图中的 Toast 全文：

```text
ApiExceptionuser banned (code=10013) (kind=business)
```

这里的 `ApiException`、`(code=10013)`、`(kind=business)` 都由客户端添加。后端只提供了 `user banned` 和错误码 `10013`。

问题有两点：

- 把用于研发排查的异常全文直接显示给用户。
- 同一封禁错误从不同登录入口触发时，用户看到的文字不一致；新用户引导还会把封禁提示替换为“请重试”。

## 2. 这次封禁错误，用户到底看到什么

以下登录场景均以本次已提供的后端返回为依据。拉黑场景是条件推导：仅当该操作接口也返回同样的错误时，才会显示表中的文字，并不表示这些接口已在线上返回过这条错误。

| 场景 | 用户看到的完整 Toast | 展示代码位置 |
| --- | --- | --- |
| 普通登录弹窗，包括业务操作触发的登录 | `ApiExceptionuser banned (code=10013) (kind=business)` | `lib/components/login_sheet.dart:67` |
| Me 页登录 | `ApiExceptionuser banned (code=10013) (kind=business)` | `lib/pages/me/me_page_actions.dart:43` |
| Home 页登录 | `ApiExceptionuser banned (code=10013) (kind=business)` | `lib/pages/home/home_page.dart:153` |
| 新用户引导中的登录 | `Sign-in failed. Please try again.` | `lib/components/onboarding/personalization_sheet.dart:253` |
| 用户资料页拉黑失败，且接口返回上述错误 | `user banned[10013]` | `lib/pages/me/user_info_page.dart:342`；拼接函数在 `:427` |
| 用户资料页解除拉黑失败，且接口返回上述错误 | `user banned[10013]` | `lib/pages/me/user_info_page.dart:388`；复用同一拼接函数 |
| Settings → Blocked users 中拉黑／解除拉黑失败，且接口返回上述错误 | `user banned[10013]` | `lib/pages/me/settings_page.dart:411`；拼接函数在 `:696` |

代码位置相对 `genesis_app/`，行号是排查时的位置，后续修改可能变化。

### 2.1 为什么登录 Toast 会多出这些字

当前链路：

1. `lib/network/v1/v1_api_resource.dart:104` 将失败响应转换成 `ApiException`，将 `err_msg` 放进 `message`、`err_no` 放进 `code`，并标记为 `business`。
2. 登录入口捕获异常后，用 `e.toString()` 或 `error.toString()` 生成 Toast 文案。
3. `lib/network/api_exception.dart:84` 的 `toString()` 拼接异常名称、文案、错误码、异常类型等信息。

本次拼接结果为：

```text
ApiException + user banned +  (code=10013) +  (kind=business)
```

`ApiException` 和 `user banned` 之间没有空格，是因为实现直接使用了 `ApiException$message`。

## 3. 所有直接显示异常全文的普通登录位置

共 3 个代码位置，均无仅 Debug 生效的限制：

| 位置 | 触发条件 | 当前行为 |
| --- | --- | --- |
| `LoginSheet._submit`，`lib/components/login_sheet.dart:63` | Google／Apple 登录过程中抛出异常，用户取消授权除外 | 展示 `e.toString().trim()`；字符串为空时才回退为 `Sign-in failed` |
| `_MePageActions._login`，`lib/pages/me/me_page_actions.dart:39` | Me 登录流程抛出异常，用户取消授权除外 | 与普通登录弹窗相同 |
| `_HomePageState._login`，`lib/pages/home/home_page.dart:151` | Home 登录流程或其登录完成回调抛出异常，用户取消授权除外 | 展示 `error.toString()` |

影响不只限于封禁：这三处收到其他业务错误时，也会显示异常前缀、错误码和类型。收到 HTTP、网络、网关等 `ApiException` 时，还可能附带以下字段，具体取决于异常对象：

```text
statusCode、transportErrorKind、clientFailureCode、cause、uri
```

收到平台或其他类型异常时，会展示该异常自身的字符串表达。不同错误的完整文字必须依据实际响应或异常对象确认，不能从本次封禁响应推断。

## 4. 其他普通业务中的错误码／错误详情拼接

### 4.1 拉黑与解除拉黑

| 场景 | 当前显示规则 | 特殊情况 | 代码位置 |
| --- | --- | --- | --- |
| 用户资料页拉黑失败 | 在后端错误文案后加方括号错误码 | 仅 `ApiException` 且 `code` 非空时拼接；其他异常显示 `Block failed` | `lib/pages/me/user_info_page.dart:427` |
| 用户资料页解除拉黑失败 | 同上 | 其他异常显示 `Unblock failed` | 同一函数 |
| Settings → Blocked users 中拉黑／解除拉黑失败 | 在错误文案后加方括号错误码 | 文案为空时显示 `Request failed` 并追加错误码；`code` 为空时仍会追加 `[null]`；其他异常显示 `Update failed` | `lib/pages/me/settings_page.dart:696` |

本次错误对应的具体结果是 `user banned[10013]`，不是完整的 `ApiException…`。

### 4.2 宝石购买失败

宝石购买的拼接提示可在钱包购买流程和宝石购买弹层展示，无需开启 Debug。下面表中的“商店错误码”“商店错误详情”是变量说明，实际用户看到的是商店返回的值。当前未提供这些购买失败的真实返回，因此不能给出唯一的完整 Toast。

| 触发条件 | 用户看到的文字规则 | 没有对应信息时的固定文案 | 生成文案的代码位置 |
| --- | --- | --- | --- |
| 查询商店商品或拉起付款抛出带 code 的 `BillingPlatformException` | `Purchase failed (` 后接错误码，再接 `).` | `Purchase failed.` | `lib/platform/billing/billing_tracking.dart:77` |
| 查询商店商品返回失败，且 errorCode 非空 | 同上 | `This product is currently unavailable.` | `lib/platform/billing/billing_tracking.dart:93` |
| 商店购买回调失败，错误码和详情都非空 | `Purchase failed (` 后接错误码、`: `、错误详情，再接 `).` | 见下方分支 | `lib/platform/billing/billing_tracking.dart:99` |
| 商店购买回调失败，仅详情非空 | `Purchase failed (` 后接错误详情，再接 `).` | — | 同一函数 |
| 商店购买回调失败，仅错误码非空 | `Purchase failed (` 后接错误码，再接 `).` | — | 同一函数 |
| 商店购买回调失败，错误码和详情都为空 | `Purchase failed.` | — | 同一函数 |

正式处理链路：

- 查询商品／拉起付款失败：`lib/platform/billing/google_play_billing_service.dart:358`、`:381`、`:451`。
- 商店失败回调：`lib/platform/billing/billing_recovery.dart:393`。
- 钱包展示：`lib/pages/gems/gem_wallet_billing_flow.dart:97`。
- 宝石购买弹层展示：`lib/components/gems/gem_purchase_bottom_sheet.dart:262`。

Premium 订阅购买有独立的商店错误文案映射，不能把宝石购买的上述规则直接套到订阅上。当前订阅文案映射见 `lib/app/membership/membership_store_failure.dart`。

## 5. 开发者页的异常全文拼接清单

以下是开发者工具界面中的提示，与普通业务入口分别处理。表中的“异常全文”表示运行时异常的字符串表达，不是用户会看到的四个汉字；每次完整文字随异常变化。

共 19 个错误处理位置；World History 的读取、更新、重置共用一个错误处理位置。

| 操作失败场景 | 用户在开发者页看到的文字规则 | 代码位置 |
| --- | --- | --- |
| 保存地图设置按钮显示开关 | `Save failed: ` 后接异常全文 | `lib/pages/me/developer_page.dart:351` |
| 保存进入 Worldo 时展开 Sheet 的设置 | 同上 | `lib/pages/me/developer_page.dart:383` |
| 保存强制显示 New 标记的设置 | 同上 | `lib/pages/me/developer_page.dart:415` |
| 保存购买 Toast 调试详情开关 | 同上 | `lib/pages/me/developer_page.dart:447` |
| 保存遥测上传开关 | 同上 | `lib/pages/me/developer_page.dart:468` |
| 保存聊天顶部效果设置 | 同上 | `lib/pages/me/developer_page.dart:480` |
| 保存聊天气泡布局设置 | 同上 | `lib/pages/me/developer_page.dart:488` |
| 清理私信缓存 | `Clear failed: ` 后接异常全文 | `lib/pages/me/developer_endpoint_actions.dart:35` |
| 清理图片缓存 | 同上 | `lib/pages/me/developer_endpoint_actions.dart:54` |
| 清理 Gateway 鉴权 | 同上 | `lib/pages/me/developer_endpoint_actions.dart:77` |
| 验证 Gateway 签名 | `Failed: ` 后接异常全文 | `lib/pages/me/developer_endpoint_actions.dart:105` |
| 保存接口地址／切换环境 | `Save failed: ` 后接异常全文；捕获到 `FormatException` 时只展示其 message | `lib/pages/me/developer_endpoint_actions.dart:177` |
| 保存版本覆盖配置 | `Save failed: ` 后接异常全文；捕获到 `FormatException` 时只展示其 message | `lib/pages/me/developer_version_actions.dart:44` |
| 重置版本覆盖配置 | `Reset failed: ` 后接异常全文 | `lib/pages/me/developer_version_actions.dart:67` |
| 读取／更新／重置 World History 水位配置 | `World History request failed: ` 后接异常全文 | `lib/pages/me/developer_world_history_actions.dart:68` |
| 保存 HTTP 抓包开关 | `Save failed: ` 后接异常全文 | `lib/pages/me/developer_network_tab.dart:44` |
| 保存 WebSocket 抓包开关 | 同上 | `lib/pages/me/developer_websocket_tab.dart:84` |
| 保存 WebSocket 方向筛选 | 同上 | `lib/pages/me/developer_websocket_tab.dart:95` |
| 保存 WebSocket 类型筛选 | 同上 | `lib/pages/me/developer_websocket_tab.dart:132` |

## 6. 仅 Debug 生效的购买诊断信息

同时满足以下两个条件，购买 Toast 才会额外添加诊断信息：

1. App 为 Debug 构建（`kDebugMode`）。
2. 已开启购买 Toast 调试详情开关。

用户看到的结构是两行：第一行以 `debug：` 开头，展示购买阶段、状态、原因、异常类型、错误码等；第二行展示原本的购买提示。

覆盖位置：

| 入口 | 触发提示的情况 | 代码位置 |
| --- | --- | --- |
| 宝石钱包购买 | 购买服务不可用、购买调用异常、失败／pending／deferred 结果 | `lib/pages/gems/gem_wallet_billing_flow.dart:41`、`:65`、`:97` |
| 宝石购买弹层 | 服务不可用、购买调用异常、失败／pending／deferred 结果 | `lib/components/gems/gem_purchase_bottom_sheet.dart:45`、`:230`、`:262` |
| Premium 订阅内容页 | 购买服务不可用 | `lib/components/gems/pro_subscription_content.dart:378` |
| Premium 购买资格／流程拦截提示 | 走 Toast 的资格或流程拦截原因 | `lib/app/membership/membership_purchase_eligibility.dart:37` |
| Premium 购买结果展示 | 上报结果提示、商店／流程结果提示、购买调用异常 | `lib/components/gems/membership_purchase_presentation.dart:171`、`:185`、`:209` |

实现：`lib/platform/billing/purchase_toast_diagnostics.dart:9`。开关条件：`lib/app/debug/purchase_toast_debug_settings.dart:15`。Release 不追加这一行。

## 7. 已采用纯文案展示的相关位置

这些位置可作为优化时的参考，不应误判为与截图相同的问题：

- `lib/utils/api_error_message.dart:3`：`ApiException` 只取非空 `message`，其他情况使用调用方的兜底文案。该函数本身不追加异常名称、错误码或类型。
- `lib/components/chat/chatroom_failure_toast.dart:48`、`:102`：从业务异常或聊天室事件中提取错误文案，不调用异常的 `toString()` 生成提示。
- `lib/components/onboarding/personalization_sheet.dart:253`：登录错误统一显示 `Sign-in failed. Please try again.`；虽然没有技术信息，但不能向封禁用户解释原因。
- `lib/components/common/genesis_center_toast.dart`：Toast 组件负责展示传入的字符串，不负责为异常添加前缀或错误码。问题来自调用方或生成文案的函数。

## 8. 建议研发优化范围

以下为建议，尚未实施；英文措辞应由产品确认。

### 优先处理：登录入口

- 普通登录弹窗、Me、Home、新用户引导统一使用登录错误文案处理。
- 对本次 `10013` 错误给出明确的账号限制说明，避免提示用户反复重试。
- 最小修复可对业务 `ApiException` 使用其 `message`：本次会显示 `user banned`。
- 更完整的产品文案可考虑 `Your account has been restricted. Please contact support.`；该句是建议文案，不是当前实现。具体限制范围和客服指引需与后端／产品确认。
- 对网络、HTTP、网关和第三方登录异常提供可读的提示，未知异常使用兜底文案，不回退到异常全文。
- `ApiException.toString()` 继续用于日志和诊断。通过统一展示函数处理用户文案，避免修改异常对象的诊断表达来影响所有调用方。

### 随后处理：拉黑与宝石购买

- 用户资料页与 Blocked users 去除方括号错误码，消除 `[null]`。
- 宝石购买对可识别的商店失败使用明确文案；对未知失败使用统一购买失败提示。商店原始错误码和详情保留在诊断记录中。
- Premium 已有独立文案映射，修改前核对该映射，避免将其替换成宝石购买的通用规则。

### 开发者工具

- 评估是否让 Toast 只显示简短失败提示，将异常全文放入工具页面的诊断区域或日志。
- 购买 Debug 详情属于显式调试功能，按调试用途单独决定是否调整，并保持仅 Debug 生效的限制。

## 9. 优化后的验收要点

下面是交给研发的验收场景，不代表本次已经执行过这些验证。

| 验收场景 | 期望结果 |
| --- | --- |
| 同一个受限账号从普通弹窗、Me、Home、新用户引导登录 | 提示一致，能说明账号限制原因；没有异常名称、错误码、类型等诊断字段 |
| 登录网络错误、超时、HTTP／网关错误、第三方授权失败 | 提示可读，未知异常也不显示异常全文 |
| 用户主动取消 Google／Apple 授权 | 沿用当前各入口约定的取消处理，避免因文案统一而误报封禁或系统异常 |
| 资料页和 Blocked users 操作失败，包括 code 为空 | 无方括号错误码，无 `[null]` |
| 宝石购买查询失败、拉起付款失败、商店失败回调；分别覆盖错误码／详情的空值组合 | 普通用户看到产品文案，研发仍可查到原始错误信息 |
| Premium 购买失败 | 原有商店错误映射仍有效 |
| Release 的会员与宝石购买提示 | 不出现 `debug：` 行 |
| Debug 开启／关闭购买 Toast 详情 | 诊断行按开关生效 |

排查依据为正式业务代码和用户提供的截图、登录错误响应。除该截图问题外，清单中的其他项目是代码路径确认，未声称每一项都已经在线上复现。本次仅创建文档，未修改业务代码，也未运行自动化测试或构建。
