# Privacy settings 接入（2026-10-26）

## 展示与保存

- Me 页面在未登录时也提供右上角设置按钮。设置页的语言、关于我们、账号、意见反馈及 Discord 可在未登录时访问；封锁列表及退出登录仅登录后显示。账号卡片未登录时显示用户图标、本地化未登录状态、登录后管理账号的说明和登录按钮；点击登录复用共享登录 Sheet，取消保留当前账号页，成功后按会话更新内容；窄屏或放大字号时按钮换行，不显示登录提供方图标、删除账号协议/说明、阅读勾选项及删除按钮；登录后恢复原有内容，切换账号重置阅读勾选状态。隐私设置移至「设置 → 账号」，位于账号卡片下方、原账号删除协议位置；登录后账号删除协议排在隐私设置下方。未登录时也可进入，按下述配置/地区/历史选择条件显示，不增加登录门槛。

- `privacy_consent_enabled` 是 `/api/v1/app/config` 的严格布尔配置。仅本次请求已成功且 true 才允许展示；默认、加载中、失败、false 均隐藏设置入口并禁止自动弹窗。
- 读取系统 Locale 的 countryCode，不读取应用内语言，不调用地理位置接口。这是产品指定的地区近似，不能证明真实所在地。
- EEA（EU 27 国及 IS/LI/NO）需要提示且 eea="1"；GB/CH 需要提示但 eea="0"；其他明确地区不自动提示且 eea="0"；缺少地区码需要提示且不传 eea。
- 有有效本地选择（含全部拒绝）不自动提示。配置开启时，需提示地区或已有选择的用户能从设置进入；配置关闭时所有用户都隐藏入口。
- 保存使用安装本地 `privacy_choices_v1`，含版本、UTC 时间和四个布尔值；不随账号切换清除。卸载后是否恢复取决于系统备份，不能将本地存储等同于绝不恢复。
- Consent / Accept all 保存全部 true；Do not consent 保存全部 false；Confirm choices 保存当前四项。第一层无关闭按钮，不能点击外部或返回关闭，须明确提交选择；设置 X 丢弃未保存修改。Manage options 内的 X 返回第一层。
- 开发者预览不读取或写入正式记录，不调用 SDK、注册接口。

## 启动与 SDK（2026-10-27 边界修正）

- 隐私功能只负责展示、保存明确用户选择，并同步给 Adjust、Firebase 和业务注册接口。不通过四项选择改变原有客户端业务门控。
- 最终顺序：iOS 网络权限处理 → 隐私流程确定（含缓存/跳过）→ Adjust 初始化／Firebase Analytics 启用 → ATT → 其他自动弹窗。隐私启动完成使用独立 Future；不依赖四项选择真假，全部拒绝也初始化 Adjust 并按环境规则启用 Analytics。
- Adjust 不再在 main 提前初始化；隐私结束后先 trackThirdPartySharing 设置已保存选择，再 initSdk，保留官方首次会话延迟作为首次发送保护并立即释放，不等待 ATT。SDK 决定非首次会话忽略延迟设置。
- Firebase Core、Crashlytics、Performance 恢复原启动流程，不等待隐私；Android 保留 FirebaseInitProvider，production Android/iOS 恢复 Performance 原生启动采样。Analytics 独立串行等待隐私流程完成，先 setConsent，再按原有环境开关启用，不用 analytics_storage 或其他选择额外控制启用。
- Firebase 用户后续修改选择时继续更新 setConsent；SDK 自行限制采集/发送。SDK 参数使用真实选择，无选择的配置关闭/无需提示/配置失败路径不伪造用户同意。
- Collect 自有监控队列仍独立初始化，config、页面和业务请求不等待 Analytics。ATT 等待 SDK 初始化尝试完成；失败或超过 10 秒后记录日志并继续展示流程，后台初始化可继续，不将故障变成弹窗永久阻塞。
- ADID、GPS ADID（含原生回退）、IDFA、IDFV 沿用原有读取链路，不受隐私模块附加门控。iOS ATT 保留系统权限与原有触发时机，不要求四项选择为 true，不通过其他标识绕过系统限制。
- 启动展示优先级固定为隐私 → ATT → 其他自动弹窗，由独立 StartupPromptSequence 协调。等待配置/隐私关闭动画结束后才安排 ATT，ATT 有最终状态（含已有授权/拒绝）或平台无需 ATT 后才放行资料填写、签到、评分奖励、购买登录及强制升级展示；隐私选择 true/false 不决定是否显示 ATT。配置失败/关闭、无需提示、有历史选择时跳过隐私展示。资料/购买检查及预加载照常执行，只有展示需要等待，不影响 SDK、标识读取、请求和打点。
- 业务注册不等待隐私选择；选择改变后额外同步 privacy_consent。暂时不可用的可选标识省略，避免误清空，不因拒绝选择主动清空已有标识。ADID 晚到合并和普通重复请求去重继续保留。
- 保存后本地状态立即发布，SDK 与注册分别同步。前台、网络恢复及下次启动重试 SDK 同步；SDK 接受调用不等于服务端已经收到。服务端转发策略独立验收。

## 启动异常恢复（2026-10-27）

- Analytics 的运行时采集开关会跨进程保存。Android AnalyticsStartupProvider（initOrder=101）在 FirebaseInitProvider（100）前调用公开 API 关闭 Analytics；iOS AppDelegate 在 Flutter/Firebase 注册前关闭 Analytics。只重置 Analytics 启用开关，不改四项选择、不清数据、不关闭 Core/Crashlytics/Performance；隐私完成后仍先 setConsent，再按环境规则开启。原生冷启动的实际发送顺序需通过设备日志/抓包验收。
- 隐私弹窗返回 submitted/closed/failed，存储读取最多 2 秒；只有真实提交才结束需要弹窗的启动阶段。失败有限重试，前台恢复可再次尝试，不把失败当作用户拒绝或流程完成。
- Analytics 的准备、同意 API、采集配置各有 8 秒期限，隐私等待本身不计入该期限。同步队列失败后可接受新请求；使用最新选择/环境版本防止旧操作继续启用，超时的原生调用迟到完成（含部分失败）后重新应用最新状态，不将超时误认为已取消原生调用。
- ATT 状态查询最多 5 秒，请求桥接最多等待 15 秒。系统弹窗导致应用 inactive 时不放行其他弹窗；恢复前台后重新查状态。前台未确定/异常最多重试 3 次，随后记录异常并将 ATT 延后到下次前台机会，不伪造同意/拒绝，也不永久挡住其他弹窗。
- Firebase 同意同步成功后以及 ATT 得到最终状态后，重读标识；注册沿用完整快照去重，变化才补报。选择的首次服务端同步不等待 SDK，SDK 完成后的刷新用于校准标识。

## 服务端配合

1. `/api/v1/device/register` 接受可选 privacy_consent JSON string，内部只保存四项 boolean。缺省表示未提供选择，不应自动解释为同意或拒绝。
2. 服务端自行转发 Google/Adjust/Firebase 时必须应用相同状态；客户端 SDK 调用不自动控制独立 S2S 请求。
3. `/api/v1/app/config` 支持 privacy_consent_enabled，默认 false；服务端字段支持与客户端实机验证后再开启。
4. 本仓库仅客户端实现，不表示服务端字段已经上线。

## 多语言与验收

- 20 个新增文案，英文语义源 + zh-TW/es/pt/fr/de/it/ja/ko；富文本使用完整句子占位符，Privacy Policy 样式沿用白色加粗、无下划线。
- 运行 `./tool/l10n/check`、隐私 controller/SDK 参数/注册测试和弹窗、Settings、引导回归测试。
- 飞书翻译表须逐项同步并回读云端，当前会话没有连接的文档会话时不能标记同步完成。
- 上线前仍需 Android/iOS 真机 SDK 日志、网络权限/ATT 顺序、服务端新字段联调，以及隐私政策内容确认。

参考：[Adjust Flutter privacy](https://dev.adjust.com/en/sdk/flutter/features/privacy/)、[Firebase app consent](https://developers.google.com/tag-platform/security/guides/app-consent)。

首次发送保护依据：[Adjust Flutter First session delay](https://dev.adjust.com/en/sdk/flutter/features/first-session-delay/)。无选择的跳过路径不保证携带用户同意值；这是保留产品配置与失败继续启动策略，不代表已有用户授权。
