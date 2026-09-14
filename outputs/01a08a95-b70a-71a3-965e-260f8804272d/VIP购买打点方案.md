# VIP 购买打点方案

版本：评审稿 v1，2026-09-14。本文为新增打点方案，尚未实现。

参考：[Gems 支付打点统计（飞书原表）](https://my.feishu.cn/wiki/WPRDwshzciQYvdk5nzQceXkCn1d?sheet=pXkE0d)。已读取该表 Gems 区域，并核对当前客户端购买入口、Tab、支付、report、游客 check 和 claim 流程。

## 0. 共用字段约定

| 字段或约定 | 定义 |
| --- | --- |
| action_type | 全部为 pay_event，保持原 Gems 采集协议。 |
| action | VIP 新增事件均以 subscription_ 开头；Gems 旧 action 名称保持不变。 |
| plan_code | 真实商品套餐值 pro_monthly / pro_yearly，填入 VIP 购买事件 object1。仅用于埋点，不增加 report / claim HTTP 参数。 |
| pageId / clickId | pageId 对应一次购买容器访问；clickId 对应一次可受理的购买按钮点击。object2 使用 track_id_{pageId} 或 track_id_{pageId}_{clickId}。 |
| 字段格式 | 核心六个事件 object3 为来源、状态原因或交易标识等标量；新增诊断事件 object3 为 JSON 字符串。 |
| 公共字段 | IP address、app_version、created_at 及现有公共用户/设备上下文沿用采集链路。provider 在诊断 JSON 中显式记录 google / apple，不能假设原表已经有 provider 列。 |
| 成功标识 | 优先真实 transaction_id，缺失时显式填 report_id:{report_id}。如后端 report_id 不能稳定对应交易，须在实施前确认稳定的订单关联键；不得用 token 替代。 |
| 点击口径 | 本稿默认 subscription_click 是底部购买按钮。月/年卡片切换使用可选 subscription_plan_select。 |
| 文档状态 | 六个核心事件为本次主体；五个诊断事件建议同时落地；一个套餐选择事件可选。全部为新增方案，未修改客户端埋点代码。 |

## 1. 核心事件

继续使用 `action_type=pay_event`。VIP 的 `action` 全部以 `subscription_` 开头。`object1/2/3` 沿用 Gems 的字段结构。IP address、app_version、created_at 和已有公共用户/设备上下文由现有采集链路提供，不挤占这三个业务字段。

本稿默认 `subscription_click` 指底部购买按钮点击，与 Gems 点击商品即发起购买的含义对齐。VIP 月/年卡片只切换选择，不发起购买；如需要统计卡片点击，使用第 2 节的可选事件，避免混在同一条转化漏斗中。

| 范围 | action_type | action | object1 | object2 | object3 | 触发时机及规则 |
| --- | --- | --- | --- | --- | --- | --- |
| 核心 | pay_event | subscription_page_show | subscription_page / subscription_sheet | track_id_{pageId} | 入口来源枚举 | Subscription Tab 首次实际可见时。全屏和 Sheet 都覆盖；打开 Gems Tab 不提前上报 VIP 曝光。具体去重见第 6 节。 |
| 核心 | pay_event | subscription_click | plan_code | track_id_{pageId}_{clickId} | subscription_page / subscription_sheet | 用户点击底部购买按钮，进入可处理的点击回调时，在异步资格校验之前上报。已订阅、禁止降级等拦截也有点击记录。 |
| 核心 | pay_event | subscription_pending | plan_code | 同一次购买的 pay_track_id | store_callback_pending / report_accepted | 平台明确返回 pending，或 report 返回 accepted。两种原因分别记录，同一购买、同一原因去重。表示尚待确认。 |
| 核心 | pay_event | subscription_timeout | plan_code | 同一次购买的 pay_track_id | prepare / store_no_callback / report | 达到对应阶段的观测超时阈值，或收到明确的超时异常。表示该阶段未确认完成，不判定扣款失败。阈值与边界见第 5 节。 |
| 核心 | pay_event | subscription_success | plan_code | 同一次购买的 pay_track_id | transaction_id；缺失时 report_id:{report_id} | report 首次明确返回 completed 时。游客 report 成功同样记录，但账号绑定是否成功单独看 claim。平台 purchased、HTTP 200、弹窗显示/关闭都不能替代此条件。 |
| 核心 | pay_event | subscription_failed | plan_code | 同一次购买的 pay_track_id | reason 或 reason[detail_code] | 明确发生资格拦截、查询/拉起失败、平台错误/取消、report 异常或 rejected 时。它表示一次失败节点，是否为最终失败要结合原因和后续结果判断。 |

`plan_code` 取当前真实商品的 `pro_monthly` / `pro_yearly`，用于区分月/年套餐。这里是埋点字段值，不是在 report / claim 请求中重新添加 `plan_code`。`pay_track_id` 也仅用于采集关联，不是恢复已移除的 HTTP `request_id`。

VIP 商品并没有与 Gems 完全一致的业务 `product_id` 字段，因此本方案明确把套餐标识放入 `object1`。Google 的两个套餐可能共用一个商店商品 ID，不能只用 `store_product_id` 区分月/年。诊断事件可以另外带真实商店商品、base plan 和 offer。

## 2. 建议补充的诊断事件

下面不是把 Gems 事件简单改名，而是为 VIP 的平台回调、游客强制登录和绑定流程补充可观测信息。六个核心事件可独立使用；若需要排查本次讨论的偶发问题，建议诊断事件同时落地。

新增诊断事件的 `object3` 为 JSON 字符串，仍使用原有采集字段，不新增接口顶层参数。核心六个事件保持上一节的标量格式。

| 范围 | action_type | action | object1 | object2 | object3 | 触发时机及规则 |
| --- | --- | --- | --- | --- | --- | --- |
| 建议 | pay_event | subscription_flow | plan_code；恢复未知套餐为 unknown | pay_track_id / recovery_id | 流程阶段 JSON | 每次真实阶段开始和结束记录。stage 包含 prepare、query_store、launch_store、store_callback、report、finish_store。用于区分卡在准备、平台还是服务端。 |
| 建议 | pay_event | subscription_guest_check | guest_purchase | recovery_id 或原 pay_track_id | check 诊断 JSON | 每轮游客恢复检查的开始、结果或跳过都记录。必须覆盖没有 UUID 因而未发出 check 的分支。不能只在接口回调里打点。 |
| 建议 | pay_event | subscription_login_show | guest_purchase | recovery_id 或原 pay_track_id | 登录曝光 JSON | 购买成功确认后或启动恢复后，强制登录弹窗实际显示时。仅设置“需要登录”标记不算曝光。 |
| 建议 | pay_event | subscription_login_result | guest_purchase | 与登录曝光相同的关联 ID | 登录结果 JSON | 强制登录流程返回成功、明确取消或失败时。不替代 claim 成功；App 被杀死且没有回调时，不推断 canceled。 |
| 建议 | pay_event | subscription_claim_result | plan_code；恢复未知套餐为 unknown | recovery_id 或原 pay_track_id | claim 结果 JSON | 每次 claim 的 completed / accepted / rejected / error / timeout，以及绑定后本地清理结果。仅接受服务端真实返回值；当前 claim 模型只有 status，不能编造 reason。 |
| 可选 | pay_event | subscription_plan_select | 新选中的 plan_code | track_id_{pageId} | subscription_page / subscription_sheet | 用户主动把选择从月切年或年切月时。默认选中、缓存回填、接口刷新恢复选择不触发，不生成购买 clickId。 |

### 诊断 JSON 字段

| 字段或事件 | 取值 | 说明 |
| --- | --- | --- |
| 通用 provider | google / apple | 来自实际支付适配器，不根据错误文案猜测。 |
| 通用 trigger | direct / retry / app_start / foreground / reinstall / store_update | 实际调用路径。只有明确识别重装场景时才用 reinstall，否则保持 app_start 或 store_update。 |
| 通用 login_state | guest / logged_in / unknown | 发起该事件时的登录状态；购买初始状态在流程中另保留 checkout_login_state。 |
| 通用 origin_page_id | 原 pageId；没有则省略 | 恢复仍能找到原点击时保留；不能伪造一个页面曝光。 |
| 通用 store_product_id / base_plan_id / offer_id | 真实已知值 | 仅诊断事件记录。没有就省略，不用测试商品或默认套餐补齐。 |
| 通用 retry_count / duration_ms | 非负整数 | retry_count 从首次 0 开始；duration_ms 是当前阶段耗时。 |
| subscription_flow | stage、status、provider、trigger、reason、error_code | status：start / success / error / timeout / canceled / pending / accepted / rejected / purchased / restored / skipped。按阶段限定含义，不把 SDK 调用返回 true 写成“支付窗已显示”。 |
| subscription_flow 的 catalog_source / uuid_source | cache / network / unknown；catalog / guest_prepare / user_profile / local_receipt / store / missing | 帮助定位缓存点击和购买身份来源。只记录来源类别，不记录 UUID。 |
| subscription_guest_check | status、reason、identity_source、candidate_count、uuid_present、check_requested、is_guest_purchase、retry_count | status：start / result / error / timeout / skipped。is_guest_purchase 只有真实接口返回后才填写；接口未调用时省略。 |
| subscription_guest_check 的 reason | uuid_missing / store_query_failed / no_purchase / pending_purchase / proof_missing / multiple_candidates / session_changed / no_guest_purchase / check_failed / login_required / gate_blocked | 根据实际分支记录；明确区分“没找到身份”和“接口返回 false”。gate_blocked 表示需要登录，但有其他流程暂时阻挡弹窗。 |
| subscription_login_show | trigger、login_state、forced | forced=true。触发来源为 purchase_success / startup_recovery / foreground_recovery。 |
| subscription_login_result | status、trigger、error_code | status：success / canceled / error。使用认证回调真实结果，不根据 claim 结果倒推登录结果。 |
| subscription_claim_result | stage、status、provider、trigger、retry_count、error_code | stage：request / cleanup。request 的 status 来自 claim；cleanup 为 success / error。两者分开，避免已绑定但清理失败被记成绑定失败。 |

示例：没有 UUID 时仍能记录为什么没请求 check：

```json
{
  "action_type": "pay_event",
  "action": "subscription_guest_check",
  "object1": "guest_purchase",
  "object2": "recovery_<recoveryId>",
  "object3": "{\"status\":\"skipped\",\"reason\":\"uuid_missing\",\"provider\":\"google\",\"trigger\":\"app_start\",\"uuid_present\":false,\"check_requested\":false}"
}
```

## 3. 入口来源与 Gems 调整

`object1` 保留页面形态，`object3` 表示直接入口。来源枚举描述用户从哪里进入，不用另一个事件名称充当来源。

### Subscription 曝光来源

| object3 建议值 | 实际入口 | 页面形态 | 备注 |
| --- | --- | --- | --- |
| home_membership | Home 顶部会员入口 | subscription_page | 直接选中 Subscription。 |
| me_membership | Me 会员卡片 | subscription_page | 直接选中 Subscription。 |
| me_pink_gems | Me 的 Pink Gems 图标、余额及对应点击区域 | subscription_page | 当前正式入口是全屏购买页。 |
| daily_check_in | 签到弹窗内的订阅入口 | subscription_sheet | 对应签到权益引导。 |
| chat_feature_quota | 聊天内会员功能或次数不足引导 | subscription_sheet | 具体功能可在诊断中带 feature，曝光先保持一个来源枚举。 |
| buy_gems_tab | 从 Buy Gems 切到 Subscription | 当前容器对应 page / sheet | 点击或滑动切换都覆盖。 |
| other | 已知存在但尚未细分的正式入口 | 实际形态 | 不当作默认兜底覆盖已有明确入口。 |
| unknown | 调用方未传来源或无法还原 | 实际形态 | 保留用于发现埋点接线遗漏。 |

### Gems 的新增来源

| Gems 事件 | 字段 | 调整建议 | 说明 |
| --- | --- | --- | --- |
| buy_page_show | object1 | 保持 buy_gems_page / buy_gems_sheet | 不改旧事件名称，也不把 Subscription 混入 Gems 的曝光。 |
| buy_page_show | object3 | 新增 subscription_tab | 从 Subscription 切到 Buy Gems 时上报，覆盖全屏和 Sheet。 |
| buy_page_show | object3 | 新增 me_red_gems / me_top_up | 可区分 Me 红 Gems 区域和 Top up 入口；已有能区分的点击区域分别传入。 |
| buy_page_show | object3 | 保留 tick_no_balance / msg_low_balance / msg_no_balance | 保留原表中三种余额引导来源。 |
| product_click | object3 | 保持 buy_gems_page / buy_gems_sheet | 此字段是点击时的页面形态，不要同时改成 subscription_tab。来源通过 pageId 关联曝光取得。 |
| purchase_pending / timeout / success / failed | 所有字段 | 保持原有 Gems 业务含义 | 本次只补缺少的曝光和来源，不混入 VIP 事件。 |

现有代码核对结果：全屏 `GemWalletPage` 只在首次访问 Gems Tab 时上报一次 `buy_page_show`；Sheet 的 Gems 曝光在 `showGemPurchaseBottomSheet` 入口发出，而从 `showSubscriptionPurchaseBottomSheet` 打开再切到 Gems 的路径没有相应曝光。实现时应由共享容器统一处理 Tab 可见性，移除重复的旧入口曝光，避免补点后双发。

## 4. 失败原因字典

所有原因放入 `subscription_failed.object3`。明确区分业务拦截、用户取消、技术异常和服务端拒绝。`reason[detail_code]` 的中括号只放稳定错误码，不放原始报错长文或支付凭据。

| reason / 格式 | 阶段或平台 | 触发条件 | 统计分类 | 后续含义 |
| --- | --- | --- | --- | --- |
| service_unavailable | 客户端准备 | 购买服务未装配或不可用 | 技术异常 | 尚未向平台下单。 |
| store_unavailable | Google / Apple | 实际商店服务不可用 | 环境异常 | Google 对应原 Gems 的 gp_unavailable，VIP 使用跨平台名称。 |
| uuid_unavailable | 身份准备 | 无法取得有效购买 UUID | 准备失败 | 尚未正常下单；详细来源放 subscription_flow。 |
| guest_prepare_failed[code] | 游客身份接口 | guest prepare 返回错误 | 接口异常 | 不等同于支付失败；超时单独记录 timeout。 |
| local_storage_failed | 本地保存 | 保存游客身份或必要购买恢复信息失败 | 技术异常 | 按当前业务流程的实际结果记录，不用埋点自行放行购买。 |
| eligibility_unavailable | 最新商品或会员查询 | 实时校验失败、套餐已变化或会员状态未知 | 校验未完成 | 不把未知状态当成 none；不使用已移除的 vip_status 字段作为新埋点依据。 |
| already_subscribed | 客户端资格校验 | 当前已有该套餐，点击被拦截 | 正常业务拦截 | 不计入平台支付技术失败率。 |
| downgrade_not_allowed | 客户端资格校验 | 当前年会员点击月套餐，业务禁止降级 | 正常业务拦截 | 不请求平台。 |
| purchase_in_progress | 防重入 | 实际接收到的新请求因已有购买进行中被拒绝 | 重复请求拦截 | 禁用按钮期间未进入回调的点击不伪造事件。 |
| session_changed | 身份校验 | 准备期间用户登录状态或账号改变，当前购买被中止 | 会话中止 | 原流程结束，新账号购买需要新 clickId。 |
| provider_mismatch | 配置校验 | 商品 provider 与实际支付平台不一致 | 配置异常 | 尚未正常下单。 |
| product_config_invalid | 商品配置 | 缺少商店商品 ID、base plan 或配置不合法 | 配置异常 | 不捏造正式商品 ID 或套餐默认值。 |
| query_failed[provider.code] | 平台商品查询 | 查询失败或指定套餐/offer 不可用 | 平台查询异常 | 记录真实 SDK 错误码，未知码用 unknown。 |
| launch_failed[provider.code] | 平台拉起 | SDK 返回失败、false 或抛出拉起异常 | 平台拉起异常 | 返回 true 也只表示调用被接受，不保证支付 UI 实际曝光。 |
| purchase_callback_error[provider.code] | 平台回调 | SDK 返回明确 error | 平台支付异常 | 比如 Google ITEM_ALREADY_OWNED，使用实际回调码。不能仅凭英文弹窗猜码。 |
| purchase_token_missing | Google 凭据 | 应有购买凭据的回调缺少 purchaseToken | 凭据异常 | 等待恢复凭据；不表示没有扣款。 |
| transaction_id_missing | Apple 凭据 | 应有交易信息的回调缺少 transactionId | 凭据异常 | 等待恢复凭据。 |
| signed_transaction_missing | Apple 游客凭据 | guest report / claim 需要的签名交易缺失 | 凭据异常 | 与登录后的普通 report 字段要求区分。 |
| report_failed[code] | report 请求 | 网络、HTTP、业务 envelope 或解析异常 | 上报异常 | 保留原凭据重试，不判定平台扣款失败。 |
| report_rejected[account_mismatch] | report 结果 | 服务端明确拒绝，归属账号不匹配 | 归属拒绝 | 与后台重试、切换到归属账号处理分开，不能记为购买成功。 |
| report_rejected[invalid_purchase] | report 结果 | 服务端明确验单不通过 | 验单拒绝 | 以服务端真实 reason 为准。 |
| report_rejected[reason] | report 结果 | product_mismatch、purchase_canceled、purchase_revoked 或其他真实 reason | 服务端拒绝 | 未知 reason 保留稳定编码，不丢点、不强行归到已知枚举。 |
| canceled | Google / Apple | 用户取消的明确回调或 SDK 取消错误 | 用户取消 | 两端统一使用 canceled；不计入技术失败率。 |
| unknown_error | 未识别阶段 | 真实异常暂时无法分类 | 未分类异常 | 用 subscription_flow 记录 stage 和可用错误码。不能用它替代正常 pending。 |

原始错误码应同时保留“来自哪一层”：Google / Apple SDK、插件包装层、HTTP 或后端业务码。例如 Apple 的 `storekit_duplicate_product_object` 属于插件/StoreKit 拉起阶段，可记录 `launch_failed[apple.storekit_duplicate_product_object]`。客户端 `already_subscribed` 与 Google 回调 `ITEM_ALREADY_OWNED` 不是同一个来源，必须分开。

## 5. Pending、超时和成功

| 条件 | 核心事件 | 结论及边界 |
| --- | --- | --- |
| 平台明确 pending | subscription_pending：store_callback_pending | 支付待完成。不能计为成功或失败。 |
| report=accepted | subscription_pending：report_accepted | 服务端已受理但未确认完成。继续后续确认，不计为 success。 |
| 平台 purchased，尚未 report completed | subscription_flow：store_callback / purchased | 仅证明收到平台已购买回调。不能计为订阅发放成功。 |
| report=completed | subscription_success | 服务端确认本笔购买。游客绑定需另看 claim；当前权益和生效时间仍以服务端会员数据为准。 |
| 游客 claim=completed | subscription_claim_result：request / completed | 账号绑定完成。不能再次补一条 subscription_success，否则同一单重复计数。 |
| prepare 超时 | subscription_timeout：prepare | 当前 VIP 准备阶段超时配置为 90 秒；平台交接后会取消此计时。不能直接把它写成现有 VIP“平台 90 秒无回调”规则。 |
| 平台交接后长期没有回调 | subscription_timeout：store_no_callback | 建议新增观测点。若沿用 Gems 90 秒阈值，应从平台交接时计时，只记录未确认，不自动认定失败或重复下单。支付 UI 等待用户输入也可能命中。 |
| report 请求超时 | subscription_timeout：report | 以 VIP 请求实际超时预算/超时异常为准。Gems 表写的是 15 秒，本稿不把 15 秒当成当前 VIP 已实现的配置。 |
| report completed 后本地清理或 Apple finish 失败 | subscription_flow：finish_store / error，或 cleanup error | report 成功仍成立。记录收尾失败并恢复，不回滚为“付款失败”，也不重复发 success。 |

超时、report 网络异常和后续成功可以发生在同一 `pay_track_id` 下。报表应按关联 ID 看阶段和后续结果，不能把事件条数直接加成互斥的成功/失败订单数。超时异常已有 `subscription_timeout` 时，不再因同一异常重复计一条 `subscription_failed`；非超时 report 错误仍记 `report_failed`。

## 6. 曝光、关联和去重规则

| 主题 | 建议规则 |
| --- | --- |
| 页面访问 ID | 每次真正打开全屏购买页或 Sheet 生成一个 pageId。容器内部两个 Tab 共用该 pageId。关闭后再次打开生成新 pageId。 |
| 曝光次数 | 同一个容器内，每个 Tab 首次实际可见只发一次曝光，沿用当前 Gems 首访口径。A 到 B 再回 A 不重发 A；缓存刷新、重建、旋转、支付系统页返回也不重发。 |
| 来源归因 | 初始 Tab 用真实外部入口；另一个 Tab 首访用 buy_gems_tab 或 subscription_tab。所有首次来源在该容器内保持不变。分析原始外部入口时，通过相同 pageId 关联两个 Tab 的曝光，不另造容器事件。 |
| 实际可见 | Tab 切换确认完成、目标内容进入可见状态后记录。不能只看 widget 构建或 TabController 监听回调次数；点选和左右滑动都要覆盖。 |
| 缓存展示 | 缓存首屏可见算一次页面曝光；接口回来刷新不增加曝光。不要求等商品接口成功才发 page_show，否则加载失败会从漏斗消失。 |
| 登录态切换 | 同一容器仅因 session keyed subtree 重建，不生成重复 page_show；由容器持有 pageId 和已曝光集合。若路由实际关闭/重新打开才新建。 |
| 点击 ID | 每次实际受理的底部购买按钮点击新建 clickId，格式 track_id_{pageId}_{clickId}。一次点击之后的资格校验、平台、report 均沿用。前一次已结束后主动再点，使用新 clickId。 |
| 未进入点击回调 | 按钮禁用、防抖忽略、仅切换卡片、仅缓存刷新都不产生 subscription_click。无有效商品的禁用状态不伪造套餐点击。 |
| 跨重启恢复 | report 重试、延迟回调、跨重启恢复能关联到原购买时，持久化并沿用原 pay_track_id。禁止只生成新 ID 而丢失原点击关联。 |
| 无原点击的历史订单 | 使用 recovery_{recoveryId} 记录诊断与 claim，不补发 page_show / click，不混入本次页面购买漏斗。即使恢复到一笔有效老订单，也不是本次新成交。 |
| 恢复 ID | 同一轮 check、强制登录和 claim 复用 recoveryId；关联信息保留到流程完成。下一轮独立检查可生成新 ID，通过真实已知的原购买关联补充串联。 |
| 不同去重粒度 | 曝光按 pageId + Tab；pending 按购买 ID + 原因；timeout 按购买 ID + 阶段；failed 按购买 ID + 阶段 + 原因（核心事件去重，诊断可按 retry_count 保留每次请求）；success 按已确认的实际交易去重并保持原归因。 |
| 真正的新交易 | 同一用户重试按钮、重复平台回调不能算多次成交。不同真实交易可分别记录；Google 自动续费可能复用 token，不能只按 token 去重，应结合平台交易 ID/服务端稳定交易标识。 |
| 自动续订 | 没有本次用户购买点击的自动续订不补发 subscription_click / subscription_success。续订完整性应由服务端平台通知统计，本方案客户端漏斗不承担全量自动续订统计。 |
| 数据缺失 | 恢复订单无法确认月/年时写 unknown，仅用于恢复诊断，不猜套餐。SDK 无 transactionId 但 report 有 report_id 时，成功标识显式使用 report_id: 前缀。不能把 token 当订单号上报。 |
| 敏感凭据 | 采集不记录 account_uuid、purchase_token、signed_transaction、收据全文或原始支付报文。UUID 是否存在及其来源用布尔值/枚举表达，沿用现有 Gems 采集边界。 |
| 埋点不影响支付 | 采集异常不能打断正常支付、report、claim 或清理。新增采集不改变已确定的账户归属、重试和交易完成规则。 |
| 未收到结尾 | 客户端被杀死、断网或未再启动，可能没有最终事件。归类为未确认，不能直接当失败；按约定观察窗口标注统计截点。 |

## 7. 验收场景

| 场景 | 预期事件/检查 |
| --- | --- |
| Home 进入 Subscription 全屏 | 一条 subscription_page_show，object1=subscription_page，object3=home_membership。 |
| 初始进入 Buy Gems，从未切到 VIP | 只有 Gems buy_page_show，没有 subscription_page_show。 |
| Gems Sheet 切到 VIP，再切回来 | 各 Tab 首访各一条曝光，共用 pageId；返回已访问 Tab 不重发。 |
| VIP Sheet 切到 Gems | 补齐 buy_page_show，object1=buy_gems_sheet，object3=subscription_tab。 |
| 连续缓存回填、接口刷新、组件重建 | 不新增曝光、不产生点击。 |
| 点月/年卡片后点购买 | 默认方案卡片不记 subscription_click，底部按钮记一次；启用可选 plan_select 时单独记录选项变化。 |
| 年会员点击月购买 | subscription_click 后 subscription_failed=downgrade_not_allowed，没有平台支付调用。 |
| 平台重复 purchased 回调，report 重试 completed | 原购买 ID 不变，subscription_success 最多一条。 |
| pending 后成功 | pending 和 success 沿用同一购买 ID，pending 不算失败。 |
| report accepted 后成功 | report_accepted 和 success 沿用同一购买 ID，accepted 不算成功。 |
| report 超时后重试成功 | timeout 后可有 success；统计最终成功，另算曾超时的比例。 |
| report rejected / account_mismatch | failed 明确带 account_mismatch；不会因重装/重复回调伪造一笔新支付成功。 |
| 游客购买完成、确认成功提示、登录并 claim | success、login_show、login_result=success、claim_result=request/completed 分别记录；绑定不重复记成交。 |
| 启动缺 UUID，未调用 check | guest_check 明确 uuid_missing、uuid_present=false、check_requested=false；不记录接口返回 false。 |
| check 返回 true，但被其他流程挡住弹窗 | 记录需要登录及 gate_blocked；等真实展示时才记 login_show。 |
| claim accepted 或网络失败，稍后重试完成 | 每次诊断带 retry_count，登录成功与绑定成功分开；不再次请求平台支付。 |
| 绑定成功但缓存清理失败 | claim_result=request/completed 与 cleanup/error 分开；清理重试不能再计一次 claim 成功。 |
| Android 与 iOS 同时验证 | 相同业务事件和 canceled 拼写；错误码保留真实平台/插件来源，不能互相套用。 |

## 8. 报表口径与实施边界

| 指标 | 口径 |
| --- | --- |
| 页面点击率 | 有 subscription_click 的 VIP 页面访问数 / VIP 页面曝光访问数，按同一 pageId cohort 关联。 |
| 购买成功率 | 有 subscription_success 的有效购买 clickId 数 / 有效购买 clickId 数，按同一进入时间 cohort 和观察截止时间统计。 |
| 取消、拦截与异常 | canceled、already_subscribed / downgrade_not_allowed 等业务拦截、技术失败分别展示。阶段事件可能先失败后成功，不能直接相加作互斥订单数。 |
| 游客绑定率 | checkout_login_state=guest 且 report completed 的购买中，最终 claim completed 的比例。需要诊断字段或等价的可靠购买时登录态数据；仅六个核心事件不足以完整区分。 |
| 未确认结果 | 等待付款、accepted、超时以及没有结束事件均保留为待确认。成功补报归回原点击 cohort，不直接除以补报当天的新点击。 |
| 自动续订 | 本方案统计用户主动购买链路。没有本次点击的自动续订由服务端平台通知单独统计，不补造点击与新成交。 |

页面曝光按 `pageId + Tab` 去重。VIP 页面点击率为发生 `subscription_click` 的 VIP 页面访问数 / VIP 页面曝光访问数，按同一页面访问 cohort 关联；购买成功率为关联到 `subscription_success` 的购买 clickId 数 / 有效购买 clickId 数。用户取消率、资格拦截率、技术异常率分别展示，不相加当成互斥最终结果。

游客绑定率应只统计游客购买 cohort：诊断中 checkout_login_state=guest、且已 report completed 的购买，关联到 claim completed 的比例；普通“登录成功”不进入绑定成功分子。核心六个事件单独使用时无法完整区分游客 cohort，需要同时落地诊断字段，或已有可靠的购买时登录态数据。

诊断 `subscription_flow` 的 report / guest prepare / query_store 等一发一回用同一个关联 ID 和 retry_count 对齐；同一次支付的当前节点失败并不取消后来发生的成功。所有转化率应使用同一进入时间 cohort，并标注观察截止时间，避免用“今天发生的补报成功”直接除以“今天新点击”。

本次新增的是采集方案，不改会员接口、购买 UI、重试策略或支付业务代码。当前客户端已有 Firebase `purchase` / `subscription_first` 等支付事件，它们和本方案 `pay_event` 漏斗口径不同，不能直接替代新增事件，也不在本次方案中改名。

当前代码核对基线：`feature/message-vip`，HEAD `261efa39`，2026-09-14 工作区。主要核对 `GemWalletPage`、`PurchaseOptionsSheet`、`ProSubscriptionContent`、`MembershipPurchaseService`、`MembershipGuestLoginGate`、`GenesisBillingAnalytics`。上述新增事件均为拟定规范，不表示已经上线。
