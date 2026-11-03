# 购买事件口径

更新：2026-11-02。客户端实现口径；真机支付、线上 Collect 和 Firebase 数据仍需验收。

## 订阅事件

订阅失败事件 `subscription_failed`（含超时）使用 `action_type=monitor`，新增 `subscription_success_skipped` 同样使用 `monitor`，`ext_data` 留空；其余订阅事件使用 `action_type=pay_event`。`object1` 是原入口来源，购买相关事件的 `object2` 统一表述为「商店 productId」（内部字段 `store_product_id`）（页面曝光留空，旧记录无法取得时留空），`object3` 按下表填写。公共 UID 使用事件入队时的身份；登录后的 claim 事件不能反推购买时是否为游客。

| action | object3 | 触发时机 |
| --- | --- | --- |
| `subscription_page_show` | `subscription_page` / `subscription_sheet` | 订阅内容首次实际可见。 |
| `subscription_purchase_click` | `yearly` / `monthly` | 可用购买按钮被点击并进入购买流程。 |
| `subscription_pending` | `store_callback_pending` | 商店明确返回 pending；不发送 report。 |
| `subscription_success` | 本笔商店交易号；缺失时为空 | 当前购买回调 purchased 时记录，不等待 report；Apple 还要求回调 appAccountToken 为有效 UUID 且与本次购买 UUID 一致，缺失或不匹配不记录。 |
| `subscription_failed` | 见下方「订阅失败阶段与原因」；飞书表见第 03 节失败阶段与原因枚举 | 点击后的前置检查、商店商品查询、商店拉起失败，或商店回调返回 error / canceled；report 拒绝／异常另按 report 阶段记录。 |
| `subscription_claim_result` | `completed` / `rejected` / `error[code]` / `timeout` | 游客登录后，每次实际 claim 请求的结果。 |
| `subscription_success_skipped` | 见下方方案的拦截原因枚举 | 可关联本次点击的 purchased 回调，因校验或去重未报成功时记录；action_type=monitor。 |

### 订阅失败阶段与原因

`object3` 格式为 `阶段_failed[reason=具体原因]`，更细操作记录在 `ext_data.step`。飞书订阅表第 03 节列出各阶段及原因。

| 阶段 | 含义 |
| --- | --- |
| `precheck` | 资格、账号会话等前置检查 |
| `prepare` | 账号 UUID、游客身份、监听或本地准备 |
| `query` | 商品、价格及 offer 查询与匹配 |
| `launch` | 调起商店购买 |
| `callback` | 商店取消／失败回调、凭据缺失或回调等待超时 |
| `stream` | 购买监听流异常或结果转换异常 |
| `report` | 服务端 report 拒绝或请求异常 |
| `unknown` | 分类信息不足时的兜底 |

原始商店错误保存在 `ext_data`，完整规则见 [支付失败监控诊断](payment-failure-monitoring.md)。

重复 purchased 回调按平台和本笔交易身份去重；pending 后转 purchased 时才记录 success。普通 restored 和无当前购买凭据的历史订单不计新购买。打点失败不阻断 report、登录、claim 或页面状态。`object2` 只承载商店商品 ID，不承载内部操作 ID 或购买凭据。

来源缺失、无法识别或为 `from_unknown` 时，统一跳过订阅事件上报（含曝光、点击、成功、失败、pending、超时及 claim 结果）。购买处理、凭据 report 和权益流程照常执行；Gems 打点不受影响。

## Gems 事件

完整字段、入口及流程见 [Gems 购买打点](gems-purchase-analytics.md)。

`purchase_failed`（含超时）使用 `action_type=monitor`，其余 Gems 购买事件使用 `action_type=pay_event`。

`buy_page_show`、`product_click`、`purchase_pending`、`purchase_success` 和 `purchase_failed` 的 `object2` 使用商店 `productId`（内部字段 `store_product_id`），其中 buy_page_show 留空；object1 为业务入口（from_me_gems／from_tick_no_balance／from_msg_low_balance／from_msg_no_balance／from_subscription_tab），由点击沿用到 pending、超时、失败、成功及 report 拒绝；曝光 object3 为 buy_gems_page／buy_gems_sheet；点击 object3 留空；pending 为 store_callback_pending；成功为交易号；失败为阶段和原因。object4 留空；仅失败 ext_data 为 JSON 字符串。未知入口 from_unknown 不上报 Gems 事件，购买业务照常执行。`purchase_success` 在当前购买的商店 purchased 回调后触发；`purchase_failed` 对应点击后的前置检查、商店商品查询、商店拉起失败、购买流 onError，或商店 canceled / error 回调。失败 `object3` 统一为 `阶段_failed[reason=具体原因]`，完整分类、诊断、脱敏和去重规则见 [支付失败监控诊断](payment-failure-monitoring.md)。监听异常独立去重，后续商店明确结果仍可记录；支付事件不代表订单最终结算状态。Gems report 返回 rejected 时记录 purchase_failed（monitor），stage=report，object3=report_failed[reason=服务端原因]，按平台和凭据在当前服务实例内去重；completed、网络错误和超时不新增结果事件。`purchase_success.object3` 使用商店本笔交易号，缺失时留空，不发送 purchase token。

## subscription_success_skipped

| object3 | 原因 |
| --- | --- |
| account_mismatch | 当前登录账号与本次购买记录所属账号不一致。 |
| account_uuid_missing | Apple 回调账号 UUID 缺失或为空。 |
| account_uuid_invalid | Apple 回调账号 UUID 格式无效。 |
| account_uuid_mismatch | Apple 回调账号 UUID 与本次购买记录不一致。 |
| receipt_missing | purchased 回调缺少必要购买凭据。 |
| duplicate_transaction | 本笔交易已统计过成功。 |
| duplicate_tracking | 本次购买 tracking 已统计过成功。 |
