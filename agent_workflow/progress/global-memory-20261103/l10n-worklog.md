# 集中多语言工作记录 · 2026-11-03

- 工作区：`C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app`。
- 分支：`feature/global-memory-deluxe-20261103`；HEAD / 基点：`8d006258`；upstream：`origin/main`。
- 范围：三个已交付 ARB 片段、目标 ARB、工具维护的翻译状态、工具生成的本地化 Dart，以及本日志。未修改业务代码、翻译工具或全局规范；不 commit/push。
- 已完整读取工程 AGENTS、`docs/l10n/translation-rules.md`、`language-profiles.json`、`glossary.json` 和本地流程 README。

## 英文源与首次生成

- 安全合并 `memory-strings.json`（47 条）、`membership-strings.json`（15 条）、`integration-strings.json`（9 条）。
- 共新增 71 个消息 key 和 71 个元数据项；同值重复 0，冲突 0。不新增片段外 key，不改既有英文 key 或元数据。Parent Developer 页使用的 9 个 `memoryPreview*` key 保持原名。
- 首次 `gen-l10n` 已成功，已及时通知主任务可以使用新 getter。
- Windows 使用 `FLUTTER_ALREADY_LOCKED=true`，直接执行 `C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe C:/dev/flutter/bin/cache/flutter_tools.snapshot gen-l10n`。首次沙盒运行因用户 telemetry 缓存写入权限失败，授权提升后退出 0。

## 翻译流程与术语

- Python：本机 Python，`PYTHONUTF8=1`。
- 先读取 `l10n.py --help`、`translate --help`、`check --help`。
- `translate --dry-run --batch-size 100`：8 个目标语言各 71 条待翻译。
- `translate --prepare-dir .dart_tool/global-memory-l10n/responses --batch-size 100`：8 批，逐批读取 prompt/schema；由本任务编写 568 条译文与响应 JSON。
- 前三次 `responses-dir` 因其他 agent 持续修改调用代码，工具重算的 `source_context` 与准备时不同而拒绝，均未写入 ARB。逐项确认只有代码上下文变化，消息/元数据/规则/既有译文一致；复核新上下文后重新生成响应。等代码稳定后，最终使用 `responses-release` 成功导入 568 条。
- 正式导入使用同样的全部 8 语言及 `--batch-size 100`。只通过工具更新 ARB 与状态，不手改生成文件或 translation-state。
- Deluxe 不在既有 glossary preserve 列表。按用户要求不修改全局 glossary，以免触发全目录 guidance hash 更新；依据元数据和任务要求保留品牌，并逐语种检查所有源含 Deluxe 的消息。
- 保留 `{membership}` 占位符、金额上限 3,500 / 18,000、每月条件及 Deluxe 尚未开放的说明。用户随后将 `memoryMembershipDeluxeUnavailable` 更新为 `Deluxe is not available yet.`，已仅同步该英文 key，并经 dry-run → prepare → responses-dir 增量重译 8 条，移除原价格/权益后半句；元数据原样保留。设计预览 key 的价格/权益未确认说明仍按其英文保留。译文状态为 AI，不标记母语审校。

| 语种 | Timeline | Cast | Bonds |
| --- | --- | --- | --- |
| zh-TW | 時間軸 | 角色 | 關係 |
| es | Cronología | Personajes | Vínculos |
| pt | Linha do tempo | Personagens | Vínculos |
| fr | Chronologie | Personnages | Liens |
| de | Zeitleiste | Figuren | Beziehungen |
| it | Cronologia | Personaggi | Legami |
| ja | タイムライン | 登場人物 | 関係 |
| ko | 타임라인 | 등장인물 | 관계 |

## 验证与交接

- 导入前 568 条响应的 key 数量、Deluxe、会员占位符和三项导航/权益说明术语一致性检查通过。
- 最终导入成功：71 × 8 = 568 条新译文均为 `ai`，其中 Deluxe 短提示经第二次增量导入更新（8 条）。无待确认内容。
- 最终 `l10n.py check --catalog-only`：`PASS catalogs: 1058 keys × 8 target languages`。
- 最终 direct snapshot `gen-l10n` 退出 0。仅提示既有空 `app_zh.arb` 的 1058 条回退，8 个目标语言无漏翻提示。已即时通知父任务可开始 build，本 agent 不再生成。
- 原始快照对比审计通过：无片段外新 key；所有既有英文消息/元数据、目标译文/元数据和翻译状态条目未变；8 语言 guidance hash 未变。新增项与三个最新片段完全一致，Deluxe、占位符和三项术语一致性均通过。
- 完整 check 启动前检测到父任务另一个 Flutter test runner，故主动延后，未并发启动测试。随后父任务急需 build，已分别完成 catalog 与 gen-l10n 段，Flutter 测试段仍待父任务集中运行 `test/l10n` 与 `test/pages/me/settings_page_test.dart`。不得将此记录表述为完整 check / Flutter tests 已通过。
- `git diff --check` 通过；全局翻译规则、语种配置及 glossary 无修改。没有 commit/push。
- 本轮检查不代表母语人工审校或真机排版验收。德法等长文案、手机布局与大字号仍应在集中 UI 回归中核对。
- 临时准备包、响应、原始快照和审计脚本保存在 `genesis_app/.dart_tool/global-memory-l10n/`（不纳入提交）。
