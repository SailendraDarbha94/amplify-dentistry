#!/usr/bin/env bash
# run_local.sh
# Validates the AmpDent migrations against a throwaway PostgreSQL cluster (no Docker, no Supabase project):
#   1. initdb a scratch cluster in a temp dir and start it on a private port
#   2. apply tests/local_supabase_stub.sql (auth/storage shims and Supabase default grants)
#   3. apply migrations/*.sql in order, then seed.sql
#   4. run tests/smoke.sql (RLS isolation, numbering, append-only guards, audit trail)
#      and tests/smoke_sync_whatsapp.sql (server-owned updated_at, devices, WhatsApp config/queue/webhook RPCs)
#   5. run the Deno tests of the Edge Functions when deno is on PATH (AMPDENT_SKIP_DENO=1 to skip)
# Requires PostgreSQL 15+ binaries (initdb, pg_ctl, psql) on PATH; Homebrew's postgresql@17 is added below.
# Environment: AMPDENT_PG_PORT (default 54329), AMPDENT_PG_SCRATCH (default mktemp -d), AMPDENT_KEEP=1 to keep the cluster.
# The server listens on TCP only (no Unix socket): long scratch paths exceed the 103-byte socket path limit on macOS.

set -euo pipefail

export PATH="/opt/homebrew/opt/postgresql@17/bin:/opt/homebrew/bin:$PATH"
# macOS: without a fixed locale the postmaster refuses to start ("became multithreaded during startup").
export LC_ALL=C
export LANG=C

SUPABASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${AMPDENT_PG_PORT:-54329}"
WORK="${AMPDENT_PG_SCRATCH:-$(mktemp -d)}"
DATA="$WORK/data"
DB="ampdent_scratch"
mkdir -p "$WORK"

cleanup() {
  if [[ -d "$DATA" ]]; then
    pg_ctl -D "$DATA" -m fast stop >/dev/null 2>&1 || true
  fi
  if [[ "${AMPDENT_KEEP:-0}" != "1" ]]; then
    rm -rf "$WORK"
  else
    echo "cluster kept at $DATA (port $PORT)"
  fi
}
trap cleanup EXIT

echo "initdb -> $DATA"
initdb -D "$DATA" -U postgres -A trust --no-locale -E UTF8 >"$WORK/initdb.log" 2>&1

pg_ctl -D "$DATA" -w -l "$WORK/postgres.log" \
  -o "-p $PORT -c unix_socket_directories= -c listen_addresses=127.0.0.1 -c fsync=off -c synchronous_commit=off" start >/dev/null

PSQL=(psql -v ON_ERROR_STOP=1 -X -q -h 127.0.0.1 -p "$PORT" -U postgres)

"${PSQL[@]}" -d postgres -c "create database $DB" >/dev/null

echo "stub      tests/local_supabase_stub.sql"
"${PSQL[@]}" -d "$DB" -f "$SUPABASE_DIR/tests/local_supabase_stub.sql"

for f in "$SUPABASE_DIR"/migrations/*.sql; do
  echo "migrate   $(basename "$f")"
  "${PSQL[@]}" -d "$DB" -f "$f"
done

echo "seed      seed.sql"
"${PSQL[@]}" -d "$DB" -f "$SUPABASE_DIR/seed.sql" >/dev/null

echo "smoke     tests/smoke.sql"
"${PSQL[@]}" -d "$DB" -f "$SUPABASE_DIR/tests/smoke.sql"

echo "smoke     tests/smoke_sync_whatsapp.sql"
"${PSQL[@]}" -d "$DB" -f "$SUPABASE_DIR/tests/smoke_sync_whatsapp.sql"

TABLES=$("${PSQL[@]}" -d "$DB" -At -c "select count(*) from pg_tables where schemaname = 'public'")
POLICIES=$("${PSQL[@]}" -d "$DB" -At -c "select count(*) from pg_policies where schemaname in ('public', 'storage')")
TRIGGERS=$("${PSQL[@]}" -d "$DB" -At -c "select count(*) from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and not t.tgisinternal")
echo "ok: $TABLES public tables, $POLICIES policies, $TRIGGERS triggers; migrations + smoke tests passed"

if [[ "${AMPDENT_SKIP_DENO:-0}" != "1" ]] && command -v deno >/dev/null 2>&1; then
  echo "deno      functions/**/*_test.ts"
  (cd "$SUPABASE_DIR/functions" && deno test --allow-read --quiet)
  echo "ok: edge function tests passed"
else
  echo "skip: deno not on PATH (brew install deno) or AMPDENT_SKIP_DENO=1; edge function tests not run"
fi
