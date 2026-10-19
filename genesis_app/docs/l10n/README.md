# 多语言开发入口

英文 `lib/l10n/app_en.arb` 是语义源。规范来自本目录的 translation-rules.md、language-profiles.json 和 glossary.json。配置使用 JSON，Python 3.9+ 标准库即可执行，无需安装 YAML/翻译 SDK 依赖。

## 开发人员

在 `genesis_app` 下执行：

```bash
# 查看需要翻译的新增/修改项，不调用模型
./tool/l10n/translate --dry-run

# 自动增量翻译到全部目标语言
./tool/l10n/translate

# 验证翻译记录、格式，生成 Flutter 本地化代码并跑相关测试
./tool/l10n/check
```

新增文案先写英文、稳定 key 和具体场景描述，再在界面引用 `context.l10n`。描述和占位符元数据的变化也会触发重新翻译。删除英文 key 后 translate 会清理对应目标 key/元数据和状态记录，不调用模型。现有未改变的文案不重写。

默认执行器是已安装、已登录的 Codex CLI。首次在开发机配置好 Codex 登录；不需要把凭据写入仓库。命令通过 stdin 提供翻译规则和相关代码片段，使用结构化 schema 输出和只读临时目录；不加载用户 config，不让翻译执行器进入当前仓库的 AGENTS 工作流。遵循 Codex 内置默认模型，无需固定型号。适配方式依据[官方非交互执行文档](https://learn.chatgpt.com/docs/non-interactive-mode)。

可用 `--language es` 单独处理一种语言，重复参数处理多种；默认批次为 20 条，`--batch-size` 可设 1..100；每批 `--timeout` 默认 300 秒。缺少执行器、超时、输出非法或需确认时明确失败，不会自动采用原英文代替译文。任一批失败时，本次运行不会部分写入 ARB。

## 当前 AI / 其他执行器

已在当前 AI 任务中时，可由当前任务完成译文，不需要递归启动 Codex：

```bash
./tool/l10n/translate --prepare-dir .dart_tool/l10n-batch-001
# 阅读目录中的 *.prompt.txt 和 *.schema.json
# 将符合 schema 的 JSON 写到对应文件，如 es-001.json
./tool/l10n/translate --responses-dir .dart_tool/l10n-batch-001
./tool/l10n/check
```

准备目录必须为空。准备和导入时须使用相同 language/batch-size 参数；manifest 固定源文案、目标目录、规则和状态的 hash。输出还必须包含 schema 中的 batch_id，避免旧响应碰巧同 key 而被导入。期间源文案或译文发生变化时，重新准备任务。

## 手动翻译与人工审校

直接修改目标 ARB 后，执行下列命令逐 key 记录，不要修改状态文件 hash：

```bash
./tool/l10n/accept --language fr --key someKey --note '按按钮所在场景修正表达'
# 仅在实际得到人类审校确认后
./tool/l10n/accept --language fr --key someKey --status reviewed --note '审校人确认了本句及其页面场景'
./tool/l10n/check
```

accept 会校验当前英文/译文并同步该 key 元数据，默认标为 manual。reviewed 只记录人类确认，不是工具自动母语审校。规则变化使整种语言过期时，不能逐 key accept 掩盖；必须完成受影响语言的整批处理。未改动的人工审校记录保留；源文案改动后的 AI 新译文标为 ai，需重新审校。

## 新增语言

1. language-profiles.json 添加正式接口码、ARB locale、列表原生名称、地区风格、称呼和 plural_policy。地区/称呼需先确定，不能由 AI 随意选。
2. glossary.json 给全部概念补齐该语言词条。英文源不变也会识别新语言的全部 807 条（数量随目录更新）。
3. 执行 translate --language <接口码>。新目录缺失时会创建对应 ARB。
4. 更新 AppLanguageController 的协议枚举、supportedLocales、系统地区解析，以及语言列表和设置页原生名称。检查会拦截仅有配置但未接入 UI 的语言。
5. 执行 check，核对生成结果和真机布局。新语言仍需要母语语义复核。原生权限提示单独配置，不由 ARB 命令处理。

## 验证与 CI

```bash
# 不调用 AI/Flutter，适合离线或早期 CI gate
./tool/l10n/check --catalog-only
python3 -m unittest discover -s tool/l10n -p 'test_*.py'

# 完整本地化 gate
./tool/l10n/check

# 仓库原有完整静态验证入口，已加入多语言 gate
bash ../agent_workflow/scripts/run_static_verify.sh
```

现有静态验证入口在 Flutter pub get 之前检查翻译记录并测试工具，之后执行 gen-l10n、analyze 和原有 Flutter 测试。仓库根目录 `.github/workflows/l10n.yml` 会在 push/PR 时运行离线目录校验及工具测试，不调用模型或 Flutter。完整 Flutter 验证使用现有静态验证入口或上述完整 check 命令。

非零退出码即失败。不在 CI 自动执行 AI 翻译/提交，也不引入模型凭据；工作流需随代码提交后才会在 GitHub 上运行。要强制阻止合并，仓库管理员须把 `Catalog and translation state` 设置为目标分支的必需检查；目前未变更远端分支规则。

check 覆盖 key、空文案、重复 JSON key、元数据、占位符、ICU/数量分支、品牌标识、文字/规则指纹及语言列表接入。它不具备母语语义判断能力，也不能替代人工检查新增代码是否绕过本地化、真机排版或服务端返回内容的翻译。

Flutter 生成可能提示 base `zh` 的 807 条未翻译。这是现有空 `app_zh.arb` 回退占位，不是提供给用户的台湾繁中包；台湾繁中使用完整的 `app_zh_TW.arb`，检查会验证其全部消息。不要为消除该提示而改变系统简体中文的回退行为。

## 当前基线与测试证据

translation-state.json 首次记录现有 807 × 8 个目标译文，均为 baseline，保留既有内容；没有把现有译文标成人工审校。英文源本身不是翻译目标。

实现验证包含真实目录检查、本地化生成/测试和模拟 Codex 执行器的端到端 stdin/schema/响应导入测试。当前无待翻译内容，因此未为验证流程启动付费/在线模型重翻既有 ARB；在线模型的响应质量和开发机认证需要在实际新增文案时验证。
