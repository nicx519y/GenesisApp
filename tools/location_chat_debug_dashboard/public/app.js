const state = {
  cursor: 0,
  events: [],
  snapshot: null,
  activeLocationId: "",
  appActiveLocationId: "",
  activeWorldId: "",
  activeQueueMainTab: "queueCompare",
  activeNetworkTab: "http",
  networkSinceCursor: 0,
  queueErrors: [],
  queueErrorMap: new Map(),
  queueFocusKey: "",
  messageSourceIndex: new Map(),
  messageSourceIndexSignature: "",
  networkFocusKey: "",
  networkMessageFocusKey: "",
  expandedNetworkRows: new Set(),
  virtualListSeq: 0,
  virtualListIds: new Map(),
  virtualLists: new Map(),
  virtualScrollTops: new Map(),
  virtualHeightCache: new Map(),
  virtualResizeObserver: null,
  locationTabsSignature: "",
  storageReady: null,
  persistedEventCount: 0,
  persistedMaxCursor: 0,
  agentJobId: "",
  agentStatus: "idle",
  agentAfterSeq: 0,
  agentLogs: [],
  agentStatusTimer: null,
  pollTimer: null
};

const EVENT_PAGE_LIMIT = 1000;
const EVENT_MEMORY_LIMIT = 2000;
const MESSAGE_SOURCE_KEY_MEMORY_LIMIT = 3000;
const MESSAGE_SOURCE_HITS_PER_KEY_LIMIT = 20;
const EXPANDED_NETWORK_ROW_MEMORY_LIMIT = 300;
const VIRTUAL_LIST_MEMORY_LIMIT = 80;
const VIRTUAL_HEIGHT_CACHE_MEMORY_LIMIT = 120;
const VIRTUAL_HEIGHT_ITEMS_PER_LIST_LIMIT = 1000;
const VIRTUAL_SCROLL_MEMORY_LIMIT = 120;
const STABLE_VIRTUAL_ID_MEMORY_LIMIT = 160;
const AGENT_LOG_MEMORY_LIMIT = 50;
const EVENT_DB_NAME = "location-chat-debug-dashboard";
const EVENT_DB_VERSION = 2;
const EVENT_STORE_NAME = "events";
const SNAPSHOT_STORE_NAME = "snapshots";

const statusEl = document.getElementById("connectionStatus");
const summaryGrid = document.getElementById("summaryGrid");
const queueMainTabGroup = document.getElementById("queueMainTabGroup");
const locationTabGroup = document.getElementById("locationTabGroup");
const queueErrors = document.getElementById("queueErrors");
const networkTabGroup = document.getElementById("networkTabGroup");
const websocketFrames = document.getElementById("websocketFrames");
const httpMessages = document.getElementById("httpMessages");
const agentStatusEl = document.getElementById("agentStatus");
const agentCountInput = document.getElementById("agentCountInput");
const agentLocationCountInput = document.getElementById("agentLocationCountInput");
const agentUseCurrentTarget = document.getElementById("agentUseCurrentTarget");
const agentStartButton = document.getElementById("agentStartButton");
const agentStopButton = document.getElementById("agentStopButton");

document.getElementById("refreshButton").addEventListener("click", refreshAll);
document.getElementById("clearButton").addEventListener("click", clearEvents);
document.getElementById("exportButton").addEventListener("click", exportJson);
agentStartButton.addEventListener("click", startAgentJob);
agentStopButton.addEventListener("click", stopAgentJob);

queueMainTabGroup.addEventListener("sl-tab-show", (event) => {
  const tabName = `${event.detail.name || ""}`.trim();
  if (!tabName || tabName === state.activeQueueMainTab) return;
  state.activeQueueMainTab = tabName;
  renderQueueTabs();
  renderQueueErrors();
  queueMicrotask(mountVirtualLists);
});

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
  renderNetworkTimeline();
  queueMicrotask(mountVirtualLists);
});

window.addEventListener("resize", () => {
  for (const container of document.querySelectorAll(".virtual-list")) {
    scheduleVirtualListRender(container, {preserveAnchor: true});
  }
});

queueErrors.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" && event.key !== " ") return;
  const row = event.target.closest("[data-queue-error-key]");
  if (!row) return;
  event.preventDefault();
  jumpToQueueError(row.dataset.queueErrorKey || "");
});

function rpc(method, params = {}, options = {}) {
  return fetch("/api/rpc", {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
      method,
      params,
      timeoutMs: options.timeoutMs
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
    await ensureEventStorage();
    const snapshot = await rpc("debug.locationChat.snapshot");
    const events = Array.isArray(snapshot.events) ? snapshot.events : [];
    await resetEventStorageIfCursorReset(snapshot);
    await storeSnapshot(snapshot);
    await appendEvents(events);
    state.snapshot = snapshot;
    state.cursor = Number(snapshot.nextCursor || 1) - 1;
    state.events = limitedMemoryEvents(events);
    state.queueErrors = [];
    setStatus(snapshot);
    render();
  } catch (error) {
    statusEl.textContent = `Disconnected: ${error.message}`;
  }
}

async function pollEvents() {
  try {
    await ensureEventStorage();
    let receivedAny = false;
    const receivedEvents = [];
    while (true) {
      const result = await rpc("debug.locationChat.events", {
        cursor: state.cursor,
        limit: EVENT_PAGE_LIMIT
      });
      const events = Array.isArray(result.events) ? result.events : [];
      if (!events.length) break;
      receivedEvents.push(...events);
      state.events.push(...events);
      trimMemoryEvents();
      state.cursor = Number(result.nextCursor || events[events.length - 1]?.cursor || state.cursor);
      receivedAny = true;
      if (events.length < EVENT_PAGE_LIMIT) break;
    }
    if (receivedAny) {
      await appendEvents(receivedEvents);
      state.snapshot = await rpc("debug.locationChat.snapshot");
      await storeSnapshot(state.snapshot);
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
    await clearEventStorage();
    state.cursor = 0;
    state.events = [];
    state.activeLocationId = "";
    state.queueErrors = [];
    state.queueErrorMap.clear();
    state.queueFocusKey = "";
    state.messageSourceIndex.clear();
    state.messageSourceIndexSignature = "";
    state.networkFocusKey = "";
    state.networkMessageFocusKey = "";
    clearBoundedUiCaches();
    setStatus(state.snapshot);
    render();
  } catch (error) {
    statusEl.textContent = `Clear failed: ${error.message}`;
  }
}

async function exportJson() {
  let events = state.events;
  let snapshot = state.snapshot;
  try {
    await ensureEventStorage();
    events = await readAllStoredEvents();
    snapshot = await readStoredSnapshot();
  } catch (error) {
    statusEl.textContent = `Export using memory cache only: ${error.message}`;
  }
  const blob = new Blob([
    JSON.stringify({
      exportedAt: new Date().toISOString(),
      snapshot,
      eventStorage: {
        memoryCount: state.events.length,
        persistedCount: state.persistedEventCount,
        persistedMaxCursor: state.persistedMaxCursor
      },
      events
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
  statusEl.textContent = `agent_control connected, debug ${enabled}, RPC ${available}, events memory ${state.events.length}, db ${state.persistedEventCount}`;
}

function ensureEventStorage() {
  if (!window.indexedDB) {
    return Promise.reject(new Error("IndexedDB is not available."));
  }
  if (state.storageReady) return state.storageReady;
  state.storageReady = openEventDb().then(async (db) => {
    const meta = await readEventStorageMeta(db);
    state.persistedEventCount = meta.count;
    state.persistedMaxCursor = meta.maxCursor;
    return db;
  });
  return state.storageReady;
}

function openEventDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(EVENT_DB_NAME, EVENT_DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(EVENT_STORE_NAME)) {
        const store = db.createObjectStore(EVENT_STORE_NAME, {keyPath: "cursor"});
        store.createIndex("source", "source", {unique: false});
        store.createIndex("worldId", "worldId", {unique: false});
        store.createIndex("timestamp", "timestamp", {unique: false});
      }
      if (!db.objectStoreNames.contains(SNAPSHOT_STORE_NAME)) {
        db.createObjectStore(SNAPSHOT_STORE_NAME, {keyPath: "key"});
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error("Failed to open IndexedDB."));
  });
}

function readEventStorageMeta(db) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(EVENT_STORE_NAME, "readonly");
    const store = transaction.objectStore(EVENT_STORE_NAME);
    const countRequest = store.count();
    const cursorRequest = store.openCursor(null, "prev");
    const meta = {count: 0, maxCursor: 0};
    countRequest.onsuccess = () => {
      meta.count = Number(countRequest.result || 0);
    };
    cursorRequest.onsuccess = () => {
      meta.maxCursor = Number(cursorRequest.result?.key || 0);
    };
    transaction.oncomplete = () => resolve(meta);
    transaction.onerror = () => reject(transaction.error || new Error("Failed to read event storage."));
  });
}

async function resetEventStorageIfCursorReset(snapshot) {
  const nextCursor = Number(snapshot?.nextCursor || 1);
  if (state.persistedMaxCursor > 0 && nextCursor > 0 && nextCursor <= state.persistedMaxCursor) {
    await clearEventStorage();
  }
}

async function appendEvents(events) {
  if (!events.length) return;
  const db = await ensureEventStorage();
  await writeStoredEvents(db, events);
  const meta = await readEventStorageMeta(db);
  state.persistedEventCount = meta.count;
  state.persistedMaxCursor = meta.maxCursor;
}

function writeStoredEvents(db, events) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(EVENT_STORE_NAME, "readwrite");
    const store = transaction.objectStore(EVENT_STORE_NAME);
    for (const event of events) {
      const cursor = Number(event?.cursor || 0);
      if (cursor <= 0) continue;
      store.put({...event, cursor});
    }
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error || new Error("Failed to write events."));
  });
}

function readAllStoredEvents() {
  return ensureEventStorage().then((db) => new Promise((resolve, reject) => {
    const transaction = db.transaction(EVENT_STORE_NAME, "readonly");
    const store = transaction.objectStore(EVENT_STORE_NAME);
    const request = store.getAll();
    request.onsuccess = () => {
      const events = Array.isArray(request.result) ? request.result : [];
      events.sort((a, b) => Number(a.cursor || 0) - Number(b.cursor || 0));
      resolve(events);
    };
    request.onerror = () => reject(request.error || new Error("Failed to read stored events."));
  }));
}

function storeSnapshot(snapshot) {
  return ensureEventStorage().then((db) => new Promise((resolve, reject) => {
    const transaction = db.transaction(SNAPSHOT_STORE_NAME, "readwrite");
    transaction.objectStore(SNAPSHOT_STORE_NAME).put({
      key: "latest",
      updatedAt: new Date().toISOString(),
      snapshot
    });
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error || new Error("Failed to write snapshot."));
  }));
}

function readStoredSnapshot() {
  return ensureEventStorage().then((db) => new Promise((resolve, reject) => {
    const transaction = db.transaction(SNAPSHOT_STORE_NAME, "readonly");
    const request = transaction.objectStore(SNAPSHOT_STORE_NAME).get("latest");
    request.onsuccess = () => resolve(request.result?.snapshot || state.snapshot);
    request.onerror = () => reject(request.error || new Error("Failed to read stored snapshot."));
  }));
}

function clearEventStorage() {
  return ensureEventStorage().then((db) => new Promise((resolve, reject) => {
    const transaction = db.transaction(
      [EVENT_STORE_NAME, SNAPSHOT_STORE_NAME],
      "readwrite"
    );
    transaction.objectStore(EVENT_STORE_NAME).clear();
    transaction.objectStore(SNAPSHOT_STORE_NAME).clear();
    transaction.oncomplete = () => {
      state.persistedEventCount = 0;
      state.persistedMaxCursor = 0;
      resolve();
    };
    transaction.onerror = () => reject(transaction.error || new Error("Failed to clear event storage."));
  }));
}

function limitedMemoryEvents(events) {
  if (!Array.isArray(events)) return [];
  return events.slice(-EVENT_MEMORY_LIMIT);
}

function trimMemoryEvents() {
  if (state.events.length <= EVENT_MEMORY_LIMIT) return;
  state.events.splice(0, state.events.length - EVENT_MEMORY_LIMIT);
}

function enforceLocalMemoryLimits() {
  trimMemoryEvents();
  trimMessageSourceIndex();
  trimSetTail(state.expandedNetworkRows, EXPANDED_NETWORK_ROW_MEMORY_LIMIT);
  trimMapTail(state.virtualLists, VIRTUAL_LIST_MEMORY_LIMIT);
  trimMapTail(state.virtualScrollTops, VIRTUAL_SCROLL_MEMORY_LIMIT);
  trimMapTail(state.virtualListIds, STABLE_VIRTUAL_ID_MEMORY_LIMIT);
  trimVirtualHeightCache();
}

function clearBoundedUiCaches() {
  state.queueErrorMap.clear();
  state.messageSourceIndex.clear();
  state.messageSourceIndexSignature = "";
  state.expandedNetworkRows.clear();
  state.virtualListIds.clear();
  state.virtualLists.clear();
  state.virtualScrollTops.clear();
  state.virtualHeightCache.clear();
}

function trimMessageSourceIndex() {
  trimMapTail(state.messageSourceIndex, MESSAGE_SOURCE_KEY_MEMORY_LIMIT);
  for (const bucket of state.messageSourceIndex.values()) {
    if (Array.isArray(bucket?.http)) {
      trimArrayTail(bucket.http, MESSAGE_SOURCE_HITS_PER_KEY_LIMIT);
    }
    if (Array.isArray(bucket?.websocket)) {
      trimArrayTail(bucket.websocket, MESSAGE_SOURCE_HITS_PER_KEY_LIMIT);
    }
  }
}

function trimVirtualHeightCache() {
  trimMapTail(state.virtualHeightCache, VIRTUAL_HEIGHT_CACHE_MEMORY_LIMIT);
  for (const heights of state.virtualHeightCache.values()) {
    if (heights instanceof Map) {
      trimMapTail(heights, VIRTUAL_HEIGHT_ITEMS_PER_LIST_LIMIT);
    }
  }
}

function trimArrayTail(array, limit) {
  if (!Array.isArray(array) || array.length <= limit) return;
  array.splice(0, array.length - limit);
}

function trimMapTail(map, limit) {
  if (!(map instanceof Map) || map.size <= limit) return;
  const overflow = map.size - limit;
  let removed = 0;
  for (const key of map.keys()) {
    map.delete(key);
    removed += 1;
    if (removed >= overflow) break;
  }
}

function trimSetTail(set, limit) {
  if (!(set instanceof Set) || set.size <= limit) return;
  const overflow = set.size - limit;
  let removed = 0;
  for (const value of set.values()) {
    set.delete(value);
    removed += 1;
    if (removed >= overflow) break;
  }
}

async function startAgentJob() {
  const count = Math.max(1, Number.parseInt(agentCountInput.value || "20", 10) || 20);
  const locationCount = Math.max(
    1,
    Number.parseInt(agentLocationCountInput.value || "1", 10) || 1
  );
  const params = {
    count,
    locationCount,
    replyTimeoutSeconds: 120
  };
  if (agentUseCurrentTarget.checked) {
    const worldId = currentWorldSnapshot().worldId || state.activeWorldId;
    const locationId =
      state.appActiveLocationId ||
      state.activeLocationId ||
      activePanelLocationId();
    if (worldId) params.wid = worldId;
    if (locationId) params.locationId = locationId;
  }

  agentStartButton.loading = true;
  updateAgentPanel("Starting agent...");
  try {
    const result = await rpc("agent.world_chat.start", params, {timeoutMs: 10000});
    state.agentJobId = `${result.jobId || ""}`.trim();
    state.agentStatus = `${result.status || "running"}`;
    state.agentAfterSeq = 0;
    state.agentLogs = [];
    persistAgentJob();
    updateAgentPanel();
    await pollAgentJobStatus();
  } catch (error) {
    updateAgentPanel(`Start failed: ${error.message}`);
  } finally {
    agentStartButton.loading = false;
  }
}

async function stopAgentJob() {
  if (!state.agentJobId) {
    updateAgentPanel("No running agent job.");
    return;
  }
  agentStopButton.loading = true;
  updateAgentPanel("Stopping agent...");
  try {
    await rpc("agent.world_chat.cancel", {jobId: state.agentJobId}, {timeoutMs: 10000});
    state.agentStatus = "cancelling";
    updateAgentPanel();
    await pollAgentJobStatus();
  } catch (error) {
    updateAgentPanel(`Stop failed: ${error.message}`);
  } finally {
    agentStopButton.loading = false;
  }
}

async function pollAgentJobStatus() {
  if (!state.agentJobId) return;
  if (isTerminalAgentStatus(state.agentStatus)) return;
  try {
    const result = await rpc("agent.world_chat.status", {
      jobId: state.agentJobId,
      afterSeq: state.agentAfterSeq
    }, {timeoutMs: 10000});
    state.agentStatus = `${result.status || state.agentStatus || "running"}`;
    const logs = Array.isArray(result.logs) ? result.logs : [];
    for (const log of logs) {
      const seq = Number(log.seq || 0);
      if (seq > state.agentAfterSeq) state.agentAfterSeq = seq;
      state.agentLogs.push(log);
    }
    trimArrayTail(state.agentLogs, AGENT_LOG_MEMORY_LIMIT);
    if (isTerminalAgentStatus(state.agentStatus)) {
      clearPersistedAgentJob();
      state.agentJobId = "";
    } else {
      persistAgentJob();
    }
    updateAgentPanel();
  } catch (error) {
    if (`${error.message || ""}`.includes("Agent job was not found")) {
      state.agentStatus = "not_found";
      clearPersistedAgentJob();
      state.agentJobId = "";
      updateAgentPanel("Agent job is no longer available in the App process.");
      return;
    }
    updateAgentPanel(`Status failed: ${error.message}`);
  }
}

function updateAgentPanel(message = "") {
  const status = normalizeAgentStatus(message || state.agentStatus || "idle");
  const job = state.agentJobId ? ` ${state.agentJobId}` : "";
  agentStatusEl.textContent = status;
  agentStatusEl.dataset.status = status;
  agentStatusEl.title = message || (job ? `job${job}` : status);
  const running = Boolean(state.agentJobId) && !isTerminalAgentStatus(status);
  agentStartButton.disabled = running;
  agentStopButton.disabled = !running;
}

function normalizeAgentStatus(value) {
  const text = `${value || ""}`.trim().toLowerCase();
  if (!text) return "idle";
  if (text.includes("fail")) return "failed";
  if (text.includes("not found")) return "not_found";
  if (text.includes("start")) return "starting";
  if (text.includes("stop")) return "stopping";
  return text.replace(/\s+/g, "_").replace(/[^a-z0-9_-]/g, "");
}

function isTerminalAgentStatus(status) {
  return status === "completed" ||
    status === "failed" ||
    status === "cancelled" ||
    status === "not_found";
}

function persistAgentJob() {
  if (!state.agentJobId) return;
  localStorage.setItem("locationChatAgentJob", JSON.stringify({
    jobId: state.agentJobId,
    status: state.agentStatus,
    afterSeq: state.agentAfterSeq
  }));
}

function restoreAgentJob() {
  try {
    const saved = JSON.parse(localStorage.getItem("locationChatAgentJob") || "{}");
    state.agentJobId = `${saved.jobId || ""}`.trim();
    state.agentStatus = `${saved.status || (state.agentJobId ? "running" : "idle")}`;
    state.agentAfterSeq = Number(saved.afterSeq || 0);
  } catch (_) {
    clearPersistedAgentJob();
  }
}

function clearPersistedAgentJob() {
  localStorage.removeItem("locationChatAgentJob");
}

function render() {
  saveVirtualScrollPositions();
  syncActiveWorld();
  rebuildMessageSourceIndex();
  deriveQueueErrorsFromReportedData();
  renderSummary();
  renderQueueTabs();
  renderQueueErrors();
  renderNetworkTimeline();
  enforceLocalMemoryLimits();
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
  renderColumnInto(
    columns,
    "disk",
    "Disk Cache",
    annotateQueueMessages(storage?.messages || [], world.worldId, locationId, "disk"),
    `${world.worldId}:${locationId}:disk`
  );
  renderColumnInto(
    columns,
    "memory",
    "Memory Cache",
    annotateQueueMessages(service?.messages || [], world.worldId, locationId, "memory"),
    `${world.worldId}:${locationId}:memory`
  );
  renderColumnInto(
    columns,
    "render",
    "Render VM",
    annotateQueueMessages(panel?.renderMessages || [], world.worldId, locationId, "render"),
    `${world.worldId}:${locationId}:render`
  );
}

function renderQueueErrors() {
  if (state.activeQueueMainTab !== "errors") {
    clearElement(queueErrors);
    return;
  }
  renderVirtualListInto(queueErrors, {
    items: state.queueErrors,
    className: "errors-virtual-list",
    key: `queue-errors:${state.activeWorldId}`,
    emptyHtml: `<p class="muted empty-state">No queue continuity errors.</p>`,
    getItemHeight: () => 96,
    getItemKey: queueErrorKey,
    renderItem: renderQueueError
  });
}

function deriveQueueErrorsFromReportedData() {
  const world = currentWorldSnapshot();
  const snapshots = state.snapshot?.snapshots || {};
  const errors = [];
  const errorMap = new Map();
  const errorDedupMap = new Map();
  for (const location of leafLocations()) {
    const storage = findSnapshotForLocation(snapshots.storage || {}, location.id, world.worldId);
    const service = findSnapshotForLocation(snapshots.service || {}, location.id, world.worldId);
    collectQueueContinuityErrors({
      errors,
      errorMap,
      errorDedupMap,
      worldId: world.worldId,
      locationId: location.id,
      locationName: location.name || location.id,
      queueLayer: "disk",
      queueLabel: "Disk Cache",
      messages: storage?.messages || []
    });
    collectQueueContinuityErrors({
      errors,
      errorMap,
      errorDedupMap,
      worldId: world.worldId,
      locationId: location.id,
      locationName: location.name || location.id,
      queueLayer: "memory",
      queueLabel: "Memory Cache",
      messages: service?.messages || []
    });
  }
  state.queueErrors = errors;
  state.queueErrorMap = errorMap;
  updateQueueErrorTabCount(errors.length);
}

function updateQueueErrorTabCount(count) {
  const tab = queueMainTabGroup.querySelector('sl-tab[panel="errors"]');
  if (!tab) return;
  const label = count > 0 ? `Errors (${count})` : "Errors";
  if (tab.textContent !== label) tab.textContent = label;
  tab.classList.toggle("has-errors", count > 0);
}

function collectQueueContinuityErrors({
  errors,
  errorMap,
  errorDedupMap,
  worldId,
  locationId,
  locationName,
  queueLayer,
  queueLabel,
  messages
}) {
  let previous = null;
  for (const message of messages) {
    if (isTickMessage(message)) continue;
    const currentId = numericLocationMsgId(message);
    if (!Number.isFinite(currentId) || currentId <= 0) continue;
    if (previous && currentId !== previous.locationMessageId + 1) {
      const errorType = currentId <= previous.locationMessageId
        ? "location_message_id_order_or_duplicate"
        : "location_message_id_gap";
      const error = {
        id: [
          worldId,
          locationId,
          queueLayer,
          previous.locationMessageId,
          currentId,
          messageGlobalId(message)
        ].join("|"),
        worldId: worldId || "",
        wid: worldId || "-",
        locationId,
        locationName,
        queueLayer,
        queueLabel,
        errorType,
        previousLocationMessageId: previous.locationMessageId,
        currentLocationMessageId: currentId,
        expectedLocationMessageId: previous.locationMessageId + 1,
        previousGlobalMessageId: previous.globalMessageId,
        currentGlobalMessageId: messageGlobalId(message),
        previousRowKey: messageRowKey(previous.message, 0),
        currentRowKey: messageRowKey(message, 0),
        previousMessageType: messageType(previous.message),
        currentMessageType: messageType(message),
        previousMessageContent: messageContent(previous.message),
        currentMessageContent: messageContent(message)
      };
      const dedupKey = queueErrorDedupKey(error);
      if (!errorDedupMap.has(dedupKey)) {
        errorDedupMap.set(dedupKey, error);
        errors.push(error);
      }
      errorMap.set(
        queueErrorMarkerKey(worldId, locationId, queueLayer, previous.message),
        {...error, markerRole: "previous"}
      );
      errorMap.set(
        queueErrorMarkerKey(worldId, locationId, queueLayer, message),
        {...error, markerRole: "current"}
      );
    }
    previous = {
      message,
      locationMessageId: currentId,
      globalMessageId: messageGlobalId(message)
    };
  }
}

function queueErrorDedupKey(error) {
  const globalMessageId = `${error.currentGlobalMessageId || ""}`.trim();
  if (globalMessageId) return `global:${globalMessageId}`;
  return `error:${queueErrorKey(error)}`;
}

function annotateQueueMessages(messages, worldId, locationId, queueLayer) {
  return messages.map((message) => {
    const error = state.queueErrorMap.get(
      queueErrorMarkerKey(worldId, locationId, queueLayer, message)
    );
    const focusKey = queueMessageFocusKey(
      worldId,
      locationId,
      queueLayer,
      messageRowKey(message, 0)
    );
    const isFocused = Boolean(state.queueFocusKey && focusKey === state.queueFocusKey);
    const sourceKeys = messageSourceKeys(message, {worldId, locationId});
    if (!error && !isFocused && !sourceKeys.length) return message;
    return {
      ...message,
      __queueError: error,
      __queueFocus: isFocused,
      __messageSourceKeys: sourceKeys
    };
  });
}

function queueMessageFocusKey(worldId, locationId, queueLayer, rowKey) {
  return [
    worldId || "",
    locationId || "",
    queueLayer || "",
    rowKey || ""
  ].join("|");
}

function queueErrorMarkerKey(worldId, locationId, queueLayer, message) {
  return [
    worldId || "",
    locationId || "",
    queueLayer || "",
    messageLocationMsgId(message) || "",
    messageGlobalId(message) || messageRowKey(message, 0)
  ].join("|");
}

function renderNetworkTimeline() {
  const activeContainer = state.activeNetworkTab === "websocket"
    ? websocketFrames
    : httpMessages;
  const inactiveContainer = state.activeNetworkTab === "websocket"
    ? httpMessages
    : websocketFrames;
  clearElement(inactiveContainer);
  const events = networkEvents();
  renderVirtualListInto(activeContainer, {
    items: events,
    className: "network-virtual-list",
    key: networkTimelineKey(),
    emptyHtml: `<p class="muted">No message network events yet.</p>`,
    getItemHeight: (event) => networkRowOpen(event)
      ? networkExpandedRowHeight(event)
      : 39,
    getItemKey: networkRowId,
    renderItem: renderNetworkEvent
  });
}

function networkTimelineKey() {
  return `network:${state.activeWorldId}:timeline`;
}

function rebuildMessageSourceIndex() {
  const lastCursor = Number(state.events[state.events.length - 1]?.cursor || 0);
  const signature = [
    state.activeWorldId,
    state.networkSinceCursor,
    state.events.length,
    lastCursor
  ].join("|");
  if (signature === state.messageSourceIndexSignature) return;

  const index = new Map();
  for (const event of networkEvents()) {
    if (event.source !== "http") continue;
    const rowId = networkRowId(event);
    const details = event.details || {};
    const messages = Array.isArray(details.messages) ? details.messages : [];
    for (const message of messages) {
      addMessageSourceHit(index, message, event, {
        source: "http",
        rowId,
        eventCursor: Number(event.cursor || 0),
        messageRowKey: messageRowKey(message, 0)
      });
    }
  }

  for (const event of networkEvents()) {
    if (event.source !== "websocket") continue;
    const rowId = networkRowId(event);
    const payloadMessages = extractMessageLikeObjects(event.details?.payload);
    for (const message of payloadMessages) {
      addMessageSourceHit(index, message, event, {
        source: "websocket",
        rowId,
        eventCursor: Number(event.cursor || 0),
        messageRowKey: messageRowKey(message, 0)
      });
    }
  }

  state.messageSourceIndex = index;
  state.messageSourceIndexSignature = signature;
}

function addMessageSourceHit(index, message, event, hit) {
  for (const key of messageSourceKeys(message, event)) {
    const bucket = index.get(key) || {http: [], websocket: []};
    bucket[hit.source].push(hit);
    index.set(key, bucket);
  }
}

function messageSourceKeys(message, context = {}) {
  const worldId = firstNonEmpty(message?.worldId, message?.world_id, context.worldId);
  const locationIds = uniqueStrings([
    firstNonEmpty(message?.locationId, message?.location_id),
    firstNonEmpty(context.locationId)
  ]);
  const globalId = messageGlobalId(message);
  const locationMsgId = messageLocationMsgId(message);
  const queueMsgId = firstNonEmpty(message?.queueMsgId, message?.queue_msg_id);
  const clientMsgId = firstNonEmpty(message?.clientMsgId, message?.client_msg_id);
  const msgId = firstNonEmpty(message?.msgId, message?.msg_id, message?.messageId, message?.message_id);
  const keys = [];
  if (globalId) keys.push(`global:${globalId}`);
  if (worldId) {
    for (const locationId of locationIds) {
      if (locationMsgId) keys.push(`loc:${worldId}:${locationId}:${locationMsgId}`);
      if (queueMsgId) keys.push(`queue:${worldId}:${locationId}:${queueMsgId}`);
    }
  }
  if (clientMsgId) keys.push(`client:${clientMsgId}`);
  if (msgId) keys.push(`msg:${msgId}`);
  return uniqueStrings(keys);
}

function extractMessageLikeObjects(value, results = [], depth = 0) {
  if (depth > 8 || results.length >= 80) return results;
  if (!value || typeof value !== "object") return results;
  if (Array.isArray(value)) {
    for (const item of value) {
      extractMessageLikeObjects(item, results, depth + 1);
      if (results.length >= 80) break;
    }
    return results;
  }

  if (isIndexableWebSocketMessage(value)) {
    results.push(value);
  }
  for (const child of Object.values(value)) {
    extractMessageLikeObjects(child, results, depth + 1);
    if (results.length >= 80) break;
  }
  return results;
}

function isIndexableWebSocketMessage(value) {
  const globalId = messageGlobalId(value);
  const locationMsgId = messageLocationMsgId(value);
  if (globalId || locationMsgId) return true;
  const clientMsgId = `${value?.clientMsgId ?? value?.client_msg_id ?? ""}`.trim();
  const msgId = `${value?.msgId ?? value?.msg_id ?? value?.messageId ?? value?.message_id ?? ""}`.trim();
  if (!clientMsgId && !msgId) return false;
  return Boolean(
    value?.senderType ||
    value?.sender_type ||
    value?.content ||
    value?.contentPreview ||
    value?.content_preview ||
    value?.text ||
    value?.status
  );
}

function uniqueStrings(values) {
  const result = [];
  const seen = new Set();
  for (const value of values) {
    const normalized = `${value || ""}`.trim();
    if (!normalized || seen.has(normalized)) continue;
    seen.add(normalized);
    result.push(normalized);
  }
  return result;
}

function renderNetworkEvent(event) {
  return event.source === "http"
    ? renderHttpPull(event)
    : renderWebSocketFrame(event);
}

function networkExpandedRowHeight(event) {
  if (event.source === "http") return httpExpandedRowHeight();
  return 430;
}

function httpExpandedRowHeight() {
  const detailHeight = Math.max(480, Math.min(680, window.innerHeight - 220));
  return detailHeight + 39;
}

function networkEvents(limit = 0) {
  const worldId = state.activeWorldId;
  const events = state.events
    .filter(isMessageNetworkEvent)
    .filter((event) => !worldId || event.worldId === worldId)
    .filter((event) => Number(event.cursor || 0) >= state.networkSinceCursor);
  events.sort(compareNetworkEventOrder);
  return (limit > 0 ? events.slice(-limit) : events).reverse();
}

function compareNetworkEventOrder(a, b) {
  const cursorA = Number(a?.cursor || 0);
  const cursorB = Number(b?.cursor || 0);
  if (cursorA !== cursorB) return cursorA - cursorB;
  const timeA = Date.parse(a?.timestamp || "") || 0;
  const timeB = Date.parse(b?.timestamp || "") || 0;
  return timeA - timeB;
}

function isMessageNetworkEvent(event) {
  if (!event) return false;
  if (event.source === "http") return true;
  if (event.source !== "websocket") return false;
  const details = event.details || {};
  const type = `${details.type || event.action || ""}`.trim();
  const eventType = `${details.eventType || ""}`.trim();
  if (eventType === "world_new_message") return true;
  if (type === "world_change") return false;
  if (!type) return true;
  return [
    "join",
    "send_message",
    "ack",
    "user_message",
    "nar_new_message",
    "tick_advance",
    "llm_stream_start",
    "llm_chunk",
    "llm_stream_end",
    "error",
    "decode_error"
  ].includes(type);
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
  state.queueFocusKey = "";
  state.networkFocusKey = "";
  state.networkMessageFocusKey = "";
  state.messageSourceIndex.clear();
  state.messageSourceIndexSignature = "";
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
  const focused = state.networkFocusKey === rowId;
  return `
    <article class="network-event ${escapeHtml(direction)} ${open ? "open" : ""} ${focused ? "network-focus-row" : ""}" data-network-row-id="${escapeAttribute(rowId)}">
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
  const focused = state.networkFocusKey === rowId;
  const renderedMessages = annotateNetworkResponseMessages(rowId, messages);
  return `
    <article class="network-event http-pull ${open ? "open" : ""} ${focused ? "network-focus-row" : ""}" data-network-row-id="${escapeAttribute(rowId)}">
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
              ${renderedMessages.length ? virtualList({
                  items: renderedMessages,
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

function annotateNetworkResponseMessages(rowId, messages) {
  return messages.map((message) => {
    const focusKey = networkMessageFocusKey(rowId, messageRowKey(message, 0));
    if (focusKey !== state.networkMessageFocusKey) return message;
    return {...message, __networkFocus: true};
  });
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
  const kind = messageType(message);
  const text = messageContent(message);
  const error = message.__queueError || null;
  const sourceKeys = Array.isArray(message.__messageSourceKeys)
    ? message.__messageSourceKeys
    : [];
  const issueTitle = error
    ? `${error.queueLabel}: expected ${error.expectedLocationMessageId}, got ${error.currentLocationMessageId}`
    : "";
  return `
    <div
      class="message-row ${isTickMessage(message) ? "tick-message" : ""} ${error ? "queue-gap-row" : ""} ${message.__queueFocus ? "queue-focus-row" : ""} ${message.__networkFocus ? "network-message-focus-row" : ""}"
      ${sourceKeys.length ? `data-message-source-keys="${escapeAttribute(encodeSourceKeys(sourceKeys))}"` : ""}
    >
      <div class="message-id">${escapeHtml(id)}</div>
      <div class="message-text">
        <strong>
          ${error ? `<span class="queue-gap-icon" title="${escapeAttribute(issueTitle)}">!</span>` : ""}
          ${escapeHtml(kind)}
        </strong>
        <div>${escapeHtml(text)}</div>
      </div>
    </div>
  `;
}

function renderQueueError(error) {
  return `
    <article
      class="queue-error-row"
      role="button"
      tabindex="0"
      data-queue-error-key="${escapeAttribute(queueErrorKey(error))}"
      title="Jump to Queue Compare"
    >
      <div class="queue-error-main">
        <span class="queue-gap-icon">!</span>
        <strong>${escapeHtml(error.errorType)}</strong>
        <span>${escapeHtml(error.queueLabel)}</span>
        <span>${escapeHtml(error.locationName || error.locationId)}</span>
      </div>
      <div class="queue-error-meta">
        <span>wid: <b>${escapeHtml(error.wid)}</b></span>
        <span>location: <b>${escapeHtml(error.locationId)}</b></span>
        <span>prev loc_msg_id: <b>${escapeHtml(error.previousLocationMessageId)}</b></span>
        <span>current loc_msg_id: <b>${escapeHtml(error.currentLocationMessageId)}</b></span>
        <span>expected: <b>${escapeHtml(error.expectedLocationMessageId)}</b></span>
        <span>prev global_message_id: <b>${escapeHtml(error.previousGlobalMessageId || "-")}</b></span>
        <span>current global_message_id: <b>${escapeHtml(error.currentGlobalMessageId || "-")}</b></span>
        <span>type: <b>${escapeHtml(error.currentMessageType || "-")}</b></span>
      </div>
      <div class="queue-error-content">${escapeHtml(error.currentMessageContent || "")}</div>
      <div class="queue-error-content previous">previous: ${escapeHtml(error.previousMessageContent || "")}</div>
    </article>
  `;
}

function queueErrorKey(error) {
  return error.id || [
    error.wid,
    error.locationId,
    error.queueLayer,
    error.previousLocationMessageId,
    error.currentLocationMessageId
  ].join("|");
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

function numericLocationMsgId(message) {
  const value = Number(messageLocationMsgId(message));
  return Number.isFinite(value) ? value : NaN;
}

function messageGlobalId(message) {
  const candidates = [
    message?.global_message_id,
    message?.global_msg_id,
    message?.globalMsgId,
    message?.globalMessageId
  ];
  for (const value of candidates) {
    const normalized = `${value ?? ""}`.trim();
    if (normalized && normalized !== "0") return normalized;
  }
  return "";
}

function messageType(message) {
  return `${message?.senderType ?? message?.sender_type ?? message?.status ?? ""}`.trim();
}

function messageContent(message) {
  return `${message?.contentPreview ?? message?.content_preview ?? message?.content ?? message?.text ?? ""}`.trim();
}

function messageRowKey(message, index) {
  const id = messageLocationMsgId(message);
  if (id) return `loc:${id}`;
  const msgId = firstNonEmpty(message?.msgId, message?.msg_id, message?.messageId, message?.message_id);
  if (msgId) return `msg:${msgId}`;
  const clientMsgId = firstNonEmpty(message?.clientMsgId, message?.client_msg_id);
  if (clientMsgId) return `client:${clientMsgId}`;
  const time = `${message?.currentTime ?? message?.current_time ?? message?.ts ?? ""}`.trim();
  const kind = `${message?.senderType ?? message?.sender_type ?? message?.status ?? ""}`.trim();
  return `${index}:${kind}:${time}:${message?.contentPreview || ""}`;
}

function firstNonEmpty(...values) {
  for (const value of values) {
    const normalized = `${value ?? ""}`.trim();
    if (normalized && normalized !== "0") return normalized;
  }
  return "";
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
  const queueErrorRow = event.target.closest("[data-queue-error-key]");
  if (queueErrorRow) {
    jumpToQueueError(queueErrorRow.dataset.queueErrorKey || "");
    return;
  }

  const sourceMessage = event.target.closest("[data-message-source-keys]");
  if (sourceMessage) {
    jumpToNetworkSource(sourceMessage.dataset.messageSourceKeys || "");
    return;
  }

  const toggle = event.target.closest("[data-network-toggle]");
  if (!toggle) return;
  const rowId = toggle.dataset.networkToggle || "";
  if (!rowId) return;
  if (state.expandedNetworkRows.has(rowId)) {
    state.expandedNetworkRows.delete(rowId);
  } else {
    state.expandedNetworkRows.add(rowId);
    trimSetTail(state.expandedNetworkRows, EXPANDED_NETWORK_ROW_MEMORY_LIMIT);
  }
  state.virtualLists.get(event.currentTarget.dataset.virtualId || "")?.itemHeights.clear();
  renderVirtualList(event.currentTarget);
}

function jumpToNetworkSource(sourceKeysValue) {
  const hit = resolveNetworkSourceHit(sourceKeysValue);
  if (!hit) return;

  state.networkFocusKey = hit.rowId;
  state.networkMessageFocusKey = hit.source === "http" && hit.messageRowKey
    ? networkMessageFocusKey(hit.rowId, hit.messageRowKey)
    : "";
  state.expandedNetworkRows.add(hit.rowId);
  trimSetTail(state.expandedNetworkRows, EXPANDED_NETWORK_ROW_MEMORY_LIMIT);

  renderNetworkTimeline();

  queueMicrotask(() => {
    mountVirtualLists();
    requestAnimationFrame(() => scrollToNetworkHit(hit));
  });
}

function resolveNetworkSourceHit(sourceKeysValue) {
  const keys = `${sourceKeysValue || ""}`
    .split(",")
    .map((item) => decodeSourceKey(item))
    .filter(Boolean);
  for (const key of keys) {
    const hit = state.messageSourceIndex.get(key)?.http?.[0];
    if (hit) return hit;
  }
  for (const key of keys) {
    const hit = state.messageSourceIndex.get(key)?.websocket?.[0];
    if (hit) return hit;
  }
  return null;
}

function encodeSourceKeys(keys) {
  return keys.map((key) => encodeURIComponent(key)).join(",");
}

function decodeSourceKey(value) {
  try {
    return decodeURIComponent(`${value || ""}`.trim());
  } catch (_) {
    return "";
  }
}

function networkMessageFocusKey(rowId, messageRowKeyValue) {
  return `${rowId || ""}|${messageRowKeyValue || ""}`;
}

function scrollToNetworkHit(hit) {
  const container = document.querySelector(
    `.virtual-list[data-virtual-key="${cssEscape(networkTimelineKey())}"]`
  );
  if (!container) return false;
  const scrolled = scrollVirtualListToItem(container, hit.rowId);
  requestAnimationFrame(() => {
    const item = container.querySelector(
      `.virtual-item[data-virtual-key="${cssEscape(hit.rowId)}"]`
    );
    item?.querySelector(".network-event")?.classList.add("network-focus-pulse");
    if (hit.source !== "http" || !hit.messageRowKey) return;
    const responseList = item?.querySelector(
      `.virtual-list[data-virtual-key="${cssEscape(`network-response:${hit.rowId}`)}"]`
    );
    if (!responseList) return;
    scrollVirtualListToItem(responseList, hit.messageRowKey);
  });
  return scrolled;
}

function jumpToQueueError(errorKey) {
  const error = state.queueErrors.find((item) => queueErrorKey(item) === errorKey);
  if (!error) return;

  const worldId = `${error.worldId || (error.wid === "-" ? "" : error.wid) || ""}`;
  const targetRowKey = `${error.currentRowKey || `loc:${error.currentLocationMessageId}`}`;
  state.activeQueueMainTab = "queueCompare";
  state.activeLocationId = error.locationId;
  state.queueFocusKey = queueMessageFocusKey(
    worldId,
    error.locationId,
    error.queueLayer,
    targetRowKey
  );

  if (typeof queueMainTabGroup.show === "function") {
    queueMainTabGroup.show("queueCompare");
  }
  renderQueueTabs();

  queueMicrotask(() => {
    if (typeof locationTabGroup.show === "function") {
      locationTabGroup.show(error.locationId);
    }
    renderActiveQueuePanel();
    queueMicrotask(() => {
      mountVirtualLists();
      requestAnimationFrame(() => scrollToQueueMessage(error, targetRowKey));
    });
  });
}

function scrollToQueueMessage(error, targetRowKey) {
  const worldId = `${error.worldId || (error.wid === "-" ? "" : error.wid) || ""}`;
  const listKey = `queue:${worldId}:${error.locationId}:${error.queueLayer}`;
  const container = document.querySelector(
    `.virtual-list[data-virtual-key="${cssEscape(listKey)}"]`
  );
  if (!container) return false;
  return scrollVirtualListToItem(container, targetRowKey);
}

function scrollVirtualListToItem(container, targetKey) {
  const config = state.virtualLists.get(container.dataset.virtualId || "");
  if (!config) return false;
  const items = config.items || [];
  const index = items.findIndex((item, itemIndex) => (
    virtualItemKey(config, item, itemIndex) === targetKey
  ));
  if (index < 0) return false;

  const heights = items.map((item, itemIndex) => itemHeight(config, item, itemIndex));
  let offset = 0;
  for (let itemIndex = 0; itemIndex < index; itemIndex += 1) {
    offset += heights[itemIndex];
  }
  const targetHeight = heights[index] || 1;
  const targetScrollTop = Math.max(
    0,
    offset - Math.max(0, (container.clientHeight - targetHeight) / 2)
  );
  container.__virtualPendingScrollTop = targetScrollTop;
  if (config.key) {
    state.virtualScrollTops.set(config.key, targetScrollTop);
  }
  renderVirtualList(container);
  requestAnimationFrame(() => {
    const item = container.querySelector(
      `.virtual-item[data-virtual-key="${cssEscape(targetKey)}"]`
    );
    const row = item?.querySelector(".message-row");
    row?.classList.add("queue-focus-pulse");
  });
  return true;
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

restoreAgentJob();
updateAgentPanel();
refreshAll();
state.pollTimer = setInterval(pollEvents, 1000);
state.agentStatusTimer = setInterval(pollAgentJobStatus, 2000);
pollAgentJobStatus();
