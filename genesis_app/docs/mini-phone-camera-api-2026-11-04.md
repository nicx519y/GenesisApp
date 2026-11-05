# 小手机拍照：客户端对接

更新：2026-11-04，按当前后端实现整理。域名、登录凭证和语言请求头沿用现有配置。

这份文档对接小手机相机，替代此前“小手机暂不对接”的说明。聊天生图仍使用原来的消息生图接口。

## 1. 接入流程

1. 打开相机：调用 `options`，显示价格和风格；角色列表沿用当前 World 的角色数据。
2. 用户选角色、比例、风格，可选填一句描述，再调用 `create`。
3. 受理后显示“生成中”，等待 WS 结果。成功进入相册，失败显示提示；两种结果都有 Inbox 通知。

相机是独立拍照任务，不创建聊天消息。首次说明由客户端维护，失败没有“重新生成”入口。

## 2. 初始化：价格和风格

`GET /aitown-chat/api/v1/phone/photo/options?world_id=world_1`

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "world_id": "world_1",
    "price_cent": 3000,
    "free_status": "available",
    "styles": [
      {"name": "手持自拍", "label": "selfie", "demo_image_url": "https://cdn-001.worldo.ai/predata/miniphonebg/1.webp"},
      {"name": "镜子自拍", "label": "mirror_selfie", "demo_image_url": "https://cdn-001.worldo.ai/predata/miniphonebg/2.webp"},
      {"name": "朋友帮拍", "label": "others_shot", "demo_image_url": "https://cdn-001.worldo.ai/predata/miniphonebg/3.webp"},
      {"name": "抓拍", "label": "candid", "demo_image_url": "https://cdn-001.worldo.ai/predata/miniphonebg/1.webp"},
      {"name": "实况照片", "label": "live", "demo_image_url": "https://cdn-001.worldo.ai/predata/miniphonebg/2.webp"}
    ]
  }
}
```

- `price_cent=3000` 表示基础价 **30 Gems**；免费时该字段仍是 3000。
- `free_status=available` 表示当前可首次免费，`used` 表示已占用或已使用；最终以提交时服务端判定为准。
- 风格显示 `name`，提交时传 `label`。示例图暂为 mock。
- 接口不返回比例列表或上次拍照参数。比例由客户端选择，如 `2:3`、`3:2`、`1:1`；`live` 也生成一张静态图片。

## 3. 提交拍照

`POST /aitown-chat/api/v1/phone/photo/create`

```json
{
  "client_request_id": "camera-photo-001",
  "world_id": "world_1",
  "character_ids": ["char_1", "char_2"],
  "prompt": "两个人在咖啡馆窗边举杯自拍",
  "aspect_ratio": "2:3",
  "style": "selfie"
}
```

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `client_request_id` | 是 | 本次操作的唯一请求键，最长128字符；可使用 UUID |
| `world_id` | 是 | 当前 World ID |
| `character_ids` | 是 | 当前 World 的角色 ID，至少1个、不重复；最终画面最多4人 |
| `prompt` | 否 | 用户描述；可以省略或传空字符串，由后端补全场景 |
| `aspect_ratio` | 是 | 正整数宽:高，如 `2:3`，最长32字符 |
| `style` | 是 | `options.styles[].label` |

例如，用户没写描述时，直接删去上面示例的 `prompt` 字段即可。客户端不传 `source`、`location_id`、`expected_price_cent`、消息 ID、模型或 Prompt 配置。

受理响应：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "source": "camera",
    "world_id": "world_1",
    "photo": {
      "task_id": "0123456789abcdef0123456789abcdef",
      "client_request_id": "camera-photo-001",
      "status": "generating",
      "image": null,
      "failure": null
    }
  }
}
```

保存 `task_id`，用于匹配后续结果。`err_no=0` 只代表受理成功；网络重发原请求时，也可能直接返回该任务的成功或失败状态。

## 4. 接收成功、失败结果

在线且处于原 World 的发起人，会收到 `type=phone.photo.result`。相机用 `payload.source=camera` 区分。

下面为 V2 WS 关键字段，其他信封字段沿用现有协议：

```json
{
  "type": "phone.photo.result",
  "world_id": "world_1",
  "err_no": 0,
  "payload": {
    "event_id": "fedcba9876543210fedcba9876543210",
    "source": "camera",
    "title": "Photo ready",
    "summary": "Your photo is ready.",
    "photo": {
      "task_id": "0123456789abcdef0123456789abcdef",
      "client_request_id": "camera-photo-001",
      "status": "succeeded",
      "image": {
        "asset_id": 123,
        "image_url": "https://cdn.example/photo.png",
        "description": "窗边的午后"
      },
      "failure": null
    }
  }
}
```

客户端用 `task_id` 更新任务，用 `event_id` 去重弹窗。弹窗显示服务端返回的 `title/summary`；相机结果没有聊天消息、轮次或地点消息 ID。相机的 `generating` 来自创建接口响应，`phone.photo.result` 只通知最终成功或失败。

| `photo.status` | 处理 |
| --- | --- |
| `generating` | 显示生成中；`image`、`failure` 均为 `null` |
| `succeeded` | 展示 `image.image_url`，说明取 `image.description`；刷新相册 |
| `failed` | 显示 `failure.message`，不展示重生成按钮 |

失败使用同一种事件，`payload.photo` 示例：

```json
{
  "task_id": "0123456789abcdef0123456789abcdef",
  "client_request_id": "camera-photo-001",
  "status": "failed",
  "image": null,
  "failure": {
    "code": "generation_failed",
    "message": "Couldn't generate the photo."
  }
}
```

`failure.code` 可能为 `generation_failed` 或 `insufficient_balance`，文案已本地化。余额不足可能在任务受理后的后台阶段返回；外层 `err_no=0` 不代表图片生成成功。

HTTP 响应和 WS 的到达顺序不固定；已收到成功/失败后，不用迟到的 `generating` 覆盖终态。离线或不在原 World 时不补弹，后续查看 Inbox 和相册即可。

## 5. Inbox 与相册

Inbox 沿用 API 服务现有接口：

`GET /api/v1/message/notifications?block=world_apply&pn=1&rn=20`

成功通知关键字段：

```json
{
  "notification_id": "fedcba9876543210fedcba9876543210",
  "notice_block": "world_apply",
  "notice_type": "photo_succeeded",
  "biz_id": "world_1",
  "obj_id": "0123456789abcdef0123456789abcdef",
  "content": "Your photo is ready.",
  "photo_target": {"source": "camera", "asset_id": 123}
}
```

- 成功：用 `biz_id` 进入原 World 相册，按 `photo_target.asset_id` 找到图片。
- 失败：`notice_type=photo_failed`，`photo_target` 只有 `source=camera`，没有 `asset_id`；可进入原 World 相机，不定位失败图片。
- `obj_id` 是任务 ID。照片通知不展示 World 申请审核按钮；已读仍走现有 `/api/v1/message/read`。
- `notification_id` 与 WS 的 `event_id` 相同；读取 Inbox 不触发补弹。

相册沿用 Chat 服务现有接口：

`GET /aitown-chat/api/v1/phone/album?world_id=world_1&pn=1&rn=20`

从 `data.list[]` 读取 `asset_id`、`image_url`、`desc`；注意相册说明字段是 `desc`，结果事件里是 `description`。相册只返回成功图片，没有生成中或失败占位，也没有新增按 `asset_id` 查询详情的接口。`asset_id` 沿用64位整数处理。

## 6. 重发、费用和错误

- 每次新的拍照操作生成新的 `client_request_id`。同一次操作响应丢失时，用**原请求键和完全相同参数**重发 `create`，返回原任务，不重复生成或收费。不新增任务轮询接口。
- 同键改参数返回 `2062`，停止自动重发。没有 `photo/regenerate` 接口。
- 首次免费与聊天生图共用账号资格。首次任务受理就占用免费次数，随后任务可并行并按30 Gems收费；原免费任务失败会归还资格，已受理的付费任务不会改为免费。
- 付费失败由服务端处理释放或退款，余额沿用现有刷新流程。失败通知不表示退款已经到账。

HTTP 接口检查 `err_no`，失败显示 `err_msg`；已受理任务的失败显示 `photo.failure.message`。

| HTTP `err_no` | 含义 |
| --- | --- |
| `1001` | 参数无效 |
| `10001` | 未登录 |
| `2061` | World 或角色访问被拒 |
| `2062` | 相同请求键对应了不同参数 |

最小接入范围：`options` + `create` + `phone.photo.result`，再复用既有 Inbox 与相册。
