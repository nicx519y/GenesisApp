# Browse Page Design Standard

这份文档只定义标准，不按代码模块逐项罗列。Home 和 Origin World 是两种不同页面形态，分别使用各自的 spacing 标准。

## Colors

| Token | Value | Usage |
| --- | --- | --- |
| `nameColor` | `#4B6192` | origin name、world name、入口文字 |
| `accentRed` | `#FF2344` | 红色强调、section icon、character tagline、red star |

## Home Page Standard

Home 是 feed 浏览页。它的基础单位是列表 card，标准按“页面 -> card -> card 内内容层级”定义。

### Home Page Level

| Standard | Value | Rule |
| --- | --- | --- |
| 页面左右边距 | `16px` | header、feed card 与页面边缘保持一致 |
| header 到 tabs | `4px` | 顶部导航区和 tab 区保持紧凑 |
| logo 到 search | `12px` | header 内主要元素间距 |
| tabs 垂直 padding | `0px` | tab 区不额外拉高 |
| tabs 对齐 | centered | tabs 在 Home 顶部居中排列 |

### Home Feed Level

| Standard | Value | Rule |
| --- | --- | --- |
| feed 顶部留白 | `10px` | tab 下方第一张 card 的起始距离；My Worlds 和 Popular 保持一致 |
| feed 底部留白 | Popular `24px` / My Worlds `36px` | My Worlds 保留更多底部滚动缓冲 |
| card 左右内缩 | `16px` | 所有 feed card 内容对齐页面主边距 |
| card 与 card 之间 | `40px` | 视觉总间距；由 `24px` 上间距 + `1px` divider + `16px` 下间距组成 |
| load more 区域上下 | `18px` | 加载更多状态的垂直留白 |

### Home Card Level

| Standard | Value | Rule |
| --- | --- | --- |
| card 缩略图 | `60px x 60px` | feed card 头部统一首图尺寸 |
| 缩略图到文字区 | `14px` | card 头部图文间距 |
| 标题到 meta | `8px` | name/title 到 ID、owner、originator 等元信息 |
| meta 项之间 | `24px` | 同一行两个 meta 信息之间 |
| meta 到 stats | `8px` | 元信息到数据统计行 |
| stats 横向 / 纵向间距 | `10px / 4px` | stats wrap 的 item 间距 |
| stat icon 到数字 | `4px` | icon 与数值紧凑绑定 |

### Home Card Content Level

| Standard | Value | Rule |
| --- | --- | --- |
| card header 到首个内容组 | `16px` | 头部摘要和正文内容之间 |
| card 内内容组之间 | `16px` | feed card 内不同信息组之间 |
| 内容组 icon 到标题 | `8px` | Home card 内所有 section header 图标和标题 |
| 内容组标题到正文 | `8px` | 标题到文本、列表、chip、输入等主体内容 |
| 正文到图片 | `8px` | 文本内容和媒体预览之间 |
| progress 正文到 meta | `0px` | progress summary 与 WID / tick / time 贴合显示 |
| 左侧 meta 到右侧时间 | `12px` | WID/tick 区域到 timestamp |
| 多张预览图之间 | `10px` | 图片网格横向间距 |

### Home Variant Rules

| Variant | Standard | Value |
| --- | --- | --- |
| My Worlds 当前用户状态 | avatar 到文字 `12px`；名称到正文 `4px`；名称到 role `8px` |
| My Worlds tick time chip | 内边距 `12px 9px` |
| My Worlds progress header | icon 到标题 `8px`；标题到右侧时间 `10px` |
| Popular origin hero image | 高度 `160.5px` |
| Popular progress summary | 固定 5 行正文高度；字号 `13px`；line-height `1.42`；高度公式 `13 * 1.42 * 5 + 6` |
| Popular tick chip | WID 到 chip `9px`；icon 到数字 `3px`；padding `5px 2px 7px 2px` |
| Popular enter row | title 到 action `12px`；action 到 chevron `4px` |

## Origin World Page Standard

Origin World 是 detail 浏览页。它的基础单位不是 card，而是详情 section。标准按“页面壳 -> section 流 -> section 内内容层级”定义。

### Origin Page Level

| Standard | Value | Rule |
| --- | --- | --- |
| 地图顶部 tabs 左右 | `12px` | 悬浮控件贴近地图但不贴边 |
| 地图顶部 tabs 到安全区 | `safe area top + 8px` | 顶部悬浮控件避开系统区域 |
| 地图 overlay 内容偏移 | `48px` | overlay 内容从 tabs 下方展开 |
| 详情面板顶部间距 | `50px` | map 和 detail panel 的初始视觉间隔 |
| 详情面板 collapsed offset | 内容态 `60px` / loading `100px` | loading 态保留更高骨架展示空间 |
| 底部操作栏左右 | `13px` | bottom bar 安全边距 |

### Origin Section Level

| Standard | Value | Rule |
| --- | --- | --- |
| section 与 section 之间 | `24px` | 详情页一级内容块之间的统一距离 |
| section 标题到正文 | `8px` | 标题到文本、列表、事件、输入、卡片 |
| 正文到媒体 | `8px` | 文本内容到地图预览图 / 图片 |
| progress 正文到 meta | `0px` | summary 与 WID / tick / time 贴合显示 |
| 左侧 meta 到右侧时间 | `12px` | WID/tick 区域到 timestamp |
| 空状态到输入区 | `8px` | 空讨论/摘要到用户输入入口 |

### Origin Header Level

| Standard | Value | Rule |
| --- | --- | --- |
| origin name 到 meta 行 | `4px` | 标题和身份信息紧密绑定 |
| meta 项之间 | `12px` | OID 到 Originator |
| meta 行到版本行 | `0px` | 版本信息属于同一身份信息组 |
| 版本行到主操作 | `8px` | Edit Origin 与身份信息组分开 |
| inline 文本到 chevron | `4px` | 可点击 inline link 的图文间距 |
| inline link 垂直 padding | `3px` | 保证点击热区但不撑高行距 |

### Origin Rich Content Level

| Standard | Value | Rule |
| --- | --- | --- |
| 详情预览图最大高度 | `360px` | 避免图片压过正文信息 |
| 详情预览图最大屏高 | `35%` | 小屏上限制媒体占比 |
| 详情预览图宽高比 | `2:3` | Origin World View 预览图比例 |
| 角色头像 | `86px` | 角色列表头像尺寸 |
| 角色头像到文字 | `14px` | 角色行图文间距 |
| 角色行之间 | `20px` | 多角色列表的行间距 |
| 角色标题到第一行 | `14px` | 角色 section 标题到列表 |
| 角色短文本间距 | `5px` | name、identity、tagline 等短文本组 |
| 角色正文段落间距 | `9px` | description、goal 等长文本组 |
| 角色红星 | `20px` | 角色头像强调标记 |

### Origin Bottom Action Level

| Standard | Value | Rule |
| --- | --- | --- |
| bottom bar 高度 | `56px` | 固定底部操作栏高度 |
| bottom stats 之间 | `20px` | 底部统计项间距 |
| stats 到按钮 | `18px` | 左侧 stats group 到 Launch button |
| Launch button | `140px x 35px` | 固定主按钮尺寸 |
| chat launch bar padding | `16px 10px 16px 10px + bottom safe area` | chat 场景下底部操作条 |

## Usage Rules

- Home 只使用 Home Page Standard；Origin World 只使用 Origin World Page Standard。
- Home 的核心单位是 feed card，所以用 card-level 标准。
- Origin 的核心单位是 detail section，所以用 section-level 标准。
- 只有颜色、标题到正文 `8px`、正文到媒体 `8px`、progress 到 meta `0px` 这类跨页面一致的规则允许保持同值。
- 新增内容时先判断页面形态，再选对应标准；不要把 Home card 标准迁移到 Origin detail，也不要反过来。
