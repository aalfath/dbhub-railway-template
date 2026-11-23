// Waits until the database in DSN accepts TCP connections (Railway's private
// DNS can take a minute to resolve on a first deploy). Exits 0 when reachable
// or when the DSN has no network host (SQLite), 1 after the timeout.
import net from "node:net";
const dsn = process.env.DSN || "";
const limit = Number(process.env.DB_WAIT_SECONDS || 120);
const defaults = { postgres: 5432, postgresql: 5432, mysql: 3306, mariadb: 3306, sqlserver: 1433, oracle: 1521, clickhouse: 8123 };
let host, port;
try {
  const u = new URL(dsn);
  const proto = u.protocol.replace(":", "");
  if (!(proto in defaults) || !u.hostname) process.exit(0);
  host = u.hostname.replace(/^\[|\]$/g, "");
  port = Number(u.port || defaults[proto]);
} catch { process.exit(0); }
const start = Date.now();
function attempt() {
  const s = net.connect({ host, port, timeout: 3000 });
  s.once("connect", () => { s.destroy(); console.error(`Database ${host}:${port} is reachable.`); process.exit(0); });
  const retry = () => {
    s.destroy();
    if ((Date.now() - start) / 1000 > limit) { console.error(`Database ${host}:${port} not reachable after ${limit}s.`); process.exit(1); }
    setTimeout(attempt, 2000);
  };
  s.once("error", retry); s.once("timeout", retry);
}
attempt();
