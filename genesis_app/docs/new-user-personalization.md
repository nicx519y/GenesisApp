# 新用户个性化 Sheet：设计与接入需求

状态：前端设计预览；未接入首次启动、真实登录、设备存储、用户资料、推荐接口或支付。
日期：2026-09-13

## 本次交付与预览入口

Developer Page → button → **Preview new user onboarding**（紧挨 Creating 按钮的正上方）。
预览选项直接打开目标画面，不再全部从初始表单开始：

| 选项 | 打开后的状态与模拟方式 |
| --- | --- |
| 新用户填表（未登录） | 两项未选，有 Sign in 链接；可填完 Continue，或点击链接再点 Google / Apple，模拟登录成功但账号未填写资料 |
| 已登录 · 尚未填写资料 | 直接进入已登录的填表状态，两项都为空，**没有登录链接**；填写完整后 Continue |
| 登录 · 账号资料已完整 | 直接进入登录步骤；点击 Google / Apple，模拟账号 Gender 与 Age 都有值，关闭 sheet |
| 订阅 sheet | 直接展示填表完成后的订阅步骤，可切换套餐、点 Skip 关闭 |
| Close sheet | 最后一项；关闭当前开发预览，回到底层页面 |

预览时 sheet 外上方保留 **Preview options**，可随时重新打开上述菜单、切换状态或 Close sheet；切换场景会重置该次预览草稿。该控制只存在于 Developer 预览，正式新用户流程不增加关闭入口。从 Developer 入口选择 Close sheet 时，会关闭已打开的新用户预览；若当前 Developer 也是 sheet，则先收起 Developer sheet。预览被其它页面盖住时按所属路由关闭，不误关其它页面；没有活动预览时不打开新预览。

账号已保存的 Gender 和 Age 只有“都有”或“都没有”两种状态；删除仅有一个字段的预览场景。未提交的表单草稿允许用户先选择一项，但必须两项都选完才能 Continue。所有登录按钮使用本地模拟，不调用真实 OAuth。订阅使用现有组件与独立设计数据，价格、权益及 Gems 数量仅用于排版，不是正式商品配置；点击订阅只显示预览提示，不支付。

从浮动 Developer sheet 打开时，先收起开发面板，保留原页面在底部正常显示和运行。从独立 Developer Page 打开时，底部仍是 Developer Page。预览不改变真实列表、账号或设备状态；必须从 Worldo list 的浮动开发入口打开，才能查看真实列表作为底图的效果。

## 视觉方案

- 沿用现有深色公共面板、顶部圆角、Inter 字体、品牌红和公共按钮。
- 表单、登录、订阅在**同一条 modal route、同一面板**内切换。高度统一与订阅 sheet 对齐，为屏幕高度的 80%，同时避开顶部安全区；底部含系统安全区。三个步骤之间不做高度动画，不反复关闭和打开 sheet。
- 三个步骤统一复用同一 Header：标题均使用公共 `GenesisTypography.pageTitle`（20px / 600、行高 1.4），左对齐；Header 左右 20px、上方 12px、下方 8px，默认高度 76px；三个标题均顶部对齐，文字布局顶部距 sheet 顶部固定 12px。禁止靠底部对齐或垂直居中造成标题上方大段空白。Header 后间距为 12px，正文起点保持一致。
- 表单完整标题 **Personalize Your Worldo Experience** 允许自然换行。三个步骤均按这个最长标题计算 Header 高度：大字体或窄屏需要更高 Header 时，三步同步采用同一高度，正文起始位置也保持一致，不随切换变化。
- 登录步骤在同一 Header 增加左侧返回按钮；订阅步骤在同一 Header 右侧显示 Skip。Subscription 使用相同标题样式，保留标题前的 22px 原皇冠图标；不套用 Wallet 的居中 Tab 与下划线。订阅正文继续复用原组件，在本流程设置 topSpacing 为 0，避免再叠加默认的 10px 顶部留白。
- Gender：Male / Female / Non_binary，三个等宽单选按钮。Age：18-24 / 25-34 / 35-44 / 45+，两列两行。两组均展示 Required；不预选。
- 选项最小高度 52px，圆角 8px，间距 8px；未选为深色卡片，选中为红色描边与浅红填充，辅以读屏选中状态。不用性别图标或性别配色。
- Continue 固定在内容底部附近，高 48px；两个字段都有值才启用，禁用态引用公共 token。
- 下方完整文案：**I have an account to Sign in.**；Sign in 使用二级红和下划线，整句触摸区可点击。
- 登录态左上角 Back，标题 Sign in，复用 Google / Apple 按钮和现有法律条款。Apple 的可见性遵循现有 flavor 配置。
- 登录成功且账号尚未填写资料（Gender、Age 都没有）时，同一 sheet 切到已登录填表状态，提示 Complete your profile to continue.；保留本次未提交的表单草稿。**此时用户已经登录，表单底部不得再显示 I have an account to Sign in.，也不得出现其它登录入口。**
- 小屏或大字体下，表单和登录内容内部滚动；大字体时 Gender 改为两列，不改变 sheet 高度。订阅沿用已有布局、套餐选择和权益滚动。
- 表单和登录没有关闭图标、Skip 或拖动条。遮罩和下拉不能关闭；表单系统返回被拦截；登录系统返回与 Back 一致，回表单。登录等待期间禁用返回和重复提交。
- Continue 后原位展示 Subscription，移除 Buy Gems tab，右上角以 **Skip** 替代关闭图标。Skip 可关闭；系统返回也可跳过订阅。遮罩与拖动仍不关闭，以保持同一路由规则。

## 目标产品流程（后续接入）

1. 新安装启动时，App shell 和 Worldo list 先正常挂载并加载；设备/用户资料检查与列表初始化并行，不让背景停在空白页。
2. 未完成资料的设备显示不可关闭、不可跳过的表单。在资料检查尚未返回前保持入口保护，避免用户先进入其它页面绕过流程；显示有限时长的检查状态及可重试错误，不把读取失败当成“已完成”。
3. 用户选择 Gender 时，更新当前内存偏好并触发 Worldo list 的筛选项重新加载和首屏刷新。Age 选择不额外触发同样的列表请求。
4. 两项完整后点击 Continue，保存 Gender、Age 和完成标记。保存成功才原位切换订阅；保存中禁用重复提交，失败保留选择并给出重试，不能把未保存状态标记为完成。
5. Skip 或完成订阅后关闭面板，展示已经按当前偏好刷新的列表。跳过订阅不撤销资料完成状态，也不造成下次启动重复填表。
6. 点击 Sign in 在同一面板进入登录。用户主动返回或取消登录时保留草稿；失败停留登录步骤，可重试。取消不显示失败错误。
7. 登录成功后必须读取 UID 的两个必填字段，不能只凭登录成功关闭面板。
8. UID 两项均有合法值：关闭面板，按 UID 资料重新加载筛选项与列表，本登录分支不展示新用户订阅步骤。
9. UID 两项都没有：原位展示已登录填表状态，保留本次草稿，隐藏底部登录链接；必须由用户填完两项并 Continue 提交。提交成功后进入订阅步骤。

## deviceid 与 UID 状态规则（待确定正式接口）

以下是领域语义，不宣称现有后端已经支持同名字段。

| 数据 | 需求 |
| --- | --- |
| deviceid | 使用现有设备身份服务生成的标识，不新造第二套设备 ID |
| Gender | Male / Female / Non_binary，最终序列化枚举由接口约定 |
| Age | 18-24 / 25-34 / 35-44 / 45+，年龄段而非生日或精确年龄 |
| 完成状态 | Gender 与 Age 均合法且已保存；不能仅看单独布尔值 |
| 版本与同步状态 | 记录协议版本、更新时间及是否待同步，具体字段名待接口评审 |

- Gender、Age 必须成对提交、成对保存、成对同步，不提供单字段保存接口；已保存的设备和账号资料只存在“都有”或“都没有”。本地未提交草稿不属于已保存资料。
- guest 提交后按 deviceid 保存完整资料和完成状态；再次启动同 deviceid 时不重复弹出。
- 登录后，若 UID 尚未填写资料，将设备上的 Gender、Age 与完成状态作为一个整体同步；若 UID 已有完整资料，以 UID 资料为准，不逐字段合并或覆盖。
- 从本表单 Sign in 进入账号后，仍按“检查 UID → 两项都没有则填写确认”的分支执行，设备完成标记不能绕过 UID 校验。
- 已完成 guest 后在其它入口登录，也必须执行资料同步；同步失败保留待同步状态，可幂等重试，不能默默当成功。
- 切换 UID 必须重新读取该账号资料；本机设备完成标记不能替代另一个账号的资料。异步结果按 UID / session revision 校验，避免写入切换后的用户。
- 杀进程发生在提交前：下次仍须填写；发生在保存成功后、订阅前：不再重复填表。是否补展示未看过的订阅，不属于本轮自动弹出规则。
- 重装后 deviceid 是否稳定取决于平台与现有设备身份实现，不能仅凭本地缓存保证跨重装记忆；服务端按 deviceid 查询及 UID 恢复方案需要配套。

## Worldo list 刷新要求

现有列表入口为 `lib/pages/origin/origin_page.dart`，当前通过 `_syncHotTags` 维护分类并有本地分类缓存。现有契约中尚未确认本功能的 Gender/Age 字段、枚举与推荐映射，不能把性别直接硬编码为某类内容标签。

- Gender 更改：加载对应筛选项，再刷新首屏；保留仍然有效的当前筛选项，否则回到 For you。后台加载不卸载现有卡片或先清空页面。
- 登录后以 UID 资料为准再走一次刷新；guest 请求尚未返回时要丢弃旧结果，避免覆盖 UID 列表。
- 快速切换选择时合并刷新，并用请求版本保证最后选择生效；分类缓存按身份与偏好区分或失效，避免复用另一性别/账号的旧结果。
- 网络失败保留旧内容并提供重试，绝不靠假数据表示刷新成功。Non_binary 的推荐规则需后端明确；本次不推断。
- 初始无缓存时展示现有静态骨架，错误时显示明确错误和重试入口，不出现空白背景。

## 验收清单

- [ ] 正式首次启动按设备完成情况决定弹出；已登录时同时校验 UID。
- [x] Developer 预览入口位于 Creating 按钮正上方，选项直达对应状态；菜单末尾 Close sheet 可退出预览。
- [x] 两个必选项、单选切换和 Continue 禁用/启用状态可操作。
- [x] 表单遮罩、下拉和系统返回不能绕过。
- [x] 登录返回保留草稿；取消和失败可重试；账号未填写时显示已登录表单且无登录链接，资料完整关闭。
- [x] 三个步骤共用 route 与恒定高度。
- [x] 订阅复用现有样式，无 Buy Gems，Skip 可关闭，无真实支付。
- [ ] deviceid/UID 持久化、资料迁移、真实登录和网络错误恢复。
- [ ] Gender/UID 改变后的真实分类、缓存及列表刷新。

方括号标记区分当前前端预览与待接入产品逻辑；自动化验证结果见本次交付说明。

## 渲染预览与验证记录

以下是 Flutter widget 实际渲染的独立弹层截图（390 × 844 逻辑尺寸），不包含底层业务页面；订阅中的数据仅为预览 fixture。

- [表单初始状态](design/personalization-empty.png)
- [表单已选择](design/personalization-selected.png)
- [登录步骤](design/personalization-login.png)
- [订阅步骤](design/personalization-subscription.png)

验证日期：2026-09-13。下列命令在 `genesis_app/` 执行：

```sh
dart format lib/components/onboarding/personalization_sheet.dart lib/components/gems/purchase_options_sheet.dart lib/components/gems/pro_subscription_content.dart lib/pages/me/developer_personalization_preview.dart lib/pages/me/developer_page.dart lib/pages/me/developer_previews.dart test/components/personalization_sheet_test.dart
flutter analyze lib/components/onboarding/personalization_sheet.dart lib/components/gems/purchase_options_sheet.dart lib/components/gems/pro_subscription_content.dart lib/pages/me/developer_personalization_preview.dart lib/pages/me/developer_page.dart lib/pages/me/developer_previews.dart test/components/personalization_sheet_test.dart
flutter test test/components/personalization_sheet_test.dart test/components/purchase_options_sheet_test.dart test/components/pro_subscription_content_test.dart --dart-define=UPDATE_PERSONALIZATION_PREVIEWS=true --reporter expanded
```

首版验证结果：静态检查无问题；43 项测试通过，包含新流程、原订阅组件回归，以及 320 × 568 / 1.5 倍字体下从表单进入订阅无溢出。三个步骤的面板矩形由测试直接比对，确保位置和高度一致。已检查渲染截图。尚未进行真机安装验收。

小屏订阅正文允许整体滚动；共享套餐卡片和折扣标记高度随字体增大，默认字体下保持原尺寸。

### 预览入口调整验证

已删除“只有 Gender、没有 Age”的场景；验证了未登录与已登录表单的链接差异、四个入口直达状态、面板高度一致，以及通过 Preview options → Close sheet 退出不可关闭的表单预览。

执行 `flutter test test/components/personalization_sheet_test.dart --reporter expanded`：8 项通过。针对本轮修改的 `flutter analyze`（personalization_sheet、developer_personalization_preview、developer_page、developer_previews 和 personalization_sheet_test）无问题；`dart format` 与 `git diff --check` 通过。本次仍为本地前端预览，未安装到真机。

### 当前 Header 布局与验证

三个标题均从 sheet 顶部下方 12px 开始，顶部对齐，不再采用居中或底部对齐。Header 默认总高 76px，标题统一 20px / 600；皇冠、返回、Skip 与标题首行对齐。保留完整两行表单标题，正文起点仍一致。以前按标题底部固定 20px 间距的方案已由此布局替代。

执行 `flutter test test/components/personalization_sheet_test.dart --dart-define=UPDATE_PERSONALIZATION_PREVIEWS=true --reporter expanded`，9 项通过；测试直接验证三种标题距 header 顶部均为 12px，也覆盖 Developer 关闭被遮挡预览的行为。执行 `flutter analyze lib/components/onboarding/personalization_sheet.dart test/components/personalization_sheet_test.dart` 无问题。`dart format` 和 `git diff --check` 通过；已重新生成并查看表单、登录和订阅截图，尚未真机验收。
