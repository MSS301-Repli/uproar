#!/usr/bin/env bash
# End-to-end smoke test through the API Gateway. Run after `docker compose up -d --build`.
# Used by CI (.github/workflows/ci.yml) and locally:  bash scripts/smoke-test.sh
# Each owner adds a few checks for their own service at the end.
set -uo pipefail

GATEWAY="${GATEWAY:-http://localhost:8080}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@socialapp.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin@123}"
JSON='Content-Type: application/json'
FAILED=0

# expect <name> <expected-status> <curl args...>
expect() {
  local name="$1" want="$2"; shift 2
  local got
  got=$(curl -s -o /tmp/smoke-body -w '%{http_code}' "$@")
  if [ "$got" = "$want" ]; then
    echo "PASS  $name ($got)"
  else
    echo "FAIL  $name: expected $want, got $got -> $(head -c 300 /tmp/smoke-body)"
    FAILED=1
  fi
}

field() { grep -o "\"$1\":\"[^\"]*" | cut -d'"' -f4; }

# The gateway needs ~30 s after start-up to see services in Eureka: wait for a working login
echo "Waiting for $GATEWAY ..."
for _ in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$GATEWAY/api/auth/login" -H "$JSON" \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")
  [ "$code" = "200" ] && break
  sleep 5
done
[ "$code" = "200" ] || { echo "Gateway/identity-service not ready (last status $code)"; exit 1; }

ADMIN_TOKEN=$(curl -s -X POST "$GATEWAY/api/auth/login" -H "$JSON" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | field accessToken)

# ---------- identity-service ----------
USER_EMAIL="smoke$(date +%s)@test.com"
USER_NAME="smoke$(date +%s)"
expect "register user" 201 -X POST "$GATEWAY/api/auth/register" -H "$JSON" \
  -d "{\"email\":\"$USER_EMAIL\",\"username\":\"$USER_NAME\",\"password\":\"password1\"}"
expect "duplicate email -> 409" 409 -X POST "$GATEWAY/api/auth/register" -H "$JSON" \
  -d "{\"email\":\"$USER_EMAIL\",\"username\":\"other$USER_NAME\",\"password\":\"password1\"}"
expect "invalid body -> 400" 400 -X POST "$GATEWAY/api/auth/register" -H "$JSON" \
  -d '{"email":"bad","username":"a","password":"1"}'
expect "wrong password -> 401" 401 -X POST "$GATEWAY/api/auth/login" -H "$JSON" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"wrong-password\"}"

LOGIN=$(curl -s -X POST "$GATEWAY/api/auth/login" -H "$JSON" -d "{\"email\":\"$USER_EMAIL\",\"password\":\"password1\"}")
USER_TOKEN=$(echo "$LOGIN" | field accessToken)
REFRESH=$(echo "$LOGIN" | field refreshToken)

expect "me with token" 200 "$GATEWAY/api/auth/me" -H "Authorization: Bearer $USER_TOKEN"
expect "me without token -> 401" 401 "$GATEWAY/api/auth/me"
expect "spoofed X-User-Id -> 401" 401 "$GATEWAY/api/auth/me" -H "X-User-Id: 1"
expect "USER on admin API -> 403" 403 "$GATEWAY/api/admin/users" -H "Authorization: Bearer $USER_TOKEN"
expect "ADMIN on admin API" 200 "$GATEWAY/api/admin/users?search=smoke" -H "Authorization: Bearer $ADMIN_TOKEN"
expect "refresh token" 200 -X POST "$GATEWAY/api/auth/refresh" -H "$JSON" -d "{\"refreshToken\":\"$REFRESH\"}"
expect "reuse old refresh token -> 401" 401 -X POST "$GATEWAY/api/auth/refresh" -H "$JSON" \
  -d "{\"refreshToken\":\"$REFRESH\"}"

# ---------- other services: owners add checks below ----------

echo
if [ "$FAILED" = 0 ]; then echo "SMOKE TEST PASSED"; else echo "SMOKE TEST FAILED"; fi
exit "$FAILED"
