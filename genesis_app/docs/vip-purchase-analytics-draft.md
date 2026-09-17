# VIP 购买打点方案（精简评审版）

日期：2026-09-16。状态：已按[飞书方案](https://my.feishu.cn/wiki/WPRDwshzciQYvdk5nzQceXkCn1d?sheet=ELAQ6i)接入客户端并完成本地自动化验证，待真机支付与线上上报验收。

## 1. 范围与公共参数

仅保留六个核心事件和 `subscription_claim_result`，共 **7 个事件**。全部使用 `action_type=pay_event`，沿用 action / object1 / object2 / object3。不增加阶段、游客检查、登录曝光或登录结果事件，不增加专用 ext_data 维度。

登录状态复用公共 UID：有效 UID 非空表示事件发生时已登录；未登录时 UID 为空。当前 collect 在事件入队时保存用户上下文，通过公共 X-UID 发送，不在业务字段重复传 UID。正常初始化后使用该口径；身份尚未初始化或采集上下文异常不能直接推断游客。

游客登录后，后续事件会有 UID。判断是否由游客发起购买，应按 object2 关联，查看 subscription_purchase_click 当时的 UID，不能用 claim 事件的 UID 倒推。没有原点击的恢复订单，不猜最初登录状态。

不改购买、重试、超时、登录拦截、UI 或 Gems 原有业务；不为打点增加接口请求。Firebase 收入统计保持原逻辑。

## 2. 事件表（共 7 个）

| action | object1 | object2 | object3 | 触发时机 |
| --- | --- | --- | --- | --- |
| subscription_page_show | subscription_page / subscription_sheet | track_id_{pageId} | 第 4 节入口来源 | Subscription 首次实际可见，包括加载状态；隐藏 Tab 仅构建不记录。 |
| subscription_purchase_click | yearly / monthly | track_id_{pageId}_{clickId} | subscription_page / subscription_sheet | 点击底部购买按钮并进入购买回调，在异步准备和降级检查之前；object1 取本次选中的商品套餐，年会员为 yearly，月会员为 monthly；仅切换套餐或禁用按钮未触发回调不记录。 |
| subscription_pending |  | 本次购买关联 ID | store_callback_pending / report_accepted | 平台明确 pending 或 report 明确 accepted；独立记录，不归到 failed。 |
| subscription_timeout |  | 本次购买关联 ID | prepare / store_callback / report | 准备超时、Apple 调用已返回后的匹配回调等待超时，或实际 report 请求超时；独立记录，不重复发 failed。 |
| subscription_success | 第 4 节入口来源 | 本次购买关联 ID | 本笔商店订单号，没有则空字符串 | 首次 report.status=completed；不等登录、绑定或点击成功弹窗。 |
| subscription_failed |  | 本次购买关联 ID | 第 3 节平台原始错误信息或兜底原因 | 实际失败、取消、业务拦截、平台错误、report 拒绝或非超时异常。 |
| subscription_claim_result |  | 原购买关联 ID；无法还原则稳定 recovery_{id} | completed / accepted / rejected / error[error_code] / timeout | 每次实际 claim 请求返回结果时记录；无码用 error。不记录 start，不另加阶段事件。 |

平台 purchased/restored 进入既有 report 流程，不单独增加回调事件，也不能仅因尚未 report 完成就发 failed。其后按 report 结果记录 success、pending、timeout 或 failed。

report 模型仅有 status；订单号取平台回调或精确匹配的已保存凭据，不从 report 编造订单号、report_id、reason。Google 用本笔订单号，Apple 用本次 transactionId，不以 UUID 或 purchaseToken 代替。

## 3. subscription_failed.object3 原因

同一次失败只记录一次，object3 按以下优先级选择：平台原始错误码（包括查询、发起购买返回及购买回调）→ SDK 原始错误码 → 明确失败/取消状态 → 客户端兜底原因。有平台信息时，不再用 service_unavailable、query_failed、launch_failed、purchase_callback_error、canceled 等笼统分类覆盖。

平台信息统一序列化到 object3，不新增事件或字段。以下花括号为真实返回值占位符；没有的子码、domain 或 status 省略，不猜码。保留平台主码，子码只能追加，不能替换主码。无原生码时保留 SDK 的真实 source/code。debugMessage/message 不作为统计分类，不按提示文案猜原因；不透传 token、UUID、订单凭据等敏感内容。

| object3 | 含义 |
| --- | --- |
| service_unavailable | 仅客户端判断购买服务不可用，且无平台/SDK 错误信息时兜底。 |
| purchase_in_progress | 客户端已有购买进行中，防重入拦截；不替代平台已有商品等错误。 |
| downgrade_not_allowed | 客户端确认有效年会员购买月会员，被降级规则拦截。 |
| provider_mismatch | 客户端商品平台与实际支付平台不匹配。 |
| catalog_unavailable | 客户端商品配置缺失、变化或无法唯一匹配；有平台错误码则优先用平台信息。 |
| guest_prepare_failed[code] | 游客身份准备接口失败，保留真实服务端/网络错误码；无码省略方括号。 |
| uuid_unavailable | 无有效购买 UUID，客户端无法继续。 |
| local_storage_failed | 必需本地保存失败，阻断购买。 |
| google[response_code={code};sub_response_code={subcode}] | Google 原始返回/回调错误码优先，包括取消；子码仅实际返回时追加，不用本地归一化原因替换。 |
| apple[domain={domain};code={code}] | Apple 原始返回/回调错误信息优先，包括取消；保留实际错误域及错误码，错误域未提供则省略。 |
| sdk[source={source};code={code}] | 无平台原始错误码时，保留 SDK 实际返回的 source/code；不把 SDK 码伪装成平台原生码。 |
| store_failure[stage={query/launch/callback};status={status}] | 仅平台/SDK 均无错误码但明确失败或取消时兜底；stage 填发生阶段，status 填实际状态，未知则省略。明确取消但无码可记 stage=callback;status=canceled。 |
| session_changed | 准备期间账号或登录状态改变，客户端中止。 |
| receipt_missing | 业务所需凭据缺失；不能据此认定未扣款。 |
| signed_transaction_missing | Apple 游客上报所需签名交易缺失。 |
| report_failed[code] | report 非超时网络异常、接口错误或解析失败；优先保留真实接口/网络错误码，无码省略方括号，不套用 Google 码。 |
| report_rejected | report.status=rejected；响应无 reason，不编造原因。 |
| unknown_error | 明确发生异常且无平台/SDK 信息、无更准确客户端分类时兜底；无回调不等于错误。 |

**pending 与 timeout 保持独立，不在 failed 重复统计。** 平台明确 pending → subscription_pending；客户端准备计时到期、Apple 调用已返回后的匹配回调等待超时，或 report 请求超时 → subscription_timeout。store_callback 计时不包含用户停留在 Apple 付款页的时间。平台返回明确失败码，即使码名含 timeout，仍在 subscription_failed 保留该平台码，不额外补发 timeout。平台返回成功、purchased/restored 不记 failed，继续既有 report 流程。

同一平台失败在查询/发起购买返回、购买回调、外层 catch 或状态监听重复传递时，只由一个责任点记录一次，并优先使用该失败可取得的原始平台信息；不能同时记平台码和本地兜底原因。不得为等待补充信息新增固定等待或接口请求。后续新的 report 请求失败属于独立结果，按真实请求记录，不跨请求吞掉重试结果。

## 4. Subscription 入口来源

| page_source / page_show.object3 / success.object1 | 入口 |
| --- | --- |
| from_home_membership | Home 会员入口。 |
| from_me_membership | Me 会员卡片。 |
| from_me_pink_gems | Me 粉钻入口。 |
| from_daily_check_in | 非会员签到弹窗订阅入口。 |
| from_chat_feature_quota | 聊天会员功能或次数引导。 |
| from_onboarding | 个性化资料保存后的订阅步骤。 |
| from_buy_gems_tab | 从 Buy Gems 切到 Subscription。 |
| from_unknown | 未提供或无法还原入口。 |

同一容器中，Subscription 首次可见记一次；反复切 Tab、build、刷新和回前台不重复。关闭后重开使用新 pageId。表单仍可见或直接转登录而未展示订阅时，不记订阅曝光。page_source 是入口枚举名称，不再单独写入 ext_data。subscription_success.object1 沿用本次购买发起时的入口来源，随购买关联保存；重试、登录或绑定不改变来源，恢复时无法还原则用 from_unknown。仅 subscription_purchase_click.object1 传 yearly / monthly，不传 plan_code；其余已清空的 object1 继续留空。

Buy Gems 只做增量：原文档、事件、字段、曝光时机和 tick_no_balance / msg_low_balance / msg_no_balance 保持不变，不加 from_。整页来源补充 me_gems（Me 红钻、Top Up、对应区域）和 subscription_tab（Subscription 切到 Buy Gems）；Sheet 追加 subscription_tab。反向切换的 Subscription 来源为 from_buy_gems_tab。

## 5. 关联、重试与去重

- 一个购买容器一个 pageId，每次真实购买点击一个 clickId；回调、report 重试和该购买的 claim 沿用 object2。不恢复已删除的 report HTTP request_id 参数。
- 原关联丢失的恢复流程使用稳定 recovery_{id}；不补造页面曝光或点击。成功事件的入口来源无法可靠还原用 from_unknown。
- 重复 pending/accepted 按 object2 + 原因去重。重复平台回调、重复 completed 不重复计 success；按平台 + 本笔交易身份归并，无订单号时先按原关联去重，补齐后归并。
- 每次真实 report 失败/超时分别记录；重试 completed 仍记一次 success，object2 不变。一个异常只由一个责任点记录，避免同一请求重复上报。
- 每次实际 claim 结果记一次；保持首次失败后最多额外 5 次退避重试的既有策略。claim completed 不重复计购买 success。同一游客身份多笔订单共用一次 claim 时，只记一次真实请求结果；不按订单数复制事件。
- 购买或绑定成功后的 wallet 刷新、客户端缓存清理失败，不撤销已完成结果；本版不再为这些步骤新增事件。Apple finish 与 Google acknowledge 统一由服务端处理，不属于客户端成功后的步骤。
- 准备沿用当前超时，平台交接后结束前置计时；不为系统付款页等待新增倒计时。report timeout 按真实 HTTP 结果记录。
- 复用 collect 持久化队列及 event_id 重传去重。业务关联须随待处理记录恢复；打点失败不阻塞支付、登录或绑定。跨重装不能承诺客户端绝对去重，以服务端订单核对为准。

## 6. 最小验收

| 场景 | 应记录 |
| --- | --- |
| 直接购买成功 | page_show → purchase_click → success；平台 pending 时插入 pending。 |
| 平台取消或错误 | purchase_click → failed，object3 优先保留平台原始错误码/子码；同一失败经外层捕获不重复记录，无码才用 SDK 或明确状态兜底。 |
| report accepted 后 completed | pending(report_accepted) → success，保持原关联。 |
| report 失败/超时后重试成功 | failed(report_failed[code]) 或 timeout(report) → success；不能仅凭失败条数判断最终失败。 |
| 游客购买后登录绑定 | 点击时公共 UID 为空；登录后的 claim_result 带 UID；completed 表示绑定成功。 |
| claim 重试 | 每次真实结果均为 claim_result，不增加重试或阶段 action。 |

只统计这 7 个事件支持的曝光、点击、购买结果和绑定结果；不再承诺独立登录曝光率、登录转化率或各准备阶段耗时。

## 7. 实现与验证记录

- 7 个订阅事件通过既有 collect 队列发送；购买和游客绑定待处理记录保存关联与来源，公共 UID 在事件入队时读取。
- 订阅曝光以实际可见绘制为准；已接入各入口来源及 Buy Gems 增量来源，保留既有支付流程、UI 和 HTTP 请求契约。
- 失败原因保留平台或 SDK 原始信息；平台回调、report 和 claim 分别在实际结果处记录，恢复流程复用关联，pending 和 success 复用稳定 event_id 去重。
- 本地 643 项相关回归测试通过；随后 136 项补充验证通过（与前者有重叠），覆盖事件字段、曝光、恢复关联、真实请求结果、错误码、collect UID/event_id 和 Gems 兼容性。
- 尚未进行 Android/iOS 真机支付、线上 collect 入库或报表验收；本地自动化测试不代表这些环节已完成。
