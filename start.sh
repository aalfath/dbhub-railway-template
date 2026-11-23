#!/bin/sh
# Starts DBHub (streamable HTTP, loopback only, bearer token required) and Caddy
# in front of it on Railway's PORT. If either process stops, the container exits
# non-zero so Railway's restart policy brings it back.
set -eu

: "${PORT:=8080}"
: "${DBHUB_INTERNAL_PORT:=8081}"
: "${WORKBENCH_USERNAME:=admin}"
: "${DBHUB_READONLY:=true}"
: "${DBHUB_MAX_ROWS:=1000}"
: "${DBHUB_QUERY_TIMEOUT:=30}"
export PORT DBHUB_INTERNAL_PORT WORKBENCH_USERNAME

fail() { echo "$*" >&2; exit 1; }

[ -n "${DSN:-}" ] || fail "DSN is empty: set it to the connection string of the database DBHub should serve (the template points it at the bundled Postgres)."
[ -n "${DBHUB_AUTH_TOKEN:-}" ] && [ "${#DBHUB_AUTH_TOKEN}" -ge 24 ] || fail "DBHUB_AUTH_TOKEN must be set (at least 24 characters); the template generates one."
case "$DBHUB_AUTH_TOKEN" in *[!A-Za-z0-9_-]*) fail "DBHUB_AUTH_TOKEN may only use letters, digits, '-' and '_'." ;; esac
[ -n "${WORKBENCH_PASSWORD:-}" ] && [ "${#WORKBENCH_PASSWORD}" -ge 12 ] || fail "WORKBENCH_PASSWORD must be set (at least 12 characters); the template generates one."
case "$DBHUB_READONLY" in true|false) ;; *) fail "DBHUB_READONLY must be true or false." ;; esac
case "$DBHUB_MAX_ROWS" in ''|*[!0-9]*) fail "DBHUB_MAX_ROWS must be a whole number." ;; esac
case "$DBHUB_QUERY_TIMEOUT" in ''|*[!0-9]*) fail "DBHUB_QUERY_TIMEOUT must be a whole number of seconds." ;; esac

# DBHub's own READONLY/MAX_ROWS variables were removed upstream and make it exit.
unset READONLY MAX_ROWS

# One source "main" from DSN; execute_sql is read-only unless DBHUB_READONLY=false.
CONF=/tmp/dbhub.toml
case "$DSN" in sqlite:*) TIMEOUTS="" ;; *) TIMEOUTS="connection_timeout = 30
query_timeout = $DBHUB_QUERY_TIMEOUT" ;; esac
cat > "$CONF" <<TOML
[[sources]]
id = "main"
description = "Database configured by the DSN variable"
dsn = "\${DSN}"
$TIMEOUTS

[[tools]]
name = "execute_sql"
source = "main"
readonly = $DBHUB_READONLY
max_rows = $DBHUB_MAX_ROWS

[[tools]]
name = "search_objects"
source = "main"
TOML

WORKBENCH_PASSWORD_HASH="$(printf '%s' "$WORKBENCH_PASSWORD" | caddy hash-password)"
export WORKBENCH_PASSWORD_HASH

# Cap Node's heap to the service's memory limit (Railway Free plan: 0.5 GB).
if [ -z "${NODE_OPTIONS:-}" ]; then
  limit=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
  heap=256
  if [ "$limit" != "max" ]; then
    heap=$(( limit / 1048576 * 3 / 5 ))
    [ "$heap" -gt 1024 ] && heap=1024
    [ "$heap" -lt 128 ] && heap=128
  fi
  export NODE_OPTIONS="--max-old-space-size=$heap"
fi
export UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-2}"

cd /app
node /app/wait-for-db.mjs || fail "Exiting so Railway retries; check DSN."

echo "DBHub: read-only=$DBHUB_READONLY, max rows=$DBHUB_MAX_ROWS, MCP endpoint /mcp (bearer token), workbench / (user $WORKBENCH_USERNAME)." >&2
env -u PORT DBHUB_HOST=127.0.0.1 DBHUB_AUTH_TOKEN="$DBHUB_AUTH_TOKEN" \
  node dist/index.js --transport http --host 127.0.0.1 --port "$DBHUB_INTERNAL_PORT" --config "$CONF" &
APP_PID=$!
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!

trap 'kill "$APP_PID" "$CADDY_PID" 2>/dev/null; exit 0' TERM INT

# BusyBox `wait -n` does not return on the first child exit, so poll.
while kill -0 "$APP_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do
  sleep 2
done
echo "A process stopped unexpectedly; exiting so Railway restarts the service." >&2
kill "$APP_PID" "$CADDY_PID" 2>/dev/null || true
exit 1
