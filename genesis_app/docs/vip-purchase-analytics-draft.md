# 购买事件口径

更新：2026-11-02。客户端实现口径；真机支付、线上 Collect 和 Firebase 数据仍需验收。

## 订阅事件

订阅失败事件 `subscription_failed` 使用 `action_type=monitor`，其余订阅事件使用 `action_type=pay_event`。`object1` 是原入口来源，`object2` 留空，`object3` 按下表填写。公共 UID 使用事件入队时的身份；登录后的 claim 事件不能反推购买时是否为游客。

| action | object3 | 触发时机 |
| --- | --- | --- |
| `subscription_page_show` | `subscription_page` / `subscription_sheet` | 订阅内容首次实际可见。 |
| `subscription_purchase_click` | `yearly` / `monthly` | 可用购买按钮被点击并进入购买流程。 |
| `subscription_pending` | `store_callback_pending` | 商店明确返回 pending；不发送 report。 |
| `subscription_timeout` | `prepare` / `store_callback` | 客户端准备或等待商店回调超时；不代表扣款失败。 |
| `subscription_success` | 本笔商店交易号；缺失时为空 | 当前购买回调 purchased 时记录，不等待 report；Apple 还要求回调 appAccountToken 为有效 UUID 且与本次购买 UUID 一致，缺失或不匹配不记录。 |
| `subscription_failed` | `阶段_failed[reason=具体原因]`；阶段为 precheck、prepare、query、launch、callback、stream，原始错误放 ext_data，详见 payment-failure-monitoring.md | 点击后的前置检查、商店商品查询、商店拉起失败，或商店回调返回 error / canceled；report 拒绝／异常另按 report 阶段记录。 |
| `subscription_claim_result` | `completed` / `rejected` / `error[code]` / `timeout` | 游客登录后，每次实际 claim 请求的结果。 |

重复 purchased 回调按平台和本笔交易身份去重；pending 后转 purchased 时才记录 success。普通 restored 和无当前购买凭据的历史订单不计新购买。打点失败不阻断 report、登录、claim 或页面状态。`object2` 不承载内部操作 ID、购买凭据或新的关联 ID。

来源缺失、无法识别或为 `from_unknown` 时，统一跳过订阅事件上报（含曝光、点击、成功、失败、pending、超时及 claim 结果）。购买处理、凭据 report 和权益流程照常执行；Gems 打点不受影响。

## Gems 事件

`purchase_failed` 使用 `action_type=monitor`，其余 Gems 购买事件使用 `action_type=pay_event`。

`buy_page_show`、`product_click`、`purchase_pending`、`purchase_timeout`、`purchase_success` 和 `purchase_failed` 的购买关联字段不再写入 `object2`。`purchase_success` 在当前购买的商店 purchased 回调后触发；`purchase_failed` 对应点击后的前置检查、商店商品查询、商店拉起失败、购买流 onError，或商店 canceled / error 回调。失败 `object3` 统一为 `阶段_failed[reason=具体原因]`，完整分类、诊断、脱敏和去重规则见 [支付失败监控诊断](payment-failure-monitoring.md)。监听异常独立去重，后续商店明确结果仍可记录；支付事件不代表订单最终结算状态。Gems report 返回 rejected 时记录 purchase_failed（monitor），stage=report，object3=report_failed[reason=服务端原因]，按平台和凭据在当前服务实例内去重；completed、网络错误和超时不新增结果事件。`purchase_success.object3` 使用商店本笔交易号，缺失时留空，不发送 purchase token。

## report 与 Firebase

Gems、登录订阅、游客订阅的 report 仅接受 completed / rejected。会员 report 被 rejected 或请求异常时记录 subscription_failed，stage=report，object3=report_failed[reason=具体原因]，每次购买尝试去重；report 正常发送，业务结果处理保持原流程。Apple 的 UUID 校验同时控制项目自定义购买归因事件。身份匹配时仍可能先记商店成功、再记 report 失败，成功不表示到账。商店 purchased 回调按上述校验触发项目自定义 Firebase 购买事件；按交易去重。平台自动采集的购买事件是独立来源，分析时应区分，避免合并重复计数。

商店 pending 不 report；后续 purchased 回调发起首次 report。点击后的前置检查、商品查询或商店拉起失败产生带阶段原因的失败事件；等待超时仍使用单独的 timeout 事件。report 阶段的失败事件不撤销已记录的商店购买成功事件，表示权益确认失败。

未完成的订阅 pending 状态可保留到 App 重启后，用于匹配商店后续的 purchased 回调；它不构成 report 重试队列。report 失败的订单不会写入本地队列等待重发。既有网络请求层策略维持原状。

## 当前验证边界

本文件描述客户端目标口径。商店真实扣款、服务端到账、Firebase/Collect 线上入库以及报表聚合应分别验收；客户端收到 purchased 不等于服务端已完成发货。

## 非当前购买的订阅回调

订阅 purchased 回调必须关联当前进程中点击购买创建的记录；仅账号 UUID 匹配不再构建恢复购买记录。启动／重启后没有本次购买记录的历史回调不触发 report、订阅成功事件或 Adjust 购买归因。已发起过 report 的购买尝试不再处理后续续订或重复 purchased 为新购买。同一进程内由本次点击产生的 pending 后续完成仍按正常购买处理。游客 claim 维护与 Gems 链路保持原逻辑。

## 非当前购买的 Gems 回调

Gems 监听仅处理当前进程点击购买创建并能匹配的购买尝试（含同一次 pending／中断后返回的结果）。无购买尝试的 purchased 与 restored 历史回调不触发成功事件、Adjust 归因、StoreKit Firebase 交易统计或 report；主动恢复查询也不再为 Gems 构建购买尝试及发送 report。正常购买的 report rejected 统计保持不变。

Gems 的 product_click 在页面／弹窗接受有效点击后立即记录，早于前置价格确认；价格确认失败或超时也保留该点击。购买服务不重复记录 product_click，禁用／防重入拦截的点击不记录。
