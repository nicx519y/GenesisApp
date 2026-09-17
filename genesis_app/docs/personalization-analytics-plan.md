# 新用户 Gender / Age 表单打点方案

日期：2026-09-17。状态：当前接入下列三个流程事件，并为既有 login 成功事件增加登录来源。Sign in 点击埋点保持移除；其余事件仍为设计稿，线上上报待验收。

当前事件统一调用 `GenesisTelemetry.collectLog`。object2 / object3 / object4 / ext_data 均为空，不增加下文设计的关联 ID 或扩展参数。

| action | action_type | object1 | 当前实现 |
| --- | --- | --- | --- |
| personalization_form_show | pageview | 空 | 表单实际绘制且处于前台当前路由时，同一 Sheet 实例记一次；登录/订阅步骤不计。关闭后重开新 Sheet 实例重新计数。 |
| personalization_continue_click | event | success / failed | Continue 触发资料保存后，在保存调用返回时记录一次。有效保存响应 completed=true 为 success；调用异常、超时或 completed=false 为 failed。先记录保存结果，再执行会话检查、缓存更新、会员查询和后续导航。 |
| personalization_skip_click | event | 空 | 在表单后订阅步骤实际点击右上角 Skip 时，关闭弹层之前记录一次；同一弹层防止连点重复。订阅页展示、购买成功关闭、其他程序关闭均不触发。 |

既有 `action_type=event, action=login` 仍在后端登录成功、设置 Collect 用户身份后记录一次，新增 `object1=登录来源`。失败和取消不记录成功事件；来源在入口发起登录时显式传递，不从登录后的页面猜测，也不加入业务接口请求。Firebase 的 login.method 保持原有 Google / Apple 渠道口径。

| login.object1 | 发起登录的入口 |
| --- | --- |
| from_personalization | 个性化表单内普通 Sign in 登录 |
| from_membership_purchase | 未登录用户点击订阅购买按钮，商品接口 has_subscription_order=true 时弹出的登录窗 |
| from_membership_claim | 购买会员后或恢复游客订单时要求登录领取权益，包括启动前置登录和表单内强制登录 |
| from_home | Home 登录区域 |
| from_me | Me 登录区域 |
| from_create_worldo | Create 导航入口或创建提交前的登录 |
| from_edit_worldo | 编辑 Worldo 提交前的登录 |
| from_messages | Messages 导航及消息分类列表内操作 |
| from_profile | 用户资料页及资料组件内操作 |
| from_follows | 关注/粉丝列表内操作 |
| from_discuss | 发帖、评论、回复、点赞等讨论入口 |
| from_private_chat | 私信发送前登录 |
| from_location_chat | 地点聊天会话失效后的重新登录 |
| from_worldo_detail | Worldo 详情的角色配置、Launch 前登录 |
| from_world_detail | World 详情内操作及会话失效后的重新登录 |
| from_unknown | 未显式传入来源的兼容兜底；当前正式入口均已标注 |

Continue 的 success/failed 暂按保存结果解释，而不是必填项校验；已向用户提出该口径确认，尚未收到回复。未填完整仅展示原提示，不产生保存结果事件；提交中禁用点击不重复记录。failed 表示客户端保存调用未确认成功，尤其超时不能证明服务端未保存；超时后底层 Future 的迟到结果不额外补记第二条。保存完成后的会话变化或跳转异常不会把已记录 success 反转为 failed。

Developer 预览通过 `trackFormEvents: false` 排除曝光和 Skip 点击，同时使用独立的本地保存回调，不走正式 Gate 保存埋点；预览登录不调用正式后端登录。埋点均异步进入现有 Collect 队列，不等待网络上传、不改原有 UI。以下完整方案中的其他事件与扩展字段保留作为后续设计，不代表当前接入内容。

上一轮曝光接入验证：相关 18 项测试及静态检查通过。另运行 `personalization_gate_test.dart`，20 项通过、9 项失败；在临时副本用改动前 HEAD 的两个源文件复测，失败用例集合相同。真机和线上 Collect 接收尚未验证。

移除 Sign in 点击前的验证：`flutter test --no-pub test/components/personalization_form_collect_test.dart test/components/personalization_sheet_test.dart test/app/onboarding/personalization_store_test.dart --reporter expanded` 共 30 项通过。对本轮涉及的 Sheet、Gate、Store、Developer 预览和两个测试文件运行 `dart analyze`，无问题；`git diff --check` 通过。

登录来源与 Skip 本轮验证共 37 项通过：

- `flutter test --no-pub test/components/personalization_form_collect_test.dart test/components/personalization_sheet_test.dart test/components/login_sheet_test.dart --reporter expanded`：29 项。
- `flutter test --no-pub test/network/genesis_api_test.dart --name 'successful .* login records|backend login failure|backend login waits' --reporter expanded`：4 项。
- `flutter test --no-pub test/widget_test.dart --name 'signed-out Home opens worlds after Google login succeeds|signed-out Me view enters Me after Google login succeeds|Messages login preserves the tab until a second tap|Create entry waits for a second tap after login' --reporter expanded`：前三项通过；Create 原测试误匹配 Home 和弹层中的同名 Google 按钮，限定到 LoginSheet 后以 `--plain-name 'Create entry waits for a second tap after login'` 单独复测通过。
- 对 31 个涉及文件执行 `dart analyze` 无问题，`git diff --check` 通过。真机和线上接收仍待验收。

## 1. 范围与现状

移除 Sign in 点击埋点后的验证：`flutter test --no-pub test/components/personalization_form_collect_test.dart --reporter expanded` 共 11 项通过；`dart analyze lib/components/onboarding/personalization_sheet.dart test/components/personalization_form_collect_test.dart` 无问题；`git diff --check` 通过。

本方案覆盖新用户个性化表单的加载、实际展示、选择、Continue 校验、资料保存和后续分流。依据当前 GenesisApp_2 正式业务代码及本地接口契约制定。

- 表单由 `PersonalizationGate` 调度，选项来自 GET `/api/v1/device/personalization`；`PersonalizationSheet` 展示并处理交互。
- POST 同一路径提交 gender / age。业务成功、响应合法且 `completed=true` 才能确认资料保存完成。
- 当前未填完整时点 Continue 会展示提示；提交中不接受重复点击。
- 登录可能读取到已经完成的账号资料，并直接结束当前流程；这不是本次 POST 保存成功。
- 保存后还需判断下一步，可能展示 Subscription、进入必要的登录步骤或关闭。保存成功和下一页实际展示是两个节点。
- 已保留表单曝光、Continue 保存结果，并增加订阅步骤 Skip 点击；Sign in 点击不再上报，登录成功由原有 login 事件携带来源。订阅步骤已有独立 Subscription 埋点，入口为 `from_onboarding`。

## 2. 推荐事件

建议第一期落地 6 个核心事件，同时补齐 3 个入口诊断事件。核心事件用于转化漏斗，诊断事件用于解释为什么没有看到表单。

### 2.1 六个核心事件

| action | action_type | 准确触发时机 | object3 | 主要扩展字段 |
| --- | --- | --- | --- | --- |
| `personalization_form_show` | `pageview` | form 步骤处于前台、当前可见路由，内容完成首帧；同一 form_id 一次 | `first_show` | form_id、schema_hash、required_count、filled_count、prefilled_fields、option_counts |
| `personalization_field_select` | `event` | 用户点击使选中值发生变化；同值重复点击、初始化回填、接口刷新清除失效值不算用户选择 | `gender` / `age`，取实际 field.name | form_id、selection_kind=first/change、filled_count、is_complete、selection_index |
| `personalization_continue_click` | `event` | Continue 的正常回调或未填完整提示回调被实际触发；提交中禁用点击不记录 | `valid` / `invalid` | form_id、click_id、missing_fields；valid 时附 submit_id |
| `personalization_submit_start` | `event` | 有效 Continue 被接受进入一次逻辑保存，在异步身份检查、会话准备和保存前记录 | `start` | form_id、click_id、submit_id、attempt_no |
| `personalization_submit_result` | `event` | 本次逻辑保存得到明确结果或客户端等待超时 | `success` / `failed` / `timeout` / `blocked` | form_id、submit_id、stage、reason、实际 error_code / http_status、server_save_status |
| `personalization_step_change` | `event` | 下一步骤实际可见，或路由确认关闭；仅作出导航决定时不记 | `form` / `sign_in` / `subscription` / `closed` | form_id（已有时）、from_step、reason；由保存触发时附 submit_id |

补充约定：

- `form_show` 不在 build、GET 成功或 beginPresentation 时记录。后两者都不能证明用户看到了表单。
- 从登录返回同一个表单，记录 step_change，不重复 form_show。登录到另一身份且需要填写时创建新的 form_id，并记录新的 form_show。
- 字段由客户端动态读取 name 和 options，不能写死性别/年龄选项数量。schema_hash 是表单结构（字段、必填规则及选项 value/顺序）的稳定摘要，不包含用户选择，不冒充服务端版本号。
- 第一期默认只记录选择动作和填写进度，不重复采集具体年龄/性别答案。若以后需要选项分布，另加白名单字段 option_value，使用接口原始 value，不使用 label 或索引解释业务含义。
- selection_index 是本表单第几次有效选择动作，从 1 递增，不是选项的位置。
- 填写开始可由首次 field_select 推导；填完整可由首次 is_complete=true 的选择事件推导，不额外新增两个事件。初始就完整的表单使用 form_show.is_complete（按 filled_count == required_count 推导）识别，并与用户主动填完整分开。
- step_change.reason 采用明确枚举，例如 user_login_click、login_back、login_incomplete_profile、login_existing_complete、save_continue、save_close、session_changed、route_removed。订阅步骤曝光仍由现有 subscription_page_show 负责，本事件只用于关联流程。

### 2.2 三个入口诊断事件

| action | action_type | 触发与字段 |
| --- | --- | --- |
| `personalization_gate_result` | `monitor` | Gate 决策发生变化时记录；object3 为 config_unresolved / disabled / waiting_required_login / need_form / already_completed / error。带 reason，有 load_id 时关联。不能把暂时缺配置记作最终关闭；同一 flow_id、身份分段和相同状态只记录一次，发生真实状态变化可再记。 |
| `personalization_load_start` | `monitor` | 一次实际 Store 加载工作开始，object3=start；带 load_id、load_source。并发调用复用同一个 in-flight 工作时只记一次。 |
| `personalization_load_result` | `monitor` | 与 load_start 配对，object3=success / failed / timeout / superseded；带 load_id、load_source、completed、schema_hash、stage、reason 及实际错误码。success 只代表返回数据有效，不代表弹窗展示。 |

load_source 使用 startup / retry / resume / login_refresh / session_change / origin_feed 等实际调用来源。推荐列表也会读取同一资料，不能把全部 GET 都统计为新用户表单入口；需要 Gate 的 need_form 决策才能进入“应展示表单”分母。共用加载仅保留首次发起来源，Gate 使用 load_id 关联自己消费的结果。

load_start 的范围包含 UID 读取和加载回调中的会话准备，并不声称 HTTP 已发送。stage 区分 identity_read、session_prepare、api、parse、session_check；接口级精确发送耗时继续使用通用 API 监控。配置状态无法从当前 Gate 参数识别时，由配置 Store 提供真实状态，不能仅凭默认 false 推断 disabled。

## 3. Collect 字段及关联

继续通过 `GenesisTelemetry.collectLog` / `collectLogAndWait` 写入现有 Collect 队列。

| 字段 | 约定 |
| --- | --- |
| object1 | 固定 `personalization` |
| object2 | `flow_id`：本次 onboarding 调度的随机关联 ID；重试及流程内登录继续沿用。独立 origin_feed 加载尚无 onboarding 流程时留空，由后续 Gate 使用 load_id 关联 |
| object3 | 上表定义的主维度：字段名、校验结果、提交结果或目标步骤 |
| object4 | 有明确计时起点时填非负整数毫秒字符串，其他情况为空 |
| ext_data | 紧凑 JSON 字符串，包含 `schema_version: 1` 和本事件所需字段；未发生的字段省略 |
| event_id / app_timestamp | 复用 Collect：事件唯一 ID 和真实发生时间；补传不重建 ID，不改时间 |
| 公共 Header | 复用平台、版本、环境、设备和 UID；业务扩展不重复传这些值 |

ID 生命周期：

- flow_id：Gate 开始本轮评估时创建。当前流程中的配置恢复、加载重试、登录和后续订阅沿用；流程结束后重新进入或冷启动创建新的 ID。
- identity_revision：flow 内的身份分段序号，初始为 1，确认身份变化后递增。已有 flow 的事件在 ext_data 携带；Gate 展示率以 flow_id + identity_revision 关联，异步提交保留发起时的分段号。
- form_id：某个身份的本次表单展示实例。build、回前台、失败后再试和同身份登录返回不换 ID；身份切换后若需要新表单，创建新 ID。跨身份不得把两套填写行为合成一个表单漏斗。
- click_id：一次实际 Continue 回调一个 ID；无效点击也有，便于统计校验提示。
- submit_id：一次有效提交一个 ID；start/result 共用。失败后用户再次点击创建新的 ID；Collect 重传和 HTTP 内部重试不创建新的逻辑提交。
- load_id：一次实际加载工作一个 ID；共享同一 Future 的消费者共用；新的业务重试创建新 ID。

对外层表单 ID 的分配可早于实际首帧，以便准备上下文；创建 ID 本身不等于曝光。流程内的匿名登录继续通过 flow_id 串联，不依赖 UID 永远不变。

公共 UID 使用事件发生时的现有快照。若请求期间切换账号，提交结果按 submit_id 关联 submit_start 的身份归属；不能拿结果上传时或后续新事件的 UID 倒推提交者。实现中需保留提交开始时的上下文，避免跨身份覆盖。

object4 计时规则：

- field_select / continue_click：本表单累计前台、实际可见时间；进入登录/订阅、被其他路由覆盖和退后台时暂停。
- submit_result：从 submit_start 起计算逻辑提交耗时，包含异步准备和等待，使用单调时钟；不当作纯 HTTP 耗时。
- load_result：从对应 load_start 起计算耗时，使用单调时钟。
- form_show / submit_start / load_start / step_change / gate_result：无相应耗时则留空，不能用 0 冒充未测量。

## 4. 保存结果口径

| result | 条件 | server_save_status |
| --- | --- | --- |
| success | POST 业务成功、响应模型合法且 completed=true，针对提交时的身份确认保存 | confirmed |
| failed | 明确业务拒绝、响应不合法或非超时异常；保留真实错误码，不能用 Toast 文案分类 | 明确未保存才用 not_saved，否则 unknown |
| timeout | 客户端等待到期，尚未确认保存结果 | unknown |
| blocked | POST 前因身份变化、表单选项失效等本地前置条件中止 | not_attempted |

仅漏填字段触发提示属于 continue_click.invalid，不创建 submit_start/result。

success 应在获得有效保存响应时确定，不等待会员查询、订阅展示、登录、推荐缓存写入或关闭弹层。当前外层 onSubmit 同时处理保存和后续分流，不能在其最外层 catch 中把所有异常一律写成资料保存失败。非关键推荐缓存写入失败也不改变已确认的保存结果。

特别情况：

- 保存响应已确认成功，但身份发生变化：保留原 submit_id 的保存成功；当前流程记 session_changed 分流/中断，不把成功反转为失败。
- 发生 timeout 后，只有捕获到同一 submit_id 对应的明确迟到响应，才能补一条 result=success、confirmation_source=late_response。分析按该 submit_id 的最终确认状态归并，不能将其当作第二次提交。
- 之后 GET 发现 completed=true，只能证明资料当前已完成；若缺少请求级因果证据，不能追认某次超时 POST 成功。流程结束可记 reason=profile_completed_on_refresh。
- 一次明确失败只由一个责任点记录；网络层、Store、Sheet 的重复 catch 不能各发一条表单失败。

## 5. 转化与诊断报表

核心漏斗按同一 form_id、事件发生时间关联，并对 form_id 去重；事件量 PV 作为另外一列。以曝光时间划分 cohort，建议同时展示同次流程结果与 24 小时观察结果，未到观察窗口的 cohort 标记进行中。跨重启后新的 form_id 不回填旧漏斗。

| 指标 | 计算口径 |
| --- | --- |
| 实际展示率 | 同一 flow_id/身份分段内有 form_show 的 need_form 决策数 ÷ need_form 决策数；已完成、关闭开关和等待登录分开列示 |
| 开始填写率 | 至少一次 field_select 的表单数 ÷ 曝光表单数 |
| 用户填完整率 | 至少一次用户选择事件 is_complete=true 的表单数 ÷ 曝光表单数；初始完整单列 |
| 有效提交率 | 至少一次 submit_start 的表单数 ÷ 曝光表单数 |
| 单次保存确认成功率 | 最终 confirmed 的 submit_id 数 ÷ submit_start 的 submit_id 数；失败、超时未确认、前置拦截分别展示 |
| 表单最终保存率 | 至少一次确认保存成功的 form_id 数 ÷ 曝光 form_id 数 |
| 校验拦截率 | continue_click.invalid 的 click_id 数 ÷ 全部 Continue click_id 数 |
| 重试挽回率 | 首次提交未确认成功、后续提交确认成功的 form_id 数 ÷ 首次提交未确认成功且发生后续提交的 form_id 数 |
| 后续订阅到达率 | 保存成功后实际到达 subscription 的 form_id 数 ÷ 确认保存成功的 form_id 数；会员、必要登录和其他关闭原因同时列示 |

同时展示：首次选择耗时、有效提交前台耗时和保存耗时 P50/P95；按平台、版本、环境、开始时登录状态及 schema_hash 分组。年龄/性别的缺填组合由 missing_fields 统计。

未见成功事件只能记作“观察窗口内未确认完成”。切后台不是放弃，杀进程也无法保证发出结束事件。缺少 result 的 start 单列为无结果记录，不能自动等同接口失败；Collect 迟到数据到达后按发生时间重算。

## 6. 接入位置与可靠性

- 新增独立 `PersonalizationAnalytics` 封装，集中事件名、字段约定、ID 和去重；UI 调用语义方法。
- `lib/components/onboarding/personalization_sheet.dart`：可见首帧、选择回调、正常/禁用 Continue 回调、登录入口及实际步骤切换。
- `lib/app/onboarding/personalization_store.dart`：加载与提交上下文、实际工作开始、前置拦截、超时、状态代际变化。
- `lib/app/bootstrap/service_registry.dart` 与 `lib/network/v1/device_api.dart` 的真实保存边界：传递本次 submit_id 和准确阶段，在获得有效保存响应时确认成功，避免后续会话检查混淆服务端保存结果。
- `lib/components/onboarding/personalization_gate.dart`：入口决策、流程上下文及路由关闭原因；beginPresentation 也用于启动准备，不可直接作为曝光位置。
- Subscription 保留现有事件。若需表单到最终支付的逐条关联，将已有 subscription page tracking ID 放入进入订阅的 step_change 扩展字段，不改变现有购买 ID 规则。

核心事件不受普通 API 监控采样开关影响，在现有遥测启用条件下全量记录。诊断事件同样明确独立策略，避免直接使用已采样的 api_req_success 计算业务漏斗。开发预览默认注入不发送的埋点实现；测试环境按现有环境字段隔离。

埋点同步捕获上下文，异步入队；保存资料、登录和导航不等待 Collect 网络确认。复用现有 SQLite、失败保留和补传机制，不在表单层额外发送网络请求或循环 flush。Collect 传输失败通过已有队列健康信息诊断，不在同一通道递归记录“埋点上报失败”。

## 7. 接入后的验收场景

1. 游客首次正常填写：一次曝光、两次首次选择、一次有效 Continue、一组提交 start/result，随后记录真实后续步骤。
2. 漏填、同值点击、修改选项：漏填无 POST 开始事件，同值不重复选择，改选为 change。
3. 快速连点、反复 build、前后台切换：不重复曝光、不产生并发逻辑提交，后台时间不算填写时长。
4. POST 业务失败后再次提交：同 form_id，新 submit_id；保留两次结果。
5. POST 超时、迟到响应及之后 GET 完成：严格按第 4 节区分未确认、同请求迟到确认和当前资料已完成。
6. 登录到已有资料账号：记录登录分流/关闭原因，不伪造 submit_success；登录到未填写账号则新建身份对应的表单实例。
7. 服务端保存成功后，会员查询、推荐缓存或导航异常：已确认保存事件保留，后续异常单独定位。
8. 配置未就绪、开关关闭、资料已完成、GET 失败/重试、推荐列表共享 GET：入口诊断可区分，未实际展示不记曝光。
9. 提交期间账号切换：结果关联原提交，旧结果不污染新身份漏斗。
10. Collect 离线、重传、进程重启：不阻塞表单；已入队事件保留 ID，服务端幂等去重；客户端事件与服务端实际收到的数据分别验收。

当前接入范围以文档顶部的流程事件表和 login 来源表为准；尚未进行真机操作或线上上报验证。其余事件及完整字段方案待后续接入。
