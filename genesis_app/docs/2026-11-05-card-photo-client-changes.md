# 候选卡内生图：客户端改动（2026-11-05）

每张候选卡可以单独生成或重生成图片。确认选卡时，同时采用这张卡的文字、图片及图片状态。小手机拍照接口和流程不变。

## 1. 在原创建接口增加 card_id

```http
POST /aitown-chat/api/v1/message/photo/create
```

```json
{
  "client_request_id": "card-photo-9902-001",
  "world_id": "world_1",
  "location_id": "cafe_1",
  "conversation_round_id": "100",
  "card_id": 9902
}
```

`conversation_round_id`继续用十进制字符串，`card_id`沿用卡片接口的int64数字。省略`card_id`仍给当前正式回复生图。

卡片文字为`succeeded`后可生图；图片成功或失败后可再次提交，使用新的`client_request_id`和同一`card_id`。同一张卡图片生成中返回`2073`，不同卡可以并行。卡组最终确认后，只允许选中卡发起新图片任务。网络重发保持请求键和全部参数不变。

价格仍为基础价20 Gems，首次免费规则不变，创建时不传价格。风格仍固定`live`、比例`2:3`；文字重生成不会自动生成图片。

候选图片受理响应示例：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "source": "chat",
    "world_id": "world_1",
    "location_id": "cafe_1",
    "conversation_round_id": "100",
    "card_id": 9902,
    "global_message_id": "8002",
    "photo": {
      "task_id": "task_002",
      "client_request_id": "card-photo-9902-001",
      "status": "generating",
      "image": null,
      "failure": null
    }
  }
}
```

尚未进入正式消息的候选图片没有`message_id/location_message_id`，不要用它推进正式历史游标。

不传`card_id`的正式生图请求，如果取材后、受理前刚好确认了另一张卡，会返回`2072`；刷新当前卡片和正式消息后再提交，避免图片挂到错误的卡。

## 2. 卡片查询返回图片消息

继续通过现有`GET /cards?conversation_round_id=100`恢复卡片；`data.list[].messages`可新增一条`live_photo`消息。关键字段示例：

```json
{
  "type": "live_photo",
  "sender_type": "live_photo",
  "message_type": "image",
  "world_id": "world_1",
  "location_id": "cafe_1",
  "conversation_round_id": 100,
  "card_id": 9902,
  "card_message_index": 3,
  "global_message_id": 8002,
  "payload": {
    "content": "https://cdn.example/photo-b.png",
    "photo": {
      "task_id": "task_002",
      "client_request_id": "card-photo-9902-001",
      "status": "succeeded",
      "image": {
        "asset_id": 502,
        "image_url": "https://cdn.example/photo-b.png",
        "description": "A quiet cafe scene",
        "chat_global_message_id": "8002"
      },
      "failure": null
    }
  }
}
```

卡片的`generation_state`仍只表示文字状态，图片单独看`payload.photo.status`：

| 状态 | 展示 |
| --- | --- |
| `generating` | 显示生成中；有旧成功图则保留旧图 |
| `succeeded` | 展示当前成功图片 |
| `failed` | 显示失败；有旧成功图则保留，可再次生成 |

图片不能通过文字`batch`接口编辑或删除，也不计入“至少保留一条文字”的数量。卡内图片的`global_message_id/card_message_index`在重生成时不变。

## 3. WS 仍用 live_photo，区分卡片与正式视图

候选图片创建、成功、失败均复用`type=live_photo`。私有卡片通知增加`payload.card_id`和`payload.card_message_index`，关键字段如下：

```json
{
  "type": "live_photo",
  "world_id": "world_1",
  "location_id": "cafe_1",
  "conversation_round_id": 100,
  "conversation_type": "user_message",
  "global_message_id": 8002,
  "sender_type": "live_photo",
  "payload": {
    "card_id": 9902,
    "card_message_index": 3,
    "content": "",
    "photo": {
      "task_id": "task_002",
      "client_request_id": "card-photo-9902-001",
      "status": "generating",
      "image": null,
      "failure": null
    }
  }
}
```

- 有`payload.card_id`：只更新指定卡片，不能插入正式消息列表。卡片查询的`card_id`在消息顶层，WS卡片通知在`payload`中。
- 没有`payload.card_id`：按原正式图片消息处理，使用`global_message_id`定位，采用最新`message_id/location_message_id`。

卡片结果同步正式消息时会另发正式事件。两种视图分别更新，不能仅凭相同`global_message_id`把候选内容覆盖到正式历史。结果去重及旧任务不能覆盖新任务的规则不变。

## 4. 选卡一起采用图片

选卡接口不增加参数，仍传`card_id`。按既有`conversation_range_updated`刷新正式历史。

| 选中卡的图片 | 选卡后的正式消息 |
| --- | --- |
| 已成功 | 显示该卡图片 |
| 生成中 | 显示该卡生成状态；完成后继续更新正式图片 |
| 失败 | 显示该卡失败状态，有旧图则保留 |
| 未生成图片 | 不显示图片 |

例如原卡有图A，候选卡9902生成图B：选择9902后正式显示B，A仍在相册；若9902从未生图，选中后正式无图。未选中卡后续完成的图片保留在该卡及相册，不能覆盖已选图片。

## 5. 结果弹窗与 Inbox 通知目标

`phone.photo.result`保持原流程；关联卡片属于收件人本人时，`payload`增加`card_id`，Inbox的`photo_target`也增加该字段。无卡片归属或关联卡片属于其他用户时省略，不能凭正式图片通知查看他人的私有候选：

```json
{
  "biz_id": "world_1",
  "photo_target": {
    "source": "chat",
    "location_id": "cafe_1",
    "conversation_round_id": "100",
    "card_id": 9902,
    "chat_global_message_id": "8002",
    "asset_id": 502
  }
}
```

2026-11-06 客户端交互调整：Inbox 点击聊天照片成功通知只进入对应 World 的地点聊天，不再根据 `card_id`、轮次或消息 ID 定位图片。通知字段协议保持兼容；离线不补弹，Inbox 保留通知。当前客户端规则见[聊天生图接入](chat-photo-client-integration.md)。
