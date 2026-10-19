# 多语言翻译复核与接入记录

2026-10-10。语义源：`lib/l10n/app_en.arb`，807 条文案。英文与既有台湾繁体中文文案不在本次改写范围内。

## 地区和表达风格

| 接口码 | ARB | 采用风格 |
| --- | --- | --- |
| en | app_en.arb | 原有英文 |
| zh-TW | app_zh_TW.arb | 原有台湾繁体中文 |
| es | app_es.arb | 拉美通用西语，tú，避免西班牙特有称呼 |
| pt | app_pt.arb | 巴西葡语，você，Salvar、Configurações |
| fr | app_fr.arb | 法国法语，vous，Enregistrer、Paramètres |
| de | app_de.arb | du，名词大写 |
| it | app_it.arb | tu，Salva、Impostazioni |
| ja | app_ja.arb | 提示采用礼貌句式，控件用简洁动作或名词 |
| ko | app_ko.arb | 提示采用一致敬语，未知名称后的助词尽量用标签结构规避 |

前三种新增语言的地区风格已由用户确认。系统地区码只选择同语言的包，不改变包内风格。例如 fr、fr-FR、fr-CA 均使用 app_fr.arb；x-system-language 保留系统原始值。

## 提示词复核

通用提示词与各语种补充项覆盖：实际页面场景、完整句子、同概念一致、占位符可重排但名称不变、元数据不改、ICU 数量分支、条件/金额/权益/退款原意不改、长度风险和读屏检查。能够用于本次翻译。

实际翻译保留 Worldo、Premium、Pro、Google、Apple、App Store、Google Play、Discord、UID/OID/WID 等品牌或标识；不把 Worldo 模板与运行中的 World 混为同一对象。Save 按保存内容处理，Launch 按从模板启动世界处理，Subscribe 按购买订阅处理。

| 概念 | es | pt | fr | de | it | ja | ko |
| --- | --- | --- | --- | --- | --- | --- | --- |
| World | Mundo | Mundo | Monde | Welt | Mondo | ワールド | 월드 |
| Gems | Gemas | Gemas | Gemmes | Gems | Gemme | ジェム | 젬 |
| Tick | Turno | Turno | Tour | Runde | Turno | ターン | 턴 |
| Inspiration | Inspiración | Inspiração | Inspiration | Inspiration | Ispirazione | インスピレーション | 영감 |
| Discuss | Discusión | Discussão | Discussion | Diskussion | Discussione | ディスカッション | 토론 |
| Launch | Iniciar | Iniciar | Lancer | Starten | Avvia | 起動 | 시작 |
| Save | Guardar | Salvar | Enregistrer | Speichern | Salva | 保存 | 저장 |
| Subscribe | Suscribirse | Assinar | S’abonner | Abonnieren | Abbonati | 登録する | 구독하기 |

Tick 沿用既有“回合”解释，机制仍待产品确认；LLM/EULA 保留缩写。示例中的数值、3层地点/15房间、10条回复等业务限制不改变。删除账户不会取消订阅的说明保留。

法语和意大利语使用弯撇号避免与 ICU 的 ASCII 单引号转义冲突。字段说明中的带引号花括号是字面字段示例，随目标语言标签翻译；真正动态参数和 `{{user}}` 字面标记保留。

## 接入和验证范围

九种语言均进入 supportedLocales 和语言列表；列表使用本地语言名称并支持滚动。有效缓存与服务端设置直接选择对应包；同值不重复通知或刷新。首次按系统语言显示时，x-setting-language 仍为空。手动切换仍须接口成功后应用。

本地化生成成功；61 项相关测试全部通过，语言相关静态检查与 `git diff --check` 通过。新增包的消息数、天数及删除导入气泡数量补充了明确的 0 分支，防止法语/葡语零数量落入硬编码 1 的分支。

本次验证覆盖 ARB key/占位符完整性、本地化生成、数量分支渲染、地区映射、七种新增语言的保存/恢复/同值响应、语言页面小屏滚动与成功/失败交互，以及原有语言数据刷新测试。真机全部页面的截断、字体、读屏和母语审校未完成，不能将源代码与测试通过当作这些项目的验收。

云端翻译表已同步七种新增语言的 5,649 个译文单元格，并补充已确认的地区风格、通用说明、语种提示词、术语和验证范围。导出后逐格比对与本地 ARB 一致，原有其他列未被改动；飞书显示已保存到云端。
