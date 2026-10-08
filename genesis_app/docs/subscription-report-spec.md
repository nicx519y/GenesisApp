# 订阅报表指标方案

更新：2026-10-08。状态：报表设计，尚未确认后台已接入或线上数据已按此口径聚合。事件定义见 `vip-purchase-analytics-draft.md`。

订阅购买事件的 `object2` 留空，不再提供页面、点击、商店结果或 claim 之间的关联 ID。任何使用旧 `object2` 关联成功尝试、游客绑定或页面访问的报表查询必须停用或重写。

## 当前可直接统计

| 指标 | 口径 |
| --- | --- |
| 订阅页曝光事件数 | `subscription_page_show` 按 event_id 去重；当前事件不提供跨事件访问 ID。 |
| 购买点击事件数 | `subscription_purchase_click` 按 event_id 去重；`object3` 区分 yearly / monthly。 |
| 商店购买成功事件数 | `subscription_success` 按 event_id 去重；有交易号时可再按平台和交易号去重。 |
| 购买失败事件数 | `subscription_failed` 按 event_id 去重；`object3` 区分前置检查、商店商品查询、商店拉起失败与商店 canceled/error 回调。report 结果不产生该事件。 |
| 商店 pending 与客户端超时 | 分别统计 `subscription_pending`、`subscription_timeout`；pending 不计失败。 |
| 游客 claim 结果数 | `subscription_claim_result` 按 event_id 去重，`object3` 区分 completed / rejected / error / timeout。 |

入口来源取 `object1`；事件发生时的登录状态取公共 UID。缺交易号的成功事件不能按订单精确去重，不能据此认定服务端已发货。客户端 `subscription_success` 现在表示商店 purchased 回调，财务订单和会员权益以服务端数据为准。

## 不再从这些事件推导

由于没有跨事件关联 ID，单靠现有 Collect 事件不能准确计算“点击后成功率”“访问购买转化率”“同一次购买先失败后成功”“游客购买到 claim 的订单级转化”，也不能将某次成功归给特定的 yearly / monthly 点击。若报表需要这些指标，应关联服务端订单数据并另行定义可验证的关联契约。claim 一次可能覆盖多笔游客购买，不得把 claim.completed 次数当作绑定成功订单数。

report 请求失败率、服务端发货成功率、收入和退款仍需使用请求监控与服务端订单数据；购买结果 `pay_event` 不再包含 report 状态。上线时分别验收 Android / iOS 回调、pending 后购买成功、重复回调、游客登录前后 UID、缺交易号和晚到事件。
