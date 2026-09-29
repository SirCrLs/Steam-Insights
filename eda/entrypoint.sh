#!/bin/sh
set -e

RENVIRON=/usr/local/lib/R/etc/Renviron.site

sed -i -E '/^(POSTGRES_|DB_|DATABASE_URL)/d' "$RENVIRON" 2>/dev/null || true

printenv | grep -E '^(POSTGRES_|DB_|DATABASE_URL)' >> "$RENVIRON" || true

exec /usr/bin/shiny-server