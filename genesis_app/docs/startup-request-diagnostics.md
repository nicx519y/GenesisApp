# 启动请求和页面诊断（schema_version=1）

本次仅增加客户端诊断，不修改看板或已有启动统计口径。诊断使用已有 Collect 队列，不阻塞请求、不新增重试、不增加网络等待。

## 事件与兼容性

新增 `monitor / launch_diagnostic`：

- object1：当前 startup_id。
- object2：目标页 home / worldo。
- object3：从 Dart 启动开始的累计毫秒数。
- object4：request_started / request_ended / post_request_error / page_state。
- ext_data：JSON，包含 schema_version=1、stage 以及下述字段。

原有 launch_startup、launch_page、launch_req_start、launch_req_end、launch_render 保持原调用及去重口径；launch_req_* 仍只记录首次请求。不要把新的诊断事件作为启动次数或阶段总耗时样本。当前看板通过事件白名单筛选，会忽略 launch_diagnostic；需查看原始日志才能读取本次新增字段。

## 请求尝试

request_id = startup_id:page:attempt；attempt 从 1 开始，retry_count = attempt - 1。同一次启动的每次目标页首屏加载分别记录开始、结束，结束只记录一次。

这是页面层的一次逻辑加载，覆盖 API 调用及返回数据解析，不是纯 HTTP 传输时长，也不等于网关或传输层内部重试次数。首次内容成功渲染后不再创建新的启动请求诊断；已经开始的请求仍可闭合，兼容缓存先渲染、网络后返回。

结束字段：result（success/failure/cancelled）、duration_ms。失败字段只记录结构化 error_type、error_kind，及可用的 transport_error_kind、client_failure_code、http_status、business_code。不会添加异常原文、URL、响应体、UID 或 token。

取消 reason：

- page_disposed：页面销毁后放弃本次加载结果。
- feed_reset：列表状态重置后放弃原加载结果。
- transport_cancelled：传输层明确返回取消异常。

前两者是逻辑加载取消，不表示已验证底层 HTTP 连接被中止。取消后的迟到成功或错误不会覆写请求终态。若请求已经成功，而后续页面准备代码抛错，则另记 post_request_error，不改写 request_ended=success。

## 页面处理

page_state 携带 state、可用的 request_id/attempt、reason、retry_delay_ms、render_result。

- loading_retained / content_retained：失败处理决定继续保留加载态或已有内容，不表示新内容已渲染。
- retry_scheduled / retry_started / retry_waiting / retry_skipped：重试计划、触发、等待现有请求结束或跳过原因。
- lifecycle_changed：Worldo 首屏完成前观察到的生命周期变化。
- render_scheduled：已安排下一帧回调，不是完成渲染。
- render_observed：通过原有页面有效性检查、执行到帧后回调。render_result 区分 cache/network/network_empty/network_error。
- render_skipped：帧回调或后续页面准备因页面销毁、页面不活跃或被新状态替代而跳过。
- page_disposed / feed_reset：页面销毁或列表状态重置。
- content_unchanged：请求返回后判定内容无变化，保留已有内容。

`lifecycle_inactive_suspected_prompt` 仅表示客户端从生命周期推测可能存在权限弹窗，不代表已确认弹窗类型或用户权限选择。

缓存渲染没有网络 request_id。已有首次内容成功后停止新的页面状态诊断，避免普通使用行为不断增加启动事件。network_error 仍是错误页，不是成功内容；本次不修改启动结果口径。

## 示例

一次失败后自动恢复：

1. attempt=1 request_started
2. attempt=1 request_ended result=failure error_kind=timeout
3. attempt=1 page_state loading_retained reason=retry_pending
4. attempt=1 page_state retry_scheduled retry_delay_ms=2000
5. attempt=1 page_state retry_started reason=timer
6. attempt=2 request_started
7. attempt=2 request_ended result=success
8. attempt=2 page_state render_scheduled render_result=network
9. attempt=2 page_state render_observed render_result=network
10. 原有 launch_render=network

页面销毁时：请求结束 cancelled/page_disposed，随后 page_disposed；如果请求已成功，保留成功终态，页面销毁或渲染跳过另行解释。

## 验证边界

需要新版客户端运行并送达日志后才能用于诊断，不能补全历史日志。进程直接退出、日志未送达或时间范围截断仍可能缺少最后一条记录。这里的帧后回调沿用已有渲染证据，不代表所有封面图片已下载，亦不证明用户实际看到了屏幕。
