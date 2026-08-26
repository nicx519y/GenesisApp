# Firebase Analytics 与 BigQuery 来源分析使用说明

本文档说明 Worldo App 的 Firebase Analytics 事件、BigQuery 来源字段，以及如何按 Android/iOS、事件名称和首次用户来源统计事件、用户与业务设备。

## 1. 文档口径

本文档对比以下两个代码版本：

| 版本口径 | Git 依据 | 说明 |
| --- | --- | --- |
| iOS 0.4.1 | 标签 `ios-v0.4.1+6`，提交 `01397ad169641a015ee85024c464d10dd90f147a` | 本次历史事件核验的基线版本。标签表示 iOS `0.4.1 (6)`；该提交中的 `pubspec.yaml` 为 `0.4.1+41`，因此判断 iOS 发布版本时以 iOS 标签和实际构建号为准。 |
| 当前仓库最新版 | `origin/main`，提交 `76b84ae174ac83e1cf6fc99d25db3ee488969858`，`pubspec.yaml` 为 `0.4.3+45` | 表示当前仓库代码版本；它不等同于已经发布到 App Store 的 iOS 线上版本。该提交同时对应 Android 标签 `android-v0.4.3+45`。 |

本文档中的“事件”主要指应用代码主动发送的 Firebase Analytics 自定义事件。Firebase SDK 自动事件、Firebase Performance、Crashlytics 和 Worldo Collect 是不同的数据通道，不能混为同一类事件。

## 2. 可直接运行的 BigQuery SQL

### 2.1 查询目标

这份 SQL：

- 同时查询 `ANDROID` 和 `IOS`。
- 只查询 `events_YYYYMMDD` 正式日表。
- 按“平台 + 事件 + 首次用户来源 + 媒介 + Campaign + 安装商店”拆分结果。
- 统计事件数、Firebase App 实例数、业务 `device_id` 数量和覆盖率。
- 不使用 `STRING_AGG` 合并来源，因此每个来源会成为单独的一行。

### 2.2 使用方法

1. 修改 SQL 开头的 `start_suffix` 和 `end_suffix`，格式为 `YYYYMMDD`。
2. 在 BigQuery 中选择 `worldo-2026` 项目后运行。
3. 正式分析首次用户来源时，不要把 `events_intraday_*` 加入查询。

```sql
DECLARE start_suffix STRING DEFAULT '20260822';
DECLARE end_suffix STRING DEFAULT '20260825';

WITH event_rows AS (
  SELECT
    platform,
    event_name,
    event_timestamp,
    user_pseudo_id,

    app_info.version AS app_version,
    COALESCE(app_info.install_source, '(not set)') AS install_source,

    -- 本查询采用首次用户来源口径。
    'first_user' AS source_scope,
    COALESCE(traffic_source.source, '(not set)') AS source,
    COALESCE(traffic_source.medium, '(not set)') AS medium,
    COALESCE(traffic_source.name, '(not set)') AS campaign,

    -- 从 event_params 中提取应用上传的业务 device_id。
    NULLIF(
      (
        SELECT ANY_VALUE(
          COALESCE(
            param.value.string_value,
            CAST(param.value.int_value AS STRING),
            CAST(param.value.float_value AS STRING),
            CAST(param.value.double_value AS STRING)
          )
        )
        FROM UNNEST(event_params) AS param
        WHERE param.key = 'device_id'
      ),
      ''
    ) AS device_id

  FROM `worldo-2026.analytics_541728927.events_*`

  WHERE
    -- BETWEEN 只选择 YYYYMMDD 后缀；正则进一步排除 intraday 表。
    _TABLE_SUFFIX BETWEEN start_suffix AND end_suffix
    AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^\d{8}$')
    AND platform IN ('ANDROID', 'IOS')
    AND event_name IN (
      'launch',
      'launch_first',
      'launch_success',
      'launch_success_first',
      'message_sent',
      'message_sent_first',
      'message_sent_10_first',
      'message_sent_20_first',
      'login',
      'login_first',
      'purchase',
      'purchase_first',
      'perf_operation_complete',
      'in_app_purchase'
    )
)

SELECT
  platform,
  event_name,

  -- 来源维度：每种组合单独成行，不合并为字符串。
  source_scope,
  source,
  medium,
  campaign,
  install_source,

  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS user_count,
  COUNT(DISTINCT device_id) AS device_count,

  COUNTIF(device_id IS NOT NULL) AS with_device_id_count,
  COUNTIF(device_id IS NULL) AS without_device_id_count,
  SAFE_DIVIDE(
    COUNTIF(device_id IS NOT NULL),
    COUNT(*)
  ) AS device_id_coverage_rate,

  MIN(
    DATETIME(
      TIMESTAMP_MICROS(event_timestamp),
      'Asia/Shanghai'
    )
  ) AS first_seen_cn,

  MAX(
    DATETIME(
      TIMESTAMP_MICROS(event_timestamp),
      'Asia/Shanghai'
    )
  ) AS last_seen_cn,

  ARRAY_AGG(
    DISTINCT app_version
    IGNORE NULLS
    ORDER BY app_version
  ) AS app_versions

FROM event_rows

GROUP BY
  platform,
  event_name,
  source_scope,
  source,
  medium,
  campaign,
  install_source

ORDER BY
  platform,
  event_name,
  event_count DESC;
```

### 2.3 结果行的含义

每一行代表一个唯一组合：

```text
平台 + 事件名称 + 首次来源 + 媒介 + Campaign + 安装商店
```

例如：

| platform | event_name | source | medium | campaign | event_count | user_count | device_count |
| --- | --- | --- | --- | --- | ---: | ---: | ---: |
| `ANDROID` | `message_sent` | `google` | `cpc` | `android_install` | 300 | 20 | 19 |
| `ANDROID` | `message_sent` | `(direct)` | `(none)` | `(not set)` | 180 | 12 | 11 |
| `IOS` | `message_sent` | `google` | `cpc` | `ios_install` | 120 | 8 | 8 |
| `IOS` | `message_sent` | `(direct)` | `(none)` | `(not set)` | 252 | 13 | 12 |

不要把不同行的 `event_count`、`user_count` 和 `device_count` 当成同一指标：一个用户或设备可以产生多次事件。

这里的 `source_scope = first_user` 表示“来源字段采用首次用户归因口径”，不表示查询结果中的每个用户都是当天新增用户。当前 SQL 的 `user_count` 是查询期间触发所选事件的 Firebase App 实例数。需要统计真正的新安装时，应以 Firebase 自动事件 `first_open` 建立安装 cohort，再通过同一个 `user_pseudo_id` 关联后续携带 `device_id` 的业务事件。

## 3. SQL 输出字段说明

| 字段 | BigQuery 类型 | 含义与统计口径 | 可能值或示例 |
| --- | --- | --- | --- |
| `platform` | `STRING` | 产生事件的数据流平台。 | `ANDROID`、`IOS` |
| `event_name` | `STRING` | Firebase Analytics 事件名称。 | `launch`、`message_sent`、`login_first` 等 |
| `source_scope` | `STRING` | 本查询采用的来源归因口径；SQL 中固定为首次用户来源。 | `first_user` |
| `source` | `STRING` | 首次获取该 Firebase 用户的来源或网络，对应 `traffic_source.source`。 | `google`、`facebook`、`apple`、`(direct)`、`(not set)`；也可能是其他自由文本来源 |
| `medium` | `STRING` | 首次获客媒介，对应 `traffic_source.medium`。 | `cpc`、`organic`、`referral`、`paid_social`、`(none)`、`(not set)` |
| `campaign` | `STRING` | 首次获客 Campaign 名称，对应 `traffic_source.name`。 | 后台配置的 Campaign 名称、`(not set)` |
| `install_source` | `STRING` | 安装 App 的商店或安装来源，对应 `app_info.install_source`；它不是广告来源。 | 取值由平台和 Firebase SDK 决定，例如 App Store、Google Play 对应的商店标识，或 `(not set)` |
| `event_count` | `INT64` | 当前平台、事件和来源组合下的事件总次数。 | 大于等于 `1` |
| `user_count` | `INT64` | `COUNT(DISTINCT user_pseudo_id)`；表示 Firebase App 实例数，不等于注册账号数。 | 大于等于 `1` |
| `device_count` | `INT64` | `COUNT(DISTINCT device_id)`；只统计有非空业务 `device_id` 的事件。 | 大于等于 `0` |
| `with_device_id_count` | `INT64` | 带有非空 `device_id` 的事件条数，不是设备数。 | `0` 到 `event_count` |
| `without_device_id_count` | `INT64` | 没有非空 `device_id` 的事件条数。 | `0` 到 `event_count` |
| `device_id_coverage_rate` | `FLOAT64` | `with_device_id_count / event_count`。 | `0.0` 到 `1.0`；乘以 100 后为百分比 |
| `first_seen_cn` | `DATETIME` | 当前组合在查询范围内最早出现的北京时间。 | `2026-08-22T10:23:22.499001` |
| `last_seen_cn` | `DATETIME` | 当前组合在查询范围内最晚出现的北京时间。 | `2026-08-25T23:59:59.000000` |
| `app_versions` | `ARRAY<STRING>` | 当前组合包含的 App 版本号集合。 | `["0.4.1"]`、`["0.4.1", "0.4.3"]` |

### 3.1 特殊来源值

| 值 | 含义 |
| --- | --- |
| `(direct)` | GA4 将用户归为直接来源，通常表示没有识别到明确的广告或引荐来源。它不一定代表用户确实手动找到 App，也可能是来源信息没有被识别。 |
| `(none)` | 没有媒介，通常与 `(direct)` 搭配。 |
| `(not set)` | 原始字段为空，SQL 通过 `COALESCE` 显示为该值。它表示字段缺失或当前数据中不可用，不等同于 `(direct)`。 |

## 4. BigQuery 中的三种来源口径

GA4 BigQuery 导出中主要有三种来源记录。完整结构见 [GA4 BigQuery Export schema](https://support.google.com/analytics/answer/7029846?hl=en) 和 [Traffic attribution data](https://developers.google.com/analytics/bigquery/traffic-attribution-data)。

| 口径 | BigQuery 字段 | 回答的问题 | 主要字段 |
| --- | --- | --- | --- |
| 首次用户来源 | `traffic_source` | 这个 Firebase 用户第一次是从哪里来的？ | `source`、`medium`、`name` |
| 会话最后点击来源 | `session_traffic_source_last_click` | 产生当前会话的最后点击来源是什么？ | `cross_channel_campaign.*`、`manual_campaign.*`、`google_ads_campaign.*` |
| 事件原始采集来源 | `collected_traffic_source` | 这个事件实际收到了哪些 UTM、referral 或广告点击参数？ | `manual_source`、`manual_medium`、`manual_campaign_name`、`gclid`、`dclid`、`srsltid` |

当前 SQL 只使用 `traffic_source`，原因是本次目标是分析“每个新用户最初从哪里来”。如果把三种口径通过 `COALESCE` 混成一个没有口径说明的 `source`，就无法判断结果代表首次获客、当前会话还是原始 UTM。

需要分析当前会话来源时，应单独使用 `session_traffic_source_last_click` 编写另一份查询，不要直接与本查询相加。

### 4.1 为什么不查询 intraday 表

`traffic_source` 表示首次用户来源，不会因为用户后续进入其他 Campaign 而改变。Firebase 官方结构说明该字段不会填充在 `events_intraday_*` 表中。因此：

- 当天实时检查事件是否上传，可以查询 intraday 表。
- 正式分析首次用户来源，应等待 `events_YYYYMMDD` 日表生成。
- intraday 中的来源为空，不应直接解释为真实的 `(direct)` 或 `(not set)` 用户。

## 5. iOS 0.4.1 的事件和参数

以下清单基于 `ios-v0.4.1+6` 对应提交中的正式业务代码。

### 5.1 应用自定义事件

| 事件 | 触发语义 | 参数 | 参数可能值或说明 | 是否包含 `device_id` |
| --- | --- | --- | --- | --- |
| `launch` | 用户发起 Origin Launch 请求时发送。它不是“打开 App”。 | `origin_id` | Origin ID，非空字符串 | 否 |
|  |  | `role_type` | `preset`、`custom` | 否 |
| `launch_success` | Origin Launch 接口明确成功并返回非空 `world_id` 时发送。 | `origin_id` | Origin ID | 否 |
|  |  | `role_type` | `preset`、`custom` | 否 |
|  |  | `world_id` | 成功创建或进入的 World ID | 否 |
| `message_sent` | 地点聊天中的首次提交动作发送；失败消息的手动重试不会再次记为新的初始发送。 | `world_id` | World ID | 否 |
|  |  | `location_id` | Location ID | 否 |
| `perf_operation_complete` | 受监控的请求或首屏渲染操作完成时发送；对应的 Firebase Performance trace 是另一条数据通道。 | `surface` | `my_worlds`、`popular`、`worldo`、`world_page`、`origin_world_page` | 否 |
|  |  | `phase` | `request`、`render` | 否 |
|  |  | `result` | `success`、`failure`、`cancelled` | 否 |
|  |  | `duration_ms` | 非负整数，单位毫秒 | 否 |
|  |  | `attempt` | 大于等于 `1` 的请求/恢复尝试次数 | 否 |
|  |  | `data_source` | `network`、`prefetched` | 否 |
|  |  | `error_type` | 可选；例如 `render_timeout`、`timeout`、`cancelled`、`transport`、`parse`、`unknown` | 否 |

iOS 0.4.1 没有以下应用自定义 Firebase Analytics 事件：

- `launch_first`
- `launch_success_first`
- `message_sent_first`
- `message_sent_10_first`
- `message_sent_20_first`
- `login`
- `login_first`
- `purchase`
- `purchase_first`

因此，iOS 0.4.1 的上述事件在 BigQuery 中出现 `with_device_id_count = 0` 符合代码预期，不代表 BigQuery 丢失了已经上传的 `device_id`。

### 5.2 iOS StoreKit 事件

iOS 0.4.1 已包含验证 StoreKit 2 transaction 后调用 Firebase 原生 `Analytics.logTransaction(...)` 的链路。Firebase SDK 会据此生成标准 `in_app_purchase` 事件。

根据 Firebase 的 [`in_app_purchase` 事件定义](https://firebase.google.com/docs/reference/swift/firebaseanalytics/api/reference/Constants)，可能出现的标准参数包括：

| 参数 | 说明 |
| --- | --- |
| `currency` | 货币代码 |
| `value` | 交易价值 |
| `product_id` | 商品 ID |
| `product_name` | 商品名称 |
| `quantity` | 数量 |
| `price` | 商品价格 |
| `free_trial` | 是否为免费试用 |
| `price_is_discounted` | 价格是否折扣 |
| `subscription` | 是否为订阅 |

具体字段是否出现由 StoreKit transaction 和 Firebase SDK 决定。该事件不是 `FirebaseAnalyticsMonitoring` 发送的业务自定义事件，业务代码没有为它显式添加 `device_id`。

## 6. 当前仓库最新版 0.4.3+45 的事件和参数

### 6.1 事件总表

| 事件 | 发送频率/语义 | 业务参数 | `device_id` |
| --- | --- | --- | --- |
| `launch` | 每次发起 Origin Launch 时发送 | `origin_id`、`role_type` | 有 |
| `launch_first` | 本地一次性事件；首次成功交给 Firebase SDK 后标记 | 与 `launch` 相同 | 有 |
| `launch_success` | 每次 Launch 明确成功且返回 `world_id` 时发送 | `origin_id`、`role_type`、`world_id` | 有 |
| `launch_success_first` | 本地一次性事件 | 与 `launch_success` 相同 | 有 |
| `message_sent` | 每次地点聊天初始发送时发送；手动重试不重复计数 | `world_id`、`location_id` | 有 |
| `message_sent_first` | 首次初始发送时的一次性事件 | 与 `message_sent` 相同 | 有 |
| `message_sent_10_first` | 本地累计初始发送达到或超过 10 次时的一次性事件 | 与 `message_sent` 相同 | 有 |
| `message_sent_20_first` | 本地累计初始发送达到或超过 20 次时的一次性事件 | 与 `message_sent` 相同 | 有 |
| `login` | 每次 Genesis 后端登录成功时发送 | `method` | 有 |
| `login_first` | 本地首次成功登录的一次性事件；不是“账号首次注册” | 与 `login` 相同 | 有 |
| `purchase` | 验证到 `purchased` 状态时发送的业务事件 | `provider`、`product_id` | 有 |
| `purchase_first` | 本地首次业务购买事件 | 与 `purchase` 相同 | 有 |
| `perf_operation_complete` | 每次受监控操作完成时发送 | `surface`、`phase`、`result`、`duration_ms`、`attempt`、`data_source`、可选 `error_type` | 无显式添加 |
| `in_app_purchase` | iOS 由验证后的 StoreKit 2 transaction 交给 Firebase SDK 生成 | Firebase SDK 标准购买参数 | 无显式添加 |

### 6.2 新增参数及可能值

| 参数 | 适用事件 | 可能值或说明 |
| --- | --- | --- |
| `device_id` | `launch*`、`launch_success*`、`message_sent*`、`login*`、`purchase*` | 平台设备标识字符串；读取为空时发送 `unknown` |
| `method` | `login`、`login_first` | `google`、`apple` |
| `provider` | `purchase`、`purchase_first` | `google`、`apple` |
| `product_id` | `purchase`、`purchase_first` | Google Play/App Store 商品 ID |
| `app_environment` | 最新版启用 Analytics 后设置的 Firebase 默认事件参数 | `production`、`test`；正式 Release + production flavor + 官方 endpoint 为 `production`，开发页强制上传等调试场景为 `test` |

基础事件仍然可以重复发送；`*_first` 事件是在本地 SharedPreferences 中记录的一次性事件。这里的“一次”是本地安装数据生命周期内的一次，不代表整个账号在所有设备上的全局第一次。

### 6.3 相比 iOS 0.4.1 的新增内容

| 变化 | iOS 0.4.1 | 当前仓库 0.4.3+45 |
| --- | --- | --- |
| 基础 `launch`、`launch_success`、`message_sent` | 有 | 保留 |
| `perf_operation_complete` | 有 | 保留，参数结构不变 |
| `login`、`purchase` | 无 | 新增 |
| `*_first` 一次性事件 | 无 | 新增 |
| 10/20 条消息里程碑 | 无 | 新增 |
| 业务 `device_id` 参数 | 无 | 新增到指定业务事件 |
| `app_environment` 默认参数 | 无 | 新增 |

## 7. `device_id` 专项说明

### 7.1 加入时间

业务事件的 `device_id` 与基础事件对应的 `*_first` 事件由提交：

```text
94cfc40a28870479a004729b8ed52f4632c5af11
2026-08-20
Add once-only Firebase analytics events
```

引入。该提交晚于 iOS 0.4.1 标签对应的 `01397ad1`，所以 iOS 0.4.1 没有这些事件参数。

### 7.2 哪些事件携带 `device_id`

最新版代码显式给以下事件添加 `device_id`：

```text
launch
launch_first
launch_success
launch_success_first
message_sent
message_sent_first
message_sent_10_first
message_sent_20_first
login
login_first
purchase
purchase_first
```

以下事件当前没有在业务参数中显式添加 `device_id`：

```text
perf_operation_complete
in_app_purchase
first_open
```

其中 `first_open` 是 Firebase SDK 自动事件，不是应用代码定义的 `*_first` 事件。当前代码的 Firebase 默认参数只设置了 `app_environment`，没有把 `device_id` 注册为默认参数，所以不能假设自动 `first_open` 一定携带业务 `device_id`。

### 7.3 平台生成规则

| 平台 | `device_id` 来源与优先级 |
| --- | --- |
| iOS | 优先读取 Keychain 中 service 为 `com.worldo.ai.device-id`、account 为 `genesis_device_id` 的 UUID；兼容迁移旧 UserDefaults 值；没有值时生成 UUID 并写入 Keychain。Keychain 值可能在卸载重装后仍保留。 |
| Android | 优先使用有效的 Android ID；不可用时使用 AAID；仍不可用时生成 UUID 并写入 SharedPreferences 的 `generated_device_id`。 |

Dart 层读取不到有效值时会返回或上传 `unknown`。因此：

- `device_id IS NOT NULL` 不一定等于“拿到了可关联的真实业务设备 ID”。
- 如需严格覆盖率，可在 SQL 中进一步排除 `device_id = 'unknown'`。
- `device_id` 是高基数字段，适合在 BigQuery 中查询，不建议注册成 GA4 自定义维度。

严格排除 `unknown` 时，可把 SQL 中的提取结果改为：

```sql
NULLIF(
  NULLIF(extracted_device_id, ''),
  'unknown'
) AS device_id
```

实际使用时应在 CTE 中先生成 `extracted_device_id`，再应用上述归一化，避免重复展开 `event_params`。

## 8. 自定义事件、自动事件和 Performance 的区别

| 类型 | 示例 | 数据位置/说明 |
| --- | --- | --- |
| 应用自定义 Analytics 事件 | `launch`、`message_sent`、`login_first` | 由 `FirebaseAnalyticsMonitoring` 调用 `logEvent`；业务参数位于 BigQuery 的 `event_params`。 |
| Firebase 自动 Analytics 事件 | `first_open`、`session_start`、`user_engagement`、部分 `screen_view` | 由 Firebase SDK 自动采集；不属于本文的应用自定义事件清单。 |
| StoreKit Analytics 事件 | `in_app_purchase` | iOS 验证 StoreKit 2 transaction 后调用 Firebase 原生交易接口，由 SDK生成标准事件。 |
| Firebase Performance | `worldo_first_request`、`my_worlds_first_render` 等 trace | 位于 Firebase Performance；不是 Analytics `event_name`。操作完成时另发 `perf_operation_complete` 供 BigQuery 统计成功率和耗时。 |
| Crashlytics | 崩溃、非致命异常 | 位于 Firebase Crashlytics，不在 Analytics `events_*` 表中。 |
| Worldo Collect | 应用业务日志 | 独立业务采集链路，不能当作 Firebase Analytics 事件。 |

## 9. 使用与解释注意事项

1. **首次来源不是当前来源。** `traffic_source` 在用户后续从其他 Campaign 进入时通常不会改变。
2. **`event_count` 不能代表用户数。** 判断用户规模请看 `user_count`，判断业务设备规模请看 `device_count`。
3. **`user_pseudo_id` 不是业务账号 ID。** 它代表 Firebase App 实例。重装、清数据或平台行为可能导致变化。
4. **0.4.1 没有 `device_id` 是代码事实。** 不应把这部分历史数据判定为导出失败。
5. **来源空值需要区分。** `(direct)/(none)` 是一种归因结果，`(not set)` 是字段没有值。
6. **平台必须作为独立维度。** Android 和 iOS 的版本、安装来源和归因能力可能不同，不能先合并再判断。
7. **不要按 `event_name` 单独聚合来源。** 只按事件聚合后再 `STRING_AGG` 来源，会丢失各来源对应的事件数和用户数。
8. **不要把安装商店当成广告来源。** `install_source` 只表示安装商店或安装来源；营销归因使用 `traffic_source`。
9. **支付和账号状态不能只依赖 Analytics。** Analytics 适合分析，不应作为订单、权益或账号首次注册的业务事实来源。
10. **首次来源口径不等于新增用户筛选。** 当前 SQL 会统计查询期间触发所选业务事件的用户；新增安装应使用 `first_open`，首次登录安装应使用 `login_first`，并明确 `login_first` 不是新账号注册。

## 10. 快速排查清单

查询结果不符合预期时，依次检查：

1. 查询的是 `events_YYYYMMDD` 还是 `events_intraday_*`。
2. 日期后缀是否覆盖事件实际发生日期。
3. `platform` 是否为大写 `ANDROID` 或 `IOS`。
4. `app_versions` 是否包含预期测试版本。
5. 事件是否属于对应版本的代码清单。
6. `device_id` 是否应由该事件显式携带。
7. 来源是 `(direct)/(none)`，还是字段真正为空并被显示为 `(not set)`。
8. DebugView 验证的是 SDK 收到事件；BigQuery 日表需要等待每日导出完成。
