# 支付失败监控诊断（schema_version=2）

## 打点与分组

- 消耗型购买：monitor / purchase_failed；object1 仍为业务商品 ID。
- 订阅：monitor / subscription_failed；object1 仍为入口来源，不将它当作商品 ID。
- object3 统一为 `阶段_failed[reason=具体原因]`。完整原始商店错误保留在 ext_data；Google、Apple、SDK 不再取代阶段。
- 阶段为 precheck、prepare、query、launch、callback、stream；无法明确分类时为 unknown。具体步骤放 step，分类器只服务遥测，不参与购买决策。

| 阶段 | 范围 | 代表原因 |
| --- | --- | --- |
| precheck | 会话、并发、会员资格 | session_unavailable、purchase_in_progress、membership_check_failed、downgrade_not_allowed、provider_mismatch |
| prepare | 支付账号、游客身份、监听器、本地订单 | uuid_unavailable、guest_prepare_failed、listener_start_failed、local_storage_failed、service_unavailable |
| query | 商品目录、商店查询、价格与购买条件确认 | catalog_unavailable、product_not_found、product_not_purchasable、product_config_invalid、price_changed、offer_mismatch、store_query_error |
| launch | 调用商店购买接口 | launch_rejected、product_details_changed、invalid_native_product、store_launch_error |
| callback | 取消、错误回调及凭证检查 | canceled、store_error、receipt_missing、signed_transaction_missing |
| stream | 接收或转换购买事件 | result_conversion_error、upstream_stream_error、unknown_stream_error |

未确认产生位置的监听异常使用 unknown_stream_error，只有明确的类型／格式转换错误才标 result_conversion_error，不通过消息猜测。

## 诊断字段

- 关联：Gems attempt_id；订阅 tracking_id，并在实际调用位置补 attempt_id。商品 product_id/store_product_id、callback_product_id、association；订阅 source 保留入口。
- 分类：schema_version、purchase_kind、provider（google / apple）、stage、step、reason、original_reason、payment_outcome。
- 通用错误：error_type、error_code、error_source、error_layer、message、脱敏 stack_trace。没有实际原始字段时不补造。
- Google：response_code、sub_response_code、debug_message；Apple：native_code、domain、可取得的错误消息。
- HTTP：api_path、http_status、business_code、client_failure_code、transport_error_kind、可取得的 request_id；不包含请求体、响应体或认证信息。
- 现场：实际可获得的阶段／累计耗时、重试次数、前后台、是否交给商店、是否已收到回调。预期与实际价格、币种仅在对应检查位置记录。失败事件没有取得缓存命中信息时不猜测。

## 上报范围及隔离

仅显式点击后的商品确认失败、购买服务失败、商店回调和监听异常进入失败监控。预加载、商品预热失败不进入两类失败点。补齐点击后 catalog.confirm 失败、store_price_changed 和订阅凭证缺失。商品确认、购买准备和回调等待超时统一进入 purchase_failed／subscription_failed（monitor），object3=阶段_failed[reason=timeout]；ext_data 包含 timeout_type、stage、step、关联 ID 和实际可得的耗时，payment_outcome=unknown。超时独立去重，不表示已确认扣款失败。

分类、编码、失败 sink 均有异常隔离；Gems 遥测调用启用 bestEffort，Collect 入队和通用 sink 的异步异常也会被处理，其他遥测调用的默认行为不变；不新增 await、商店请求或重试，不改变付款调起、价格／资格校验、购买结果、发货与补单控制。多个捕获位置的同一失败继续去重；监听异常独立去重，不吞掉后续明确的取消、错误或成功结果。原始成功上报语义保持不变。

## 脱敏和长度

只允许明确的标量字段，不上传购买 token、收据、签名交易、支付账号 UUID、认证头或任意原生 payload。消息中明确的敏感赋值、邮箱、JWT 会遮盖；URL 去掉查询参数，堆栈清理用户目录名，保留代码文件和行号。保留普通长请求／关联 ID，不再把所有长串一律当作凭证。普通字符串最多700字符，堆栈最多1400字符；整个 JSON 不超过3900字符。超长时保留分类、关联与原始错误码，截短消息／堆栈或省略可选字段，写 diagnostics_truncated 与 truncated_fields。堆栈还原仍依赖对应版本的符号文件。

## 报表

支付监控位于聊天监控下方；消耗型与订阅分别统计，按阶段 → 中文原因 → 平台原始错误（包括子码／错误域）分组，每组最多展示最新200条。提供阶段说明、原因解释、原始错误消息和完整诊断。历史格式兼容解析；没有足够信息时保留未知阶段，不推算原因。取消与结果待确认单独标识；监听异常和凭证缺失不代表已确认扣款失败。事件数不等于失败订单数，不计算缺少分母的失败率。订阅 report 拒绝／异常、Gems report 拒绝以 report 阶段记录失败；Gems report 请求异常及 claim 异常不并入这两类失败点。

## 四条失败路径字段对齐

Gems 的 product_id 始终是业务商品 ID；订阅套餐使用 plan_code，store_product_id 始终是商店 SKU，不再在 product_id 中混放套餐代码与商店 SKU。订阅准备、回调、监听失败都在已知时携带真实 attempt_id，同时保留 tracking_id；两者不强行互相替代。失败回调保留 callback_product_id 和实际关联方式，空回调商品不伪造。Gems 支付服务尚未取得的早期失败也补齐尝试 ID、入口、当前平台和所选 SKU。SDK 只有错误码或来源而没有异常对象时仍标 sdk。event_status 表示当前事件状态；purchase_status 只在真实商店回调时记录，监听异常不伪造购买状态。Google 与 Apple 原始诊断字段保持各自语义；Apple 正常取消没有原生错误对象时不补造错误码。

订阅公共失败入口从本次购买记录补齐 base_plan_id、offer_id，覆盖商店取消／错误、凭证缺失、签名交易缺失及监听异常；记录创建前的并发拦截从本次点击商品补齐。Android 与 Apple 使用同一补传规则，空值由编码器省略，不从商品名称或全局当前订阅推算。
