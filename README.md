[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/dbhub-1?utm_medium=integration&utm_source=button&utm_campaign=dbhub)

# DBHub on Railway

One-click Railway template for [DBHub](https://github.com/bytebase/dbhub) **2.1.0**, Bytebase's MIT-licensed MCP server for PostgreSQL, MySQL, MariaDB, SQL Server, SQLite, Oracle and ClickHouse, in streamable-HTTP mode with its web workbench.

## What it deploys

| Service | What it does |
|---|---|
| **DBHub** | Built from this repo: the official `bytebase/dbhub:2.1.0` image (pinned by digest) listening on `127.0.0.1`, plus a Caddy front on `$PORT`. MCP clients need `Authorization: Bearer DBHUB_AUTH_TOKEN`; browsers get basic auth (`admin` / `WORKBENCH_PASSWORD`) for the workbench. `/healthz` is open for Railway's health check. |
| **Postgres** | Railway's PostgreSQL 18 on a volume: the example database DBHub serves until you point `DSN` at your own. |

Queries are **read-only by default** (statement parser plus a read-only transaction), with at most 1,000 rows and a 30 s timeout per query. DBHub keeps no state of its own, so it has no volume. It uses about 80 MB of RAM and fits Railway's Free plan (0.5 GB).

## Variables (DBHub service)

| Variable | Default | Meaning |
|---|---|---|
| `DSN` | `${{Postgres.DATABASE_URL}}` | Connection string of the database DBHub serves (`postgres://`, `mysql://`, `mariadb://`, `sqlserver://`, `sqlite:///`, `oracle://`, `clickhouse://`). |
| `DBHUB_AUTH_TOKEN` | generated | Bearer token MCP clients send. |
| `WORKBENCH_USERNAME` | `admin` | Workbench login name. |
| `WORKBENCH_PASSWORD` | generated | Workbench login password. |
| `DBHUB_READONLY` | `true` | `false` lets `execute_sql` write. |
| `PORT` | `8080` | Public port (Caddy). |

Optional, not in the template: `DBHUB_MAX_ROWS` (default 1000) and `DBHUB_QUERY_TIMEOUT` (seconds, default 30).

## Connect a client

```bash
claude mcp add --transport http dbhub https://YOUR-DOMAIN/mcp --header "Authorization: Bearer YOUR-DBHUB_AUTH_TOKEN"
```

```json
{ "mcpServers": { "dbhub": { "url": "https://YOUR-DOMAIN/mcp", "headers": { "Authorization": "Bearer YOUR-DBHUB_AUTH_TOKEN" } } } }
```

Use a least-privilege, read-only database user for real data: DBHub's read-only mode is a guardrail, not a permission boundary ([upstream docs](https://dbhub.ai/config/read-only-mode)).

## Updates

The service builds from this repo's `main` branch. When we bump DBHub here, Railway shows deployers an "update available" notice; each version is described in [`CHANGELOG.md`](CHANGELOG.md), breaking changes first.

## Licence

This wrapper is MIT. DBHub is MIT, © Bytebase.
