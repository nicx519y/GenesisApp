# 购买事件口径

更新：2026-10-08。客户端实现口径；真机支付、线上 Collect 和 Firebase 数据仍需验收。

## 订阅事件

订阅事件使用 `action_type=pay_event`。`object1` 是原入口来源，`object2` 留空，`object3` 按下表填写。公共 UID 使用事件入队时的身份；登录后的 claim 事件不能反推购买时是否为游客。

| action | object3 | 触发时机 |
| --- | --- | --- |
| `subscription_page_show` | `subscription_page` / `subscription_sheet` | 订阅内容首次实际可见。 |
| `subscription_purchase_click` | `yearly` / `monthly` | 可用购买按钮被点击并进入购买流程。 |
| `subscription_pending` | `store_callback_pending` | 商店明确返回 pending；不发送 report。 |
| `subscription_timeout` | `prepare` / `store_callback` | 客户端准备或等待商店回调超时；不代表扣款失败。 |
| `subscription_success` | 本笔商店交易号；缺失时为空 | 当前购买的商店回调返回 purchased，立即记录，不等待 report。 |
| `subscription_failed` | `precheck_failed[原因]`、`query_failed[原因]`、`launch_failed[原因]`，或商店回调的原生错误码／取消原因 | 点击后的前置检查、商店商品查询、商店拉起失败，或商店回调返回 error / canceled；report 结果不触发。 |
| `subscription_claim_result` | `completed` / `rejected` / `error[code]` / `timeout` | 游客登录后，每次实际 claim 请求的结果。 |

重复 purchased 回调按平台和本笔交易身份去重；pending 后转 purchased 时才记录 success。普通 restored 和无当前购买凭据的历史订单不计新购买。打点失败不阻断 report、登录、claim 或页面状态。`object2` 不承载内部操作 ID、购买凭据或新的关联 ID。

## Gems 事件

`buy_page_show`、`product_click`、`purchase_pending`、`purchase_timeout`、`purchase_success` 和 `purchase_failed` 的购买关联字段不再写入 `object2`。`purchase_success` 在当前购买的商店 purchased 回调后触发；`purchase_failed` 对应点击后的前置检查、商店商品查询、商店拉起失败、购买流 onError，或商店 canceled / error 回调。前三类失败的 `object3` 分别为 `precheck_failed[错误码]`、`query_failed[错误码]`、`launch_failed[错误码]`；拉起失败没有错误码时为 `launch_failed`。购买流 onError 的 `object3` 优先保留结构化平台错误码，否则为 `store_failure[stage=stream;status=error]`。流错误后如仍收到本笔 purchased 回调，可在 `purchase_failed` 之后再记录 `purchase_success`；两条事件都只按各自的回调事实计入。report 的 completed、rejected、网络错误和超时都不生成购买结果事件。`purchase_success.object3` 使用商店本笔交易号，缺失时留空，不发送 purchase token。

## report 与 Firebase

Gems、登录订阅、游客订阅的 report 仅接受 completed / rejected。report 响应负责发货与页面业务状态，不决定购买打点。商店 purchased 回调同时触发项目自定义 Firebase 购买事件；按交易去重。平台自动采集的购买事件是独立来源，分析时应区分，避免合并重复计数。

商店 pending 不 report；后续 purchased 回调发起首次 report。点击后的前置检查、商品查询或商店拉起失败产生带阶段原因的失败事件；等待超时仍使用单独的 timeout 事件。report 异常不把已购买的交易改记为 purchase_failed / subscription_failed。

未完成的订阅 pending 状态可保留到 App 重启后，用于匹配商店后续的 purchased 回调；它不构成 report 重试队列。report 失败的订单不会写入本地队列等待重发。既有网络请求层策略维持原状。

## 当前验证边界

本文件描述客户端目标口径。商店真实扣款、服务端到账、Firebase/Collect 线上入库以及报表聚合应分别验收；客户端收到 purchased 不等于服务端已完成发货。
