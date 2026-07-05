# Location Chat Debug Dashboard

Local web dashboard for inspecting location chat debug data from an Android
device over USB. The app exposes read-only debug RPC through `agent_control` on
the device, and the dashboard reads it through `adb forward`.

## Requirements

- Android device connected by USB.
- Flutter debug/profile build. Release builds do not collect or expose this
  debug data.
- `GENESIS_LOCATION_CHAT_DEBUG=true` must be passed at launch. Without it, the
  debug RPC is available in debug/profile but returns disabled/empty data.
- Node.js 18 or newer.
- The dashboard UI uses Shoelace web components from jsDelivr CDN for tabs,
  cards, and buttons.

## Run the App

Recommended one-command flow from the repository root:

```bash
./tools/agent_cli/run-with-dashboard
```

This starts the App with both agent CLI and location chat debug enabled, then
starts this dashboard with the same local CLI token.

From `genesis_app/`:

```bash
flutter run \
  --dart-define=GENESIS_AGENT_CONTROL_ENABLED=true \
  --dart-define=GENESIS_AGENT_CONTROL_TOKEN=local-debug \
  --dart-define=GENESIS_LOCATION_CHAT_DEBUG=true
```

For a specific device:

```bash
flutter devices
flutter run -d <device_id> \
  --dart-define=GENESIS_AGENT_CONTROL_ENABLED=true \
  --dart-define=GENESIS_AGENT_CONTROL_TOKEN=local-debug \
  --dart-define=GENESIS_LOCATION_CHAT_DEBUG=true
```

## Start Dashboard With USB Forwarding

From this directory:

```bash
./start-usb.sh
```

Or from the same directory with npm:

```bash
npm run start:usb
```

This script runs:

- `npm install`
- `adb forward tcp:17317 tcp:17317`
- `npm start`

By default the dashboard server uses:

- Dashboard URL: `http://127.0.0.1:17318/`
- Agent RPC URL: `http://127.0.0.1:17317/rpc`
- Agent token: `local-debug`

Useful overrides:

```bash
PORT=17319 ./start-usb.sh
SKIP_NPM_INSTALL=true ./start-usb.sh
SKIP_ADB_FORWARD=true ./start-usb.sh
ADB=/path/to/adb ./start-usb.sh
```

## Manual USB Port Forwarding

In another terminal:

```bash
adb forward tcp:17317 tcp:17317
```

The app listens on device-local `127.0.0.1:17317`; this command exposes it on
the Mac at `127.0.0.1:17317`. The `./start-usb.sh` script runs this for you.

## Manual Dashboard Start

From this directory:

```bash
npm start
```

Override when needed:

```bash
PORT=17319 \
GENESIS_AGENT_CONTROL_URL=http://127.0.0.1:17317/rpc \
GENESIS_AGENT_CONTROL_TOKEN=local-debug \
npm start
```

## What the Dashboard Shows

The dashboard is a single-screen dark split view:

- `Agent Control`: starts/stops the App-side background world-chat job through
  `agent.world_chat.start` and `agent.world_chat.cancel`. The current `jobId`
  is stored in browser local storage so a refreshed page can still stop a
  running App job while the App process remains alive. `Locations` lets the job
  visit multiple locations in one world by entering a location, sending its
  assigned messages, exiting, and then entering the next location. `Wid` lets
  the job enter a specific world. Enter `Current` to use the world from the
  latest App debug snapshot and keep the current location target. When `Wid` is
  empty, the dashboard uses the current world/location if `Use current location`
  is checked, otherwise the App picks a random eligible world. You can also
  prefill it with `http://127.0.0.1:17318/?wid=<WID>`.
- Top info row: 300px-wide cards for `Wid`, `Num Of Leaf Locations`, and
  `Websocket Status`.
- Left card: `Queue Compare`, with one tab per leaf location.
- Right card: `Net Work`, with separate `HTTPS` and `WebSocket` tabs.
- `HTTPS`: stored and rendered as HTTP request rows, newest first, with the raw
  response JSON and parsed messages when the row is expanded.
- `WebSocket`: stored and rendered as individual WebSocket packet rows, newest
  first, preserving inbound/outbound direction, frame type, raw payload size, and
  expandable raw/payload JSON.

## Event Retention

Debug events use a two-tier local cache in the dashboard:

- Recent events are kept in browser memory for rendering and frequent lookup.
- All events and the latest full snapshot are persisted into the browser
  IndexedDB database
  `location-chat-debug-dashboard`. Raw debug events remain in the `events`
  store, while the right-side request list is also materialized into a
  `networkRecords` store with `networkKind`, `networkRecordId`, and
  `networkRecordType` metadata so it can be queried and rebuilt by HTTP request
  or WebSocket packet.

The Network timeline renders the in-memory window for the active world so large
captures do not slow down DOM rendering. `Export JSON` reads the full persisted
event set from IndexedDB. Events are cleared only when you click `Clear Events`,
which clears both dashboard memory and IndexedDB and calls
`debug.locationChat.clear` in the App process.

Dashboard memory limits are cache limits, not data-loss limits for the active
render. The current snapshot used by Queue Compare, Errors, and summary cards is
not trimmed before rendering; full raw data is kept in IndexedDB, while bounded
memory structures act as the hot bridge between disk and the visible UI.

Current cache limits:

- Network/debug event render window: 2,000 events.
- Message-source index keys: 3,000 keys, with 20 hits per source per key.
- Expanded Network rows: 300 rows.
- Virtual-list UI caches: bounded by list/key/height-entry limits.
- Agent job logs: 50 rows.

Queue continuity errors are derived from the current dashboard-local disk cache
and memory cache lists. The `Errors` tab count can shrink when a later snapshot
fills a temporary gap or reorders the queue into a continuous state.

The App side only reports raw debug events and snapshots. Queue continuity
classification, deduplication, counting, and rendering are dashboard-side
logic in `public/app.js`.

## Useful Checks

Confirm the dashboard static server is up:

```bash
curl -I http://127.0.0.1:17318/
```

Confirm the app-side RPC is reachable through USB forwarding:

```bash
curl -s http://127.0.0.1:17318/api/rpc \
  -H 'content-type: application/json' \
  -d '{"id":"debug-check","method":"debug.locationChat.snapshot","params":{}}'
```

If the dashboard connects but shows disabled/empty data, check that the app was
started with `GENESIS_LOCATION_CHAT_DEBUG=true` and that you have entered
`WorldPage` and opened a leaf location chat page.
