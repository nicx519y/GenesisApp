# Gems Cent 客户端契约

新版客户端对所有数值型 Gems 统一使用整数 cent：接口解析、内存模型、业务计算、请求上传和本地 Mock 都保留原始 cent，不转换为浮点数。

## 字段映射

| 场景 | JSON 字段 | Dart 字段 |
|---|---|---|
| 钱包 | `wallet.balance_cent` | `GemWallet.balanceCent` |
| 流水普通宝石（红钻） | `list[].regular_amount_cent` | `GemRecordItem.regularAmountCent` |
| 流水会员宝石（粉钻） | `list[].membership_amount_cent` | `GemRecordItem.membershipAmountCent` |
| 商品 | `base_gems_cent`、`bonus_gems_cent` | `baseGemsCent`、`bonusGemsCent` |
| 购买完成 | `granted_gems_cent` | `GemPurchaseReport.grantedGemsCent` |
| 任务 | `reward_gems_cent` | `GemTask.rewardGemsCent` |
| 模型预估 | `estimated_next_message_gems_cent`、`estimated_next_tick_gems_cent` | `estimatedNextMessageGemsCent`、`estimatedNextTickGemsCent` |
| 模型消息区间 | `min_gems_cent`、`max_gems_cent` | `minGemsCent`、`maxGemsCent` |
| WebSocket 低余额 | `balance_cent` | `ChatroomBalanceLow.balanceCent` |

流水两个金额字段必返，允许 `null` 表示历史来源未知，不能转为 0；其他上述 cent 字段必须是 JSON 整数。字段缺失，或值为浮点数、字符串等其他类型时，客户端按协议错误处理，不使用其他字段回退。购买结果只有 `status=completed` 时要求并解析 `granted_gems_cent`；其他状态不承载发放金额。

## 展示规则

- 用户可见 Gems 数值（包括 Model item 的预计消息费用和消息区间）统一通过 `formatGemCent` 展示一位小数。
- cent 除以 100 后固定显示一位小数，并使用整数运算四舍五入到 0.1 Gem；例如 `100 -> 1.0`、`10 -> 0.1`、`105 -> 1.1`、`123456 -> 1,234.6`。
- 负数先按绝对值四舍五入，再恢复原始负号，即使舍入为零也保留；例如 `-10 -> -0.1`、`-1 -> -0.0`。流水按各自原始分项金额判断正负号和颜色，正数保留 `+` 及红色，负数保留 `-` 及原文字颜色。
- 服务端下发的 `title`、`description` 等文本保持原样，客户端不替换其中的数字。模型列表不再读取 `range_text`。

## Model item 范围（2026-09-14）

- `GET /api/v1/gem/model/list` 必传 `world_id`，仅 `err_no=0` 表示成功。每个模型必返整数 `min_gems_cent`、`max_gems_cent`、`min_memory_tokens`、`max_memory_tokens`；缺失、非整数或范围无效按协议错误处理，不以零或旧字段回退。
- `min_gems_cent` 必须等于 `estimated_next_message_gems_cent`，`max_gems_cent >= min_gems_cent >= 0`。客户端只格式化服务端报价，不实现定价公式。
- 消息区间显示 `2.2–4.8 gems`，整数金额保留 `.0`；两端显示值相等时合并为一个值。预计消息费用同样保留一位小数。底层 cent 保持整数原值，仅展示四舍五入。
- 模型的 `min_memory_tokens` 表示当前保存预算，`max_memory_tokens` 表示系统预算上限（并非价格区间对应的用量范围）。前者为正值，后者不得小于前者。
- 卡片 Memory 区间使用当前 World 的 `GET /api/v1/user/memory-settings?world_id=...` 返回的 `memory_used_tokens → memory_tokens`，每个模型重复显示。顶部、滑杆气泡和区间统一向上取整到整数 K：`500 → 1K`、`2400 → 3K`、`12400 → 13K`，`0` 保留为 `0`，取整到 1000K 时显示 `1M`；两端显示值相等时合并为单值，例如 `memory 32K`，不重复显示箭头和相同数字。
- 完整底部说明示例：`2.2–4.8 gems (memory 3K → 13K)`，允许自然换行。
- 保留 500ms 自动保存、对数映射及 1K 步进（接口边界不足整 K 时仍保留原始值并保持可达）。标题为 `Max memory token limit`，滑杆上下限分别读取 `memory-settings.min_memory_tokens` 和 `max_memory_tokens`，不使用客户端固定范围；拖动不预览卡片范围。滑杆显式横向 padding 和气泡共用 24px 轨道留边；气泡主体与尖角始终居中对齐操作柄，包含两端及 RTL；轨道两端到卡片边框各 19px。保存成功后联合获取 World 用量和模型报价，完成后一次更新卡片数据，并检查 World、请求版本与预算一致性。
- 报价刷新失败显示金额骨架及重试，已获取的 Memory 区间正常展示；用量失败显示 Memory 骨架，不把旧用量截断推算成新区间。失败数据不缓存为有效范围。保存本身失败时，滑杆或模型选择恢复到最近一次成功记录，并清除该次待提交操作；退出页面不重发失败请求。卡片保留此前确认的数据。旧请求失败不覆盖用户后续的新操作。超时等不确定结果同样先恢复显示，Memory 保留一次只读核对，不自动重试。
- 缓存仍由 WorldPage 生命周期管理；本次未扩展聊天事件触发的失效策略。mock 的报价仅用于测试，不代表实际计费。

## 边界

- `price_amount` 是法币最小单位，继续使用现有法币格式化和支付逻辑，不属于 Gems cent 展示转换。
- 支付请求、任务请求、订单恢复和订单持久化不修改金额语义。
- 任务领取成功后继续刷新钱包；不从领取响应建立第二条本地余额更新链路。

## Gem Records 分项金额（2026-09-16）

- 客户端移除 `amount_cent` 总额字段，不使用它回退。`membership_amount_cent` 对应粉钻 `roseGemIconAsset`，`regular_amount_cent` 对应红钻 `gemIconAsset`；图标放在金额后。
- 仅显示非零分项；两项都非零时右侧同一行先展示红钻金额、再展示粉钻金额，组间距 8px，保留现有字号和文字颜色，钻石尺寸为 9×12。
- 两项都明确为 0 时只显示 `-0.0` 加红钻，使用支出文字颜色。
- 流水标题默认 14px，根据金额区域占用后剩余的宽度按 0.5px 递减，最小 8px；最小字号仍放不下时单行省略。测量与显示共用字体、系统文字缩放和字重。
- `null` 不是零，不显示该未知分项；仍展示已知的非零分项。如果没有可展示的非零分项且不满足两项都为 0，则显示 `--`，不使用总额或虚构零消费。
- 查询参数、分页、服务端标题、世界 ID 展示和复制行为不变。Mock 与测试使用分项字段，不代表实际计费。
