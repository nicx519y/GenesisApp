const state = {
  cursor: 0,
  events: [],
  snapshot: null,
  activeLocationId: "",
  appActiveLocationId: "",
  activeWorldId: "",
  activeNetworkTab: "http",
  networkSinceCursor: 0,
  expandedNetworkRows: new Set(),
  virtualListSeq: 0,
  virtualListIds: new Map(),
  virtualLists: new Map(),
  virtualScrollTops: new Map(),
  virtualHeightCache: new Map(),
  virtualResizeObserver: null,
  locationTabsSignature: "",
  pollTimer: null
};

const statusEl = document.getElementById("connectionStatus");
const summaryGrid = document.getElementById("summaryGrid");
const locationTabGroup = document.getElementById("locationTabGroup");
const networkTabGroup = document.getElementById("networkTabGroup");
const websocketFrames = document.getElementById("websocketFrames");
const httpMessages = document.getElementById("httpMessages");

document.getElementById("refreshButton").addEventListener("click", refreshAll);
document.getElementById("clearButton").addEventListener("click", clearEvents);
document.getElementById("exportButton").addEventListener("click", exportJson);

locationTabGroup.addEventListener("sl-tab-show", (event) => {
  const locationId = `${event.detail.name || ""}`.trim();
  if (!locationId || locationId === state.activeLocationId) return;
  state.activeLocationId = locationId;
  renderQueueTabs();
  queueMicrotask(mountVirtualLists);
});

networkTabGroup.addEventListener("sl-tab-show", (event) => {
  const tabName = `${event.detail.name || ""}`.trim();
  if (!tabName || tabName === state.activeNetworkTab) return;
  state.activeNetworkTab = tabName;
  renderWebSocketFrames();
  renderHttpMessages();
  queueMicrotask(mountVirtualLists);
});

window.addEventListener("resize", () => {
  for (const container of document.querySelectorAll(".virtual-list")) {
    scheduleVirtualListRender(container, {preserveAnchor: true});
  }
});

function rpc(method, params = {}) {
  return fetch("/api/rpc", {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
      method,
      params
    })
  }).then(async (res) => {
    const json = await res.json();
    if (!json.ok) {
      const message = json.error?.message || json.error?.code || "RPC failed";
      throw new Error(message);
    }
    return json.result;
  });
}

async function refreshAll() {
  try {
    const snapshot = await rpc("debug.locationChat.snapshot");
    state.snapshot = snapshot;
    state.cursor = Number(snapshot.nextCursor || 1) - 1;
    state.events = Array.isArray(snapshot.events) ? snapshot.events : [];
    setStatus(snapshot);
    render();
  } catch (error) {
    statusEl.textContent = `Disconnected: ${error.message}`;
  }
}

async function pollEvents() {
  try {
    const result = await rpc("debug.locationChat.events", {
      cursor: state.cursor,
      limit: 100
    });
    state.cursor = Number(result.nextCursor || state.cursor);
    if (Array.isArray(result.events) && result.events.length) {
      state.events.push(...result.events);
      if (state.events.length > 500) {
        state.events.splice(0, state.events.length - 500);
      }
      state.snapshot = await rpc("debug.locationChat.snapshot");
      setStatus(state.snapshot);
      render();
    } else if (state.snapshot) {
      setStatus(state.snapshot);
    }
  } catch (error) {
    statusEl.textContent = `Disconnected: ${error.message}`;
  }
}

async function clearEvents() {
  try {
    state.snapshot = await rpc("debug.locationChat.clear");
    state.cursor = 0;
    state.events = [];
    state.activeLocationId = "";
    setStatus(state.snapshot);
    render();
  } catch (error) {
    statusEl.textContent = `Clear failed: ${error.message}`;
  }
}

function exportJson() {
  const blob = new Blob([
    JSON.stringify({
      exportedAt: new Date().toISOString(),
      snapshot: state.snapshot,
      events: state.events
    }, null, 2)
  ], {type: "application/json"});
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `location-chat-debug-${Date.now()}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}

function setStatus(snapshot) {
  const enabled = snapshot?.enabled ? "enabled" : "disabled";
  const available = snapshot?.available ? "available" : "not available";
  statusEl.textContent = `agent_control connected, debug ${enabled}, RPC ${available}`;
}

function render() {
  saveVirtualScrollPositions();
  syncActiveWorld();
  renderSummary();
  renderQueueTabs();
  renderWebSocketFrames();
  renderHttpMessages();
  queueMicrotask(mountVirtualLists);
}

function renderSummary() {
  const world = currentWorldSnapshot();
  setHtmlIfChanged(summaryGrid, [
    infoItem("Wid", world.worldId || "-"),
    infoItem("Num Of Leaf Locations", leafLocations().length),
    infoItem("Websocket Status", websocketStatus())
  ].join(""));
}

function infoItem(label, value) {
  return `
    <div class="info-item">
      <span>${escapeHtml(label)}</span>
      <b>${escapeHtml(value)}</b>
    </div>
  `;
}

function renderQueueTabs() {
  const locations = leafLocations();
  if (!locations.length) {
    state.activeLocationId = "";
    state.locationTabsSignature = "";
    setHtmlIfChanged(locationTabGroup, `<div class="empty-state">No leaf locations</div>`);
    return;
  }

  syncAppActiveLocation(locations);

  if (!locations.some((location) => location.id === state.activeLocationId)) {
    state.activeLocationId = locations[0].id;
  }

  const signature = locations
    .map((location) => `${location.id}\u001F${location.name || ""}`)
    .join("\u001E");
  if (signature === state.locationTabsSignature) {
    updateLocationTabState();
    renderActiveQueuePanel();
    return;
  }
  state.locationTabsSignature = signature;

  const tabs = locations.map((location) => `
    <sl-tab
      class="${location.id === state.appActiveLocationId ? "app-active-location-tab" : ""}"
      slot="nav"
      panel="${escapeAttribute(location.id)}"
    >
      <span class="location-tab-label">
        <span class="location-tab-name">${escapeHtml(location.name || location.id)}</span>
        <span class="location-tab-id">${escapeHtml(location.id)}</span>
      </span>
    </sl-tab>
  `).join("");
  const panels = locations.map((location) => `
    <sl-tab-panel name="${escapeAttribute(location.id)}">
      <div class="panel-scroll queue-scroll" data-queue-location-id="${escapeAttribute(location.id)}"></div>
    </sl-tab-panel>
  `).join("");

  setHtmlIfChanged(locationTabGroup, `${tabs}${panels}`);
  queueMicrotask(() => {
    if (typeof locationTabGroup.show === "function") {
      locationTabGroup.show(state.activeLocationId);
    }
    updateLocationTabState();
    renderActiveQueuePanel();
    queueMicrotask(mountVirtualLists);
  });
}

function updateLocationTabState() {
  for (const tab of locationTabGroup.querySelectorAll("sl-tab")) {
    const locationId = `${tab.getAttribute("panel") || ""}`.trim();
    tab.classList.toggle("app-active-location-tab", locationId === state.appActiveLocationId);
  }
  if (typeof locationTabGroup.show === "function") {
    locationTabGroup.show(state.activeLocationId);
  }
}

function syncAppActiveLocation(locations = leafLocations()) {
  const nextAppActiveLocationId = activePanelLocationId();
  if (nextAppActiveLocationId === state.appActiveLocationId) return;

  state.appActiveLocationId = nextAppActiveLocationId;
  if (!nextAppActiveLocationId) return;
  if (!locations.some((location) => location.id === nextAppActiveLocationId)) {
    return;
  }
  state.activeLocationId = nextAppActiveLocationId;
}

function renderActiveQueuePanel() {
  const scroll = locationTabGroup.querySelector(
    `.queue-scroll[data-queue-location-id="${cssEscape(state.activeLocationId)}"]`
  );
  if (!scroll) return;
  renderQueueColumnsInto(scroll, state.activeLocationId);
}

function renderQueueColumnsInto(container, locationId) {
  const world = currentWorldSnapshot();
  const snapshots = state.snapshot?.snapshots || {};
  const storage = findSnapshotForLocation(snapshots.storage || {}, locationId, world.worldId);
  const service = findSnapshotForLocation(snapshots.service || {}, locationId, world.worldId);
  const panel = findSnapshotForLocation(snapshots.panel || {}, locationId, world.worldId);
  const issues = compareIssues(storage, service, panel);
  let issueBanner = container.querySelector(":scope > .issue-banner");
  if (issues.length) {
    if (!issueBanner) {
      issueBanner = document.createElement("div");
      issueBanner.className = "issue-banner";
      container.prepend(issueBanner);
    }
    issueBanner.textContent = issues.join(", ");
  } else if (issueBanner) {
    issueBanner.remove();
  }

  let columns = container.querySelector(":scope > .columns");
  if (!columns) {
    columns = document.createElement("div");
    columns.className = "columns";
    container.append(columns);
  }
  renderColumnInto(columns, "disk", "Disk Cache", storage?.messages || [], `${world.worldId}:${locationId}:disk`);
  renderColumnInto(columns, "memory", "Memory Cache", service?.messages || [], `${world.worldId}:${locationId}:memory`);
  renderColumnInto(columns, "render", "Render VM", panel?.renderMessages || [], `${world.worldId}:${locationId}:render`);
}

function renderWebSocketFrames() {
  if (state.activeNetworkTab !== "websocket") {
    clearElement(websocketFrames);
    return;
  }
  const frames = networkEvents("websocket", 500);
  renderVirtualListInto(websocketFrames, {
    items: frames,
    className: "network-virtual-list",
    key: `network:${state.activeWorldId}:websocket`,
    emptyHtml: `<p class="muted">No WebSocket frames yet.</p>`,
    getItemHeight: (event) => networkRowOpen(event) ? 430 : 39,
    getItemKey: networkRowId,
    renderItem: renderWebSocketFrame
  });
}

function renderHttpMessages() {
  if (state.activeNetworkTab !== "http") {
    clearElement(httpMessages);
    return;
  }
  const pulls = networkEvents("http", 500);
  renderVirtualListInto(httpMessages, {
    items: pulls,
    className: "network-virtual-list",
    key: `network:${state.activeWorldId}:http`,
    emptyHtml: `<p class="muted">No HTTPS message pulls yet.</p>`,
    getItemHeight: (event) => networkRowOpen(event) ? httpExpandedRowHeight() : 39,
    getItemKey: networkRowId,
    renderItem: renderHttpPull
  });
}

function httpExpandedRowHeight() {
  const detailHeight = Math.max(480, Math.min(680, window.innerHeight - 220));
  return detailHeight + 39;
}

function networkEvents(source, limit) {
  const worldId = state.activeWorldId;
  return state.events
    .filter((event) => event.source === source)
    .filter((event) => !worldId || event.worldId === worldId)
    .filter((event) => Number(event.cursor || 0) >= state.networkSinceCursor)
    .slice(-limit)
    .reverse();
}

function syncActiveWorld() {
  const worldId = currentWorldSnapshot().worldId;
  if (!worldId) return;
  if (!state.activeWorldId) {
    state.activeWorldId = worldId;
    state.networkSinceCursor = 0;
    return;
  }
  if (state.activeWorldId === worldId) return;
  state.activeWorldId = worldId;
  state.expandedNetworkRows.clear();
  state.networkSinceCursor =
    Number(latestWorldEventFor(worldId)?.cursor || state.cursor || 0);
}

function activePanelLocationId() {
  const worldId = currentWorldSnapshot().worldId;
  const panels = Object.values(state.snapshot?.snapshots?.panel || {});
  const activePanel = panels.find((panel) => {
    if (panel?.active !== true) return false;
    if (!worldId) return true;
    return `${panel?.worldId || ""}`.trim() === worldId;
  });
  return `${activePanel?.locationId || ""}`.trim();
}

function latestWorldEventFor(worldId) {
  return state.events
    .slice()
    .reverse()
    .find((event) => event.source === "world" && event.worldId === worldId);
}

function currentWorldSnapshot() {
  const worlds = state.snapshot?.snapshots?.world || {};
  const latestWorldId = latestWorldIdFromEvents();
  const byLatestEvent = latestWorldId ? worlds[latestWorldId] : null;
  const byWorldId = Object.values(worlds).find(
    (item) => `${item?.worldId || ""}`.trim() === latestWorldId
  );
  const values = Object.values(worlds);
  const fallback =
    values.find((item) => item && Array.isArray(item.descriptors)) ||
    values[0] ||
    {};
  const world = byLatestEvent || byWorldId || fallback;
  return {
    ...world,
    worldId: world.worldId || latestWorldId || ""
  };
}

function latestWorldIdFromEvents() {
  for (const event of state.events.slice().reverse()) {
    if (event.source !== "world") continue;
    const worldId = `${event.worldId || ""}`.trim();
    if (worldId) return worldId;
  }
  for (const event of state.events.slice().reverse()) {
    const worldId = `${event.worldId || ""}`.trim();
    if (worldId) return worldId;
  }
  return "";
}

function leafLocations() {
  const world = currentWorldSnapshot();
  const byId = new Map();
  const descriptors = Array.isArray(world.descriptors) ? world.descriptors : [];
  for (const descriptor of descriptors) {
    if (descriptor?.isLeafLocation !== true) continue;
    const id = `${descriptor.locationId || ""}`.trim();
    if (!id) continue;
    byId.set(id, {
      id,
      name: `${descriptor.locationName || id}`.trim()
    });
  }

  const snapshots = state.snapshot?.snapshots || {};
  for (const collection of [snapshots.storage, snapshots.service, snapshots.panel]) {
    for (const [key, value] of Object.entries(collection || {})) {
      const id = extractLocationId(key, value, world.worldId);
      if (!id || byId.has(id)) continue;
      byId.set(id, {id, name: id});
    }
  }

  return Array.from(byId.values()).sort((a, b) => a.name.localeCompare(b.name));
}

function extractLocationId(key, value, worldId) {
  const valueWorldId = `${value?.worldId || ""}`.trim();
  if (worldId && valueWorldId && valueWorldId !== worldId) return "";

  const valueLocationId = `${value?.locationId || ""}`.trim();
  if (valueLocationId) return valueLocationId;

  const parts = `${key || ""}`.split("|").map((part) => part.trim()).filter(Boolean);
  if (!parts.length) return "";
  if (worldId && parts.length >= 2 && !parts.includes(worldId)) return "";
  if (worldId) {
    const worldIndex = parts.indexOf(worldId);
    if (worldIndex >= 0 && parts[worldIndex + 1]) return parts[worldIndex + 1];
  }
  return parts[parts.length - 1] || "";
}

function findSnapshotForLocation(collection, locationId, worldId) {
  for (const [key, value] of Object.entries(collection || {})) {
    if (extractLocationId(key, value, worldId) === locationId) return value;
  }
  return null;
}

function websocketStatus() {
  const world = currentWorldSnapshot();
  const services = Object.values(state.snapshot?.snapshots?.service || {})
    .filter((item) => !world.worldId || item?.worldId === world.worldId);
  if (services.some((item) => item?.reconnecting === true)) {
    return "Reconnecting";
  }
  if (services.some((item) => item?.connected === true)) {
    return "Connected";
  }
  return "Disconnected";
}

function renderWebSocketFrame(event) {
  const details = event.details || {};
  const direction = details.direction === "out" ? "out" : "in";
  const type = details.type || details.eventType || event.action || "frame";
  const time = event.timestamp ? new Date(event.timestamp).toLocaleTimeString() : "";
  const payload = details.payload || {};
  const rawLength = `${details.raw || ""}`.length;
  const rowId = networkRowId(event);
  const open = networkRowOpen(event);
  return `
    <article class="network-event ${escapeHtml(direction)} ${open ? "open" : ""}" data-network-row-id="${escapeAttribute(rowId)}">
      <button class="network-summary" type="button" data-network-toggle="${escapeAttribute(rowId)}">
        <span class="direction ${escapeHtml(direction)}">${escapeHtml(direction)}</span>
        <span class="network-time">${escapeHtml(time)}</span>
        <strong>${escapeHtml(type)}</strong>
        <span>${escapeHtml(event.locationId || "-")}</span>
        <span>${escapeHtml(event.action || "-")}</span>
        <span>${escapeHtml(rawLength ? `${rawLength} B` : "-")}</span>
        <span class="network-cursor">#${escapeHtml(event.cursor)}</span>
      </button>
      ${open ? `
        <div class="network-detail">
          ${details.raw ? `<pre class="raw">${escapeHtml(details.raw)}</pre>` : ""}
          <pre>${escapeHtml(JSON.stringify(payload, null, 2))}</pre>
        </div>
      ` : ""}
    </article>
  `;
}

function renderHttpPull(event) {
  const details = event.details || {};
  const messages = Array.isArray(details.messages) ? details.messages : [];
  const hasRawResponse = details.response !== undefined && details.response !== null;
  const responseJson = details.response;
  const time = event.timestamp ? new Date(event.timestamp).toLocaleTimeString() : "";
  const rowId = networkRowId(event);
  const open = networkRowOpen(event);
  return `
    <article class="network-event http-pull ${open ? "open" : ""}" data-network-row-id="${escapeAttribute(rowId)}">
      <button class="network-summary" type="button" data-network-toggle="${escapeAttribute(rowId)}">
        <span class="direction http">https</span>
        <span class="network-time">${escapeHtml(time)}</span>
        <strong>${escapeHtml(event.action || "getMessages")}</strong>
        <span>${escapeHtml(event.locationId || "-")}</span>
        <span>${escapeHtml(details.endpoint || "-")}</span>
        <span>${escapeHtml(`${details.loaded || 0} msgs`)}</span>
        <span class="network-cursor">#${escapeHtml(event.cursor)}</span>
      </button>
      ${open ? `
        <div class="network-detail http-detail">
          <section class="network-response-pane network-response-json">
            <h4>Raw Response JSON</h4>
            <pre>${hasRawResponse ? escapeHtml(JSON.stringify(responseJson, null, 2)) : "No raw response captured for this event."}</pre>
          </section>
          <section class="network-response-pane network-response-messages">
            <h4>Messages · ${escapeHtml(messages.length)}</h4>
            <div class="message-list network-response-list">
              ${messages.length ? virtualList({
                  items: messages,
                  className: "message-virtual-list network-message-virtual-list",
                  key: `network-response:${rowId}`,
                  getItemHeight: () => 58,
                  getItemKey: messageRowKey,
                  renderItem: renderMessage
                }) : `<p class="muted">No messages in response</p>`}
            </div>
          </section>
          </div>
      ` : ""}
    </article>
  `;
}

function renderColumn(title, messages, key) {
  const listId = virtualList({
    items: messages,
    className: "message-virtual-list",
    key: `queue:${key}`,
    getItemHeight: () => 58,
    getItemKey: messageRowKey,
    renderItem: renderMessage
  });
  return `
    <div class="column">
      <h3>${escapeHtml(title)} · ${messages.length}</h3>
      ${messages.length ? listId : `<p class="muted empty-column">No data</p>`}
    </div>
  `;
}

function renderColumnInto(parent, columnKey, title, messages, key) {
  let column = parent.querySelector(`:scope > .column[data-queue-column="${cssEscape(columnKey)}"]`);
  if (!column) {
    column = document.createElement("div");
    column.className = "column";
    column.dataset.queueColumn = columnKey;
    column.innerHTML = `<h3></h3><div class="column-body"></div>`;
    parent.append(column);
  }
  const heading = column.querySelector("h3");
  const nextHeading = `${title} · ${messages.length}`;
  if (heading.textContent !== nextHeading) {
    heading.textContent = nextHeading;
  }
  renderVirtualListInto(column.querySelector(".column-body"), {
    items: messages,
    className: "message-virtual-list",
    key: `queue:${key}`,
    emptyHtml: `<p class="muted empty-column">No data</p>`,
    getItemHeight: () => 58,
    getItemKey: messageRowKey,
    renderItem: renderMessage
  });
}

function renderMessage(message) {
  const id = isTickMessage(message) ? "" : messageLocationMsgId(message);
  const kind = message.senderType || message.status || "";
  const text = message.contentPreview || "";
  return `
    <div class="message-row ${isTickMessage(message) ? "tick-message" : ""}">
      <div class="message-id">${escapeHtml(id)}</div>
      <div class="message-text">
        <strong>${escapeHtml(kind)}</strong>
        <div>${escapeHtml(text)}</div>
      </div>
    </div>
  `;
}

function compareIssues(storage, service, panel) {
  const issues = [];
  const storageIds = ids(storage?.messages || []);
  const serviceIds = ids(service?.messages || []);
  const panelIds = ids(panel?.renderMessages || []);
  if (hasDuplicates(serviceIds)) issues.push("service duplicates");
  if (hasDuplicates(panelIds)) issues.push("render duplicates");
  return issues;
}

function ids(messages) {
  return messages
    .filter((message) => !isTickMessage(message))
    .map(messageLocationMsgId)
    .filter(Boolean);
}

function hasDuplicates(values) {
  return new Set(values).size !== values.length;
}

function isTickMessage(message) {
  return `${message?.senderType || ""}`.trim().toLowerCase() === "tick";
}

function messageLocationMsgId(message) {
  const candidates = [
    message?.location_msg_id,
    message?.location_message_id,
    message?.locationMsgId,
    message?.locationMessageId
  ];
  for (const value of candidates) {
    const normalized = `${value ?? ""}`.trim();
    if (!normalized || normalized === "0") continue;
    return normalized;
  }
  return "";
}

function messageRowKey(message, index) {
  const id = messageLocationMsgId(message);
  if (id) return `loc:${id}`;
  const msgId = `${message?.msgId ?? message?.msg_id ?? ""}`.trim();
  if (msgId) return `msg:${msgId}`;
  const clientMsgId = `${message?.clientMsgId ?? message?.client_msg_id ?? ""}`.trim();
  if (clientMsgId) return `client:${clientMsgId}`;
  const time = `${message?.currentTime ?? message?.current_time ?? message?.ts ?? ""}`.trim();
  const kind = `${message?.senderType ?? message?.sender_type ?? message?.status ?? ""}`.trim();
  return `${index}:${kind}:${time}:${message?.contentPreview || ""}`;
}

function networkRowId(event) {
  return `${event.source}:${event.cursor}`;
}

function networkRowOpen(event) {
  return state.expandedNetworkRows.has(networkRowId(event));
}

function virtualList({items, className, key = "", getItemHeight, getItemKey, renderItem}) {
  const stableKey = `${key || ""}`;
  const id = stableKey
    ? stableVirtualListId(stableKey)
    : `vl-${++state.virtualListSeq}`;
  const resolvedKey = stableKey || id;
  if (!state.virtualHeightCache.has(resolvedKey)) {
    state.virtualHeightCache.set(resolvedKey, new Map());
  }
  state.virtualLists.set(id, {
    key: resolvedKey,
    items,
    getItemHeight,
    getItemKey,
    renderItem,
    itemHeights: state.virtualHeightCache.get(resolvedKey),
    overscanItems: 4
  });
  return `
    <div
      class="virtual-list ${escapeAttribute(className || "")}"
      data-virtual-id="${escapeAttribute(id)}"
      data-virtual-key="${escapeAttribute(resolvedKey)}"
    ></div>
  `;
}

function stableVirtualListId(key) {
  const stableKey = `${key || ""}`;
  const existing = state.virtualListIds.get(stableKey);
  if (existing) return existing;
  const id = `vl-${++state.virtualListSeq}`;
  state.virtualListIds.set(stableKey, id);
  return id;
}

function renderVirtualListInto(parent, {
  items,
  className,
  key = "",
  emptyHtml = "",
  getItemHeight,
  getItemKey,
  renderItem
}) {
  if (!parent) return;
  if (!Array.isArray(items) || !items.length) {
    setHtmlIfChanged(parent, emptyHtml);
    return;
  }

  const stableKey = `${key || "inline"}`;
  parent.__lastHtml = "";
  let container = parent.querySelector(":scope > .virtual-list");
  if (!container || container.dataset.virtualKey !== stableKey) {
    parent.innerHTML = "";
    container = document.createElement("div");
    container.className = `virtual-list ${className || ""}`.trim();
    container.dataset.virtualId = stableVirtualListId(stableKey);
    container.dataset.virtualKey = stableKey;
    parent.append(container);
  } else if (container.className !== `virtual-list ${className || ""}`.trim()) {
    container.className = `virtual-list ${className || ""}`.trim();
  }

  if (!state.virtualHeightCache.has(stableKey)) {
    state.virtualHeightCache.set(stableKey, new Map());
  }
  state.virtualLists.set(container.dataset.virtualId, {
    key: stableKey,
    items,
    getItemHeight,
    getItemKey,
    renderItem,
    itemHeights: state.virtualHeightCache.get(stableKey),
    overscanItems: 4
  });
  mountVirtualListContainer(container);
  scheduleVirtualListRender(container, {preserveAnchor: true});
}

function saveVirtualScrollPositions() {
  for (const container of document.querySelectorAll(".virtual-list")) {
    const key = container.dataset.virtualKey || "";
    if (!key) continue;
    state.virtualScrollTops.set(key, container.scrollTop);
  }
}

function mountVirtualLists() {
  if (!state.virtualResizeObserver && typeof ResizeObserver !== "undefined") {
    state.virtualResizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        scheduleVirtualListRender(entry.target, {preserveAnchor: true});
      }
    });
  }
  for (const container of document.querySelectorAll(".virtual-list")) {
    mountVirtualListContainer(container);
  }
}

function mountVirtualListContainer(container) {
  const id = container.dataset.virtualId || "";
  const config = state.virtualLists.get(id);
  if (!config) return;
  if (container.dataset.virtualMounted !== "true") {
    container.addEventListener("scroll", () => {
      if (container.__virtualRendering) return;
      container.__virtualPendingScrollTop = container.scrollTop;
      if (config.key) {
        state.virtualScrollTops.set(config.key, container.scrollTop);
      }
      scheduleVirtualListRender(container);
    });
    container.addEventListener("click", handleVirtualListClick);
    state.virtualResizeObserver?.observe(container);
    container.dataset.virtualMounted = "true";
  }
  if (container.dataset.virtualScrollRestored !== "true") {
    const scrollTop = state.virtualScrollTops.get(config.key);
    if (Number.isFinite(scrollTop)) {
      container.__virtualPendingScrollTop = scrollTop;
    }
    container.dataset.virtualScrollRestored = "true";
  }
  renderVirtualList(container);
}

function scheduleVirtualListRender(container, {preserveAnchor = false} = {}) {
  const hasPendingScrollTop = hasVirtualPendingScrollTop(container);
  if (preserveAnchor && !hasPendingScrollTop && !container.__virtualAnchor) {
    container.__virtualAnchor = readVirtualAnchor(container);
  }
  if (container.dataset.virtualFrame) return;
  const scheduledVersion = Number(container.__virtualVersion || 0);
  container.dataset.virtualFrame = "true";
  requestAnimationFrame(() => {
    delete container.dataset.virtualFrame;
    if (Number(container.__virtualVersion || 0) !== scheduledVersion) {
      container.__virtualAnchor = null;
      return;
    }
    const anchor = container.__virtualAnchor || null;
    container.__virtualAnchor = null;
    renderVirtualList(container, {anchor});
  });
}

function renderVirtualList(container, {anchor = null} = {}) {
  const config = state.virtualLists.get(container.dataset.virtualId || "");
  if (!config) return;
  const renderVersion = Number(container.__virtualVersion || 0) + 1;
  container.__virtualVersion = renderVersion;
  const items = config.items || [];
  const heights = items.map((item, index) => itemHeight(config, item, index));
  const offsets = [];
  let totalHeight = 0;
  for (const height of heights) {
    offsets.push(totalHeight);
    totalHeight += height;
  }

  const viewportHeight = Math.max(0, container.clientHeight || 0);
  if (viewportHeight <= 0 || !items.length) {
    const {spacer, windowEl} = ensureVirtualSkeleton(container);
    spacer.style.height = `${totalHeight}px`;
    windowEl.replaceChildren();
    return;
  }

  const pendingScrollTop = hasVirtualPendingScrollTop(container)
    ? Number(container.__virtualPendingScrollTop)
    : null;
  const requestedScrollTop = pendingScrollTop !== null
    ? pendingScrollTop
    : container.scrollTop;
  container.__virtualPendingScrollTop = null;
  const scrollTop = Math.max(0, Math.min(totalHeight, requestedScrollTop));
  const overscanItems = Math.max(1, Number(config.overscanItems) || 1);
  const averageHeight = averageItemHeight(heights);
  const overscanPx = averageHeight * overscanItems;
  const startTarget = Math.max(0, scrollTop - overscanPx);
  const endTarget = scrollTop + viewportHeight + overscanPx;
  const start = findVirtualStart(offsets, heights, startTarget);
  const end = findVirtualEnd(offsets, heights, endTarget);
  const visibleItems = items.slice(start, end);
  container.__virtualRendering = true;
  const {spacer, windowEl} = ensureVirtualSkeleton(container);
  spacer.style.height = `${totalHeight}px`;
  windowEl.style.transform = `translateY(${offsets[start] || 0}px)`;
  syncVirtualWindow(windowEl, config, visibleItems, start);
  restoreVirtualScrollTop(container, totalHeight, scrollTop);
  restoreVirtualAnchor(container, config, offsets, totalHeight, anchor);
  for (const child of container.querySelectorAll(".virtual-list")) {
    mountVirtualListContainer(child);
  }
  requestAnimationFrame(() => {
    if (Number(container.__virtualVersion || 0) !== renderVersion) return;
    container.__virtualRendering = false;
    measureVirtualItems(container);
  });
}

function ensureVirtualSkeleton(container) {
  let spacer = container.querySelector(":scope > .virtual-spacer");
  if (!spacer) {
    spacer = document.createElement("div");
    spacer.className = "virtual-spacer";
    container.replaceChildren(spacer);
  }
  let windowEl = spacer.querySelector(":scope > .virtual-window");
  if (!windowEl) {
    windowEl = document.createElement("div");
    windowEl.className = "virtual-window";
    spacer.replaceChildren(windowEl);
  }
  return {spacer, windowEl};
}

function syncVirtualWindow(windowEl, config, visibleItems, start) {
  const reusable = new Map();
  for (const child of Array.from(windowEl.children)) {
    if (!child.classList.contains("virtual-item")) {
      child.remove();
      continue;
    }
    reusable.set(child.dataset.virtualKey || child.dataset.virtualIndex || "", child);
  }

  const used = new Set();
  let cursor = windowEl.firstElementChild;
  visibleItems.forEach((item, index) => {
    const itemIndex = start + index;
    const key = virtualItemKey(config, item, itemIndex);
    let itemEl = reusable.get(key);
    if (!itemEl) {
      itemEl = document.createElement("div");
      itemEl.className = "virtual-item";
    }
    itemEl.dataset.virtualIndex = `${itemIndex}`;
    itemEl.dataset.virtualKey = key;
    const html = config.renderItem(item, itemIndex);
    if (itemEl.__virtualHtml !== html) {
      itemEl.innerHTML = html;
      itemEl.__virtualHtml = html;
    }
    used.add(key);
    if (itemEl === cursor) {
      cursor = cursor.nextElementSibling;
    } else {
      windowEl.insertBefore(itemEl, cursor);
    }
  });

  for (const [key, itemEl] of reusable.entries()) {
    if (!used.has(key)) itemEl.remove();
  }
}

function restoreVirtualScrollTop(container, totalHeight, scrollTop) {
  const maxScrollTop = Math.max(0, totalHeight - container.clientHeight);
  const nextScrollTop = Math.max(0, Math.min(maxScrollTop, scrollTop));
  if (Math.abs(container.scrollTop - nextScrollTop) > 1) {
    container.scrollTop = nextScrollTop;
  }
}

function hasVirtualPendingScrollTop(container) {
  const value = container.__virtualPendingScrollTop;
  return value !== null && value !== undefined && Number.isFinite(Number(value));
}

function itemHeight(config, item, index) {
  const measured = config.itemHeights.get(virtualItemKey(config, item, index));
  if (measured) return measured;
  return Math.max(1, Number(config.getItemHeight(item, index)) || 1);
}

function virtualItemKey(config, item, index) {
  if (typeof config.getItemKey === "function") {
    const key = `${config.getItemKey(item, index) || ""}`.trim();
    if (key) return key;
  }
  return `${index}`;
}

function measureVirtualItems(container) {
  const config = state.virtualLists.get(container.dataset.virtualId || "");
  if (!config) return;
  const windowEl = container.querySelector(":scope > .virtual-spacer > .virtual-window");
  if (!windowEl) return;

  var changed = false;
  for (const itemEl of windowEl.children) {
    if (!itemEl.classList.contains("virtual-item")) continue;
    const index = Number(itemEl.dataset.virtualIndex);
    if (!Number.isFinite(index)) continue;
    const measured = Math.ceil(itemEl.getBoundingClientRect().height);
    if (measured <= 0) continue;
    const key = itemEl.dataset.virtualKey || `${index}`;
    const previous = config.itemHeights.get(key);
    if (Math.abs((previous || 0) - measured) <= 1) continue;
    config.itemHeights.set(key, measured);
    changed = true;
  }

  if (changed) {
    scheduleVirtualListRender(container, {preserveAnchor: true});
  }
}

function readVirtualAnchor(container) {
  const containerTop = container.getBoundingClientRect().top;
  const items = Array.from(
    container.querySelectorAll(":scope > .virtual-spacer > .virtual-window > .virtual-item")
  );
  const candidate =
    items.find((item) => item.getBoundingClientRect().bottom >= containerTop) ||
    items[0];
  if (!candidate) return null;
  const index = Number(candidate.dataset.virtualIndex);
  if (!Number.isFinite(index)) return null;
  return {
    key: candidate.dataset.virtualKey || "",
    index,
    top: candidate.getBoundingClientRect().top - containerTop
  };
}

function restoreVirtualAnchor(container, config, offsets, totalHeight, anchor) {
  if (!anchor || !Number.isFinite(anchor.index)) return;
  const items = config.items || [];
  const key = `${anchor.key || ""}`;
  const anchorIndex = key
    ? items.findIndex((item, index) => virtualItemKey(config, item, index) === key)
    : -1;
  const resolvedIndex = anchorIndex >= 0 ? anchorIndex : anchor.index;
  const nextOffset = offsets[resolvedIndex];
  if (!Number.isFinite(nextOffset)) return;
  const maxScrollTop = Math.max(0, totalHeight - container.clientHeight);
  const nextScrollTop = Math.max(
    0,
    Math.min(maxScrollTop, nextOffset - anchor.top)
  );
  if (Math.abs(container.scrollTop - nextScrollTop) > 1) {
    container.scrollTop = nextScrollTop;
  }
}

function averageItemHeight(heights) {
  if (!heights.length) return 1;
  return heights.reduce((total, height) => total + height, 0) / heights.length;
}

function findVirtualStart(offsets, heights, target) {
  let low = 0;
  let high = heights.length;
  while (low < high) {
    const mid = Math.floor((low + high) / 2);
    if (offsets[mid] + heights[mid] < target) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

function findVirtualEnd(offsets, heights, target) {
  let low = 0;
  let high = heights.length;
  while (low < high) {
    const mid = Math.floor((low + high) / 2);
    if (offsets[mid] < target) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return Math.min(heights.length, low + 1);
}

function handleVirtualListClick(event) {
  const toggle = event.target.closest("[data-network-toggle]");
  if (!toggle) return;
  const rowId = toggle.dataset.networkToggle || "";
  if (!rowId) return;
  if (state.expandedNetworkRows.has(rowId)) {
    state.expandedNetworkRows.delete(rowId);
  } else {
    state.expandedNetworkRows.add(rowId);
  }
  state.virtualLists.get(event.currentTarget.dataset.virtualId || "")?.itemHeights.clear();
  renderVirtualList(event.currentTarget);
}

function setHtmlIfChanged(element, html) {
  if (!element) return;
  if (element.__lastHtml === html) return;
  element.innerHTML = html;
  element.__lastHtml = html;
}

function clearElement(element) {
  if (!element) return;
  if (!element.childNodes.length) return;
  element.replaceChildren();
  element.__lastHtml = "";
}

function cssEscape(value) {
  if (window.CSS && typeof window.CSS.escape === "function") {
    return window.CSS.escape(`${value}`);
  }
  return `${value}`.replaceAll("\\", "\\\\").replaceAll('"', '\\"');
}

function escapeAttribute(value) {
  return escapeHtml(value).replaceAll("`", "&#096;");
}

function escapeHtml(value) {
  return `${value ?? ""}`
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

refreshAll();
state.pollTimer = setInterval(pollEvents, 1000);
