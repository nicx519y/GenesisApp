# Gems 购买打点

飞书同步工作表：[gems打点](https://my.feishu.cn/wiki/WPRDwshzciQYvdk5nzQceXkCn1d?sheet=1xK81p)

## Gems 购买打点 · 当前代码说明

- **统计口径**：仅当前进程内用户点击购买创建的尝试参与购买回调统计；来源随尝试保留。成功表示商店 purchased 回调，不等于服务端发放成功。

## 01 · 核心事件

| action_type | action | object1 · 入口 | object2 · 商品 | object3 · 事件内容 | 触发时机与条件 | object4 | ext_data |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pay_event | buy_page_show | 见第 02 节入口枚举 |  | buy_gems_page / buy_gems_sheet | Gems 页／弹层首次展示时记录；切换到 Gems 标签首次展示也记录。 |  |  |
| pay_event | product_click | 见第 02 节入口枚举 | 商店 productId |  | 接受有效点击后立即记录，早于价格确认和购买服务；禁用和防重入拦截不记录。 |  |  |
| pay_event | purchase_pending | 见第 02 节入口枚举 | 商店 productId | store_callback_pending | 匹配本次购买的商店 pending 回调；暂不 report，后续 purchased 可继续处理。 |  |  |
| pay_event | purchase_success | 见第 02 节入口枚举 | 商店 productId | 本笔 transaction_id | 匹配当前尝试的 purchased 回调，按交易去重；不等待 report。无尝试的旧交易／restored 不报。 |  |  |
| monitor | purchase_failed | 见第 02 节入口枚举 | 商店 productId | 见第 03 节失败阶段与超时 | 前置检查、商品查询、商店拉起、取消／错误回调、购买流异常、准备超时或 report rejected。 |  | JSON 字符串；见第 04 节 |
| monitor | purchase_success_skipped | 见第 02 节入口枚举 | 商店 productId | 见第 06 节 object3 原因枚举 | 收到可关联本次点击的 purchased 回调，因校验或去重未报成功时记录。 |  |  |

## 02 · 入口枚举

- **from_me_gems**：Me 页 Gems 入口

- **from_tick_no_balance**：World tick 余额不足入口

- **from_msg_low_balance**：消息余额偏低入口

- **from_msg_no_balance**：消息余额不足入口

- **from_subscription_tab**：从订阅页／订阅弹层切换到 Gems 标签

- **入口继承**：曝光、点击、pending、失败和成功沿用同一业务入口；页面／弹层类型仅在曝光 object3。未知入口 from_unknown 不上报 Gems 事件，不阻断购买。旧 buy_gems_page／buy_gems_sheet 枚举仅兼容内部旧调用，正式 UI 已传业务入口。

## 03 · 失败阶段与超时

- **object3**：格式为 `阶段_failed[reason=具体原因]`。共享分类器将错误归一化为以下阶段，更细操作见 `ext_data.step`。

| 阶段 | 含义 |
| --- | --- |
| precheck | 购买前置条件检查 |
| prepare | 监听启动、账号 UUID、本地准备等；服务不可用也可能归入此阶段 |
| query | 商品目录、价格确认、商店商品查询 |
| launch | 向商店发起购买 |
| callback | 商店取消／失败回调、购买凭据缺失 |
| stream | 购买监听流异常或回调结果转换异常 |
| report | 服务端 report 拒绝 |
| unknown | 无法识别阶段时的兜底 |

- **平台错误**：Google 响应码、Apple 错误域／码和 SDK 错误保存在 ext_data，不拼接回 object3。

- **前置价格确认超时**：purchase_failed；query_failed[reason=timeout]；timeout_type=prepare，step=confirm_product。

- **购买准备超时**：总准备预算 30 秒；purchase_failed；prepare_failed[reason=timeout]。step 标明监听、账号 UUID、商品查询或拉起等操作。

- **系统支付交接后**：不设置此准备预算倒计时；超时不是订单最终失败，不主动补报；后续匹配的明确商店结果仍可处理。

- **超时去重**：purchase_timeout 已移除。使用 purchase_failed 独立超时去重键，不吞掉后续明确商店结果。

## 04 · ext_data 与空值

- **传输类型**：object1～object4 与 ext_data 最终均为字符串。object4 无业务赋值。除失败外，ext_data 无业务赋值；表格空白格表示不填业务内容。

- **失败 JSON**：schema_version=2、purchase_kind=consumable、source、product_id、商店 productId、attempt_id（可取得时）、provider、stage、step、reason、original_reason、payment_outcome；按实际分支增加诊断。

- **超时诊断**：timeout_type、耗时与具体 step 等按可取得信息填写；不伪造耗时、交易号或商店错误。

- **payment_outcome**：取消为 canceled；超时、监听异常或凭据缺失等不确定结果为 unknown；其余失败为 failed。

- **敏感信息**：诊断经白名单、脱敏及截断；不传购买 token、完整凭据、签名交易或账号敏感内容。

- **商品口径**：object2 为 Apple／Google 商店 SKU，不是 Gems 业务 product_id，也不是 offer_id；曝光无选中商品时留空。


## 05 · 任务列表与模型选择（保留原定义）

| 模块 | action_type | action | object1 | object2 | object3 |  |  |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Task | pay_event | task_claimed | task_code：        create_first_worldo        launch_first_world        invite_friend        write_comment        request_join_world        daily_checkin        send_message        progress_world        discord_follow |  |  |  |  |
| Mode | pay_event | switch_model_page | wid |  |  |  |  |
|  | pay_event | switch_model_save | wid | model_name |  |  |  |

## purchase_success_skipped

| object3 | 原因 |
| --- | --- |
| account_mismatch | 回调账号归属校验未通过。 |
| receipt_missing | purchased 回调缺少必要的购买凭据。 |
| duplicate_transaction | 本笔交易已统计过成功。 |
