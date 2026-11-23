# DBHub for Railway: Bytebase's official DBHub image (v2.1.0, pinned by digest)
# plus a small Caddy front. MCP clients send a generated bearer token; the
# browser workbench sits behind basic auth with a generated password; /healthz
# is open for Railway's health check.
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM bytebase/dbhub:2.1.0@sha256:71e33fd6967072b63095e61e8b2108ce0cf80314cf5312374413081f8b760f9d
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /usr/local/bin/start.sh
COPY wait-for-db.mjs /app/wait-for-db.mjs
RUN chmod 755 /usr/local/bin/start.sh /usr/local/bin/caddy \
 && caddy version \
 && WORKBENCH_PASSWORD_HASH="$(caddy hash-password --plaintext build-check-password)" \
    DBHUB_AUTH_TOKEN=build-check-token-0123456789 WORKBENCH_USERNAME=admin \
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile \
 && node -e "console.log('dbhub', require('/app/package.json').version)" \
 && mkdir -p /tmp/caddy-config /tmp/caddy-data && chown -R node:node /tmp/caddy-config /tmp/caddy-data
USER node
ENV PORT=8080 \
    DBHUB_INTERNAL_PORT=8081 \
    NODE_ENV=production \
    XDG_CONFIG_HOME=/tmp/caddy-config \
    XDG_DATA_HOME=/tmp/caddy-data \
    GOMAXPROCS=1 \
    GOMEMLIMIT=64MiB
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start.sh"]
