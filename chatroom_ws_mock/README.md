# Chatroom WebSocket Mock

这是一个本地 Node.js WebSocket mock 服务，用于测试 Flutter 端 chatroom 客户端。

## 启动

```sh
npm install
npm start
```

默认监听地址：

```text
ws://localhost:8787/ws
```

覆盖端口：

```sh
PORT=9090 npm start
```

如需让同一局域网内的真机访问，可以监听所有网卡：

```sh
HOST=0.0.0.0 npm start
```

## 客户端连接 URL

```text
ws://localhost:8787/ws?world_instance_id=world-001&location_id=living-room
```

## 支持的消息

客户端发往服务端：

- `join`
- `send_message`
- `heartbeat`
- `leave`

收到 `send_message` 后，服务端会依次推送：

1. `ack`
2. `ai_stream_start`
3. 多个 `ai_stream_chunk`
4. `ai_stream_end`

## 健康检查

```sh
curl http://localhost:8787/health
```
