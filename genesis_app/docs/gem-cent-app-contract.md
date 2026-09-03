# Gems Cent 客户端契约

新版客户端对所有数值型 Gems 统一使用整数 cent：接口解析、内存模型、业务计算、请求上传和本地 Mock 都保留原始 cent，不转换为浮点数。

## 字段映射

| 场景 | JSON 字段 | Dart 字段 |
|---|---|---|
| 钱包 | `wallet.balance_cent` | `GemWallet.balanceCent` |
| 流水 | `list[].amount_cent` | `GemRecordItem.amountCent` |
| 商品 | `base_gems_cent`、`bonus_gems_cent` | `baseGemsCent`、`bonusGemsCent` |
| 购买完成 | `granted_gems_cent` | `GemPurchaseReport.grantedGemsCent` |
| 任务 | `reward_gems_cent` | `GemTask.rewardGemsCent` |
| 模型预估 | `estimated_next_message_gems_cent`、`estimated_next_tick_gems_cent` | `estimatedNextMessageGemsCent`、`estimatedNextTickGemsCent` |
| WebSocket 低余额 | `balance_cent` | `ChatroomBalanceLow.balanceCent` |

上述 cent 字段必须是 JSON 整数。字段缺失，或值为浮点数、字符串等其他类型时，客户端按协议错误处理，不使用其他字段回退。购买结果只有 `status=completed` 时要求并解析 `granted_gems_cent`；其他状态不承载发放金额。

## 展示规则

- 所有用户可见的 Gems 数值通过 `formatGemCent` 展示。
- cent 除以 100 后固定显示一位小数，并使用整数运算四舍五入到 0.1 Gem；例如 `100 -> 1.0`、`10 -> 0.1`、`105 -> 1.1`、`123456 -> 1,234.6`。
- 负数先按绝对值四舍五入，再恢复符号；例如 `-10 -> -0.1`。
- 服务端下发的 `title`、`description`、`range_text` 等文本保持原样，客户端不替换其中的数字。

## 边界

- `price_amount` 是法币最小单位，继续使用现有法币格式化和支付逻辑，不属于 Gems cent 展示转换。
- 支付请求、任务请求、订单恢复和订单持久化不修改金额语义。
- 任务领取成功后继续刷新钱包；不从领取响应建立第二条本地余额更新链路。
