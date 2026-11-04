# Global memory / Deluxe
Base: origin/main 8d006258. Branch feature/global-memory-deluxe-20261103.
Design: C:/Project/worldo/界面设计/全局记忆; user selected Subscribe sliding dual card.
User explicitly confirmed frontend-first scope in async reply: “先完成前端，待后端接口后接入”. Premium uses existing catalog/checkout and latest complete summary; Deluxe and structured-memory backend writes/checkout are not implemented. Examples live only in the explicit Developer gallery. No account entitlement override is installed.

Implemented shared Recap (Timeline/Summary), Cast, Bonds UI, World capsules, MiniPhone second-page apps, Me independent subscription carousel, Subscribe sliding dual cards, and isolated Developer gallery. New 71 English keys + 568 translations imported via required workflow. Latest main baseline APK built and verified at ../packages/main-debug-20261103-8d006258/.

Verification so far: 25 shared-memory tests, 10 membership tests, 41 integration/navigation/cache/screenshot tests passed. Real-font review images at genesis_app/build/global-memory-review/. Whole-project analyze reports 24 existing issues including two invalid ChatroomClient.connect overrides in test/widget_test.dart; new paths have no diagnostics. Baseline confirmation and final modified-file analysis pending.

Review fixes: root Navigator for MiniPhone subscription, account/session-scoped summary cache invalidation even while sheet closed, entry refresh retaining visible cache. Phone summary update notifier integration and Host focused tests are being finalized. Full l10n/check running through Windows executable adapter; do not launch duplicate SDK/test commands.

Full l10n/check now passed: catalog 1058 × 8, generated localization, 90 localization/Settings tests. Windows runner adapter only replaces the non-executable `flutter` wrapper with the exact SDK command; no check skipped. Baseline targeted analysis reproduced the same two test/widget_test.dart invalid_override errors (baseline-errors.log in original-main APK archive).

Frozen product verification: final-feature-tests.log reports 54/54 passed (Host 8, Phone notification 3, membership 14, shared memory 25, gallery/navigation/render 4). Earlier 41 integration tests include the same 4 gallery tests, so 37 additional World/cache/existing-phone tests passed. Localization/Settings 90 passed. Total distinct executed test cases: 181. Real-font screenshots cover Recap/Cast/Bonds/Premium/Deluxe/Me; final Me normal card 314x82 and action82x30 assertions passed. Phone header now96/r20 centered. Changed-file analysis had one new brace-style lint, corrected; follow-up on the final six product files reports No issues found. Original whole-project diagnostics retained separately, not reported as a clean full-project check.

Review closed: World `_attachWorldChatroom` now binds the existing service's summaryUpdates to MiniPhoneSession; no additional Socket/connect/join. Host and session tests validate lifecycle; this is not real-backend/device end-to-end acceptance.

COMPLETE: Feature Internal Debug build succeeded 16:41 local, exit0, Gradle342.3s. Archived C:/Project/worldo/frontend-debug/packages/global-memory-deluxe-debug-20261103/worldo-global-memory-deluxe-internal-debug.apk (87,216,692bytes; SHA256 9A04C581BBD5BDAE9D39BEC50EBD6183C36F63BC12BED31023B52C066108B101). Manifest com.worldo.ai.internal /9.9.9+999/debuggable, signature and all six new assets verified. Build record, previews, changelog and verification logs archived beside APK. Main baseline APK remains separately archived.

No install/commit/push performed or authorized in this turn. Original camera worktree/branch untouched. SDK-auto analysis_options.yaml/pubspec.lock changes retained, not a feature edit. No required work outstanding for local frontend first version; future scope is backend adapters/Deluxe checkout and user-requested device preview.

## 2026-11-04 用户要求重建并安装预览

- 按用户明确指令，从本工作区原有全局记忆/Deluxe代码重新构建Internal Debug，未拉取/合并新基线，也未修改功能代码。构建exit0，assembleInternalDebug129.7秒。
- 包名com.worldo.ai.internal、9.9.9+999、debuggable和签名已核对；APK SHA256为9A04C581BBD5BDAE9D39BEC50EBD6183C36F63BC12BED31023B52C066108B101，与20261103归档一致。日志global-memory-debug-build-20261104.log。
- vivo1578064333000VV在线，adb install -r --no-streaming已传包，正在PackageInterceptActivity等待用户安装确认；安装exec会话78704仍挂起。已用异步问题请用户点击允许。尚不能声称完成安装。
- 旧Camera热重载session77522已detach，不要再向该旧工作区执行热更。全局记忆确认安装后，用adb核对lastUpdateTime/启动，再按需从本工作区attach。
- 其他任务相机已推团队新分支feature/camera-multishot-20261104/7556df37；本全局记忆分支仍未提交/未推送。

## 2026-11-04 设计重修（覆盖前面的安装等待状态）

两次安装均被 vivo 拒绝，用户随后选择稍后安装。无待续的安装会话；本轮没有重新安装。归档 APK 不含本轮样式修改。

基于同一工作区和未提交版本，对照源 HTML 的实际渲染重新调整 shared World/MiniPhone memory、会员双卡及 Me 卡。源图在 references/global-memory-20261103/source-*.png；Flutter 图在 genesis_app/build/global-memory-review/。首轮最终检查找到一条旧预览额度断言，已改为同时检查显式预览有额度、默认正式入口无预览额度；人物详情操作采用公共字体并复用宿主返回头，避免重复返回行。

已完成完整 l10n/check：1062 keys × 8 languages，90 项本地化/设置测试通过。最终 UI 定向检查及静态检查的结果见 style-final-tests.log / style-final-analyze.log，视觉复核见 design-qa.md。保持全部本地未提交、不推送。

样式最终定向测试 57/57 通过（含可选真字体截图）。人物详情按钮最终截图已确认正常字体，World/Phone 列表与表单、会员双卡及 Me 卡已逐图复核。没有运行全量项目测试；没有重新构建旧归档 APK 或安装手机。

## 2026-11-04 真机逐屏对照 + 示例数据接入真实入口

用户要求基于设计稿构建前端、示例数据展示效果，并指出样式差距大；选用逐屏对照（真机 + 本地渲染 vs 设计稿渲染），差距大的组件按设计稿源码重写。基点仍为 origin/main 8d006258（已 ls-remote 核对），未提交、未推送。线上画布与本地备份 canvas 逐文件一致。

- 手机原装 APK SHA 9a04c581 是样式修正前的旧包，用户此前看到的差距部分来自这里。
- 新增 `lib/app/debug/world_memory_debug_preview.dart`：kDebugMode 才生效，`main` 默认 both + live；World / MiniPhone / Me / 钱包读它，Developer › button 页切会员和剧情，选 Off 回真实账号。示例状态下订阅只弹提示，不进真实结账。替换了已失效的 World recap 预览按钮。
- 发现并修复：Theme.bodyMedium 带 Material 0.25 字距（设计稿 Inter 为 0），模块内统一 0。
- World 浮窗外壳按稿：无图标 20px 标题、36 关闭钮、6px 页点、底部胶囊常驻且当前项白底、红点；header 高 66。这是共享外壳，Detail/History/Events/Locations 同步变化。胶囊四个图标换成稿子线性图标。
- 锁定态按稿子重写（时间线轨道、Summary 骨架、Cast 露名字头像 + World 首项展开表单、Bonds 数量 + 占位）。图标换成稿子 SVG。付费卡额度加粉宝石 + 加粗；Me 卡额度加粗；Me 名字旁皇冠跟示例会员。小手机首页角标：皇冠带底圆、红数字。
- 文案对齐稿子：memoryTimelineEmptyBody（含 every 5 turns，后端周期待确认）、memoryToYouEmpty、memoryBetweenEmpty，新增 memoryKeyEventsSoFar；8 语言经 prepare/import 流程导入。

未按稿改、保留线上：World 收起态胶囊在玩家卡上方（稿子在下方）；Camera 在 main 上仍是锁定。

验证：定向测试 63/63（含 2 项预期变更：锁定 Cast 露名字头像）；l10n check 90/90；静态分析零问题；world_page_layout_source_test 有 10 项失败，baseline 同样失败，非本轮引入。真机已核对 World Recap / Summary / Cast / Bonds（解锁态）；锁定态、小手机、订阅页、Me 卡是本地真字体渲染对比，尚未在真机复核。

收尾补充（2026-11-04）：浮窗收起时内容区压到接近 0 会让固定 Tab 溢出（debug 黄黑条），`_buildSheetContent` 改为最小布局高度 240 + 裁剪；付费卡粉宝石与额度数字绑成一组不换行。定向测试 85 通过（2 项跳过，截图测试需环境变量）。最终包 SHA256 b7979eb0…a381，归档 `frontend-debug/packages/global-memory-deluxe-debug-20261104/`。未提交、未推送。

## 2026-11-04 真机复核第二轮

b7979eb0 包已装到手机（11:20），真机看了 Me（两张卡 + 双皇冠）、订阅页（Premium / Deluxe）、小手机首页和 Recap / Cast / 人物卡 / Bonds，内容基本对齐。发现并修复（**这些修复在 b1608120 包里，尚未装到手机、未在真机复核**）：
- 到期日改 yyyy-MM-dd（原来是 Tue, Sep 7，丢年份）。
- 卡宽 `memoryMembershipCardWidth`：屏宽 ≥360 固定 314（384 逻辑宽的手机原来只有 308，check-in 折行）。Me 卡改成贴屏幕边缘滚动。
- 钱包 Tab 下划线跟当前卡片变色、字距归零。
- 小手机首页改 4 列网格左对齐，Camera/Maps/Calendar/锁图标换稿子线性图标，锁定项标签变暗。

测试：钱包 / Me 的 6 个测试还在按旧单卡断言，已更新到双卡；gem_wallet_page_test 剩 4 个失败基线同样失败。定向 92 通过（2 跳过）。切 Tab 时不再额外加载一次会员目录，回到 Subscription 仍刷新。卡片区域横滑只切卡片，不再切到 Buy Gems，要从套餐区或点 Tab 切（新设计带来的行为变化）。

未处理：Me 页 Tab 在 4 位数计数时重叠（Worldo 2052 / Playing 47），基线已有，非本功能。还没在真机看：锁定态、胶囊点击切换、浮窗收起溢出修复。
最终包 SHA256 b1608120…3195，归档 `frontend-debug/packages/global-memory-deluxe-debug-20261104/`。

## 2026-11-04 真机复核第三轮（收尾）

b1608120 装机后真机确认：日期、Me 卡贴边、Deluxe Tab 粉色下划线、check-in 不折行、小手机首页 4 列网格和角标、未订阅的 World 锁定态（Recap / Timeline / Cast / Bonds）、Me 未订阅卡、胶囊点击切换和自动居中、Recap 与 Cast 下拖收起无溢出日志、Subscribe 落到 Deluxe 卡且 CTA 只弹预览提示。
发现并修复我自己引入的 bug：Camera 图标取错路径（显示成半个音符）。Deluxe 付费卡 Save 标签改珠光渐变和稿子墨色。
最终包 SHA256 a8dd0790…42bb 已装机（12:00）。Camera 图标真机确认；Save 标签只做了本地渲染确认（之后未再操作手机）。小手机锁定态内页只有本地渲染对比。
定向测试 127 通过（2 跳过）；gem_wallet_page_test 剩 4 个失败与基线相同。未提交、未推送。

收尾：本地渲染比对空状态和退场状态，基本一致；退场人物档案的状态标签和 Status 行改为 Left the story（列表短标签仍是 Left，复用已有翻译）。归档最终包 SHA256 7d478a2e010e69aac7c895f337cb82543f69a8295fc2b663881aca61a9f95331。手机上是 a8dd0790（差这一处文案），未再安装。

用户决定（2026-11-04）：World 收起态胶囊保持线上顺序，在玩家卡上方，不按稿子改。无代码改动。

## 2026-11-04 用户第二轮细节

用户要求并已实现（最终包 SHA256 7b5d5993…41cf，12:47 已装机）：
1. World 浮窗拉起后底部不放胶囊（回退此前按稿子加的常驻胶囊），标题栏和页点保留稿子样式。
2. Timeline 从旧到新，最新在最底并标红；仍只留最近 10 条。打开时停在顶部，没有自动滚到底。
3. Summary 用线上 Recap 样式：抽出 `components/world_memory/world_memory_tick_tile.dart`，线上和示例共用；真实路径直接挂 `WorldRecapSection`（分页、Show earlier、重试、语言刷新都沿用线上）。锁定骨架改成同样的轨道；去掉 The story so far 标题，空状态用线上的 recapEmpty 文案。
4. World 栏顺序 Detail / History / Recap / Cast / Bonds / Events / Locations。
5-7. `memoryMembershipOrder`：只有「Premium 生效且 Deluxe 未生效」时 Premium 在前，其余 Deluxe 在前，Me 卡、订阅页卡片和页点都用它；名字旁皇冠 Deluxe 在前。未指定入口落在第一张卡（未订阅即 Deluxe）；Summary 锁、Me 卡这类明确入口仍落对应卡，路由参数改为 `membershipTier`。

核查：设计稿 Subscribe 卡有 1px 内描边（#F5C24B59 / #FFD3DD59），App 与稿子一致，等用户决定是否去掉。Me 卡稿子和 App 都无边框。

验证：定向 133 通过（2 跳过）；gem_wallet_page_test 4 个、world_recap_section_test 2 个失败与基线相同。真机确认：Me 卡序和皇冠、无胶囊、页点位置、History 第二、Timeline 顺序、Summary 样式。未真机确认：Off 真实账号下的 Summary（用户切走，靠 Host 测试）、只订 Premium 的排序（靠组件测试）、订阅页 Deluxe 首屏（靠组件测试）。未提交未推送。

更正（2026-11-04）：订阅卡边框。上一条写的「App 与稿子一致」是错的，当时只看了 CSS 声明。稿子的内描边画在卡片背景上，顶部 200px 的渐变层（遮罩 30% 处开始淡出）盖在它上面，实际效果是顶部约 60px 看不见、60–200px 渐显、200px 以下完全显示（按亮度差实测）。App 原来把描边画在最上层，整圈都亮。已把描边移到渐变层下面，渲染数值和稿子基本重合，加了像素级测试。最终包 SHA256 e012f996…5bb8。

真机复核（e012f996，13:15 装机）：Deluxe 卡描边亮度差和稿子逐点差值在 ±8 以内；从 Me 的 Deluxe 卡进入落在 Deluxe，页点和下划线正确。

## 2026-11-04 用户第三轮细节

最终包 SHA256 5acf6380…4caf，13:45 已装机。
1. 字号校验：写了逐字比对（Chrome 导出设计稿每段文字的计算样式和位置，Flutter 导出同样字段）。修掉：嵌套 Material 把字距重置为 0.25（分段、套餐卡、Subscribe、订阅页底部）、付费卡价格字距、Deluxe 18,000 和未选中套餐价的颜色、Me 卡额度颜色、人物卡 Right now 文字亮度和退场姓名颜色、小手机说明文字颜色、Bonds 标题行高 18；间距：Message/Bonds 按钮 48→40、Bonds 分组外边距折叠、空状态下 22px、Save 标签垂直居中。审计结果只剩用户要求的 Expires。工具脚本未进仓库。
2. 订阅页 Expires 改 12/15（偏离稿子的 14，用户要求）。
3. Deluxe 权益拆成 Timeline、Cast、Bonds 三行，文案是我拟的，待用户确认；8 语言已导入。
4. 底部会员卡问题根因：`previewDraftOffers` 把真实账号路径走成旧文案、无价格、Deluxe not available 提示。已删除这个开关，所有路径同一张卡；Premium 优先用商店价，未加载时用 $99/$9.90；Deluxe 用 $449/$44.90。Deluxe 真实购买仍只弹未开放提示。

验证：定向测试通过，gem_wallet_page_test 4 个、world_recap_section_test 2 个失败与基线相同；l10n check 90 通过。真机：Expires、三卖点、真实账号三张锁定卡、模拟 Premium 下 Summary 解锁且 Timeline 仍锁。真实 Summary 有数据时的显示只有测试覆盖（该世界暂无摘要）。真实路径 Cast 锁定态没有名字头像（Host 未接角色数据，等后端）。未提交未推送。

用户第四轮：Deluxe 三个卖点文案先用这版。订阅卡标题区（皇冠、名称、ACTIVE、到期日或标语）固定在顶部，只滚动下面的权益列表，列表顶部 16px 淡出（稿子里标题随内容滚动，这里按用户要求改）。包 SHA256 3ae28238…f25c 已归档；安装时 vivo 返回 INSTALL_FAILED_ABORTED，手机上仍是 5acf6380，这项尚未真机确认。未提交未推送。

真机确认（3ae28238，14:10 装机，15:25 复核）：Deluxe 卡竖向滑动时只滚动权益列表，标题和到期日区域像素无变化，卡片不切换。复核途中出现过两次卡片被切到 Premium，手机空闲时用同样滑动未复现，手势代码里竖向滑动也不会切卡，测试已覆盖同样的滑动；判断是用户同时操作，未完全排除。之后只改了测试，手机和归档的包都是 3ae28238。未提交未推送。

## 2026-11-04 用户第五轮（字标、底边、间距、Cast 展开）

包 SHA256 9b7234a4…3e5f，已归档，16:12 已装机（16:01 第一次试装被手机拒绝，用户确认后重装成功）。

1. 字标金色：稿子和代码渐变相同。实测金色占比：稿子 .28、手机订阅页 .28、手机 Me .39。根因是 Me 标题 `Expanded(ShaderMask)` 把渐变拉到整行，ACTIVE 也被推到行尾。改 `Flexible`，渐变只铺文字，ACTIVE 紧贴（间距 8）。未改渐变色标，所以预期是回到稿子的 .28；用户说“希望金色占比更小”，若 .28 仍嫌多要动色标，那是偏离稿子。
2. 订阅卡底边：底部渐变层没有圆角，盖掉圆角处描边；描边移到内容下层后，滚动内容又会压在底边上。渐变层加 17 圆角，滚动区底部让出 1px。两档卡都生效。
3. 三个板块顶部间距：World 统一 12（偏离稿子，用户要求一致）。Recap 页签 12、Cast 头像 12（原 28）、Bonds 标题 12（原 16）、未解锁说明文字 12（原 2）。说明文字下方内容也统一 12；Recap 已解锁时页签下方仍 16。小手机布局不动。
4. Cast 展开：World 用 `_expandedPersonIds` 集合，每行独立开合，不收起其他行，不动滚动位置；切板块、Deluxe 失效时清空。小手机仍是单人详情页。

验证：定向测试通过（memory_membership、world_memory 全部、world_memory_host）。gem_wallet_page_test 4、world_recap_section_test 2、world_page_layout_source_test 失败都在基线名单。新增测试：Me 渐变宽度等于文字宽度、底边与圆角像素连续、三板块间距（含未解锁）、两行同时展开且滚动位置不变。

真机复核（9b7234a4，16:13-16:18）：
- Me 字标金色占比 .39 → .28，和稿子相同，尾部回到淡紫，ACTIVE 紧贴名字。
- Deluxe 卡底边：静止、滚动中两处、滚到底，四个状态底边亮度波动都是 4（旧版静止时 383，有字压线），圆角描边完整，无透字。Premium 卡同一组件，只测试未单独上机。
- 三个板块首个内容都在屏幕 114.5-114.8 逻辑 px，差 0.3 内。未解锁状态的 12px 只有测试覆盖，未上机。
- Cast：展开 Adrian 后点 Vivienne，再滚到中途点 Sebastian，前面的行都保持展开，点击行上方区域逐像素不变。

复核中途用户也在操作手机，等屏幕静止后才发输入；工具 `step.py` 每次输入前比对上一帧，变化就停。

## 2026-11-04 推团队分支

用户要求推团队新分支。分支 `feature/global-memory-deluxe-20261104`（团队习惯 `feature/<主题>-<首次推送日期>`），基点 8d006258，比推送时的 origin/main 落后 14 个提交，未合并，因为这版是已真机复核的版本。

没有带上的内容：`pubspec.lock`（本地 pub get 换源导致 7 个依赖漂移，已恢复团队版本，含 adjust_sdk，用 `PUB_HOSTED_URL=https://pub.flutter-io.cn flutter pub get --enforce-lockfile` 还原后重新跑测试和打包）；`analysis_options.yaml`（本地排除桌面目录，和功能无关，留在工作区未提交）；对照图、设计参考图、翻译批次和本地脚本（agent_workflow 在 main 上不存图片，只提交 md）。

