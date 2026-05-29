# Prompt 字段拼接逻辑

本文档梳理场景化测试中各 slot（P1/P2/P3）prompt 的占位符及其拼接逻辑。所有 `{xxx}` 形式的占位符由 [`substitute()`](../backend/scenario_render.py) 替换；变量装配在 [`routers/scenario_session.py`](../routers/scenario_session.py) 的 `_build_*_vars()` 中完成。

> 拼接逻辑与 `prompt_version` **无关**——只要 prompt body 用到对应占位符，传入值就一致。`v1.3` 仅是把 `tick_history` + `location_history` 合并成 `history_events`。

---

## 共享上下文字段（_common_world_vars）

P1/P2 共用的世界级变量，由 worldview 静态部分渲染（P3 仅用其中的 `world_name` / `world_setting`）。

| 占位符 | 来源 | 拼接逻辑 |
|---|---|---|
| `{world_name}` | `worldview.world_architecture.world_name` | 直接取字符串 |
| `{world_setting}` | `worldview.world_architecture.world_setting` | 直接取字符串 |
| `{world_locations}` | `worldview.world_locations` 树 | DFS 展平为 `loc_id` + ` / ` 分隔的层级名 |
| `{world_events}` | `worldview.world_architecture.world_events[]` | `"1. xxx\n2. yyy\n..."` 编号列表 |
| `{metric}` | `worldview.metric` | `"基于「label」，单位：unit，范围：[min~max]。<delta 提示>"` |

---

## P1 · 叙事推进（narrative）

**用途**：生成当前 tick 的世界级 narrator 与 paragraphs。

| 占位符 | 来源/装配 | 备注 |
|---|---|---|
| 共享上下文字段 | 见上 | |
| `{character_briefs_full}` | `render_character_briefs_full(characters, metric)` | 所有角色（含 `char_1`/`{user}`）的完整简介块 |
| `{current_time}` | `compute_current_time(start_time, tick_duration_days, user_tick_count+1)` | 仅用户触发的 tick 计入（跳过 seed） |
| `{memory_summary}` | `render_memory_summary(sess.memories)` | 按 importance 降序，每行 `[ts] (imp=n) entry` |
| `{tick_history}` | `_assemble_tick_history_v13(sess, wv, last_n=5)` | 最近 5 个 tick 的 P1 输出，旧格式 |
| `{location_history}` | `_assemble_location_history_v13(sess, wv, total_limit=50)` | 最近 50 条消息按 location 分组 |
| `{history_events}` | `_assemble_unified_history_v13(sess, wv)` | **v1.3 推荐**：tick + 对话融合时间线（见下） |

---

## P2 · 地点 intent 调度（intent）

**用途**：基于刚生成的 P1 推断 tick 结束时各角色所处地点，并为每个 intent 生成 1~2 条 seed 对话。

| 占位符 | 来源/装配 | 备注 |
|---|---|---|
| 共享上下文字段 | 见上 | |
| `{character_briefs_no_user}` | `render_character_briefs_no_user(characters, metric)` | 排除 user 角色（`char_1`/`{user}`） |
| `{current_time}` | 同 P1 | |
| `{memory_summary}` | 同 P1 | |
| `{tick_history}` | 同 P1 | |
| `{location_history}` | 同 P1 | |
| `{history_events}` | 同 P1 | |
| `{current_tick}` | `render_tick_for_history_v13(p1_parsed, name_map)` | 本 tick 刚由 P1 生成、尚未入库的 narrator+paragraphs |

---

## P3 · 角色对话（intervention）

**用途**：响应用户的 chat 消息，在指定 location 生成 1~3 条角色回复/旁白。

| 占位符 | 来源/装配 | 备注 |
|---|---|---|
| `{world_name}` | 同上 | |
| `{world_setting}` | 同上 | |
| `{current_location}` | `f"{name_map[location_id]} <{location_id}>"` | 当前对话地点 |
| `{character_briefs_on_location}` | `render_character_briefs_on_location(characters, metric, effective_intent, location_id)` | **依据 `_resolve_location_group` 解析当前 location 在最新 tick P2 中的角色集**；找不到回退 `initial_intent` |
| `{character_briefs_not_on_location}` | `render_character_briefs_not_on_location(characters, metric, effective_intent, location_id)` | `on_location` 的反集（非 user、非当前 location 的角色）。`effective_intent` 中找不到当前 location 时退化为"所有非 user 角色" |
| `{user_name}` | `find_user(characters).name` | `char_1` 或 name=`{user}` 的角色 |
| `{user_brief}` | 用户角色的身份/人设/描述/目标四行 | |
| `{char_names}` | `render_char_names(characters, effective_intent, location_id)` | 在场非 user 角色名，顿号分隔；解析逻辑同 `character_briefs_on_location` |
| `{current_time}` | `compute_current_time(..., user_tick_count)` | **不加 1**（P3 不推进 tick） |
| `{memory_summary}` | 同上 | |
| `{tick_history}` | 同上 | |
| `{location_history}` | 同上 | |
| `{history_events}` | `_assemble_unified_history_v13(sess, wv, restrict_latest_tick_to_location=location_id)` | **关键差异**：最新 tick 的 intent 块只保留当前 location，避免对话串到其它地点 |
| `{current_tick}` | `_latest_tick_p1_text(sess)` | 最新 tick 的 P1 文本（旧 v1 格式） |
| `{current_location_intent}` | `_latest_location_intent(sess, location_id)` | 当前 location 的最新 P2 group（旧 v1 格式） |
| `{user_message}` | 用户本次输入原文 | |

---

## 关键拼接器详解

### `_assemble_unified_history_v13` — 时间线融合

实现于 [`scenario_render.py::render_unified_history_v13`](../backend/scenario_render.py)。

**输入**：`ticks`、`chats_map`、`name_map`、`last_n_ticks=5`、`total_chat_limit=50`、`restrict_latest_tick_to_location` (optional)

**算法**：
1. **窗口选取**：取 `ticks[-5:]` 作为 tick 窗口。
2. **chat → tick 归属**：
   - 每个 location 的 chat 列表内向前传播 `from_tick`：P3 消息（无 `from_tick`）继承前面最近一条 seed 消息的 tick。
   - 同一 location 内若无任何 seed 在前，`effective_ft` 保持 `None`。
3. **取最近 50 条**：按 `(effective_ft, lid, ci)` 排序，取末尾 50 条。
4. **分桶**：
   - `effective_ft` 在窗口内 → 进入对应 tick 的桶。
   - 其余（`None` 或落在窗口外）→ overflow 桶。

**输出格式**：

```
[Earlier dialogues]               ← overflow 桶（仅当有内容）
  <Location @ <name> <loc_id>>
    [发言人]: 内容
    ...

[Tick N · Day D, HH:MM]           ← 每个 tick 一段
[narrator] <tick.p1.narrator>
[Day D, HH:MM @ <name> <loc_id>] <paragraph.text>
...                               ← 所有 P1 paragraph（含其它 location，无 Δ）
  <Location @ <name> <loc_id>>      ← P2 location_groups 顺序
    [发言人]: 内容
    ...
  <Location @ <name> <loc_id>>
    ...
```

**P3 专属过滤** (`restrict_latest_tick_to_location`)：
- 仅作用于**最新 tick** 的 intent 渲染段。
- 非当前 location 的 `<Location @ ...>` 块整段跳过。
- narrator / paragraphs 不受影响（保留世界级语境）。
- 更早 tick 完全不受影响。

### `_assemble_tick_history_v13`（兼容字段）

`ticks[-5:]` 的 `p1` 用 `render_tick_for_history_v13` 渲染，块间用 `\n\n` 拼接。每个块：

```
[narrator] <narrator>
[Day D, HH:MM @ <name> <loc_id>] <paragraph.text>
...
```

无 Δ。**不包含**对话。

### `_assemble_location_history_v13`（兼容字段）

跨 location 取最近 50 条 msg，按 location **首次出现顺序**重新分组：

```
[<首条 ts> @ <name> <loc_id>]
[发言人]: 内容
...

[<首条 ts> @ <name> <loc_id>]
...
```

### 角色位置解析（P3 用）

`_resolve_location_group(sess, wv, location_id)` 依次查：
1. `sess.ticks[-1].p2.location_groups` 中 `location_id` 匹配项
2. `sess.worldview_snapshot.initial_intent.location_groups` 中匹配项
3. 都没有 → `None`

返回的 group 被包成 `{"location_groups": [group]}` 作为 `effective_intent` 传给 `render_character_briefs_on_location` / `render_char_names`，从而反映**当前**的角色分布，而非 worldview 初始态。

### Chat 入库时的字段

| 字段 | seed（tick 触发）| P3（用户聊天触发）|
|---|---|---|
| `role` | 旁白/角色/user（按 `_role_for(char_id)` 判定） | 同 |
| `char_id` / `char_name` | 来自 P2 `initial_dialogue` 或 P3 输出 | 用户输入或 P3 输出 |
| `content` | 同上 | 同上 |
| `timestamp` | tick 的 in-world 时间 `Day D, HH:MM` | wall-clock ISO（如 `2026-05-27T10:00:00`）|
| `from_tick` | tick.index | **不存在** |

`from_tick` 的有无是 unified history 区分 seed/P3 并完成归属推断的依据。

---

## 示例

以下示例都基于同一个迷你 worldview：

- **Locations**：`loc_1` 咖啡馆 / `loc_1_1` 吧台 / `loc_1_2` 后院
- **Characters**：`char_1` 用户（user）/ `char_2` 阿明 / `char_3` 客人
- **Ticks**：跑过 2 次（不含 seed）；当前正在请求第 3 次

### 示例 1 · `tick_history`（v1.3 兼容字段）

session 已存在的 ticks 数组（节选）：

```json
[
  {"index": 1, "timestamp": "Day 1, 16:00",
   "p1": {"narrator": "夜色降临。",
          "paragraphs": [
            {"location_id": "loc_1",   "timestamp": "Day 1, 16:00", "text": "客人陆续进门。"},
            {"location_id": "loc_1_1", "timestamp": "Day 1, 16:10", "text": "阿明擦着杯子。"}
          ]}},
  {"index": 2, "timestamp": "Day 1, 16:30",
   "p1": {"narrator": "店里渐渐热闹。",
          "paragraphs": [
            {"location_id": "loc_1", "timestamp": "Day 1, 16:35", "text": "排队的人变多。"}
          ]}}
]
```

渲染输出：

```
[narrator] 夜色降临。
[Day 1, 16:00 @ 咖啡馆 <loc_1>] 客人陆续进门。
[Day 1, 16:10 @ 吧台 <loc_1_1>] 阿明擦着杯子。

[narrator] 店里渐渐热闹。
[Day 1, 16:35 @ 咖啡馆 <loc_1>] 排队的人变多。
```

### 示例 2 · `location_history`（v1.3 兼容字段）

session 的 `chats`：

```json
{
  "loc_1": [
    {"char_name": "客人", "content": "一杯拿铁。", "timestamp": "Day 1, 16:02", "from_tick": 1},
    {"char_name": "客人", "content": "再来一块蛋糕？", "timestamp": "2026-05-27T10:00:00"}
  ],
  "loc_1_1": [
    {"char_name": "阿明", "content": "欢迎光临。",   "timestamp": "Day 1, 16:05", "from_tick": 1},
    {"char_name": "阿明", "content": "马上好。",     "timestamp": "Day 1, 16:33", "from_tick": 2}
  ]
}
```

渲染输出（按 location 首次出现顺序分组，每组首条 ts 做表头）：

```
[Day 1, 16:02 @ 咖啡馆 <loc_1>]
[客人]: 一杯拿铁。
[客人]: 再来一块蛋糕？

[Day 1, 16:05 @ 吧台 <loc_1_1>]
[阿明]: 欢迎光临。
[阿明]: 马上好。
```

### 示例 3 · `history_events`（v1.3 推荐字段，P1/P2 视角）

同一份 ticks + chats，P2 的 `location_groups`：

```json
"tick 1 p2": {"location_groups": [
  {"location_id": "loc_1_1", "characters": []},
  {"location_id": "loc_1",   "characters": []}
]},
"tick 2 p2": {"location_groups": [
  {"location_id": "loc_1",   "characters": []},
  {"location_id": "loc_1_1", "characters": []}
]}
```

渲染输出：

```
[Tick 1 · Day 1, 16:00]
[narrator] 夜色降临。
[Day 1, 16:00 @ 咖啡馆 <loc_1>] 客人陆续进门。
[Day 1, 16:10 @ 吧台 <loc_1_1>] 阿明擦着杯子。
  <Location @ 吧台 <loc_1_1>>
    [阿明]: 欢迎光临。
  <Location @ 咖啡馆 <loc_1>>
    [客人]: 一杯拿铁。

[Tick 2 · Day 1, 16:30]
[narrator] 店里渐渐热闹。
[Day 1, 16:35 @ 咖啡馆 <loc_1>] 排队的人变多。
  <Location @ 咖啡馆 <loc_1>>
    [客人]: 再来一块蛋糕？
  <Location @ 吧台 <loc_1_1>>
    [阿明]: 马上好。
```

> 说明：
>
> - "再来一块蛋糕？" 是 P3 消息（无 `from_tick`），通过 location 内向前传播继承到 tick 1。但因为 tick 2 的 seed 消息也来自同一 location，它最终随同 tick 2 的"咖啡馆" intent 一起渲染——具体见算法步骤 2/3。
> - intent 内顺序按 `ci`（插入序）保留。

### 示例 4 · `history_events`（P3 视角，restrict 到 `loc_1_1`）

同样的数据，但用户正在 `loc_1_1` 吧台聊天。`_build_p3_vars` 传入 `restrict_latest_tick_to_location='loc_1_1'`：

```
[Tick 1 · Day 1, 16:00]
[narrator] 夜色降临。
[Day 1, 16:00 @ 咖啡馆 <loc_1>] 客人陆续进门。
[Day 1, 16:10 @ 吧台 <loc_1_1>] 阿明擦着杯子。
  <Location @ 吧台 <loc_1_1>>
    [阿明]: 欢迎光临。
  <Location @ 咖啡馆 <loc_1>>
    [客人]: 一杯拿铁。

[Tick 2 · Day 1, 16:30]
[narrator] 店里渐渐热闹。
[Day 1, 16:35 @ 咖啡馆 <loc_1>] 排队的人变多。
  <Location @ 吧台 <loc_1_1>>
    [阿明]: 马上好。
```

差异：

- Tick 2（最新 tick）下 `<Location @ 咖啡馆 <loc_1>>` **整块被隐藏**，避免 P3 把"咖啡馆"的对话串到"吧台"。
- narrator + 段落（含 "排队的人变多。"）保留——世界级语境不丢。
- Tick 1（更早）不受影响。

### 示例 5 · `[Earlier dialogues]` overflow

如果有一个 location 从来没在任何 P2 `location_groups` 里出现过，但用户在那儿发过 P3 消息，例如：

```json
"chats": {
  "loc_1_2": [
    {"char_name": "用户", "content": "后院有人吗？", "timestamp": "2026-05-27T09:50:00"},
    {"char_name": "用户", "content": "好安静",       "timestamp": "2026-05-27T09:51:00"}
  ]
}
```

`loc_1_2` 没有任何 seed → 这些消息的 `effective_ft = None` → 进入 overflow 桶，渲染到时间线最前：

```
[Earlier dialogues]
  <Location @ 后院 <loc_1_2>>
    [用户]: 后院有人吗？
    [用户]: 好安静

[Tick 1 · Day 1, 16:00]
...
```

同样规则适用于 `from_tick` 指向窗口外（早于最近 5 个 tick）的消息。

### 示例 6 · P3 角色解析对照

worldview 的 `initial_intent` 只包含 `loc_1`（用户初始在咖啡馆）。session 跑了几 tick 后，用户走到 `loc_1_1`，最新 tick P2 给出：

```json
{"location_groups": [
  {"location_id": "loc_1_1", "characters": [{"char_id": "char_2", "name": "阿明"}]},
  {"location_id": "loc_1",   "characters": [{"char_id": "char_3", "name": "客人"}]}
]}
```

`_build_p3_vars(location_id='loc_1_1')`：

- `_resolve_location_group` 先查最新 tick → 命中 `{loc_1_1: [char_2]}` group。
- `effective_intent = {"location_groups": [<loc_1_1 group>]}`。
- `{character_briefs_on_location}` → 仅渲染 char_2 阿明的简介。
- `{char_names}` → `"阿明"`。
- `{current_location}` → `"吧台 <loc_1_1>"`。

如果 P3 直接用 `wv.initial_intent`，因 `loc_1_1` 不在初始 intent 里，这两个字段都会变成空串——这就是修复前的 bug。

---

## 当前 v1.3 prompt 全文

源文件位于 [`backend/scenario_prompts/`](../backend/scenario_prompts/)，下面是 v1.3 的完整 body（占位符未替换状态）。

### P1 · 叙事推进 — [`p1/v1.3.json`](../backend/scenario_prompts/p1/v1.3.json)

```text
<Role_and_Task>
    你是《{world_name}》的叙事作者。你的任务是基于设定续写世界发生的故事。
</Role_and_Task>

<Worldview_settings>
    {world_setting}
    {metric}

    <Locations>
        {world_locations}
    </Locations>

    <world_events>
        {world_events}
       【预设剧情事件】（世界创建时设定的关键事件，请在叙事推进中择机自然融入，无需每 tick 都触发）
    </world_events>

    <Character_settings>
        {character_briefs_full}
    </Character_settings>
</Worldview_settings>

<History_Events>
    【全局压缩记忆】（供参考，了解历史发生的重要事件）
    {memory_summary}

    【近期事件】（最近 5 个 tick 按时间顺序排列；最近 50 条对话按所属 intent 归入对应 tick 内。每个 tick 块结构为：tick 头 → narrator → 段落 → 各 intent 下的对话。本段叙述需与此衔接，勿重复已交代过的事件）
    {history_events}
</History_Events>

<Current_Time>{current_time}</Current_Time>

<Rules>
    【叙事规则】
	1. 基于current_time的设定，叙述过去一段时间内所发生的故事
	2. 这段故事应该是基于【近期事件】和【基于近期事件的交互细节】两部分的延续，或者基于此开始的新场景
	3. 叙事及地点描述需符合各角色的性格、身份、目标，避免出现与设定矛盾的行为描述。
	4. 角色之间会基于设定和全局压缩记忆做出行为，通过 narrator 与各段落体现。
	5. 时间戳应合理分布在本时段内，事件按时间先后排列。
	6. 从<Locations>中选取合适的场景。
    7. 输出的各个段落之间应该彼此有联系，组成一个共同的故事，而不是彼此完全独立。
	8. 预设剧情事件应在合适时机推进，已发生的事件无需重复触发。

    【数值体系】
    {metric}
    叙事中每段需给出参与角色的 delta，正数表示增加，负数表示减少。
</Rules>

<Output_Schema>
    你的输出包含 2 部分：narrator（旁白段落，描述世界层面的变化与冲突推进，约 80~180 字），paragraphs（数组，1~3 项，每项包含细分地点下发生的具体事件）。

    输出一行合法 JSON（首字符 { 末字符 }，不要换行、不要 markdown、不要解释）：
    {
      "narrator": "旁白段落（80~180字）",
      "paragraphs": [
        {
          "location_id": "loc_X_Y_Z",
          "timestamp": "Day N, HH:MM",
          "text": "子段落正文（角色互动/事件推进，≤80字）",
          "character_deltas": [
            { "char_id": "char_X 或 user_X", "name": "显示名", "delta": 数值 }
          ]
        }
      ]
    }

    硬性要求：
    - 回复有且仅有「一行合法 JSON」
    - 严禁在字符串内部裸用英文双引号 "，改用「」或转义 \"
    - paragraphs 1~3 项，每项必须含 character_deltas
</Output_Schema>
```

### P2 · 地点 intent 调度 — [`p2/v1.3.json`](../backend/scenario_prompts/p2/v1.3.json)

```text
<Role_and_Task>
    你是《{world_name}》的地点调度器与剧本作者。
    任务有两个：
    （1）根据本 tick 刚生成的叙事，给出叙事结束时各角色所处的地点分布；
    （2）为每个地点直接生成 1~2 条初始对话与旁白（总字数 ≤150 字），作为用户进入该地点时的初始剧本。
</Role_and_Task>

<Worldview_settings>
    {world_setting}

    <Locations>
        {world_locations}
    </Locations>

    <world_events>
        {world_events}【预设剧情事件】（世界创建时设定的关键事件，请在叙事推进中择机自然融入，无需每 tick 都触发）
    </world_events>

    <Character_settings>
        {character_briefs_no_user}
    </Character_settings>
</Worldview_settings>

<History_Events>
    当前时间：{current_time}

    【全局压缩记忆】（供参考，了解历史发生的重要事件）
    {memory_summary}

    【近期事件】（最近 5 个 tick 按时间顺序排列；最近 50 条对话按所属 intent 归入对应 tick 内。每个 tick 块结构为：tick 头 → narrator → 段落 → 各 intent 下的对话）
    {history_events}

    【本 tick 叙事】（基于此叙事推断结束时各角色所在地点，并据此生成各地点初始对话；行首格式同上）
    {current_tick}
</History_Events>

<Rules>
    【地点分布规则】
    - 输出 location_groups（数组，1~5 项）
    - location_id 必须来自 world_locations 树中已有的 id，从<Locations>中选取合适的场景match故事。
    - 每个角色只能出现在一个 location_group 的 characters 中
    - 地点分布必须与本 tick 叙事内容一致
    - characters 中不要包含用户角色（user_X）

    【初始对话规则】
    - 每个 location_group 必须附带 initial_dialogue（1~2 条，总字数 ≤150 字）
    - 对话需符合各角色人设与口吻，与 location_summary 衔接
    - 旁白：char_id="nar"，char_name="旁白"，content 用 *斜体* 描写环境/氛围/动作
    - 角色：char_id=该角色 id，char_name=显示名，content 用 *动作* + 台词
    - 临时 NPC：char_id="char_npc"，char_name 写具体称谓如「助理」「服务员」
    - initial_dialogue 中不要为用户角色（user_X）生成台词
</Rules>

<Output_Schema>
    你的输出包含多个location groups。
    只输出合法 JSON：
    {
      "location_groups": [
        {
          "location_id": "loc_X_Y_Z",
          "location_summary": "该地点当前状态（谁在干什么，40~120 字）",
          "characters": [
            { "char_id": "char_X", "name": "显示名" }
          ],
          "initial_dialogue": [
            { "char_id": "nar / char_X / char_npc", "char_name": "旁白 / 显示名 / NPC称谓", "content": "*xxx* xxx" }
          ]
        }
      ]
    }
    不要 markdown 或解释，仅一行合法 JSON。
    硬性要求：严禁在字符串内部裸用英文双引号 "，台词请改用「」或 \"；段落内换行用 \n。
</Output_Schema>
```

### P3 · 角色对话 — [`p3/v1.3.json`](../backend/scenario_prompts/p3/v1.3.json)

```text
<Role_and_Task>
    你是《{world_name}》中该地点的叙事与对话控制器。
</Role_and_Task>

<Worldview_settings>
    【世界观背景与设定】
    {world_setting}
    【世界观背景下的其他角色】
    其他角色list：{character_briefs_not_on_location}
</Worldview_settings>

<History_Events>
    【全局压缩记忆】(供参考，了解已发生的重要事件)
    {memory_summary}

        【近期事件】
        {history_events}
</History_Events>

<Runtime_Context>
    当前时间：{current_time}
    当前地点：{current_location}
    当前角色list：{character_briefs_on_location}

    <User_settings>
    我现在扮演 {user_name}。
    {user_brief}
    </User_settings>

    <User_query>
        [{user_name}]: {user_message}
    </User_query>
</Runtime_Context>

<Rules>
    你需要用「仅一行 JSON 数组」回复，不要用 ``` 包裹、不要输出解释文字。

    【回复类型】共三类，每次可从单类或多种类中组合输出（总条数建议 1~3 条）：
    1. 旁白：描写环境、氛围、动作或结果，用 *斜体* 格式，char_id 固定为 "nar"
    2. 角色回复：在场角色之一，格式 *动作* + 台词，char_name 为在场角色显示名：{char_names} 之一
    3. 临时 NPC：路人、助理等，char_name 直接写入其称谓（如「助理」「工程师」），char_id 固定为 "char_npc"

    【回复要求】
    1. 请遵循角色设定，模拟每个角色的真实表现，让角色动态地做出决定和提议，自主地与环境中的人互动，无需确认或许可。
    2. 角色的表现请尽可能合理地贴近真实情境，让用户有代入感。
    3. 角色的回复需要推动剧情的发展，而不是单纯对用户输入做出反应。
    4. 确保剧情充满起伏，创造多层次的冲突（外部、内部和角色之间），仔细设计合理且意料之外的困境和突破方式。
    5. 当用户引导设定外的地点/人物/事件时，请遵从用户的指引合理推动剧情。
    6. 不为 {user_name} 生成任何台词。
    7. 若某角色已在剧情中离场（死亡或离开），之后的对话中不应再出现该角色的台词。

    【数量与节奏】不必每个在场角色都回复。多数情况下 1 名角色发言即可；仅当剧情需要（如多人同时反应、争执）时才 2~3 人。总条数 1~3 条为宜。

    只输出这一行 JSON 数组，不要其他任何内容。
</Rules>

<Output_Schema>
    请从「旁白 / 角色 / 临时NPC」三类中选单类或组合，输出 1~3 条。每项格式：{"char_id": "nar" | "char_X" | "char_npc", "char_name": "...", "content": "..."}。
    [
      {
        "char_id": "nar / char_X / char_npc",
        "char_name": "旁白 / 角色显示名 / NPC称谓",
        "content": "*动作* 台词"
      }
    ]
    硬性要求：严禁在 content 字符串内部裸用英文双引号 "，台词必须改用「」中文引号或转义 \"；段落内换行用 \n；输出仅一行合法 JSON 数组，无 markdown 围栏、无解释。
</Output_Schema>
```
