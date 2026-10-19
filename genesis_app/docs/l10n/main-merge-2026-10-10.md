# main 合并与增量本地化（2026-10-10）

将 origin/main `caedc291` 合并到 feature/translate。保留 main 的故事回顾、旁白输入切换、章节状态、订阅布局、错误消息处理和购买/归因业务改动，同时保留当前分支的语言设置与刷新逻辑。

新增 24 个英文 key，并通过 prepare/responses 增量流程生成繁中、西语、葡语、法语、德语、意语、日语、韩语共 192 条译文，状态为 ai。目录共 831 个消息 key。新文案覆盖故事回顾、旁白切换及无障碍标签、登录错误、封锁后检举失败、商店错误和通用 API 回退提示。服务端 err_msg、故事正文、角色及地点名保持原文。

故事回顾复用语言版本刷新机制：当前可见回顾更新，隐藏回顾在再次显示时刷新；替换旧语言缓存且不重建页面。添加回归用例验证延迟刷新及旧内容替换。

飞书「翻译」表新增第 812–835 行，A 为 key，B 为实际 UI 场景，C 为翻译说明，D 为英文，E–L 为 8 个目标语言。重新载入后导出核对，24 行 × 12 列与本地增量完全一致。AI 译文尚未母语人工审校。

## 验证

- `./tool/l10n/check`：831 keys × 8；本地化及设置专项 39 个测试通过。
- `./tool/l10n/translate --dry-run`：8 个目标语言均 0 pending。
- 登录、订阅、回顾、旁白与章节等 8 个 focused 测试文件：162 个测试通过。
- 聊天协议、HTTP 映射及 Google Play 服务 5 个测试文件：428 个测试通过。
- 源码结构断言用例修正为支持语言刷新 mixin，独立运行通过；最终章节/回顾检查 29 个测试通过。
- `flutter analyze --no-pub`：0 error；20 条 warning/info 尚存。
- `git diff --check`：通过。

扩展运行 chat_ui_test 与 location_chat_page_test 时，28 个运行失败在隔离的原始 main 中全部复现，两边均在 location-sync-failure 场景停止推进，已中止该扩展运行。因此不宣称完整聊天测试集通过。另一个合并分支特有的源码字符串断言只接受无 mixin 的类声明，已更新并独立验证。

未进行真机排版验收、部署或推送。

## 合并后二次审计

以共同祖先 `9dfb3dc`、main `caedc291` 和合并提交 `69dec804` 对照文案的删除/新增路径，并检查当前非生成 Dart 源码的全量 key 引用。

确认并删除以下 4 个无引用条目，同时经翻译工具清理英文、8 个目标 ARB、元数据、翻译状态和生成代码：

| key | 清理原因 |
| --- | --- |
| purchaseBeingConfirmed | main 移除 accepted 购买状态的展示分支 |
| updateFailed | 原 blocked-user 错误拼接辅助方法已删除；其他更新功能使用 meUpdateFailed |
| homeSignInFailed | main 登录链路改为 loginErrorMessage 与完整的 meSignInFailed 回退文案 |
| meRequestFailed | 通用 API 本地错误改为 genericError，旧 Request failed 回退已失效 |

main 中因组件拆分、代码移动或共享提示调整而删除的文字，若仍有实际展示引用则保留对应 key，例如 proSubscriptionTagline、premiumAlsoIncluded、meUpdateFailed、inboxReviewFailed；不把行级删除误判为整个功能文案删除。

发现并修复的遗漏：

- blocked-user 设置页的 Block/Unblock 本地回退仍硬编码，统一改用 meBlockFailed / meUnblockFailed，并将两条源文案和全部语言更新为 main 的完整重试提示。
- 订阅卡片无障碍标签的 per year / per month 未本地化，改为完整 ICU select 句子，保留动态 plan/price。
- main 新增的开发者回顾预览标签、模式说明、清理/重设失败、Gateway 验签失败和端点保存/重启说明未本地化，现已补齐。
- 宝石卡片的英文标题截取原先使用译后的类别名称；改为用英文源类别解析，仅显示名称使用本地化，未知服务端后缀保持原文。新增测试验证台湾语言下的 suffix 原文和无障碍账期。

新增 14 条、更新 2 条，8 个目标语言共 128 条增量译文；删除 4 条后目录为 841 个消息 key。当前非生成源码中未引用的消息 key 为 0，各语言 pending 为 0。

飞书清空已删除 key 原行的 A–L 单元格（保留其他行及布局），更新 meBlockFailed / meUnblockFailed，新增第 836–849 行。云端重载导出确认：841 个唯一 key 与英文目录完全一致，删除 key 不存在，新增/修改行保存正确。全量 841 × 9 语言核对无语义差异；既有英文列 21 条将真实换行显示为字面 \n，按既有文档显示规则归一化核对后匹配，未改变这些原行。

二次审计验证：`./tool/l10n/check` 841 keys × 8，41 个测试通过；订阅与设置 focused tests 59 个测试通过；`flutter analyze --no-pub` 0 error、21 条 warning/info；`git diff --check` 通过。真机及全量聊天测试限制仍按上文保留。
