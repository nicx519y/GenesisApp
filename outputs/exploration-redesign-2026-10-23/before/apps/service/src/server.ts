import { buildApp } from "./app.js";

const app = await buildApp();
const port = Number.parseInt(process.env.GENESIS_QA_PORT ?? "4317", 10);

await app.listen({ host: "127.0.0.1", port });

const shutdown = async () => {
  await app.close();
  process.exit(0);
};
process.once("SIGINT", () => void shutdown());
process.once("SIGTERM", () => void shutdown());
