#!/usr/bin/env bash
# Repro: after DELETE returns 202, POST with the same name returns 409 ALREADY_EXISTS
# for ~2 s, while GET on that name returns 404 NOT_FOUND.
#
# Needs: curl, jq, CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN (Artifacts edit).
# Usage: ./recreate-after-delete.sh [trials=5]
set -euo pipefail

: "${CLOUDFLARE_ACCOUNT_ID:?}" "${CLOUDFLARE_API_TOKEN:?}"
NS=${ARTIFACTS_NAMESPACE:-artifacts-repro}
BASE="https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/artifacts/namespaces/$NS"
api() { curl -s -w '\n%{http_code}' -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H 'Content-Type: application/json' "$@"; }
code() { tail -n1 <<<"$1"; }
body() { sed '$d' <<<"$1" | jq -c '.errors // [] | map({code, message})'; }
now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }

for i in $(seq 1 "${1:-5}"); do
  name="recreate-$(date +%s)-$i"
  r=$(api -X POST "$BASE/repos" -d "{\"name\":\"$name\"}")
  [ "$(code "$r")" = 201 ] || { echo "setup create failed: $r"; exit 1; }

  r=$(api -X DELETE "$BASE/repos/$name"); del=$(code "$r")
  t0=$(now_ms)
  r=$(api -X POST "$BASE/repos" -d "{\"name\":\"$name\"}"); first=$(code "$r"); first_err=$(body "$r")
  g=$(api "$BASE/repos/$name"); get=$(code "$g")

  # Retry create every 200 ms until it succeeds, to measure how long the name stays taken.
  attempts=1; c=$first
  while [ "$c" != 201 ] && [ "$attempts" -lt 100 ]; do
    sleep 0.2; attempts=$((attempts + 1))
    c=$(code "$(api -X POST "$BASE/repos" -d "{\"name\":\"$name\"}")")
  done
  freed=$(( $(now_ms) - t0 ))

  echo "trial $i: DELETE=$del  immediate POST=$first $first_err  GET=$get  create succeeded after ${freed} ms ($attempts attempts)"
  api -X DELETE "$BASE/repos/$name" >/dev/null
done
