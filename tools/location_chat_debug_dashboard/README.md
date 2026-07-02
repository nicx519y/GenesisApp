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

## Forward USB Port

In another terminal:

```bash
adb forward tcp:17317 tcp:17317
```

The app listens on device-local `127.0.0.1:17317`; this command exposes it on
the Mac at `127.0.0.1:17317`.

## Start the Dashboard

From this directory:

```bash
npm start
```

By default the dashboard server uses:

- Dashboard URL: `http://127.0.0.1:17318/`
- Agent RPC URL: `http://127.0.0.1:17317/rpc`
- Agent token: `local-debug`

Override when needed:

```bash
PORT=17319 \
GENESIS_AGENT_CONTROL_URL=http://127.0.0.1:17317/rpc \
GENESIS_AGENT_CONTROL_TOKEN=local-debug \
npm start
```

## What the Dashboard Shows

The dashboard is a single-screen dark split view:

- Top info row: 300px-wide cards for `Wid`, `Num Of Leaf Locations`, and
  `Websocket Status`.
- Left card: `Queue Compare`, with one tab per leaf location.
- Right card: `Net Work`, with `HTTPS` and `WebSocket` tabs.
- `HTTPS`: `GET /aitown-chat/api/messages` latest/older responses used to
  hydrate or paginate messages.
- `WebSocket`: inbound/outbound WebSocket payloads from the location chat page.

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
