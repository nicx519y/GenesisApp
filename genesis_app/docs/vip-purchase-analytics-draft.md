# VIP 购买打点方案（评审草案）

日期：2026-09-16  
代码核对基线：`82e375e5`  
状态：**仅设计，尚未接入代码。事件名、字段和去重规则均为本次建议。**

## 1. 目标与边界

沿用 Gems 的 `action_type / action / object1 / object2 / object3` 结构，独立使用 `subscription_*` 事件名，避免与 Gems 购买混在一起。公共维度放现有 `ext_data` JSON 字符串，不修改 collect 接口结构。

需要回答：

1. 用户从哪里进入订阅，选择月会员还是年会员，在哪个环节退出或失败？
2. 平台是否回调成功，服务端是否确认完成？
3. 游客购买后是否实际看到强制登录、是否登录成功、是否绑定成功？
4. 月升年是否成功，失败来自客户端、平台还是 report？
5. 重试、启动恢复、平台重复回调是否被误计为新的购买？

本方案不修改购买、超时、重试、登录拦截、UI 或 Gems 的业务逻辑，不为打点新增 wallet、商品列表、商店订单查询。Firebase 购买收入事件保留原逻辑，不与这里的业务漏斗重复汇总。

## 2. 六个核心事件

以下事件建议全部接入。`action_type` 均为 `pay_event`。

| action | 含义 | object1 | object2 | object3 | 触发时机 |
| --- | --- | --- | --- | --- | --- |
| `subscription_page_show` | 订阅页面曝光 | `subscription_page` / `subscription_sheet` | `track_id_{pageId}` | 入口来源，见第 4 节 | Subscription 内容首次实际可见，包括显示加载状态；仅构建隐藏 Tab 不算曝光。 |
| `subscription_product_click` | 点击购买 | 当前商品 `plan_code` | `track_id_{pageId}_{clickId}` | `subscription_page` / `subscription_sheet` | 有明确选中商品且进入购买回调时，在异步准备和降级校验之前。禁用按钮未触发回调时不记录。 |
| `subscription_pending` | 等待支付或服务端确认 | 本次购买 `plan_code` | 本次购买关联 ID | `store_callback_pending` / `report_accepted` | 平台明确返回 pending，或 report 明确返回 accepted。两个原因分别记录。 |
| `subscription_timeout` | 某阶段超时，结果未确认 | 本次购买 `plan_code` | 本次购买关联 ID | `prepare` / `report` | 购买准备超时，或实际 report 请求抛出超时。不能据此判定用户未扣款。 |
| `subscription_success` | 服务端确认本笔购买 | 本次购买 `plan_code` | 本次购买关联 ID | 平台订单号；缺失时空字符串 | 首次解析到 report 的 `status=completed` 时记录。游客与登录用户一致，不等待登录绑定或点击成功弹窗按钮。 |
| `subscription_failed` | 购买流程发生失败或拦截 | 本次购买 `plan_code` | 本次购买关联 ID | `reason` / `reason[error_code]` | 实际发生准备失败、业务拦截、平台取消/错误或 report 拒绝/异常。原因见第 6 节。 |

补充规则：

- `object1` 使用接口真实 `plan_code`，当前模型支持 `pro_monthly` / `pro_yearly`。同一个 Google 商品可以有不同 base plan，不能只用商店商品 ID 区分月/年。
- 无原始点击的恢复流程使用 `recovery_{id}`，且 `flow_origin=recovery`。套餐无法可靠还原时用 `unknown`，不能猜成月会员或根据当前选中项填充。
- `subscription_success.object3` 取本笔平台回调的 `transactionId`，或精确匹配的本地凭据所保存的订单号。Google 通常是 GPA 订单号，Apple 是本次 transactionId。
- 当前 VIP report 模型只有 `status`，没有订单号、`report_id`、`reason`。不能从响应里虚构这些字段，也不能用 UUID、purchaseToken 代替订单号。
- 成功弹窗显示和点击 Enjoy it / OK 不是支付成功依据；绑定成功也不是第二笔购买成功。
- 核心失败事件是“发生过失败节点”，不保证整笔订单最终失败。例如 report 网络失败后仍可补报成功；报表必须按关联 ID 看后续结果。

## 3. 公共维度和关联 ID

### 3.1 `ext_data` 建议字段

所有字段来自当前真实上下文；未知时省略，枚举允许 unknown 的字段可明确填 unknown。不为补齐字段发请求。

| 字段 | 类型 / 值 | 说明 |
| --- | --- | --- |
| `schema_version` | integer，`1` | 本方案版本。 |
| `provider` | `google` / `apple` | 实际支付平台。 |
| `flow_origin` | `direct` / `recovery` / `renewal` | 原始来源，一旦确定不随补报改变。没有证据证明续费时归 recovery，不靠时间猜测。 |
| `trigger` | `user_click` / `retry` / `app_start` / `foreground` / `store_callback` / `login` | 本次操作的直接触发原因。补报仍保留原 flow_origin。 |
| `checkout_login_state` | `guest` / `logged_in` / `unknown` | 点击购买时冻结的身份；游客后来登录也不修改。 |
| `login_state` | `guest` / `logged_in` / `unknown` | 当前事件时的身份。 |
| `page_source` | 第 4 节枚举 | 原购买入口，跨登录与重试保留；恢复无法还原则 from_unknown。 |
| `store_product_id` | string | 实际商店商品 ID。 |
| `base_plan_id` | string | 已知时记录目标 Google base plan，仅分析使用，不加入 report/claim 请求。 |
| `purchase_mode` | `new` / `upgrade` / `resubscribe` / `unknown` | 点击时的购买意图。已知有效月会员购买年会员标记 upgrade；不能代表平台最终接受升级。没有可靠前态用 unknown。 |
| `previous_plan_code` | string | 已知的购买前套餐；不使用失效/未知缓存硬判。 |
| `uuid_source` | `last_account_uuid` / `guest_prepare` / `user_uuid` / `recovered_receipt` / `unknown` | 只记来源，不上报 UUID 值。 |
| `stage` | 阶段枚举 | 用于超时、失败及诊断。 |
| `error_code` | string | SDK / HTTP / 后端 envelope 的实际稳定错误码，存在才填。 |
| `error_source` | `client` / `google` / `apple` / `plugin` / `http` / `backend` | 错误所属层。不能根据 Toast 文案猜平台错误码。 |
| `duration_ms` | 非负整数 | 当前操作耗时，采用单调计时；不混入整个支付页停留时间。 |
| `retry_count` | 非负整数 | 首次 0；第 1 次重试为 1，按该流程持续计数。 |
| `request_attempt_id` | string | 每次实际 report/claim/check 请求独立生成；一次请求的 start/result 共用，网络打点重传不重建。 |
| `transaction_id_present` | boolean | 是否有商店订单号。缺失也允许记录服务端 completed。 |

用户、设备、平台、App 版本和时间继续走现有公共采集上下文。业务点位不自行拼 IP 或 `created_at`；现有客户端事件携带 `app_timestamp`，服务端存储时间与客户端发生时间应区分。

### 3.2 ID 生命周期

1. 打开一个购买容器生成 pageId；同一容器在两个 Tab 之间切换不更换 pageId。
2. 每次进入有效购买点击回调生成新的 clickId；所有购买状态、report 重试、游客登录和 claim 沿用本次 `track_id_{pageId}_{clickId}`。
3. 当前 VIP 的 `attemptId` 可以承接这一关联，但需要从页面传入。它只用于本地关联和采集，不恢复已删除的 report HTTP `request_id` 参数。
4. 关联上下文应随需要恢复的订单/游客记录保存，避免重启后无法关联；这是待实现的分析元数据，不代表当前已保存这些字段。
5. 原购买关联丢失时生成 `recovery_{id}` 并保持该恢复流程稳定，不补造页面展示或购买点击。不得直接把 `guestLoginRequestId` 当作采集 ID，它在部分恢复路径可能是 account_uuid。
6. 登录弹窗一次可处理多笔待绑定记录：弹窗只记一次曝光，生成非敏感 `login_flow_id`；各订单 claim 通过该 ID 关联。不把一次曝光按订单数重复发送。
7. 绑定流程按实际待绑定游客身份组织，不能假定一笔订单对应一次 claim。同一 UUID 下多笔订单共用一个非敏感 `claim_flow_id`；claim 事件记录该 ID 及已知 `related_purchase_track_ids`，只按真实接口调用次数发事件。UUID 只用于本地分组，不进入采集；无法还原订单关联时保留恢复 ID，不虚构关联。

## 4. 页面与入口来源

| `page_source` / 曝光 object3 | 入口 |
| --- | --- |
| `from_home_membership` | Home 顶部会员入口。 |
| `from_me_membership` | Me 会员卡片。 |
| `from_me_pink_gems` | Me 粉钻入口。 |
| `from_daily_check_in` | 非会员签到弹窗中的订阅入口。 |
| `from_chat_feature_quota` | 聊天会员功能或次数引导。 |
| `from_onboarding` | 个性化资料保存后的订阅步骤。使用 subscription_sheet 形态。 |
| `from_buy_gems_tab` | 从 Buy Gems 切到 Subscription。形态由所在容器决定。 |
| `from_unknown` | 调用方没有传入或恢复时无法还原，用于定位漏接入口。 |

每个容器的 Subscription 首次可见记一次曝光。重复 build、返回前台、接口刷新、同一容器来回切 Tab 不重复记；关闭后重新打开产生新 pageId。

Buy Gems 采用增量接入：保留原文档、原事件、字段及曝光时机；已有来源 `tick_no_balance`、`msg_low_balance`、`msg_no_balance` 不改名、不加 `from_`。仅新增 `subscription_tab` 来源，表示从 Subscription 切到 Buy Gems。反向切换记录 `subscription_page_show`，来源为 `from_buy_gems_tab`。`from_` 命名规则仅适用于本 VIP 方案的 `page_source`，不批量改造 Gems。

资料表单仍可见时不提前记 from_onboarding 的订阅曝光。如果已有待绑定订单而直接进入登录、没有展示订阅页，也不记录订阅曝光。

## 5. VIP 特有的配套事件

建议与六个核心点一起接入，才能区分“付款完成”与“游客成功绑定”。`action_type` 均为 `pay_event`，额外维度放 `ext_data`。

| action | object1 | object2 | object3 | 触发时机 / 附加字段 |
| --- | --- | --- | --- | --- |
| `subscription_stage` | plan_code / unknown | 购买或恢复关联 ID | `{stage}:{status}` | 记录实际阶段的开始和结果，阶段与状态见下表。 |
| `subscription_guest_check` | `guest_purchase` | 购买或恢复关联 ID | `start` / `unbound` / `bound_or_none` / `skipped` / `error` / `timeout` | 记录未登录恢复检查；附 `identity_source`、`check_requested`、`has_unbound_order`、`reason`。接口未返回时不填写 has_unbound_order。 |
| `subscription_login_show` | `guest_purchase` | 购买或恢复关联 ID | `purchase_success` / `startup_recovery` / `foreground_recovery` | 强制登录弹窗真正可见时；附 login_flow_id、forced。被个性化表单阻挡时不提前记曝光。 |
| `subscription_login_result` | `guest_purchase` | 与曝光相同的关联 ID | `success` / `error` / `canceled` | 认证回调的真实结果；附 login_flow_id、实际 error_code。没有回调不推断取消，强制登录无正常关闭事件。 |
| `subscription_claim_result` | plan_code / unknown | 原购买或恢复关联 ID | `start` / `completed` / `accepted` / `rejected` / `error` / `timeout` | 每次实际 claim 请求及其结果；附 request_attempt_id、retry_count、login_flow_id。 |

### `subscription_stage` 阶段

| stage | status | 说明 |
| --- | --- | --- |
| `prepare` | start / success / error / timeout | 准备商品与购买身份，错误细分放 reason。准备成功不代表购买成功。 |
| `query_store` | start / success / error | 获取平台商品和目标 offer。 |
| `launch_store` | start / handed_off / error / canceled | handed_off 仅表示实际 SDK 交接信号，不命名为“系统弹窗曝光”；通用接口不能可靠证明用户已经看到支付页。 |
| `store_callback` | pending / purchased / restored / canceled / error | 原始平台状态，按购买/交易和状态去重。历史 restored 不直接算新购买。 |
| `report` | start / completed / accepted / rejected / error / timeout | 每次实际 report 的结果，用 request_attempt_id 关联开始/结果，用 retry_count 区分重试。 |
| `finish_store` | success / error | 业务确实调用平台 finish 时记录；不为打点额外调用。 |
| `wallet_refresh` | success / error | 购买/claim 完成后已有的钱包刷新；刷新失败不撤销购买或绑定成功。 |
| `cleanup` | success / error | 本地待处理记录/游客缓存清理；附 target=purchase/guest_claim。与 report/claim 成功分开。 |
| `claim_retry` | scheduled / exhausted | 记录实际安排重试和本轮重试耗尽，不伪造一次接口请求；附 delay_ms、retry_count。 |

检查流程的 identity_source：`paid_cache` / `store` / `none`。没有购买凭据、只有临时 prepare UUID 时记录 skipped，reason=unpaid_identity；不能为了打点对它调用 check。无缓存时沿用现有商店恢复流程，记录 no_purchase、uuid_missing、proof_missing 或真实查询错误。

`has_unbound_order=false` 只能说明接口没有发现待绑定订单，不能推断为“已绑定”或“从未买过”；因此结果统一为 bound_or_none。该 check 也不等于当前有效 VIP 判断。

## 6. 失败原因字典

`subscription_failed.object3` 使用下列原因；中括号仅附真实、清洗后的稳定错误码。不上传 SDK 整段错误、原始响应或支付凭据。

| reason | 触发条件 | 分析分类 |
| --- | --- | --- |
| `service_unavailable` | 点击后购买服务缺失。 | 客户端准备异常 |
| `purchase_in_progress` | 请求进入服务后，被已有购买拦截。 | 防重入，不计技术支付失败 |
| `downgrade_not_allowed` | 已确认当前有效年会员，点击月会员被拦截。 | 业务拦截，不计技术支付失败 |
| `provider_mismatch` | 商品平台与实际支付平台不一致。 | 配置异常 |
| `catalog_unavailable` | 现有商品目录无法读取、选中套餐配置变化或无法唯一匹配。 | 商品准备异常；对应现有 eligibility_unavailable 分支 |
| `guest_prepare_failed[code]` | 游客 prepare 实际请求失败。 | 身份准备异常 |
| `uuid_unavailable` | 没有取得有效购买 UUID。 | 身份准备异常 |
| `local_storage_failed` | 必需的身份/购买状态保存失败，阻断当前流程。 | 本地异常 |
| `query_failed[code]` | 平台商品或 offer 查询失败。 | 平台查询异常；如 billing_unavailable 保留实际错误码 |
| `launch_failed[code]` | 发起平台购买返回 false 或明确异常。 | 平台调用异常 |
| `purchase_callback_error[code]` | 平台返回明确 error。 | 平台购买异常 |
| `canceled` | 平台明确返回取消。 | 用户取消，不计技术支付失败 |
| `session_changed` | 购买准备期间登录状态/账号变化，业务中止本次操作。 | 会话中止 |
| `receipt_missing` | 已购买/待处理状态缺少业务需要的凭据。 | 凭据待恢复，不能判定未扣款 |
| `signed_transaction_missing` | Apple 游客上报所需签名交易无法取得。 | 凭据异常 |
| `report_failed[code]` | report 非超时请求异常、业务 envelope 错误或解析异常。 | 上报失败，可重试 |
| `report_rejected` | report 的 status 明确为 rejected。 | 服务端拒绝；当前没有 reason 字段，不编造拒绝原因 |
| `unknown_error` | 已发生真实异常但没有稳定分类。 | 未分类异常；保留 stage 和可用 error_code |

准备或 report 超时只发对应核心 timeout，不再同时发同一次的核心 failed；stage 结果仍记录 timeout，避免报表重复计失败。此处是 VIP 草案的建议规则，Gems 现有行为不改。

不添加 `already_subscribed` 等当前客户端并未执行的资格拦截点。平台“已有订阅”等情况以真实平台返回码记录，不根据英文系统弹窗猜测原因。

## 7. 成功、等待、超时和重试口径

- **平台 purchased ≠ 服务端确认成功**：先记录 store_callback:purchased；只有 report=completed 才记核心 success。
- **report=accepted**：记 pending/report_accepted，继续既有恢复补报，不记 success。
- **游客 claim=completed**：表示绑定完成，独立记 claim_result；不重复发购买 success。
- **report/claim 成功后的 wallet、finish、缓存清理失败**：保留已有成功结果，单独记相应 stage 错误。
- **准备超时**：沿用当前 90 秒前置计时。平台交接后取消计时，不新增支付弹窗等待倒计时；用户迟迟不确认付款不等于客户端超时。
- **report 超时**：按实际 HTTP 超时结果记录；当前公共 ApiClient 默认预算 15 秒，不另造第二个 90 秒 report 定时器。配置变化时记录实际 duration_ms，以调用结果为准。
- **没有终态回调**：保持未确认，不合成 failed/canceled/success；分析时标记“观察窗口内未确认”。
- **claim 退避**：保持现有首次请求加最多 5 次重试；当前默认间隔为 15、30、60、120、240 秒。记录每次实际结果，以及本轮 exhausted。当前重试计数随会话重置，不能写成永久最多 6 次。
- 自动续费通常由服务端平台通知处理，App 不一定收到。客户端打点不能替代服务端完整续费账单，也不能仅靠 App 计算实际收入。

## 8. 去重与恢复

### 8.1 业务事件去重

| 事件 | 建议业务去重范围 |
| --- | --- |
| page_show | pageId + subscription_surface，每个容器首次可见一次。 |
| product_click | 每次真实购买点击的新关联 ID，一次。 |
| pending | 购买关联 ID + object3 原因，各一次；重复 pending/accepted 不刷量。 |
| timeout / failed | 购买关联 ID + 阶段 + 原因 + 本次请求编号；每个实际失败操作一次。一个异常只能由一个责任层发核心事件。 |
| success | 平台 + 本笔交易身份，一次；同时标记所属购买关联已成功。 |
| login_show | login_flow_id，实际展示一次。 |
| login_result | login_flow_id + 单次认证尝试编号 + 结果；允许用户失败后再次尝试。 |
| claim_result | 绑定流程 + request_attempt_id + 结果，每次实际请求独立记录。 |

Google 同一 purchaseToken 可能贯穿续费，不能仅凭 token 将所有交易合并；优先使用本次订单号。Apple 使用本次 transactionId，不用 originalTransactionId 合并所有续期。没有交易号时按原购买关联临时去重，后来补齐交易号应归并到原记录。

支付凭据只在本地匹配和去重，不上传到采集字段。跨重装原关联可能丢失，无法承诺客户端绝对去重；服务端分析可按已有平台订单号进一步归并。只有 check 返回待绑定、没有本次 report=completed 时，不补发购买 success。

### 8.2 采集发送可靠性

- 复用现有 collect 持久化队列，事件生成后固定 event_id；采集网络重传沿用同一 event_id。
- 业务状态推进、成功去重标记、待发送事件需要可恢复地协调。不能只用进程内 Set，否则重启会重复；也不能先写“已上报”再丢弃未入队事件。
- 建议实现业务 outbox：先保存待采集事件及稳定 ID，再交给 collect；失败可继续入队/发送，服务端按 event_id 去重。跨存储写入需要恢复步骤，不宣称天然 exactly-once。
- report=completed 与本地 outbox 写入仍有崩溃窗口，需要保留/恢复待处理凭据进行核对。观测遗漏不能被当成交易失败。
- 打点失败不能阻止用户支付、登录、绑定或正常界面退出。恢复责任放服务层，不依赖购买页面一直存在。
- 核心事件及登录/claim 结果建议全量；阶段诊断先全量验证，后续如采样必须单独标记，不能将采样诊断作为核心漏斗分母。

## 9. 示例

以下为说明格式的虚构值，不代表正式商品配置或真实订单。

### 游客点击年会员

```json
{
  "action_type": "pay_event",
  "action": "subscription_product_click",
  "object1": "pro_yearly",
  "object2": "track_id_pageA_click1",
  "object3": "subscription_sheet",
  "ext_data": "{\"schema_version\":1,\"provider\":\"google\",\"flow_origin\":\"direct\",\"trigger\":\"user_click\",\"checkout_login_state\":\"guest\",\"login_state\":\"guest\",\"page_source\":\"from_onboarding\",\"purchase_mode\":\"unknown\"}"
}
```

### report 确认成功

```json
{
  "action_type": "pay_event",
  "action": "subscription_success",
  "object1": "pro_yearly",
  "object2": "track_id_pageA_click1",
  "object3": "example-store-order-id",
  "ext_data": "{\"schema_version\":1,\"provider\":\"google\",\"flow_origin\":\"direct\",\"trigger\":\"store_callback\",\"checkout_login_state\":\"guest\",\"login_state\":\"guest\",\"transaction_id_present\":true}"
}
```

### 游客登录后，第二次 claim 请求绑定成功

```json
{
  "action_type": "pay_event",
  "action": "subscription_claim_result",
  "object1": "pro_yearly",
  "object2": "track_id_pageA_click1",
  "object3": "completed",
  "ext_data": "{\"schema_version\":1,\"provider\":\"google\",\"flow_origin\":\"direct\",\"trigger\":\"retry\",\"checkout_login_state\":\"guest\",\"login_state\":\"logged_in\",\"login_flow_id\":\"loginA\",\"request_attempt_id\":\"claimA2\",\"retry_count\":1}"
}
```

## 10. 验收场景与报表

| 场景 | 必须能观察到的结果 |
| --- | --- |
| 登录用户购买月/年会员 | 曝光 → 点击 → 平台回调 → report completed → success 一次。 |
| 游客购买并绑定 | 上述购买链路 + 实际强制登录曝光 → 登录成功 → claim completed；购买成功与绑定成功分别统计。 |
| 月升年 | 目标 plan_code=pro_yearly；已知前态时 purchase_mode=upgrade；错误定位到具体阶段。 |
| 年点月 | 点击 → failed/downgrade_not_allowed，无平台发起或 success。 |
| 用户取消、pending、长时间停留系统付款界面 | 仅取消有明确取消结果；pending 单独计；等待界面不自动伪造失败。 |
| report accepted 后重试 completed | pending 一次，实际 report 重试有独立请求编号，最终 success 一次。 |
| report 超时后补报成功 | timeout 与后续 success 可串联，订单最终计成功，不按失败事件条数计算失败率。 |
| 重复平台回调、重复 completed、进程重启 | 同一交易 success 不重复；沿用原关联及待发送事件。 |
| 无缓存启动恢复 | recovery 关联；guest check → 必要时登录 → claim；不补造曝光/点击/购买成功。 |
| 表单阻挡登录弹窗 | check 可成功；login_show 等表单完成且登录实际展示后才出现。 |
| claim 重试耗尽、钱包刷新失败、缓存清理失败 | 能明确区别未绑定、已绑定但刷新失败、已绑定但清理失败。 |
| 会话切换、不同设备、商店账号变化 | 旧回调仍归原流程，不根据新当前用户改写购买初始身份；恢复未知关联明确标记。 |
| Android 与 iOS | 分别验证查询、平台交接、取消、pending、成功、异常及恢复；不由单平台结果推断另一平台。 |

建议首批报表：曝光到点击转化率；直接点击到 report 完成率；按阶段/错误码的失败分布；pending 与观察窗口内未确认占比；游客登录转化率与最终 claim 完成率；月升年意图完成率；report/claim 重试完成率。

核心指标按独立 pageId、购买关联 ID、login_flow_id、绑定流程去重。按观察窗口展示尚未完成的队列，取消、业务拦截、技术异常、待确认分开。恢复与已确认续费单列，不进入新购买点击漏斗分母。

## 11. 落地位置与本次待评审项

| 代码位置 | 建议接入职责 |
| --- | --- |
| `lib/pages/gems/gem_wallet_page.dart`、`lib/components/gems/purchase_options_sheet.dart`、`lib/components/onboarding/personalization_gate.dart` | 容器 ID、实际 Subscription 曝光与入口来源。由一个可见性责任点触发，避免父子重复。 |
| `lib/components/gems/pro_subscription_content.dart`、`membership_purchase_presentation.dart` | 点击关联、选中套餐、传递 attemptId；真实成功确认操作仅影响现有流程。 |
| `lib/app/membership/membership_purchase_service.dart` | 准备、平台回调、report、核心终态与重试关联；不能仅在 UI 监听流打点。 |
| `lib/app/membership/membership_guest_startup_check.dart` | 有/无缓存的恢复检查及跳过原因。 |
| `lib/components/gems/membership_guest_login_gate.dart`、认证流程 | 真正展示登录及认证结果；覆盖个性化表单直接转强制登录的路径，统一去重。 |
| `lib/app/membership/membership_guest_claim.dart` | 每次 claim、退避、绑定确认、钱包刷新与清理。 |
| 拟新增 VIP analytics 适配层 | 事件映射、白名单、去重与 collect 入队，保持 Gems 适配层不变。 |

本稿建议确认：采用六个 subscription 核心事件；套餐标识用 plan_code；购买成功以 report completed 为准；游客登录和 claim 单独统计；现有 ext_data 承载诊断维度；不新增平台等待超时。确认后再实施代码与联调。

核对来源：当前正式业务代码中的 MembershipPurchaseService、MembershipPurchasePresentation、MembershipGuestLoginGate、membership_guest_claim.dart、membership_guest_startup_check.dart、membership_purchase.dart、membership_claim.dart，以及 Gems 的 billing_analytics.dart、billing_models.dart 和公共 collect_telemetry.dart。当前源码没有实现本稿列出的完整 subscription 业务采集事件；本稿不等于上线验收结果。
