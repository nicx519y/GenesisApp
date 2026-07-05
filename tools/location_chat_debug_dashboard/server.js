const http = require("http");
const fs = require("fs");
const path = require("path");

const port = Number(process.env.PORT || 17318);
const agentControlUrl = new URL(
  process.env.AGENT_CONTROL_URL || "http://127.0.0.1:17317"
);
const token = process.env.GENESIS_AGENT_CONTROL_TOKEN || "local-debug";
const publicDir = path.join(__dirname, "public");

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8"
};

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, {"content-type": "application/json; charset=utf-8"});
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        reject(new Error("request body too large"));
        req.destroy();
      }
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

function proxyRpc(body) {
  const payload = Buffer.from(JSON.stringify(body));
  const options = {
    hostname: agentControlUrl.hostname,
    port: agentControlUrl.port || 80,
    path: "/rpc",
    method: "POST",
    headers: {
      "content-type": "application/json",
      "content-length": payload.length,
      "x-genesis-agent-token": token
    }
  };
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let raw = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        raw += chunk;
      });
      res.on("end", () => {
        try {
          resolve({statusCode: res.statusCode || 500, body: JSON.parse(raw)});
        } catch (error) {
          reject(new Error(`invalid agent_control response: ${error.message}`));
        }
      });
    });
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

async function handleRpc(req, res) {
  try {
    const raw = await readBody(req);
    const body = raw.trim() ? JSON.parse(raw) : {};
    const response = await proxyRpc({
      id: body.id || `${Date.now()}`,
      method: body.method,
      params: body.params || {},
      timeoutMs: body.timeoutMs || 5000,
      dryRun: false
    });
    sendJson(res, response.statusCode, response.body);
  } catch (error) {
    sendJson(res, 502, {
      ok: false,
      error: {
        code: "dashboard_proxy_failed",
        message: error.message
      }
    });
  }
}

function serveStatic(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  const pathname = url.pathname === "/" ? "/index.html" : url.pathname;
  const filePath = path.normalize(path.join(publicDir, pathname));
  if (!filePath.startsWith(publicDir)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }
  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    res.writeHead(200, {
      "content-type": mimeTypes[path.extname(filePath)] || "application/octet-stream"
    });
    if (req.method === "HEAD") {
      res.end();
      return;
    }
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  if (req.method === "POST" && req.url === "/api/rpc") {
    handleRpc(req, res);
    return;
  }
  if (req.method === "GET" || req.method === "HEAD") {
    serveStatic(req, res);
    return;
  }
  sendJson(res, 405, {ok: false, error: {code: "method_not_allowed"}});
});

server.listen(port, "127.0.0.1", () => {
  console.log(
    `Location chat debug dashboard: http://127.0.0.1:${port}`
  );
  console.log(
    `Proxying agent_control at ${agentControlUrl.origin} with token ${token ? "set" : "missing"}`
  );
});
