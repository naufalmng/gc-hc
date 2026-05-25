#!/usr/bin/env bash
# tests/smoke.sh — smoke tests for pure functions.
# Sources individual modules and exercises them in isolation.
# This is the "is the build basically sane" test; bats holds the formal suite.

set -e

ROOT="$(cd -- "$(dirname -- "$0")/.." >/dev/null && pwd -P)"
cd "$ROOT"

# Sourcing modules requires their dependencies; provide minimal stubs.
die()  { printf 'DIE: %s\n'  "$1" >&2; return 1; }
warn() { printf 'WARN: %s\n' "$1" >&2; }

# shellcheck disable=SC1091
source src/tool/04-utils.sh

# 04-utils.sh re-defines die/warn — restore stubs.
die()  { printf 'DIE: %s\n'  "$1" >&2; return 1; }
warn() { printf 'WARN: %s\n' "$1" >&2; }

# shellcheck disable=SC1091
source src/tool/07-validate.sh
# shellcheck disable=SC1091
source src/tool/09-url.sh

PASS=0
FAIL=0
assert_eq() {
  local exp="$1" got="$2" name="$3"
  if [[ "$exp" == "$got" ]]; then
    printf '  ok    %s\n' "$name"
    PASS=$((PASS+1))
  else
    printf '  FAIL  %s\n        want: %q\n        got : %q\n' "$name" "$exp" "$got"
    FAIL=$((FAIL+1))
  fi
}

echo "host_from_url:"
assert_eq "prometheus-prod-01-eu-west-0.grafana.net" "$(host_from_url https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push)" "Grafana prom URL"
assert_eq "logs-prod-008.grafana.net" "$(host_from_url https://logs-prod-008.grafana.net:443/loki/api/v1/push)" "URL with explicit port"
assert_eq "example.com" "$(host_from_url https://example.com)" "bare host"

echo "port_from_url:"
assert_eq "443"  "$(port_from_url https://example.com)"            "default 443"
assert_eq "8443" "$(port_from_url https://example.com:8443/path)"  "explicit 8443"

echo "prom_query_url:"
assert_eq "https://prom.example.com/api/prom/api/v1/status/buildinfo" \
          "$(prom_query_url https://prom.example.com/api/prom/push)"  "rewrite push -> buildinfo"
assert_eq "https://example.com/foo" "$(prom_query_url https://example.com/foo/)" "trim trailing slash"

echo "calendar_from_interval:"
assert_eq "*:0/5:00"        "$(calendar_from_interval 5m)"  "5m"
assert_eq "*:0/15:00"       "$(calendar_from_interval 15m)" "15m"
assert_eq "*-*-* 0/1:00:00" "$(calendar_from_interval 1h)"  "1h"
assert_eq "*:*:0/30"        "$(calendar_from_interval 30s)" "30s"

echo "valid_url:"
valid_url   "TEST" "https://ok.example.com/path" 2>/dev/null && { echo "  ok    accepts https";  PASS=$((PASS+1)); } || { echo "  FAIL  accepts https"; FAIL=$((FAIL+1)); }
! valid_url "TEST" "http://insecure.com"         2>/dev/null && { echo "  ok    rejects http";   PASS=$((PASS+1)); } || { echo "  FAIL  rejects http"; FAIL=$((FAIL+1)); }
! valid_url "TEST" ""                            2>/dev/null && { echo "  ok    rejects empty";  PASS=$((PASS+1)); } || { echo "  FAIL  rejects empty"; FAIL=$((FAIL+1)); }
! valid_url "TEST" "https://has spaces.com"      2>/dev/null && { echo "  ok    rejects ws";     PASS=$((PASS+1)); } || { echo "  FAIL  rejects ws"; FAIL=$((FAIL+1)); }

echo "valid_id:"
valid_id   "TEST" "12345" 2>/dev/null && { echo "  ok    accepts numeric";  PASS=$((PASS+1)); } || { echo "  FAIL"; FAIL=$((FAIL+1)); }
! valid_id "TEST" "abc"   2>/dev/null && { echo "  ok    rejects letters";  PASS=$((PASS+1)); } || { echo "  FAIL"; FAIL=$((FAIL+1)); }

echo "valid_key:"
valid_key   "glc_eyJvIjoiMTIzNDU2In0=" 2>/dev/null && { echo "  ok    accepts glc_";  PASS=$((PASS+1)); } || { echo "  FAIL"; FAIL=$((FAIL+1)); }
! valid_key "wrong_prefix"             2>/dev/null && { echo "  ok    rejects other"; PASS=$((PASS+1)); } || { echo "  FAIL"; FAIL=$((FAIL+1)); }

echo "json_escape:"
assert_eq 'hello \"world\"'   "$(json_escape 'hello "world"')"               "double quotes"
assert_eq 'back\\slash'       "$(json_escape 'back\slash')"                   "backslash"
assert_eq 'line1\nline2'      "$(json_escape "$(printf 'line1\nline2')")"     "newline"

echo "trim:"
assert_eq "abc" "$(trim "  abc  ")"            "spaces"
assert_eq "abc" "$(trim "$(printf 'abc\r')")"  "carriage return"

echo "mask:"
assert_eq "<empty>"          "$(mask "")"                          "empty"
assert_eq "********"         "$(mask "short")"                     "short"
assert_eq "glc_eyJvLongerSecretwxyz" "glc_eyJvLongerSecretwxyz"   "(self check)"
got_mask="$(mask 'glc_eyJvLongerSecretwxyz')"
assert_eq "glc_ey...wxyz"    "$got_mask"                           "long value 6+...+4"

echo
echo "Total: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
