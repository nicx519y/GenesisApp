# 用户文案翻译规则

`lib/l10n/app_en.arb` 是语义源。新增界面文案必须先定义英文 key 和 `@key.description`，通过 `context.l10n` 使用。没有 context 的展示辅助方法用 `GenesisL10n.current`，不要在字段初始化时永久缓存可变的本地化文案。不得手改 `app_localizations*.dart`。

## 场景与语义

- 已确认：首页底部导航 Tab 在所有语言下固定使用英文 Home、Worldo、Inbox、Me；中间创建按钮保持仅图标，其无障碍标签 Create 也保留英文。此例外仅适用于 navHome/navWorldo/navCreate/navInbox/navMe，不得全局禁止翻译 Home、Inbox、Me、Create。Inbox 和 Me 页面标题与对应 Tab 共用英文文案，也不翻译。其他页面标题、按钮和正文照常翻译。

- description 说明页面、控件/提示类型、触发条件、对象和歧义。例如 `Settings page: language-save failure toast after the server rejected the selection.`，不能只写 `UI text`。
- 使用原意和场景进行翻译，不逐词拼接。Worldo 是模板，World 是运行的世界；Save 是保存，Launch 是从模板启动世界，Subscribe 是订阅购买。
- 同一概念遵循 glossary.json；语种的地区、称呼和句式遵循 language-profiles.json。地区不同的手机仍加载同一语言包，不能自行改变包内地区风格。
- 条件、否定、金额、权益、业务上限、退款/续费含义、删除不可恢复及删除账号不取消订阅的限制必须保留。不要擅自扩写产品承诺。
- 品牌和标识按术语表原样保留。LLM/EULA 保留缩写；Tick 是产品术语，所有语言保留英文，句中其余内容正常翻译；聊天场景的普通 round 仍按语境翻译。`statMessages` 是统计标签，Message/Messages 保留英文；私信按钮和普通句子中的 message 正常翻译。机制仍不明确的文案须标记待确认。
- AI 统一保留英文，不替换成 IA/KI。Apple Account 使用对应地区的 Apple 官方本地化名称；意语、日语、韩语的当前写法上线前还需核对官方用词。
- Launch 指从 Worldo 启动一个世界，和 Create、Open、Publish 分开；繁中用“啟動”，拉美西语及巴西葡语用 Iniciar。翻译按钮引用时须与按钮本身一致。
- 按钮用简短动作或名词，提示用自然完整句子。允许目标语言比英文长，禁止为缩短而删除条件。提示待真机检查的长度风险，不把它作为翻译完成的证据。

## ARB、ICU 与富文本

- 只翻译消息字符串。key、`@@locale` 和占位符名称不翻译。目标 `@key` 元数据从英文同步，保留类型和格式说明。
- 占位符可重排，不能丢失或自行增加。完整句子包含富文本占位符，不按英文词序拼接或找英文子串来样式化。
- 保留 select 的选择条件和显式数值分支；plural 必须有 other。可补充语言需要的数量类别和 `=0`。不能让 0 落入写死的“1个”文案。中日韩不屈折的数量表达允许扁平化 plural，但保留数量参数；select 不允许扁平化。
- 遵守 `use-escaping: true`。ASCII 单引号按 ICU 正确转义（字面单引号为两个单引号）；法语/意语可采用自然弯撇号。`'{{user}}'` 是给用户看的字面标记，不能变成参数或更名。其他带引号的字段示例按场景翻译。
- 动态人名、世界名、地点名不能预设性别、读音或词尾。日语/韩语需避免未知名称造成的助词错误，必要时采用自然的标签或句式。
- 换行、前缀加号、富文本图标和占位符要保留实际用途；表格同步时加号不能成为公式。

## 完成标准

- 输出仅包含本次需要更新的 key，未变更的译文不重写。
- 场景不足或术语无法确定时，在结构化输出中填 `needs_confirmation` 和原因。该批次不写入，检查不能算通过。
- AI 翻译状态为 ai，既有基线为 baseline，人工录入为 manual；只有明确的人类审校才能标为 reviewed。AI 不能宣称母语审校完成。
- 英文文本、元数据或语种规则变化后，相关翻译必须重新处理。源文案变化会使原 reviewed 状态失效，不能沿用旧审校结论。
- 完成后执行 `./tool/l10n/check`，确保目录/指纹、Flutter 生成、相关本地化测试通过。检查不证明真机排版或服务器内容的翻译质量。
- 涉及新增语言时，先补齐规范和术语，再生成全部译文，并更新客户端枚举、locale 支持、切换列表及设置页名称。接口码与 ARB locale 必须明确分开。
