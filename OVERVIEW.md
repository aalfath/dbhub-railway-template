# Deploy and Host DBHub on Railway

DBHub is Bytebase's open-source MCP server for databases. It lets AI assistants such as Claude, Cursor, VS Code and Codex explore schemas and run SQL against PostgreSQL, MySQL, MariaDB, SQL Server, SQLite, Oracle and ClickHouse, with only two compact tools, plus a web workbench to run the same tools by hand.

## About Hosting DBHub

This template runs DBHub 2.1.0 (official `bytebase/dbhub` image, pinned by digest) in streamable-HTTP mode, plus a Railway Postgres as a working example database. DBHub listens only inside the container. A small Caddy front on the public domain asks MCP clients for a generated bearer token and asks browsers for a generated workbench password, so nothing is open on the first deploy. Queries are read-only by default (DBHub parses each statement and also runs it in a read-only transaction), limited to 1,000 rows and 30 seconds. To serve your own database, change one variable, `DSN`. DBHub keeps no state of its own, so there is no volume to back up.

## Common Use Cases

* Let Claude, Cursor or another MCP client answer questions about your production data, read-only
* Give an AI coding agent the real schema of your database while it writes queries and migrations
* Run ad-hoc SQL against a private Railway database from a browser, without exposing the database itself

## Dependencies for DBHub Hosting

* DBHub: one service built from `aalfath/dbhub-railway-template` (DBHub plus a Caddy auth front)
* Postgres: Railway's PostgreSQL 18 with a volume, the example database DBHub points at first

### Deployment Dependencies

* DBHub source and docs: https://github.com/bytebase/dbhub and https://dbhub.ai
* Release used: https://github.com/bytebase/dbhub/releases/tag/v2.1.0
* Template repository: https://github.com/aalfath/dbhub-railway-template

### Implementation Details

After the deploy, open the DBHub service's **Variables** tab and copy `DBHUB_AUTH_TOKEN` (for MCP clients) and `WORKBENCH_PASSWORD` (user `admin`, for the browser workbench at the public URL). Then add the server to your MCP client, for example Claude Code:

```bash
claude mcp add --transport http dbhub https://YOUR-DOMAIN/mcp --header "Authorization: Bearer YOUR-DBHUB_AUTH_TOKEN"
```

or any client that takes JSON (Cursor, VS Code, Claude Desktop through `mcp-remote`):

```json
{ "mcpServers": { "dbhub": { "url": "https://YOUR-DOMAIN/mcp", "headers": { "Authorization": "Bearer YOUR-DBHUB_AUTH_TOKEN" } } } }
```

**Your own database:** set `DSN` to its connection string (for another Railway service, a reference such as `${{MySQL.MYSQL_URL}}` keeps it on the private network) and redeploy. Use a database user that can only read what the AI should see: read-only mode is a guardrail, not a permission boundary. Set `DBHUB_READONLY=false` only if you want the AI to write. You can then delete the example Postgres.

**Updates:** the service builds from the template's GitHub repo. When we move it to a new DBHub release, Railway shows an update notice in your project; read the repo's `CHANGELOG.md` and apply it when it suits you. Health check: `/healthz`. DBHub uses about 80 MB of RAM, so it runs on Railway's Free plan.

## Why Deploy DBHub on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying DBHub on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
