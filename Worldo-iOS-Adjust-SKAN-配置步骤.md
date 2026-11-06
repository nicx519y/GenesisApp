# Worldo iOS Adjust SKAN 配置与验收步骤
当前客户端 Adjust 接入和正式应用配置已核对完成，iOS 应用验证已通过；转化值映射正在配置，广告渠道和事件链路仍需验收。
客户端尚未配置 `https://adjust-skadnetwork.com`。**渠道转发正常时，配不配通常差异不大；配置后多一条 Apple 直达 Adjust 的回传路径，减少对渠道转发的依赖，但不会提高 Apple 的归因准确率。** 建议下次发版补上，见第 6 步。
| 事项 | 当前状态 |
| --- | --- |
| 客户端接入与正式配置核对 | 已完成 |
| iOS 应用验证 | 已完成 |
| 转化值映射、保存并应用 | 未确认完成，截图已选好六个事件 |
| Facebook / Google Ads SKAN 服务 | 未完成，截图显示“可用” |
| 渠道事件分享映射 | 未确认完成 |
| Apple 回传副本地址 | 未配置，建议补充 |
| 事件、收入及设备更新 | 未验收 |
| 真实投放回传 | 未验收 |
## 第 1 步：核对客户端和正式应用——已核对完成
| 检查项 | 核对结果 |
| --- | --- |
| Flutter / iOS Adjust SDK | 均为 5.8.0 |
| Adjust 初始化 | 已接入 |
| SKAN 功能 | 未关闭，使用 SDK 默认开启行为 |
| App Token | `k5fhwrccqmtc` |
| 正式 Bundle ID | `com.worldo.ai` |
| 正式 SDK 环境选择逻辑 | Release 且使用正式 API 等条件满足时，选择 `production` |
主要依据：
- `genesis_app/pubspec.lock`
- `genesis_app/ios/Podfile.lock`
- `genesis_app/lib/app/attribution/adjust_attribution_runtime.dart`
- `genesis_app/ios/Runner.xcodeproj/project.pbxproj`
这里完成的是代码和配置核对，不代表已验证线上发布包运行、服务端事件转发或设备转化值更新。Adjust SDK 默认在初始化时注册 SKAN；采用后台管理转化值时，不需要自行将事件名转换为数字。
参考：[SDK SKAN 官方说明](https://dev.adjust.com/zh/sdk/ios/features/skad/)。
## 第 2 步：iOS 应用验证——已验证完成
入口：**AppView → Worldo → 应用设置 → iOS → Apple App Store**。
根据本次截图：
- DataWorks 中 App Store Connect 的“iOS 应用验证”服务显示 **OK**。
- Worldo 的 Apple ID **`6781946729`** 旁显示绿色 **“已验证”**。
因此无需重新提交 Issuer ID、Key ID 或 `.p8` 私钥。服务关联与具体应用验证是两件事，本次截图已分别确认。
参考：[iOS 应用验证](https://help.adjust.com/zh/article/skadnetwork-settings-ios-app)。
## 第 3 步：配置 SKAN 转化值映射——未确认完成
入口：**AppView → Worldo → SKAdNetwork Conversion Hub → 映射转化值 → 高级设置**。
直达：[Worldo SKAN 配置页面](https://suite.adjust.com/skan-conversion-hub/k5fhwrccqmtc/details)（需登录）。
### 3.1 保留默认监测窗口
| 配置项 | 设置 |
| --- | --- |
| SKAN 3 CV 窗口 | 24 小时 |
| SKAN 4 第一次窗口 | 0–2 天 |
| SKAN 4 第二次窗口 | 3–7 天 |
| SKAN 4 第三次窗口 | 8–35 天 |
| lockWindow | 初期不启用 |
监测窗口不是回传到达时间，窗口结束后仍有随机延迟。
操作：在“回调安排”保留上述数值，不添加 lockWindow，点击右下角“下一步”。
### 3.2 选择 6 bit 或 63 个转化值：两者有什么区别
Apple 的细粒度转化值只能携带一个 **0～63 的数字**。这两种模式使用相同的编码空间，区别是如何定义这个数字。
| 对比 | 6 bit 模式 | 63 个转化值模式 |
| --- | --- | --- |
| 配置方式 | 最多选择 6 个事件 | 为数字定义事件、次数、收入等条件 |
| 表达内容 | 六个事件分别有没有发生 | 用户满足哪个自定义条件或档位 |
| 数字生成 | Adjust 根据六个事件自动组合 | Adjust 按自定义规则计算 |
| 购买金额 | 仅凭购买事件这一位，不能区分金额 | 可设计收入区间 |
| 适合用途 | 关键行为、活跃和付费漏斗 | 收入、次数及用户价值细分 |
| 是否需要改事件名 | 不需要 | 不需要 |
**6 bit：六个独立的“有没有”开关。**
例如选择登录、首次聊天、聊天 10 条、聊天 20 条、购买、订阅。事件发生就打开对应开关，Adjust 自动把六个开关组合成一个数字。在收到细粒度值的情况下，可解读出哪些选定事件发生过。但买 1 美元和买 100 美元，购买这一位都是“发生过”。
**63 个转化值：自己定义一张编码表。**
以下仅用于解释，不是可以直接套用的收入配置：
| 数字 | 自定义含义示例 |
| --- | --- |
| 0 | 安装基线 |
| 1 | 已登录 |
| 2 | 聊天达到 20 条 |
| 3 | 累计收入处于低金额区间 |
| 4 | 累计收入处于中金额区间 |
| 5 | 累计收入处于高金额区间 |
还可以为同一转化值设置多个条件；全部满足才匹配。正式设计需要处理条件重叠、收入边界和编码顺序。它不是自动记录 63 个独立事件，而是允许自定义最多 63 个非零编码。
无论选择哪种，客户端和服务器继续上报原来的事件，由 Adjust 按后台映射计算转化值，再通过 SDK 更新 Apple。
**当前建议：第一版先用 6 bit**，观察“登录 → 聊天 → 深度使用 → 付费”，接通并验收链路。后续明确需要按收入优化时，再依据真实收入分布设计 63 个转化值。事件多，本身不意味着必须选 63 模式。
这两种模式用于首个回调的细粒度映射；SKAN 4 的第二、第三次回调使用粗粒度值。即便首个回调配置了细粒度值，也不保证每份回传都能返回它，实际受 Apple 隐私条件影响。
参考：[Conversion Hub](https://help.adjust.com/zh/article/conversion-hub)、[6 bit 模式](https://help.adjust.com/zh/article/conversion-hub-6-bits-mode)、[63 个转化值模式](https://help.adjust.com/zh/article/63-conversion-values-mode)。
### 3.3 配置首次回调的六个事件
最近截图已按以下方案选好：
| 比特位 | 事件 | 目的 |
| --- | --- | --- |
| 1 | `login_first` | 完成登录 |
| 2 | `message_sent_first` | 开始聊天 |
| 3 | `message_sent_10_first` | 持续使用 |
| 4 | `message_sent_20_first` | 深度使用 |
| 5 | `purchase` | 发生付费，覆盖 Gems 和订阅 |
| 6 | `subscription` | 发生订阅购买 |
这是第一版建议方案，不是唯一正确方案。若更需要分别识别 Gems 与订阅，可考虑用 `gems` 替换一个聊天里程碑。
操作：在“第 1 次回调”选择“6 比特”，逐行选择表中事件；已选好时直接核对，不重复切换模式。
后台所选事件的 **Event Token 必须与服务端实际转发的 Token 一致**，不能只核对名称。
**其他事件怎么办？**
其他事件不删除，继续按现有链路上报。成功转发到 Adjust 后，普通事件报表仍可统计；但不能从这套 SKAN 摘要中单独还原所有其他事件，也不能保证把它们逐一归因到 iOS 广告活动。
本方案不再选 `purchase_first`、`purchase_day0` 等，是因为 `purchase` 已表达是否购买，避免占用有限位置。项目中的 `day0` 按北京时间自然日计算，与安装后 0–2 天窗口不同。
### 3.4 配置三次回调的粗粒度值
| 回调 | low | medium | high |
| --- | --- | --- | --- |
| 第一次：0–2 天 | 会话 | `message_sent_20_first` | `purchase` |
| 第二次：3–7 天 | 会话 | `purchase` | `subscription` |
| 第三次：8–35 天 | 会话 | `purchase` | `subscription` |
页面操作：
1. low：选择“会话”。
2. medium：条件类型先选“事件”，再选择表中的事件。
3. high：条件类型先选“事件”，再选择表中的事件。
首次回调完成后点“下一步”，依次进入第 2、3 次回调，按表填写，每页完成后点“下一步”。后两次只配置粗粒度值，最后进入“检查映射”。
这套方案将订阅视作后续窗口的高价值行为，是业务选择，不代表订阅收入一定高于 Gems 收入。
**第二、第三次回调只看各自窗口内发生的行为。** 第一天的购买不会自动延续到后续窗口。若后续窗口很少发生再次购买，应依据实际数据调整。
## 第 4 步：检查并保存应用——未确认完成
1. 在“检查映射”页核对六个事件、三次粗粒度配置、默认窗口及未启用 lockWindow。
2. 有误则返回对应回调修改，再回到检查页。
3. 点击 **“保存并应用”**，按页面提示确认；不要只保存草稿。
4. 返回 [Worldo SKAN 配置页面](https://suite.adjust.com/skan-conversion-hub/k5fhwrccqmtc/details)，重新打开映射，核对内容已保留。
5. 保存生效页面截图和应用时间，供研发及投放核对。
完成标准：不再显示“未配置”，能查看正确的已应用映射。本次尚未获得最终生效截图。
后续可以编辑；切换 6 bit / 63 模式会删除原有映射配置，切换前应记录方案。更改不会重新计算已经收到的历史回传，正式投放期间应记录变更时间，便于比较数据。
## 第 5 步：关联实际投放渠道——未完成
入口：**DataWorks → 关联 → Facebook / Adwords・Google Ads → 对应账户**。
此前截图显示广告支出为 **OK**，SKAN 为 **“可用”**，只能确认广告支出服务已关联，不能据此认定 SKAN 已接通。
### 5.1 Facebook / Meta——SKAN 未关联
1. 在 Adjust 左侧打开 **DataWorks → 关联**。
2. 返回合作伙伴关联列表，点击右上角 **“＋新关联 / New Connection”**。截图中的“SKAN 可用”是状态，不是完成凭证。
3. 合作伙伴选择 **Facebook**。
4. 在服务选择页勾选 **SKAdNetwork / SKAN**。
5. 按向导登录拥有实际投放广告账户访问权限的 Facebook 账号，并完成页面要求的授权。
6. 若向导列出账户，选择实际用于 Worldo 投放的广告账户，核对账户 ID，避免只授权了其他账户。
7. 完成页面要求的信息，点击 **“关联 / Connect”**。
8. 返回 **DataWorks → 关联**，确认 Facebook 的 **SKAN 列显示 OK**。
9. 点击该行账户数量旁的 **`»`**，核对具体投放账户处于激活状态，且其 SKAN 服务正常；合作伙伴汇总状态不能代替账户核对。
**Meta 端进一步确认映射：**
1. 确认 Conversion Hub 的映射已保存并应用。
2. 打开 **Meta Events Manager（事件管理工具）→ Data sources（数据源）**。
3. 选择 Worldo 对应应用，进入 **Settings（设置）**。
4. 在 **Configure App Events for SKAdNetwork** 区域确认 **Adjust 是已连接的合作伙伴**。
5. 根据 Adjust 当前 Meta SKAN 专项文档，Meta 会自动拉取已保存的映射，无需常规手动粘贴 Connection URL。若实际页面提示不同，按页面检查连接状态，不把旧版手动导入流程作为必做项。
6. 如应用同时集成 Facebook SDK，由研发确认没有让 Facebook SDK 与 Adjust 同时管理转化值；专项文档要求关闭 Facebook SDK 的转化值管理。
参考：[Meta SKAN 专项接入说明](https://help.adjust.com/en/article/skad-facebook-integration)。
### 5.2 Google Ads——SKAN 和 CV 映射共享未关联
1. 在 Adjust 打开 **DataWorks → 关联**。
2. 点击右上角 **“＋新关联 / New Connection”**。
3. 合作伙伴选择 **Adwords / Google Ads**。
4. 在服务选择页同时勾选：
   - **SKAdNetwork**。
   - **CV 映射共享 / CV Mapping Sharing**。
5. 按向导登录能访问实际投放 Google Ads 账户的 Google 账号，并完成授权。
6. 若向导列出账户，选择实际投放 Worldo 的账户，核对账户 ID。
7. 点击 **“关联 / Connect”**。
8. 返回关联列表，确认 Google Ads 的 **SKAN 和 CV 映射共享均显示 OK**。
9. 进入账户详情，确认实际投放账户处于激活状态且没有服务错误；同时确认 Conversion Hub 映射已应用，供 Adjust 推送给 Google。
参考：[Google Ads SKAN 专项接入步骤](https://help.adjust.com/en/article/skad-google-integration)。
完成标准：实际投放账户已激活；Facebook 的 SKAN 为 OK；Google Ads 的 SKAN、CV 映射共享均为 OK。真实回传另按第 8 步验收。
### 5.3 渠道事件分享映射——未确认完成
1. 进入 **Campaign Lab → 合作伙伴 / Partners**，选择投放渠道，打开 Worldo 配置。
2. 找到 **数据分享 / Data sharing**，确认设置对象包含 **iOS**；未启用时填写渠道要求的凭证并启用。
3. 打开 **映射事件 / Map events**，选择 Adjust 事件，再选渠道支持的对应事件，点击“应用”并保存。
4. 优先核对 `purchase`、`subscription` 及实际用于优化的事件；不要将同一交易的全部派生事件重复映射为购买并重复传收入。
5. 重新打开配置，确认 iOS 映射已保留。
完成标准：所需事件映射已保存，服务端确认购买收入口径不重复。参考：[事件映射官方步骤](https://help.adjust.com/zh/article/data-sharing-ad-network)。
## 第 6 步：补充 Apple 回传副本地址——当前未配置，建议下次发版补充
正式包使用的 `genesis_app/ios/Runner/Info-Release.plist` 此前核查未包含以下配置：
操作人员：iOS / Flutter 研发。打开该文件，在最外层 `<dict>` 内添加下列键值，与其他顶层 key 同级。
```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://adjust-skadnetwork.com</string>
```
添加后：
1. 执行 `plutil -lint genesis_app/ios/Runner/Info-Release.plist`，确认格式正确。
2. 按项目正式发布流程构建 iOS 归档，检查产物内 `Runner.app/Info.plist` 包含正确键值，避免只改到开发配置。
3. 随下一版提交 App Store 并发布。
完成标准：发布产物包含该配置。仅修改源码不等于已对用户生效。本次只补文档，未修改 plist 或发版。
配置收益：增加 Apple 直达 Adjust 的回传路径。渠道转发正常时差异通常不大；不配置更依赖渠道转发，不影响 SKAN 开启。
参考：[直接安装回调配置](https://dev.adjust.com/zh/sdk/ios/features/skad/)。
## 第 7 步：验收事件、收入和设备更新——待验收
当前客户端约定的业务链路为：
```text
客户端业务事件
→ 业务服务器转发 Adjust S2S
→ Adjust 按映射计算转化值
→ 后续 SDK 请求取得转化值
→ SDK 更新 Apple SKAN
```
操作人员：服务端研发、客户端研发和测试。服务端实际执行结果尚未核验。
1. **比对配置**：在 AppView → Worldo → 事件记录六个事件及 Token，与服务器实际 S2S 配置逐项比对，确认 App Token 和环境正确。
2. **准备真机**：选用能够触发首次事件的测试设备，记录设备标识、版本及时间；旧设备可能已有首次事件标记，重装不保证清除全部标记。测试与生产环境分开记录。
3. **触发行为**：依次首次登录、成功发消息至 1/10/20 条，分别测试 Gems 和订阅购买，记录事件时间、交易 ID。
4. **查服务端日志**：按设备和时间查询 `/api/v1/event/report` 接收及 Adjust S2S 转发，核对 Token、设备关联、响应与重试。客户端接口成功不等于转发成功。
5. **核对收入**：将一笔交易的金额、币种与 Adjust 接收结果比对；检查派生事件未重复累计收入，重试同一交易不重复计数。
6. **观察设备更新**：研发在诊断包接入 Adjust SKAN 转化值更新回调，记录转化值、粗粒度值、lockWindow 和错误。触发行为后等待后续 SDK 请求，确认预期值更新且无错误。
7. **测试退出场景**：购买后立即退出，再在窗口内重开，检查更新时效。若无法满足窗口要求，评估 SDK 事件方案及与 S2S 的去重。
8. **保留证据**：保存事件/Token、时间、S2S 响应与设备更新结果；测试通过后核对正式包和生产服务端配置。
完成标准：事件发送、Adjust 接收及设备更新均有对应证据，收入不重复。设备更新成功不等于真实广告回传成功，后者看第 8 步。
回调接入参考：[Flutter SKAN 文档](https://dev.adjust.com/en/sdk/flutter/features/skan/)。诊断代码仍需研发实施，本次未修改客户端。
**普通事件报表出现购买，不等于 SKAN 转化值更新成功。**
Adjust 后台默认采用异步方式处理 S2S 转化值：后台不能主动连接 SDK，需等待后续 SDK 请求后返回值。用户购买后立即退出，可能来不及更新。若必须在事件发生的同一窗口及时更新，Adjust 建议通过 SDK 记录事件；调整时需同时设计 SDK 与 S2S 的去重。
参考：[S2S 转化值更新机制](https://help.adjust.com/zh/article/support-for-s2s-events)。
## 第 8 步：小规模真实投放——待配置和检查完成后执行
操作人员：投放负责人、数据分析，研发配合排查。
1. 确认映射已应用、实际投放账户 SKAN 服务正常，第 7 步事件链路已验收。
2. 在广告渠道创建小规模 iOS 安装推广活动，目标应用核对为 Apple ID `6781946729`，记录账户、活动 ID、开始时间和地区。
3. 使用 App Store 正式版本承接投放；开发包或 TestFlight 功能测试不代替真实投放验收。
4. 在 **Datascape** 打开 SKAN 控制面板/报表，筛选 Worldo、实际渠道、活动及覆盖投放和回传的日期范围。
5. 先检查 SKAN 安装，再检查细粒度值和 low/medium/high；不要与普通归因安装混算。
6. 按下表等待后续回调，保存报表截图或导出结果。低量时可能缺失字段，不要求每个安装都有完整值或三份回传。
7. 没有数据时依次检查：投放是否有流量 → 渠道是否已有 SKAN 数据 → DataWorks 账户与服务 → Apple ID → 报表筛选和延迟。有安装无行为值时回查映射及设备更新。
完成标准：实际活动收到 SKAN 安装，并能在隐私条件允许的粒度下查看转化数据；异常已解释或修复，低量无法确认项保留待验收。
截图中的默认安排：
| 回调 | 监测窗口 | 窗口结束后的随机延迟 |
| --- | --- | --- |
| 第一次 | 0–2 天 | 24–48 小时 |
| 第二次 | 3–7 天 | 24–144 小时 |
| 第三次 | 8–35 天 | 24–144 小时 |
SKAN 不是实时事件报表，还可能存在报表处理延迟；隐私条件也会影响回传字段。应区分仍在等待回传、字段被隐私机制限制，以及配置或链路异常。
