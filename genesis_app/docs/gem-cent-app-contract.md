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
| 模型消息区间 | `min_gems_cent`、`max_gems_cent` | `minGemsCent`、`maxGemsCent` |
| WebSocket 低余额 | `balance_cent` | `ChatroomBalanceLow.balanceCent` |

上述 cent 字段必须是 JSON 整数。字段缺失，或值为浮点数、字符串等其他类型时，客户端按协议错误处理，不使用其他字段回退。购买结果只有 `status=completed` 时要求并解析 `granted_gems_cent`；其他状态不承载发放金额。

## 展示规则

- 常规用户可见 Gems 数值通过 `formatGemCent` 展示；Model item 的预计消息费用和消息区间使用 `formatExactGemCent` 精确展示两位小数。
- cent 除以 100 后固定显示一位小数，并使用整数运算四舍五入到 0.1 Gem；例如 `100 -> 1.0`、`10 -> 0.1`、`105 -> 1.1`、`123456 -> 1,234.6`。
- 负数先按绝对值四舍五入，再恢复符号；例如 `-10 -> -0.1`。
- 服务端下发的 `title`、`description` 等文本保持原样，客户端不替换其中的数字。模型列表不再读取 `range_text`。

## Model item 范围（2026-09-14）

- `GET /api/v1/gem/model/list` 必传 `world_id`，仅 `err_no=0` 表示成功。每个模型必返整数 `min_gems_cent`、`max_gems_cent`、`min_memory_tokens`、`max_memory_tokens`；缺失、非整数或范围无效按协议错误处理，不以零或旧字段回退。
- `min_gems_cent` 必须等于 `estimated_next_message_gems_cent`，`max_gems_cent >= min_gems_cent >= 0`。客户端只格式化服务端报价，不实现定价公式。
- 消息区间显示 `2.16–4.83 gems`；两端相等显示 `4.83 gems`。预计消息费用同样保留两位小数；其余页面金额格式不变。
- 模型的 `min_memory_tokens` 表示当前保存预算，`max_memory_tokens` 表示系统预算上限（并非价格区间对应的用量范围）。前者为正值，后者不得小于前者。
- 卡片 Memory 区间使用当前 World 的 `GET /api/v1/user/memory-settings?world_id=...` 返回的 `memory_used_tokens → memory_tokens`，每个模型重复显示。复用页面已有精度：`500`、`2.4K`、`12.4K`、`1M`；两端显示值相等时合并为单值，例如 `memory 32K`，不重复显示箭头和相同数字。
- 完整底部说明示例：`2.16–4.83 gems (memory 2.4K → 12.4K)`，允许自然换行。
- 保留 500ms 自动保存和现有滑杆；拖动不预览卡片范围。保存成功后联合获取 World 用量和模型报价，完成后一次更新卡片数据，并检查 World、请求版本与预算一致性。
- 报价刷新失败显示金额骨架及重试，已获取的 Memory 区间正常展示；用量失败显示 Memory 骨架，不把旧用量截断推算成新区间。失败数据不缓存为有效范围。保存本身失败沿用现有处理，卡片保留此前确认的数据。
- 缓存仍由 WorldPage 生命周期管理；本次未扩展聊天事件触发的失效策略。mock 的报价仅用于测试，不代表实际计费。

## 边界

- `price_amount` 是法币最小单位，继续使用现有法币格式化和支付逻辑，不属于 Gems cent 展示转换。
- 支付请求、任务请求、订单恢复和订单持久化不修改金额语义。
- 任务领取成功后继续刷新钱包；不从领取响应建立第二条本地余额更新链路。
