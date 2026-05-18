const { randomUUID } = require('node:crypto');
const http = require('node:http');
const { WebSocketServer, WebSocket } = require('ws');

const port = Number.parseInt(process.env.PORT || '8787', 10);
const host = process.env.HOST || '127.0.0.1';

let nextMessageId = 1000;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  res.writeHead(404, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ error: 'not_found' }));
});

const wss = new WebSocketServer({ noServer: true });
const sessions = new Map();

server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url || '/', `http://${req.headers.host || `${host}:${port}`}`);
  if (url.pathname !== '/ws') {
    socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
    socket.destroy();
    return;
  }

  wss.handleUpgrade(req, socket, head, (ws) => {
    wss.emit('connection', ws, req, url);
  });
});

wss.on('connection', (ws, req, url) => {
  const session = {
    id: `sess-${randomUUID()}`,
    worldInstanceId: url.searchParams.get('world_instance_id') || '',
    locationId: url.searchParams.get('location_id') || '',
    userId: '',
    senderId: '',
    senderName: '',
    timers: new Set(),
  };
  sessions.set(ws, session);

  ws.on('message', (raw) => {
    let envelope;
    try {
      envelope = JSON.parse(raw.toString('utf8'));
    } catch (error) {
      send(ws, 'error', {
        session_id: session.id,
        code: 'invalid_json',
        message: error.message,
      });
      return;
    }

    const payload = envelope && typeof envelope.payload === 'object' && envelope.payload !== null
      ? envelope.payload
      : {};

    switch (envelope.type) {
      case 'join':
        handleJoin(ws, session, payload);
        break;
      case 'send_message':
        handleSendMessage(ws, session, payload);
        break;
      case 'heartbeat':
        console.log(`[heartbeat] ${session.id} ${payload.timestamp || Date.now()}`);
        break;
      case 'leave':
        cleanup(ws);
        ws.close(1000, 'leave');
        break;
      default:
        send(ws, 'error', {
          session_id: session.id,
          code: 'unsupported_type',
          message: `Unsupported message type: ${envelope.type}`,
        });
        break;
    }
  });

  ws.on('close', () => cleanup(ws));
  ws.on('error', () => cleanup(ws));
});

function handleJoin(ws, session, payload) {
  session.userId = String(payload.user_id || 'local-user');
  session.senderId = String(payload.sender_id || 'player1');
  session.senderName = String(payload.sender_name || 'Local Player');

  send(ws, 'joined', {
    session_id: session.id,
    world_instance_id: session.worldInstanceId,
    location_id: session.locationId,
    online_users: [
      {
        user_id: session.userId,
        sender_id: session.senderId,
        sender_name: session.senderName,
      },
    ],
  });
}

function handleSendMessage(ws, session, payload) {
  const clientMsgId = String(payload.client_msg_id || `client-${randomUUID()}`);
  const text = String(payload.text || '');
  const userMessageId = ++nextMessageId;
  const aiMessageId = ++nextMessageId;
  const roundId = `round-${randomUUID()}`;
  const createdAt = new Date().toISOString();

  send(ws, 'ack', {
    session_id: session.id,
    message_id: userMessageId,
    conversation_round_id: roundId,
    client_msg_id: clientMsgId,
    queue_position: 0,
  });

  send(ws, 'ai_stream_start', {
    session_id: session.id,
    message_id: aiMessageId,
    conversation_round_id: roundId,
    round_order: 1,
    sender_type: 'character',
    sender_id: 'local-ai',
    sender_name: 'Local AI',
  });

  const chunks = buildChunks(text);
  chunks.forEach((chunk, index) => {
    schedule(session, index * 200, () => {
      send(ws, 'ai_stream_chunk', {
        session_id: session.id,
        message_id: aiMessageId,
        conversation_round_id: roundId,
        sender_id: 'local-ai',
        chunk,
        is_delta: true,
      });
    });
  });

  schedule(session, chunks.length * 200, () => {
    send(ws, 'ai_stream_end', {
      session_id: session.id,
      message_id: aiMessageId,
      conversation_round_id: roundId,
      sender_id: 'local-ai',
      created_at: createdAt,
    });
  });
}

function buildChunks(text) {
  const prompt = text.trim() || '空消息';
  const base =
    `本地 AI 已收到消息：「${prompt}」。` +
    '现在开始模拟打字机式流式回复，客户端应当能逐步渲染这些内容。';
  return chunkByUtf8Bytes(`${base}${base}`, 5);
}

function chunkByUtf8Bytes(text, maxBytes) {
  const chunks = [];
  let current = '';
  let currentBytes = 0;

  for (const char of text) {
    const charBytes = Buffer.byteLength(char, 'utf8');
    if (current && currentBytes + charBytes > maxBytes) {
      chunks.push(current);
      current = '';
      currentBytes = 0;
    }
    current += char;
    currentBytes += charBytes;
  }

  if (current) {
    chunks.push(current);
  }
  return chunks;
}

function schedule(session, delayMs, fn) {
  const timer = setTimeout(() => {
    session.timers.delete(timer);
    fn();
  }, delayMs);
  session.timers.add(timer);
}

function send(ws, type, payload) {
  if (ws.readyState !== WebSocket.OPEN) {
    return;
  }
  ws.send(JSON.stringify({ type, payload }));
}

function cleanup(ws) {
  const session = sessions.get(ws);
  if (!session) {
    return;
  }
  for (const timer of session.timers) {
    clearTimeout(timer);
  }
  session.timers.clear();
  sessions.delete(ws);
}

server.listen(port, host, () => {
  console.log(`Chatroom WS mock listening at ws://localhost:${port}/ws`);
});

function shutdown() {
  for (const ws of sessions.keys()) {
    cleanup(ws);
    ws.close(1001, 'server_shutdown');
  }
  server.close(() => process.exit(0));
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
