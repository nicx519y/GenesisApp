import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "/Users/ionix/Works/GenesisApp/outputs";
const outputPath = `${outputDir}/worldo_collect_埋点计划.xlsx`;
const previewDir = `${outputDir}/collect_excel_build/previews`;

const commonFields = [
  ["位置", "字段", "值来源", "是否进入 body"],
  ["Header", "X-Platform", "当前平台，归一为 android / ios", "否"],
  ["Header", "X-Device-ID", "App 当前设备 ID", "否"],
  ["Header", "X-App-Version", "App version name", "否"],
  ["Header", "X-UID", "已登录用户 uid；未登录不传", "否"],
  ["Body", "action_type", "pageview 或 event", "是"],
  ["Body", "action", "页面名或事件名", "是"],
  ["Body", "object1", "业务对象 ID / query，按具体统计项传", "是，非空才传"],
  ["Body", "object2", "第二业务对象 ID / tickN，按具体统计项传", "是，非空才传"],
  ["Body", "object3", "第三业务对象 ID，按具体统计项传", "是，非空才传"],
  ["服务端", "IP address", "collect 服务端从请求来源 IP 获取", "否"],
  ["服务端", "created_at", "collect 服务端生成", "否"],
];

const pageViews = [
  ["统计", "加入场景", "方法", "action_type", "action", "object1", "object2", "object3", "参数值来源"],
  ["home_my_worlds", "进入首页 My worlds 或切到该 tab", "GenesisTelemetry.collectLog", "pageview", "home_my_worlds", "", "", "", "HomePage 当前 tab"],
  ["home_popular", "进入首页 Popular 或切到该 tab", "GenesisTelemetry.collectLog", "pageview", "home_popular", "", "", "", "HomePage 当前 tab"],
  ["worldo_detail", "打开 worldo 详情页", "GenesisTelemetry.collectLog", "pageview", "worldo_detail", "oid", "", "", "路由参数 oid / 页面 OriginDetail.oid"],
  ["world_detail", "打开 world 详情页", "GenesisTelemetry.collectLog", "pageview", "world_detail", "wid", "", "", "路由参数 wid / WorldPage.widget.wid"],
  ["worldo_list_tab", "切到 worldo list tab", "GenesisTelemetry.collectLog", "pageview", "worldo_list_tab", "", "", "", "AppShellPage selectedIndex=1"],
  ["create_worldo", "进入创建页", "GenesisTelemetry.collectLog", "pageview", "create_worldo", "", "", "", "CreateOriginPage init"],
  ["messages_home", "进入 Messages 首页", "GenesisTelemetry.collectLog", "pageview", "messages_home", "", "", "", "AppShellPage selectedIndex=3"],
  ["me", "进入 Me tab", "GenesisTelemetry.collectLog", "pageview", "me", "", "", "", "AppShellPage selectedIndex=4"],
  ["profile", "打开用户 Profile", "GenesisTelemetry.collectLog", "pageview", "profile", "uid", "", "", "RouteNames.userInfo 参数 uid"],
  ["launch_sheet", "打开 launch 弹窗", "GenesisTelemetry.collectLog", "pageview", "launch_sheet", "oid", "", "", "OriginDetail.oid"],
  ["worldo_detail_location_list", "worldo 详情页进入 location list", "GenesisTelemetry.collectLog", "pageview", "worldo_detail_location_list", "oid", "", "", "OriginWorldPage.widget.oid"],
  ["messages_notifications", "打开 Notifications", "GenesisTelemetry.collectLog", "pageview", "messages_notifications", "", "", "", "RouteNames.notifications"],
  ["messages_new_followers", "打开 New followers", "GenesisTelemetry.collectLog", "pageview", "messages_new_followers", "", "", "", "RouteNames.newFollowers"],
  ["messages_comments", "打开 Comments", "GenesisTelemetry.collectLog", "pageview", "messages_comments", "", "", "", "RouteNames.comments"],
  ["messages_private_chat", "打开私聊页", "GenesisTelemetry.collectLog", "pageview", "messages_private_chat", "peer_uid", "", "", "RouteNames.chat 参数 peer_uid / uid"],
  ["search", "进入 Search 页面", "GenesisTelemetry.collectLog", "pageview", "search", "", "", "", "RouteNames.search"],
  ["worldo_map", "打开 worldo location map", "GenesisTelemetry.collectLog", "pageview", "worldo_map", "oid", "loc_id", "", "OriginDetail.oid；WorldPoint sceneId/pointId/id"],
  ["worldo_location_chat", "打开 worldo location chat", "GenesisTelemetry.collectLog", "pageview", "worldo_location_chat", "oid", "loc_id", "", "OriginDetail.oid；WorldPoint sceneId/pointId/id"],
  ["world_detail", "world 内 detail tab", "GenesisTelemetry.collectLog", "pageview", "world_detail", "wid", "", "", "WorldPage.widget.wid"],
  ["world_locations", "world 内 locations tab", "GenesisTelemetry.collectLog", "pageview", "world_locations", "wid", "", "", "WorldPage.widget.wid"],
  ["world_events", "world 内 events tab", "GenesisTelemetry.collectLog", "pageview", "world_events", "wid", "", "", "WorldPage.widget.wid"],
  ["world_status", "world 内 status tab", "GenesisTelemetry.collectLog", "pageview", "world_status", "wid", "", "", "WorldPage.widget.wid"],
  ["world_cast", "world 内 cast tab", "GenesisTelemetry.collectLog", "pageview", "world_cast", "wid", "", "", "WorldPage.widget.wid"],
  ["world_map", "打开 world location map", "GenesisTelemetry.collectLog", "pageview", "world_map", "wid", "loc_id", "", "WorldPage.widget.wid；WorldPoint sceneId/pointId/id"],
  ["world_location_chat", "打开 world location chat", "GenesisTelemetry.collectLog", "pageview", "world_location_chat", "wid", "loc_id", "", "WorldPage.widget.wid；WorldPoint sceneId/pointId/id"],
];

const events = [
  ["统计", "加入场景", "方法", "action_type", "action", "object1", "object2", "object3", "参数值来源"],
  ["create_worldo_submit_start", "点击 Create 后，调用 create 接口前", "GenesisTelemetry.collectLog", "event", "create_worldo_submit_start", "", "", "", "此时还没有 oid，不传 object1"],
  ["create_worldo_submit_success", "create 接口返回 oid 后", "GenesisTelemetry.collectLog", "event", "create_worldo_submit_success", "oid", "", "", "CreateOriginResult.oid"],
  ["create_worldo_async_complete", "轮询 origin/info 确认完成后", "GenesisTelemetry.collectLog", "event", "create_worldo_async_complete", "oid", "", "", "OriginPendingSubmissionCoordinator completed outcome"],
  ["edit_worldo_submit_start", "点击 Publish 后，调用 update 接口前", "GenesisTelemetry.collectLog", "event", "edit_worldo_submit_start", "oid", "", "", "EditOriginPage draft.basics.originId"],
  ["edit_worldo_submit_success", "update 接口返回成功后", "GenesisTelemetry.collectLog", "event", "edit_worldo_submit_success", "oid", "", "", "CreateOriginResult.oid"],
  ["edit_worldo_async_complete", "轮询 origin/info 确认完成后", "GenesisTelemetry.collectLog", "event", "edit_worldo_async_complete", "oid", "", "", "OriginPendingSubmissionCoordinator completed outcome"],
  ["worldo_launch_submit_start", "launch 确认提交，调用 origin/launch 前", "GenesisTelemetry.collectLog", "event", "worldo_launch_submit_start", "oid", "", "", "OriginDetail.oid"],
  ["worldo_launch_submit_success", "origin/launch 返回 wid 后", "GenesisTelemetry.collectLog", "event", "worldo_launch_submit_success", "oid", "wid", "", "OriginDetail.oid；origin/launch 返回 world_id/wid"],
  ["worldo_launch_async_complete", "轮询确认 tick1 完成后", "GenesisTelemetry.collectLog", "event", "worldo_launch_async_complete", "oid", "wid", "", "OriginLaunchCoordinator completed outcome"],
  ["world_progress_submit_start", "点击 Progress 后，调用 world/tick 前", "GenesisTelemetry.collectLog", "event", "world_progress_submit_start", "wid", "", "", "WorldPage.widget.wid"],
  ["world_progress_submit_success", "world/tick 返回成功后", "GenesisTelemetry.collectLog", "event", "world_progress_submit_success", "wid", "tickN", "", "WorldPage.widget.wid；world/tick 返回 tick_cnt"],
  ["world_progress_async_complete", "world/info 轮询确认不再 progressing 后", "GenesisTelemetry.collectLog", "event", "world_progress_async_complete", "wid", "tickN", "", "WorldPage.widget.wid；刷新后的 WorldDetail.tickCount"],
  ["login", "登录成功写入用户态后", "GenesisTelemetry.collectLog", "event", "login", "", "", "", "BackendAuthCoordinator login success"],
  ["logout", "logout 清理用户态前", "GenesisTelemetry.collectLog", "event", "logout", "", "", "", "BackendAuthCoordinator signOut"],
  ["delete_account", "删除账号成功后", "GenesisTelemetry.collectLog", "event", "delete_account", "", "", "", "BackendAuthCoordinator deleteAccount"],
  ["request_submit", "world request 提交成功后", "GenesisTelemetry.collectLog", "event", "request_submit", "wid", "", "", "WorldPage.widget.wid"],
  ["search_click", "点击搜索结果", "GenesisTelemetry.collectLog", "event", "search_click", "query", "oid/wid/uid", "", "SearchPage._activeQuery；SearchResultItem.entityId"],
  ["home_my_worlds_click", "点击 My worlds item", "GenesisTelemetry.collectLog", "event", "home_my_worlds_click", "wid", "", "", "WorldListItem.wid"],
  ["home_popular_click", "点击 Popular item", "GenesisTelemetry.collectLog", "event", "home_popular_click", "oid", "", "", "OriginListItem.oid"],
  ["worldo_list_click", "点击 worldo list item", "GenesisTelemetry.collectLog", "event", "worldo_list_click", "oid", "", "", "OriginListItem.oid"],
  ["me_click", "点击 Me/Profile 页面 oid/wid 内容", "GenesisTelemetry.collectLog", "event", "me_click", "oid/wid", "", "", "UserProfileOriginItem.oid 或 UserProfileWorldItem.wid"],
  ["worldo_map_click", "点击 worldo map 任意位置", "GenesisTelemetry.collectLog", "event", "worldo_map_click", "oid", "", "", "OriginDetail.oid"],
  ["world_locations_click", "点击 location 列表项", "GenesisTelemetry.collectLog", "event", "world_locations_click", "wid", "loc_id", "", "WorldDetail.worldId；WorldPoint sceneId/pointId/id"],
  ["world_map_click", "点击 world map 任意位置", "GenesisTelemetry.collectLog", "event", "world_map_click", "wid", "", "", "WorldPage.widget.wid"],
  ["location_chat_send_message", "location chat 发消息成功后", "GenesisTelemetry.collectLog", "event", "location_chat_send_message", "wid", "loc_id", "message_id", "LocationChatPage.widget.worldId；widget.locationId；ack.messageId"],
  ["private_chat_send_message", "私聊发送成功后", "GenesisTelemetry.collectLog", "event", "private_chat_send_message", "peer_uid", "message_id", "", "ChatPage._peerUid；dm send 返回 message_id/id"],
];

function writeSheet(workbook, name, rows, tableName, widths) {
  const sheet = workbook.worksheets.add(name);
  sheet.showGridLines = false;
  const rowCount = rows.length;
  const colCount = rows[0].length;
  const range = sheet.getRangeByIndexes(0, 0, rowCount, colCount);
  range.values = rows;
  sheet.freezePanes.freezeRows(1);
  sheet.getRangeByIndexes(0, 0, 1, colCount).format = {
    fill: "#1F4E79",
    font: { bold: true, color: "#FFFFFF" },
  };
  sheet.getRangeByIndexes(0, 0, rowCount, colCount).format = {
    wrapText: true,
    borders: { preset: "inside", style: "thin", color: "#E5E7EB" },
  };
  sheet.getRangeByIndexes(0, 0, rowCount, colCount).format.borders = {
    preset: "outside",
    style: "thin",
    color: "#CBD5E1",
  };
  for (let col = 0; col < widths.length; col += 1) {
    sheet.getRangeByIndexes(0, col, rowCount, 1).format.columnWidth = widths[col];
  }
  sheet.getRangeByIndexes(0, 0, rowCount, colCount).format.rowHeight = 30;
  const table = sheet.tables.add(
    `A1:${columnName(colCount)}${rowCount}`,
    true,
    tableName,
  );
  table.showFilterButton = true;
  return sheet;
}

function columnName(count) {
  let n = count;
  let name = "";
  while (n > 0) {
    const rem = (n - 1) % 26;
    name = String.fromCharCode(65 + rem) + name;
    n = Math.floor((n - 1) / 26);
  }
  return name;
}

await fs.mkdir(outputDir, { recursive: true });
await fs.mkdir(previewDir, { recursive: true });

const workbook = Workbook.create();
writeSheet(workbook, "公共字段", commonFields, "CommonFieldsTable", [12, 20, 44, 18]);
writeSheet(workbook, "页面访问统计", pageViews, "PageViewStatsTable", [28, 36, 28, 16, 30, 18, 18, 18, 48]);
writeSheet(workbook, "行为统计", events, "BehaviorStatsTable", [30, 42, 28, 16, 32, 18, 18, 18, 52]);

for (const [sheetName, range] of [
  ["公共字段", "A1:D12"],
  ["页面访问统计", `A1:I${pageViews.length}`],
  ["行为统计", `A1:I${events.length}`],
]) {
  const preview = await workbook.render({
    sheetName,
    range,
    scale: 1,
    format: "png",
  });
  await fs.writeFile(
    `${previewDir}/${sheetName}.png`,
    new Uint8Array(await preview.arrayBuffer()),
  );
}

const inspectCommon = await workbook.inspect({
  kind: "table",
  range: "公共字段!A1:D12",
  include: "values",
  tableMaxRows: 12,
  tableMaxCols: 4,
});
console.log(inspectCommon.ndjson);

const inspectPages = await workbook.inspect({
  kind: "table",
  range: `页面访问统计!A1:I${pageViews.length}`,
  include: "values",
  tableMaxRows: pageViews.length,
  tableMaxCols: 9,
  maxChars: 6000,
});
console.log(inspectPages.ndjson);

const inspectEvents = await workbook.inspect({
  kind: "table",
  range: `行为统计!A1:I${events.length}`,
  include: "values",
  tableMaxRows: events.length,
  tableMaxCols: 9,
  maxChars: 6000,
});
console.log(inspectEvents.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);
console.log(outputPath);
