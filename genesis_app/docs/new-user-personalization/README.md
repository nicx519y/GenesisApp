# 新用户个性化引导：流程与后端对接需求

更新日期：2026-09-14。本文为当前交接版本；**用户流程和接口在前，样式规范集中在最后一节**。

本轮已完成前端样式与交互预览。首次启动拦截、设备资料持久化、UID 资料读写、按 Gender 刷新推荐，以及本流程的真实登录和支付尚未接入。现有 App 的登录、商品及购买服务可以复用，但不能把“服务已存在”视为“新用户流程已接通”。

## 1. 交付文件与截图说明

本目录包含需求正文、7 张直接从手机截取的原图、7 张逻辑标注图和可交互标注页。

- [截图标注总览](screenshots.html)：点击编号说明，高亮原图对应区域。
- `*-phone.png`：连接 Android 真机，通过 `adb exec-out screencap -p` 直接截图，未重画 App 内容。
- `*-annotated.png`：原始手机截图加编号、区域框和逻辑说明的标注文档图。
- [原图记录](capture-manifest.json)：来源、尺寸与文件 SHA-256。
- [标注数据](annotations.json)：标注编号与说明，可继续维护。

真机截图为 1080×2340，DPR 2.8125，对应 384×832 个逻辑像素。本次展示的是手机上运行的 **Developer 前端预览**，底层为真实 For You 列表；登录结果和订阅商品在预览中模拟。没有真实登录、保存资料或支付。图中的 `Preview options` 和 `debug` 仅供开发操作，不是正式新用户流程入口。截图中的价格、折扣不能作为线上商品配置；列表画面不能作为个性化推荐已生效的证据。

## 2. 用户流程

### F01 — 启动时并行加载列表与检查资料

App 启动时正常挂载 Worldo list，列表初始加载与资料检查并行。已有缓存先展示缓存，无缓存使用现有加载骨架；网络失败保留可理解的错误和重试入口，底层不能空白。

没有登录会话时，使用现有 `DeviceIdService.getDeviceId()` 获取设备身份，查询该设备是否已完成 Gender 与 Age；已有登录会话时，读取当前 UID 的资料，UID 状态优先。资料检查尚未完成时不允许进入其它功能绕过本流程。查询失败属于“未知 / 可重试”，不得当成“已填写”放行，也不得当成“未填写”覆盖服务端资料。

### F02 — 是否展示表单

| 身份及已保存状态 | 结果 |
| --- | --- |
| 游客，deviceid 两项都没有 | 弹出必填表单，显示 Sign in 链接 |
| 游客，deviceid 两项都有 | 不再弹出表单，按设备偏好加载列表 |
| 已登录，UID 两项都没有 | 必须填写，表单不显示 Sign in 链接 |
| 已登录，UID 两项都有 | 不弹出表单，按 UID 信息刷新列表 |
| 查询失败、资料类型错误、仅返回一个字段 | 保持流程保护，提示重试 / 修复，不当成合法空资料或完成资料 |

已保存的资料只有“两项都有”或“两项都没有”，不会有只保存一项的合法状态。表单不能关闭、不能跳过；遮罩点击、下拉、系统返回不能退出。

![首次进入及设备检查标注](01-form-empty-annotated.png)

### F03 — 填写与校验

Gender 必选 Male / Female / Non_binary；Age 必选 18-24 / 25-34 / 35-44 / 45+。两组均为单选、不预选。未提交草稿可以只选一项；用户切换选项时只更新本次草稿，不能提前标记已完成。

两项完整时 Continue 可提交。未完整时保持禁用视觉，但点击会弹出对应 Toast，不发送保存请求：

| 缺少内容 | Toast |
| --- | --- |
| Gender 和 Age | `Please select your gender and age.` |
| Gender | `Please select your gender.` |
| Age | `Please select your age.` |

服务端也必须校验两个字段及枚举；前端校验不能替代服务端校验。

![未完成填写的校验标注](02-form-validation-annotated.png)

### F04 — Gender 改变时刷新底层内容

用户选定或切换 Gender 后，按当前草稿偏好重新获取分类项，再刷新对应列表。Age 改变不额外触发同一轮刷新。此时还未提交资料，因此需要推荐接口支持临时 Gender 参数，不能为了刷新而单独保存 Gender。

当前 For You 实际使用 `GET /api/v1/origin/feed`，其它分类使用 `GET /api/v1/origin/list`；分类来源为 `GET /api/v1/origin/hot_tags`。现有方法均未暴露本流程的 Gender 参数，传递方式待扩展。Non_binary 的推荐策略由后端明确，不由前端映射为某个分类。

快速切换时合并刷新，使用请求版本防止旧 Gender 响应覆盖新选择。刷新期间保留底层旧内容，不先清空页面。

### F05 — 从表单进入登录

点击 `I have an account to Sign in.`，在同一条 Sheet route 内切换登录。保留表单草稿，不保存完成状态。

登录 Header 有返回按钮，返回表单保留草稿；系统返回与此一致。发起登录后禁用重复请求与返回。用户取消平台授权时留在登录步骤；失败提示后可重试。

### F06 — Continue 保存成功后进入订阅

1. 校验两项完整后，根据当前身份提交：游客写 deviceid，已登录写当前 UID。
2. 服务端必须原子保存 Gender、Age 与完成状态；客户端不能只写一个 `completed=true`。
3. 保存期间防重复提交；只有服务端确认成功后更新本地缓存并进入 Subscription。
4. 保存失败保留草稿及表单，可重试，不进入订阅。
5. 超时但可能已经保存时，用资料读取或幂等重试确认结果，不能因重复点击创建冲突数据。
6. 同一 Sheet 内切换表单 / 登录 / 订阅，不通过反复关闭、重开实现步骤切换。

### F07 — 登录成功后检查 UID

复用现有 Google / Apple 登录服务获取真实会话，再读取当前用户信息。不能仅凭拿到 token 就关闭引导。

| 当前 UID 资料 | 登录后的行为 |
| --- | --- |
| Gender、Age 都有 | 关闭引导，使用 UID 信息刷新分类与列表；本分支不进入新用户订阅步骤 |
| 两项都没有 | 回到已登录表单；保留本次草稿，用户仍须 Continue 确认；隐藏所有登录入口 |
| 查询失败 / 不合法 | 保持登录态，显示可重试的资料读取状态；不当作空字段，不自动覆盖 |

已登录表单显示 `Complete your profile to continue.`。截图中的选中项是登录前草稿，**不表示 UID 已经保存**；没有草稿时保持两组未选。点击 Continue 按 F06 保存到 UID，成功后进入订阅。

250 Gems 文案复用现有登录提示；奖励实际发放、到账与幂等由现有服务端规则负责，本流程不因为按钮点击而自行加 Gems。奖励适用条件需要沿用或核实既有账户规则。

![登录分支与接口标注](04-sign-in-annotated.png)

![登录后返回表单的标注](05-signed-in-form-annotated.png)

### F08 — Skip 与退出

Subscription 右侧 Skip 可关闭，系统返回也可跳过订阅。跳过不清除资料、不撤销完成状态、不触发购买；再次启动不能因为跳过订阅而重新要求填表。仍保留原来的遮罩、拖动退出限制。

完成资料后在订阅步骤杀进程，下次启动依据资料已完成放行。是否另行补展示订阅营销不属于本需求，不以“没买会员”为条件重新弹必填表单。

### F09 — 订阅与购买复用现有链路

新用户订阅只展示 Subscription，没有 Buy Gems Tab。商品、价格、优惠、权益与购买资格使用现有会员商品接口；根据选中套餐展示相应信息。前端预览中的金额与折扣不是生产配置，正式接入不得作为默认值回填。

| 操作或结果 | 处理 |
| --- | --- |
| 切换年付 / 月付 | 更新选中套餐、权益与金额，不触发购买 |
| 点击购买 | 重新获取购买资格和凭据，调用现有商店 SDK 与会员服务 |
| 取消 / 失败 | 保留已填写资料；按原购买流程提示，仍可重试或 Skip |
| 待支付 / 补报中 | 按既有购买状态显示，不当作成功到账 |
| 登录用户购买成功 | 服务端上报确认后刷新钱包 / 会员状态，完成后关闭引导 |
| 游客购买成功 | 复用既有成功提示 → 强制登录 → claim 认领流程；不能单凭商店回调直接结束游客权益绑定 |

游客订阅后的强制登录与本 Sheet 内“已有账号登录”是两个业务分支。前者用于绑定已付款权益，不能随意关闭；后者允许返回表单。正式接入要避免同时弹出多个登录 Sheet，并复用现有 claim 失败重试逻辑。游客已提交的完整资料，在该登录成功后按 F11 规则绑定 UID。

![订阅操作与购买接口标注](06-subscription-annotated.png)

![完整权益列表的下半部分](07-subscription-benefits-annotated.png)

### F10 — 结束后刷新与缓存

按最终有效身份和已保存偏好刷新分类、列表。For You 首屏游标重置为 `start_score=0`；其它分类重置为 `pn=1`。分类失效时回退 For you；仍存在的选择可以保留。

分类缓存、For You 首屏缓存和正在执行的请求都要按账号 / 设备及偏好版本隔离或失效。登录 / 切 UID 后丢弃旧身份迟到响应，不能让游客列表覆盖账号列表。网络失败保留旧内容并可重试，不能用模拟数据宣称刷新成功。

![返回列表与刷新标注](08-worldo-list-annotated.png)

### F11 — deviceid 与 UID 绑定规则

- 游客提交后保存整对资料到 deviceid，重启查询该设备完成状态。
- 已完成的设备在本流程外登录，或完成填写后在购买分支登录：先读 UID；UID 完整则以 UID 为准，UID 为空才将已保存设备资料整对绑定。
- 从“未完成表单 → Sign in”进入登录：先走 F07；UID 为空时回表单，由用户 Continue 确认。不能用未提交草稿直接调用自动绑定。
- 绑定必须幂等，不覆盖完整 UID 资料，不将设备完成状态当成任意其它 UID 已完成。
- 绑定失败不撤销登录成功；保留同一目标 UID 的待同步状态，允许重试。切换账号后旧请求或队列不能写入新 UID。
- 重装后 deviceid 是否稳定，依赖既有设备身份服务与平台行为；不能仅靠本地缓存承诺重装后仍记得。设备读取和 UID 恢复必须由后端支持。

## 3. 状态与数据规则

下表的字段名是**接口评审建议**，不是现有正式字段。存储与同步采用完整资料快照。

| 建议字段 | 含义与规则 |
| --- | --- |
| `gender` | `male` / `female` / `non_binary`，对应 UI 的 Male / Female / Non_binary；编码待后端确认 |
| `age_range` | `18-24` / `25-34` / `35-44` / `45+`；年龄段，不采集生日 |
| `completed` | 服务端按两项合法且持久化成功计算，不允许客户端单独提交 true |
| `version` | 资料版本，用于缓存、绑定与迟到请求识别；类型由契约确认 |
| `updated_at` | 服务端更新时间，建议 Unix 秒；不以客户端时钟决定归属 |
| `device_id` | 使用现有设备服务；具体通过签名上下文、header 还是 body 传递，由设备接口契约确定 |
| UID | 从当前授权会话解析；写入接口不能接受任意 UID 来指定保存对象 |

合法快照：未完成时 `gender=null`、`age_range=null`、`completed=false`；完成时两项均合法且 `completed=true`。字段缺失、只返回一项、非法枚举、状态与字段矛盾都属于协议异常，不应被正常保存或继续传播。

## 4. 后端接口对接清单

**核对依据：当前仓库正式 API 实现与接口文档，不是联网验证后端已部署。** A 表列出现有代码可复用能力；B 表是本功能尚缺的能力。截图右侧的 A / B 编号与本节一致。

### 4.1 已有接口（A）

下列路径统一基于当前配置的 API host。沿用现有 Gateway 签名与登录会话，不能额外加入调试身份头。

| 编号 | 接口 | 现有契约 / 用途 | 本需求的接入点 |
| --- | --- | --- | --- |
| A01 | `POST /api/v1/user/oauth/google` | 请求 `id_token`，可选 `nonce/name/avatar`；返回 token 和 user | F07 复用登录服务，成功后继续 A03+B03 |
| A02 | `POST /api/v1/user/oauth/apple` | 同样通过 `id_token` 等换取会话 | 与 A01 同分支；平台支持沿用配置 |
| A03 | `GET /api/v1/user/info` | 当前用户读取由会话解析 UID，发送对应授权；校验响应 UID 与 `relation.is_self` | 需 B03 增加当前账号个性化资料，不使用匿名他人 UID 查询来判定当前账户完成状态 |
| A04 | `POST /api/v1/user/update` | 当前只接收 `name/avatar/bio` | 需 B04 扩展 Gender/Age 成对保存；当前不能直接传新字段当作已支持 |
| A05 | `GET /api/v1/origin/hot_tags` | 当前无参数，返回 `data.list` 分类字符串 | 扩展草稿 Gender / 设备或 UID 偏好，刷新分类 |
| A06 | `GET /api/v1/origin/feed` | For You 使用 `start_score/rn`；首屏 0，后续接 `next_score` | 扩展个性化上下文，Gender/UID 改变时重置首屏 |
| A07 | `GET /api/v1/origin/list` | 其它分类使用 `scene/tag/pn/rn` 等 | 扩展同一偏好上下文，保留分页与标签契约 |
| A08 | `GET /api/v1/membership/products?provider=google\|apple` | 返回 `vip_status/list`；每个商品自带价格、`benefits`、商店商品标识及可选 `account_uuid`；游客按既有方式传 `X-Device-ID` | F09 正式替换设计预览数据；付款前刷新资格 |
| A09 | `POST /api/v1/membership/guest/prepare` | body 为 `provider/device_id`，返回 `account_uuid`；商品已带 UUID 时无需重复 prepare | 游客付款前按既有会员服务执行，不作为资料保存接口 |
| A10 | `POST /api/v1/membership/purchase/report`；游客为 `/api/v1/membership/guest/purchase/report` | 上报 `provider/store_product_id` 与平台凭据；游客还带 `account_uuid` | 复用已有请求模型和确认 / 重试流程，不新造订单协议 |
| A11 | `POST /api/v1/membership/claim`；恢复检查 `/api/v1/membership/guest/purchase/check` | 登录后认领已有游客购买；check 根据原 `account_uuid` 查询是否需绑定 | 复用游客订阅后强制登录及恢复流程；不是 Gender/Age 的设备绑定接口 |
| A12 | `GET /api/v1/gem/wallet` | 现有钱包与会员状态来源 | report / claim 成功后刷新；不能把客户端支付回调直接当作会员有效 |

A10 / A11 的 Google 凭据为现有 `purchase_token`；Apple 为 `transaction_id`，游客 report / claim 按现有要求携带 `signed_transaction`。沿用现有请求模型，不新增 `plan_code/request_id`、客户端金额或任意 UID。会员接口完整规则见 [现有接口契约](../apifox-http-api-contract.md)。

### 4.2 需要新增或扩展的能力（B）

**下表路径为建议草案，尚未实现或确认，不应当作可调用地址。** 可在后端评审中替换路径，但职责与分支必须覆盖。A03/A04 是现有路径，其个性化字段扩展同样尚未确认。

| 编号 | 建议对接方式 | 需要后端提供的行为 | 前端调用时机 |
| --- | --- | --- | --- |
| B01 | 新增设备资料读取；建议 `GET /api/v1/user/personalization/device` | 根据已验证设备身份返回空 / 完整快照；未找到记录应明确返回未完成，读取错误不能伪装为空 | F01 未登录启动、保存超时后的核对 |
| B02 | 新增设备资料写入；建议 `POST /api/v1/user/personalization/device` | 两项原子校验、成对保存并返回服务端快照；幂等重试；禁止只写完成标记 | F06 游客 Continue |
| B03 | 扩展 A03 当前用户响应，建议增加 `data.personalization` | 返回当前 UID 的完整快照；空状态、版本和字段类型明确；只在当前用户有权读取的响应暴露这组资料 | F01 已登录启动、F07 登录完成 |
| B04 | 扩展 A04，请求建议增加 `personalization` 对象 | 同时提交 gender 与 age_range，整对持久化到会话 UID；响应返回已保存快照 | F06 已登录 Continue |
| B05 | 新增设备资料绑定；建议 `POST /api/v1/user/personalization/bind` | 根据会话 UID 与验证后的设备身份绑定；仅从已保存的完整设备记录迁移；UID 完整时保留 UID；返回最终有效快照与绑定结果 | F11 已完成游客随后登录 |

B05 仅绑定个性化资料；A11 仅认领付费权益，两者必须分别确认与重试，不能用一个成功状态代替另一个。

### 4.3 建议请求 / 响应字段（待后端确认）

B02 的业务资料对象建议如下；设备身份的鉴权与传输位置另行确定，不将可随意伪造的裸 ID 当作授权：

```json
{"gender":"female","age_range":"25-34"}
```

B04 建议在原用户更新请求中扩展独立对象，保留原 `name/avatar/bio` 兼容：

```json
{"personalization":{"gender":"female","age_range":"25-34"}}
```

B01/B02 与 B03/B04 建议统一快照格式，避免客户端分别推导完成状态：

```json
{
  "personalization": {
    "gender": "female",
    "age_range": "25-34",
    "completed": true,
    "version": 1,
    "updated_at": 0
  }
}
```

该示例仅展示结构；`updated_at=0` 是占位，不是正式默认值。实际响应仍放入现有 `err_no/err_msg/data` envelope 中。空状态两项必须同时为 null。B05 建议另外返回 `result=bound|uid_profile_kept|no_device_profile` 与最终 `personalization`，用于决定刷新或回表单；这些结果值也属于待评审草案。

### 4.4 推荐接口扩展

A05/A06/A07 需要明确两个阶段：

1. **未提交阶段**：建议接收可选 `personalization_gender`，仅用于当次推荐，不写入设备或 UID；来源是当前表单草稿。
2. **提交或登录完成后**：按认证 UID，或未登录时的验证设备身份读取已保存偏好；清理草稿覆盖参数。UID 资料优先于设备资料。

最终参数名、header / query 位置及服务端策略待契约确认。必须保留 A06 的 cursor 分页和 A07 的 page 分页。Age 不触发即时刷新；若后端推荐也使用 Age，应在完整保存后的下一轮推荐读取已保存值。

### 4.5 商品权益文案

用户要求的 8 条 Premium 权益按下列顺序配置到商品的 `benefits`，年付、月付均适用此展示要求。正式数据由 A08 返回；当前 Developer 使用相同文本作排版预览。文案中的 Gems 数量和付费权益实际履行需要与商品配置核对，不能仅凭 UI 文字发放奖励。

| 顺序 | `title` | `display_type` |
| --- | --- | --- |
| 1 | Up to 3,500 Gems Monthly | enhanced |
| 2 | Story Recap the AI Remembers beyond Memory | enhanced |
| 3 | Free 2,000 Pink Gems per Month | enhanced |
| 4 | Free 50 Extra Red Gems per Daily Check-in | enhanced |
| 5 | Unlimited Inspirations | enhanced |
| 6 | Unlimited Editing | enhanced |
| 7 | Exclusive Premium Badge | enhanced |
| 8 | Gem Recharge | included |

`code` 在单个数组中唯一，`icon_key` 走既有客户端映射。显示权益不等于授权；功能权限仍查各功能原有后端规则。

## 5. 接入顺序与异常处理

| 顺序 | 工作 | 完成标准 |
| --- | --- | --- |
| 1 | 确认 B01–B05 与 A05–A07 扩展契约 | 字段、枚举、鉴权、空状态、错误、幂等和优先级确定 |
| 2 | 后端实现设备 / UID 读写与绑定 | 重启、并发、重复提交、完整 UID 不被设备覆盖均可验证 |
| 3 | 客户端资料 service、缓存、启动 gate | gate 和列表并行运行；错误不误放行；监听身份变化 |
| 4 | 接入真实登录、保存与推荐刷新 | 替换 Developer 回调，正确执行 F04/F06/F07/F10 |
| 5 | 接入会员商品与既有购买服务 | 复用 A08–A12、游客认领和恢复；不使用预览价格 |
| 6 | 联调与回归 | 完成下面验收矩阵 |

额外异常要求：账户切换使正在进行的保存、查询、绑定和刷新响应失效；本地 draft 与服务端 saved snapshot 分开存放；只在确认保存成功后持久化完成缓存。网络错误与非法资料均提供重试，不销毁草稿。

后端评审仍需确定：设备记录鉴权及重装稳定性；字段最终编码；资料写入是否需要版本冲突控制；绑定接口最终路径；完整 UID 是否及如何反写当前设备记录；Non_binary 推荐策略；资料检查与现有强制升级 / 游客订单登录 gate 的调度优先级。以上未确定事项不以预览模拟结果代替正式决策。

## 6. 验收矩阵与当前状态

| 验收项 | 当前前端预览 | 正式接入待验收 |
| --- | --- | --- |
| 两组必选、单选切换、三类缺失提示 | 已完成；真实手机截图 01、02、05，自动测试覆盖 | 服务端枚举与原子校验 |
| 表单不能关闭 / 跳过，登录可返回 | 已完成 | 启动 gate 不可绕过 |
| 登录后完整关闭、空资料回填表 | 本地回调已模拟；截图 04–05 | 真实 OAuth + 当前 UID 资料检查 |
| 已登录表单隐藏登录入口、保留草稿 | 已完成 | 会话变化与异步结果隔离 |
| 同一 Sheet 切换三步 | 已完成 | 接入后继续复用同一路由 |
| 保存成功再进入 Subscription | 预览没有真实保存 | B02/B04 成功、失败、超时、重复点击 |
| 设备和 UID 完成状态及绑定 | 未接入 | 重启、登录、账号切换、同步重试 |
| Gender 改变刷新分类与列表 | 未接入 | A05–A07 扩展、竞态和缓存隔离 |
| 订阅权益、套餐切换与 Skip | 已完成；截图 06–08 | A08 真实配置与资格 |
| 支付、上报、强制登录、claim | 新流程未接入 | A09–A12 与既有服务协同 |

本次文档中的原图直接取自真机；实际操作包括空表单提示、选择两项、进入登录、本地模拟登录返回表单、Continue 进入订阅、滚动权益、Skip 返回列表。没有发起真实平台授权或商店付款，也没有验证 B 类接口已经存在。

本次 40px 间距调整后，`flutter test test/components/personalization_sheet_test.dart --reporter expanded` 9 项通过；`dart analyze lib/components/onboarding/personalization_sheet.dart` 无问题，`git diff --check` 通过。本次没有重新生成测试渲染图或重新截取手机屏幕。测试渲染图位于旧 `docs/design/`，本目录原图来自手机，不混用两种来源。

## 7. 开发预览与实现位置

Developer → button → **Preview new user onboarding**，位于 Creating 正上方。`Preview options` 可随时切换新用户表单、已登录未填资料、登录且账号资料完整、订阅预览；末项 Close sheet 退出当前预览。切场景重置本次预览草稿；切换实际流程步骤保留草稿。

| 责任 | 实现位置 |
| --- | --- |
| 三步 UI、校验、登录回调、Skip | [personalization_sheet.dart](../../lib/components/onboarding/personalization_sheet.dart) |
| 开发场景及设计商品 | [developer_personalization_preview.dart](../../lib/pages/me/developer_personalization_preview.dart) |
| 登录奖励文案、平台按钮和协议 | [login_provider_button.dart](../../lib/components/login_provider_button.dart) |
| 普通 / 强制登录原组件 | [login_sheet.dart](../../lib/components/login_sheet.dart) |
| 订阅正文 / 购买 Sheet | [pro_subscription_content.dart](../../lib/components/gems/pro_subscription_content.dart)、[purchase_options_sheet.dart](../../lib/components/gems/purchase_options_sheet.dart) |
| Header 与正文公共容器 | [genesis_bottom_sheet_panel.dart](../../lib/components/common/genesis_bottom_sheet_panel.dart) |
| 登录、资料接口 | [user_api.dart](../../lib/network/v1/user_api.dart) |
| 分类及推荐接口 | [origin_api.dart](../../lib/network/v1/origin_api.dart)、[origin_page.dart](../../lib/pages/origin/origin_page.dart) |
| 会员接口 | [membership_api.dart](../../lib/network/v1/membership_api.dart) |
| 设备身份 | [device_id_service.dart](../../lib/platform/device/device_id_service.dart) |

## 8. 样式规范（最终确认版）

本节集中记录视觉尺寸与控件，以上用户逻辑不依赖页面手写样式。以公共组件和当前代码为实施来源。

### 8.1 通用外壳与 Header

| 属性 | 当前标准 |
| --- | --- |
| Sheet 总高 | **600** 逻辑像素，包含底部系统安全区；短屏限制在可用高度内 |
| 步骤切换 | 共用同一面板，保持 Header 与总高一致，不做高度动画 |
| 背景 / 圆角 | `darkRaisedBackground`，现有公共 Sheet 圆角 |
| Header | `GenesisActionSheetHeader`，总高 **68** |
| 标题 | **18 / 600**，行高 24，居左，单行不足时省略，读屏保留完整文案 |
| Header 内对齐 | 标题、图标、右侧操作垂直居中，不另设固定顶部 padding |
| 左右边距 | Header 与 `GenesisActionSheetBody` 统一 **16** |
| 订阅 Header | 标题前保留 22px 皇冠，右侧 Skip 用二号白 `darkTextSecondary` |
| 正文起点 | Header 底部开始；各正文内部间距见下方 |
| 底部协议 | 两个订阅 Sheet 与完整购买页均只保留系统安全区，不叠加额外 10 / 14 |
| 内容超高 | 内部滚动，保持外壳高度；步骤切入时正文从顶部显示 |

普通 Subscription / Buy Gems 的居中 Tab 字号维持 16 / 600、Header 68；Mention 特例不受本需求影响。

### 8.2 表单

- 标题：`Personalize Your Worldo Experience`。
- Gender 三列，Age 两列；字号较大时 Gender 可改两列。选项间距 8，最小高 52，圆角 8。
- 未选底色为 **6% 白**，引用 `GenesisColors.darkPurchaseCardBackground`；未选文字用二号白，边框用 `darkCardBorder`。
- 选中为品牌红边框与 12% 红色填充，文字用一级白；两组旁均显示 Required。
- Gender 与 Age 两组间距 24，Age 模块下方间距 40，随后直接排列 Continue 与登录链接，不再贴底固定。
- Continue 高 48，保留公共深色禁用样式；缺项点击复用公共 Toast。
- 未登录时下方为 `I have an account to Sign in.`，Sign in 用二级红和下划线；已登录时整行移除。
- 表单正文内部保留底部 14；这不是订阅协议的额外留白。

### 8.3 登录

- Header 标题 `Sign in`，左上返回，使用标准 Header。
- **正文顶部对齐，不再整体垂直居中**。
- App 图标 `assets/images/app_icon.png`，96×96，圆角 12，水平居中；距 Header 底部 **16**，图标到奖励文案 **40**。
- `Sign up and get 250 Gems!` 复用 `LoginSignupRewardText`：14 / 600、行高 1.35，居中、`redSecondary`；文案到平台按钮间距 12。
- Google / Apple 按钮复用 `LoginProviderButtons`，两个按钮间距 12；按钮后到协议间距 20。
- 协议复用 `LoginLegalText`。正文内部协议左右再留 16；平台可见性遵循 App flavor。

### 8.4 新用户订阅

- 复用 `ProSubscriptionContent`；无 Buy Gems Tab；右上 Skip，二号白。
- `topSpacing: 0`、`horizontalInset: 0`，外层公共正文容器提供左右 16。
- 使用第 4.5 节完整权益文案。前 7 条右侧为红色 up 图标 `upgradeIconAsset`，最后 Gem Recharge 为对勾。
- 权益较多时在权益卡内滚动，保留套餐和主操作。短屏或大字体下正文整体也可滚动。
- 套餐和购买按钮复用现有样式；协议下方只留系统安全区。

### 8.5 仅开发预览的控件位置

`Preview options` 位于新用户 Sheet 上沿上方 12、距右侧 16；强制登录演示的 `Close preview` 同样相对其 Sheet 上沿定位。正式 UI 不显示这些工具。图中存在的 `debug` 按钮也是开发工具。

### 8.6 截图与最终间距

按本轮确认，Age 到 Continue 的最终间距为 **40px**，Continue 与下方登录文案跟随 Age 排列。按用户要求，本次间距调整不重新截图：图 01、02 为 28px 时的截图；图 05 保留较早的已登录状态截图，仅用于说明草稿保留与登录链接隐藏，按钮最终位置以本节和代码为准。
