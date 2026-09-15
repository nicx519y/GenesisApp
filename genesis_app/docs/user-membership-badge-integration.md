# 用户名会员图标接入

当前方案：接口用户模型直接驱动，不为图标单独发请求。

| 用户名位置 | 状态来源 |
| --- | --- |
| Me / Profile | 已有 user/info 响应的 user.membership_status |
| 搜索 User | 搜索用户项 membership_status |
| 搜索 Worldo / World | owner.membership_status |
| 关注/粉丝、黑名单 | user.membership_status |
| Inbox 私信列表 | peer.membership_status |
| 关注、评论、加入申请通知 | sender / user 的 membership_status |
| Worldo Creator、Discuss 顶部作者 | owner_user.membership_status |
| 评论作者、回复者 | author.membership_status |
| Playing Owner | owner_user.membership_status |
| 回复目标 / Reply to 提示 | 已有目标用户数据；只有 UID/名字时隐藏 |

所有用户模型补齐 gender、age、membershipStatus（JSON 为 membership_status），映射与复制保留这些字段。未知、缺失、非法会员状态不显示，已删除用户不显示；只有整数 1 显示。性别和年龄仅透传，不新增 UI。

复用 ProUserName、ProUserBadge.span、GenesisInlineMetaLabel.membershipStatus 与唯一皇冠组件 ProMembershipBadge，保留文字样式、省略、点击行为、图标比例及系统文字缩放；Me 名字间距 6px，其他 4px。

World / Chat / Location Chat 页面不显示用户名皇冠。图标组件不查询接口、没有 UID 状态缓存及轮询；状态随所属列表/资料接口刷新。现有会员购买、钱包、权益判断保持各自的业务链路。

此文档描述客户端实现与用户提供的新字段约定，不代表在线 Apifox 已保存或后端全接口已经发布。
