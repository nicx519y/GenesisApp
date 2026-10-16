# Post 发帖人筛选：客户端增量对接

日期：2026-10-14。本文仅包含本次变更；接口前缀为 `/aitown-chat/api/v1/phone`，沿用登录凭据及世界访问权限。

## 1. 新增发帖人列表

`GET /post/authors?world_id=world_1`

仅传必填 `world_id`。返回该世界已发布帖子中去重后的作者角色 ID，包含玩家角色与 AI 角色；不分页，不返回名字、头像、total、pn 或 rn。按 char_id 升序返回，无数据时 list=[]。

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {"list": ["char_ai_1", "char_player_1"]}
}
```

`list` 中每项均为字符串 char_id。玩家也返回其在该世界的角色 ID，不返回用户 UID。该列表取整个世界的帖子，不受当前帖子分页或已选作者影响。

## 2. 帖子列表增加 char_id 筛选

`GET /posts?world_id=world_1&char_id=char_player_1&pn=1&rn=10`

| Query | 必填 | 说明 |
|---|---|---|
| world_id | 是 | 当前世界，字符串 |
| char_id | 否 | 发帖人角色 ID，最长 64 字符；省略或空字符串表示全部作者；不传 author_type 或用户 UID |
| pn / rn | 否 | 沿用分页：默认 1 / 10，rn 最大 100 |

响应仍为 `data={list,total,pn,rn}`，帖子字段不变；total 为筛选后的帖子总数，仍按 published_at DESC、post_id DESC 排序。角色在该世界没有帖子时 list=[]、total=0。

## 3. 客户端调整

- 加载发帖人列表后，用 char_id 关联已有角色资料；“全部”由客户端提供，查询时省略 char_id。
- 切换作者时重置 pn=1；收到 Post 通知后刷新帖子时保留当前 char_id 筛选，并刷新发帖人列表。
- 两个查询均不自动标记已读。未登录、世界不可访问及参数错误沿用现有错误包装，按 err_no 判断成功。
