# worldo Gems 产品设计

日期：2026-07-05
分支：`main_gems`
状态：用于 Figma 设计与 Flutter 静态高保真原型的设计草案

## 范围

本阶段只设计 worldo 的 Gems 体验，不实现后端。
Flutter 后续只做高保真静态原型，数据使用页面本地 fixture。
不要新增 API resource、repository、mock service、支付 SDK 或本地扣费逻辑。

## 目标

- 在 Me 页面展示用户当前 Gem 余额入口。
- 创建 Gem Wallet 页面，把付费充值和免费领取任务放在同一个页面。
- 创建 Gem Records 页面，用于未来展示充值、领取和消耗流水。
- 创建 Memory & Model 页面，用于 world 内的模型与记忆长度选择。
- 保持 world chat 和 progress 主流程安静，不在每次 message/progress 上显性展示消耗数量。
- 明确未来后端职责，避免前端先沉淀一套假的接口契约。

## 非目标

- 接入真实支付渠道。
- 实现后端 API。
- 实现本地 mock service 或模拟业务 repository。
- 增加 subscription 入口。
- 在 message 发送框或 progress 按钮上展示每次消耗的 Gem 数量。

## 设计系统要求

严格遵照 `worldo-design-spec.md`：

- 移动端画布：`375 x 778`。
- 页面左右边距：`20px`；主体内容宽度：`335px`。
- 页面背景：`#FFFFFF`。
- 主行动红色：`#F42C47`。
- 文本层级：`#333333`、`#444444`、`#666666`、`#999999`。
- 正文：`12px / 18px`。
- 顶部标题：`16px` semibold。
- 优先使用留白、分割线、图片/图标引导和克制的模块，不做重卡片化页面。
- 主 tab 页面需要为底部导航预留空间；二级工具页使用居中标题 header 和返回入口。

## 信息架构

### Me 页面入口

在已登录 Me 页的账号区域附近增加一个紧凑的 Gem 余额入口。

内容：

- Gem 图标。
- 当前余额，例如 `430`。
- 标签：`Gems`。
- 右侧 chevron 或轻量点击提示。

行为：

- 点击进入 `Gem Wallet`。
- 未登录时隐藏该入口，或沿用 Me 页现有未登录引导。

### Gem Wallet

目的：把购买 Gems 与免费领取 Gems 放在同一个页面，让用户每次做免费任务时都能看到充值区域。

模块顺序：

1. 余额
2. 充值套餐
3. 新手任务
4. Bonus 任务
5. Daily 任务
6. Join us 任务

Header：

- 居中标题：`Gems`。
- 左侧返回。
- 右侧 records 图标或文字按钮。
- 不出现 subscription 入口。

余额模块：

- 强展示当前 Gem 余额。
- 可借鉴参考图的红/粉氛围，但要适配 worldo 白底视觉系统。
- 不使用深色全页背景，整体仍然要像 worldo。

充值套餐：

- 6 个套餐，3 列网格。
- 每个套餐展示 Gem 数量、可选促销标签和价格。
- 示例套餐：`+500`、`+1100`、`+4400`、`+8800`、`+16500`、`+55000`。
- 一期充值按钮只是视觉占位。
- 点击行为：页面本地 toast 或短暂 pressed 反馈，例如 `Payment coming soon`。

新手任务：

- 一次性的新用户任务。
- 示例任务：
  - `Create your first worldo`
  - `Join your first world`
- 奖励在右侧展示，例如 `+50`。
- CTA 使用红色 pill button。

Bonus 任务：

- 偶发或更深度的参与任务。
- 示例任务：
  - `Invite a friend to a world`
  - `Write a comment`
  - `Share a worldo`

Daily 任务：

- 每日可重复任务。
- 示例任务：
  - `Daily check-in`
  - `Send a message`
  - `Progress a world`
- 已领取任务展示 disabled/claimed 状态。

Join us 任务：

- 社媒或社区关注任务。
- 示例条目：
  - `Discord`
  - `Instagram`
  - `TikTok`
  - `YouTube`
  - `X`
- 每行展示平台图标占位、奖励和 `Follow` CTA。

### Gem Records

目的：未来透明展示所有 Gem 增减流水。

Header：

- 居中标题：`Gem Records`。
- 左侧返回。

筛选：

- 文本 tab：`All`、`Earned`、`Spent`、`Top-up`。
- 激活态使用 worldo 红色下划线。

流水行：

- 标题：行为名称，例如 `Daily check-in`、`Message in #Moonlit Market`、`World progress`、`Top-up package`。
- 元信息：时间和来源。
- 数额：收入用 `+`，支出用 `-`；收入可以使用红色或更强文本强调，支出使用中性深色。
- 空状态使用柔和的居中文案，不使用重卡片。

### Memory & Model

入口：

- World map 右上角工具入口。
- Location chat 右上角工具入口。

目的：

- 让用户选择最大记忆长度和模型。
- 在该设置页内展示下一次预计 Gem 消耗。
- 保持 chat 发送和 world progress 主流程不展示显性费用标签。

Header：

- 左侧返回。
- 居中标题：`Memory & Model`。
- 右侧 `Save` 文字按钮。

Memory 区域：

- 当前记忆使用量，例如 `2K`。
- 最大记忆长度 slider。
- 设计稿建议使用离散值：`4K`、`32K`、`156K`、`512K`、`1M`。
- `Apply to all characters` toggle。
- 预留 `View details` 入口，用于未来解释记忆规则。

Model 区域：

- 区块标题：`Choose model`。
- 可选 `View details` 链接。
- 分组：
  - `Recommended`
  - `Basic`
- 每个模型卡片展示：
  - 模型名称。
  - 可选 `Hot` 或 `New` badge。
  - 下一次 message 预计消耗。
  - 简短描述。
  - 基于 memory 的消耗范围，例如 `4-320 gems`。
  - radio 选中/未选中状态。

静态设计示例模型：

- `Top Pick V3`，带 `Hot`，预计下一条 message `4 gems`。
- `Top Pick V3.5`，预计下一条 message `4 gems`。
- `Luxury Selection V4.0`，带 `New`，预计下一条 message `9 gems`。
- `Sake Pro`，带 `New`，预计下一条 message `3 gems`。
- `Sake Max`，预计下一条 message `4 gems`。
- `Sake V2`，带 `Hot`，预计下一条 message `1 gem`。
- `Water`，带 `New`，预计下一条 message `1 gem`。

一期保存行为：

- 只更新当前页面打开期间的本地选中状态。
- 展示轻量确认反馈。
- 不写入 service 或 API。

## 产品逻辑

### Gem 获取方式

用户可以通过以下方式获得 Gems：

- 充值套餐。
- 新手任务。
- Bonus 任务。
- Daily 任务。
- Join us 任务。

一期充值：

- 只展示套餐卡片。
- 不接支付渠道。
- 文案避免承诺支付成功。

未来任务奖励逻辑：

- 后端决定任务资格、进度、是否可领取、奖励金额、冷却时间和最终发放。
- 前端只展示后端返回的状态。
- 前端永远不在本地授予权威余额。

任务状态：

- `available`：用户可以执行。
- `in_progress`：展示进度，例如 `0/3`。
- `claimable`：任务奖励可领取。
- `claimed`：当前周期或永久任务已领取。
- `locked`：条件未满足，暂不可用。

### Gem 消耗方式

Gem 消耗发生在：

- 每次 location chat message。
- 每次 world progress。

影响消耗的因素：

- 用户选择的模型。
- 用户选择的最大记忆长度。
- 当前实际记忆使用量。
- 行为类型：message 或 progress。
- 未来后端定价规则。

用户可见规则：

- 主 chat 和 progress UI 不在每次操作上展示消耗数量。
- Memory & Model 页面展示下一次预计消耗。
- 如果后端因为余额不足拒绝操作，前端展示明确的余额不足提示，并引导到 Gem Wallet。

权威归属：

- 后端是余额校验、定价和扣费的唯一权威。
- 前端展示的预计消耗只作为信息提示。

### 余额状态

UI 未来需要支持：

- 正常余额。
- 低余额。
- 余额不足。
- 余额加载中。
- 余额不可用。

静态原型阶段只使用正常余额状态；如有必要，可在 MD 或 Figma 注释中说明未来状态。

### 未来接入时的错误处理

未来后端可能返回：

- Gems 不足。
- 任务不可领取。
- 任务已领取。
- 支付订单不可用。
- 定价已变化。
- 模型不可用。
- 记忆长度不可用。

建议前端处理：

- 根据严重程度使用简短 toast 或 bottom sheet。
- Gems 不足时引导到 Gem Wallet。
- 定价变化时刷新预计消耗，并让用户重试。
- 模型或记忆长度不可用时，回退到后端推荐默认值。

## 未来后端契约说明

以下是产品契约说明，不是当前前端实现任务。

Wallet：

- 获取余额。
- 获取充值套餐。
- 获取任务分组和任务状态。
- 领取任务奖励。
- 获取 Gem 流水。

Pricing：

- 获取模型列表。
- 获取某个 world 或角色的当前 memory/model 设置。
- 估算下一条 message 消耗。
- 估算下一次 progress 消耗。
- 保存 memory/model 设置。

Spending：

- Message 发送接口执行权威余额校验和扣费。
- World progress 接口执行权威余额校验和扣费。
- 接口响应尽量返回更新后的余额。

Records：

- 每一次发放或消耗都应生成不可变流水。
- 流水应包含金额、类型、来源、可选 world/location 上下文、时间戳，以及后端支持时的交易后余额。

## Figma 交付物

在 `G设计` Figma 文件中创建高保真移动端 frame：

- `Gem Wallet`
- `Gem Records`
- `Memory & Model`
- 如空间允许，可增加一个 Me 页 Gem 入口示例 frame/component。

Frame 要求：

- 宽度 `375px`。
- 使用 `20px` 左右边距和 `335px` 内容宽度。
- 遵循 worldo 白底、红色、灰阶设计系统，不沿用竞品的深色调。
- 竞品参考图只借鉴结构和信息层级，不直接复制视觉语言。

## Flutter 静态原型规则

Figma 设计通过后，进入 Flutter 实现时：

- 增加 route 和页面。
- 使用页面本地 fixture 数据，或 UI-only fixture 文件。
- 不创建后端 API class。
- 不创建 mock service/repository 抽象。
- action handler 保持本地且易替换。
- 如有必要，只补充路由和稳定渲染相关测试。

## 验收标准

- 已登录 Me 页有可见的 Gem 余额入口。
- Gem Wallet 页面符合 Figma 定稿和指定模块顺序。
- Gem Records 可以从 Wallet header 进入。
- Memory & Model 可以从 world map 和 location chat 进入。
- 主 chat 和 progress 控件不展示每次行为的 Gem 消耗标签。
- 静态原型不新增后端 API、repository、mock service 或支付 SDK 代码。
- 产品逻辑文档明确说明未来后端对定价、余额和扣费拥有权威。
