#!/usr/bin/env bash
# tests/smoke.sh — smoke tests for pure functions.
# Sources individual modules and exercises them in isolation.
# This is the "is the build basically sane" test; bats holds the formal suite.

set -e

ROOT="$(cd -- "$(dirname -- "$0")/.." >/dev/null && pwd -P)"
cd "$ROOT"

# 04-utils.sh defines die/warn — we override them after sourcing so failures
# return rather than exit, keeping the test runner alive across assertions.

# shellcheck disable=SC1091
source src/tool/04-utils.sh
# shellcheck disable=SC1091
source src/tool/07-validate.sh
# shellcheck disable=SC1091
source src/tool/09-url.sh
# shellcheck disable=SC1091
source src/tool/15-trace.sh

die()  { printf 'die: %s\n'  "$1" >&2; return 1; }
warn() { printf 'warn: %s\n' "$1" >&2; }
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

# Run a command; assert it exits zero.
assert_ok() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then
    printf '  ok    %s\n' "$name"
    PASS=$((PASS+1))
  else
    printf '  FAIL  %s\n' "$name"
    FAIL=$((FAIL+1))
  fi
}

# Run a command; assert it exits non-zero.
assert_fail() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then
    printf '  FAIL  %s (expected failure)\n' "$name"
    FAIL=$((FAIL+1))
  else
    printf '  ok    %s\n' "$name"
    PASS=$((PASS+1))
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
assert_ok   "accepts https"        valid_url "TEST" "https://ok.example.com/path"
assert_fail "rejects http"         valid_url "TEST" "http://insecure.com"
assert_fail "rejects empty"        valid_url "TEST" ""
assert_fail "rejects whitespace"   valid_url "TEST" "https://has spaces.com"

echo "valid_id:"
assert_ok   "accepts numeric"      valid_id "TEST" "12345"
assert_fail "rejects letters"      valid_id "TEST" "abc"

echo "valid_key:"
assert_ok   "accepts glc_ prefix"  valid_key "glc_eyJvIjoiMTIzNDU2In0="
assert_fail "rejects bad prefix"   valid_key "wrong_prefix"

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
assert_eq "glc_eyJvLo...wxyz" "glc_eyJvLo...wxyz"   "(self check)"
got_mask="$(mask 'glc_eyJvLo...wxyz')"
assert_eq "glc_ey...wxyz"    "$got_mask"                           "long value 6+...+4"

echo "trace_summarize:"
# tracepath sample — first hop is local gateway, last is destination
tp_sample="$(printf '%s\n' \
  ' 1?: [LOCALHOST]                                         pmtu 1500' \
  ' 1:  192.168.1.1                                         0.503ms' \
  ' 2:  10.0.0.1                                            5.123ms' \
  ' 3:  isp.example.net                                    12.456ms')"
assert_eq "hops=3 last=isp.example.net rtt=12.456ms" \
          "$(trace_summarize "$tp_sample")"            "tracepath multi-hop"

# traceroute sample — single line per hop
tr_sample="$(printf '%s\n' \
  'traceroute to dst.example.com (1.2.3.4), 15 hops max' \
  ' 1  192.168.1.1  0.503 ms' \
  ' 2  isp.example.net  5.0 ms')"
assert_eq "hops=2 last=isp.example.net rtt=5.0ms" \
          "$(trace_summarize "$tr_sample")"            "traceroute multi-hop"

# All-timeout output (every hop a star)
star_sample="$(printf '%s\n' \
  ' 1  * * *' \
  ' 2  * * *')"
got_star="$(trace_summarize "$star_sample")"
assert_eq "hops=2 last=* rtt=timeout"  "$got_star"     "all timeouts"

# Empty input
assert_eq "hops=0"            "$(trace_summarize "")"  "empty input"

# Single hop
single_sample=" 1:  gw.local  0.5ms"
assert_eq "hops=1 last=gw.local rtt=0.5ms" \
          "$(trace_summarize "$single_sample")"        "single hop"

echo "trace_state path helpers:"
STATE_DIR="/tmp/.gc-hc-test-state"
LOG_DIR="/tmp/.gc-hc-test-log"
rm -rf "$STATE_DIR" "$LOG_DIR"
assert_eq "/tmp/.gc-hc-test-state/trace/prom.dns.last" \
          "$(trace_state_path "prom.dns")"             "state path format"
assert_eq "/tmp/.gc-hc-test-log/trace/prom.dns.log" \
          "$(trace_log_path "prom.dns")"               "log path format"

echo "trace_state_set/get round-trip:"
trace_state_set "prom.dns" "fail"
assert_eq "fail" "$(trace_state_get "prom.dns")" "round-trip fail"
trace_state_set "prom.dns" "pass"
assert_eq "pass" "$(trace_state_get "prom.dns")" "round-trip pass"
assert_eq ""     "$(trace_state_get "nonexistent")" "missing probe → empty"
rm -rf "$STATE_DIR" "$LOG_DIR"

echo "log_tail_rotate:"
LOG_TMP="$(mktemp)"
trap 'rm -f "$LOG_TMP" "$LOG_TMP.rot"' EXIT

# JSONL marker (^): one block per line. Keep last 3 of 5.
printf '%s\n' '{"n":1}' '{"n":2}' '{"n":3}' '{"n":4}' '{"n":5}' > "$LOG_TMP"
log_tail_rotate "$LOG_TMP" 3 '^'
assert_eq '{"n":3}
{"n":4}
{"n":5}' "$(cat "$LOG_TMP")" "JSONL keep last 3 of 5"

# Multi-line block marker (^=== ): keep last 2 of 4 trace-style entries.
printf '%s\n' \
  '=== 2026-01-01 ===' '1: a 1ms' '2: b 2ms' \
  '=== 2026-01-02 ===' '1: c 3ms' \
  '=== 2026-01-03 ===' '1: d 4ms' \
  '=== 2026-01-04 ===' '1: e 5ms' '2: f 6ms' > "$LOG_TMP"
log_tail_rotate "$LOG_TMP" 2 '^=== '
assert_eq 5 "$(grep -c '^=== \|^[0-9]:' "$LOG_TMP")" "trace blocks: 2 markers + 3 hop lines"
assert_eq "1" "$(grep -c '2026-01-03' "$LOG_TMP")" "trace keep: third block present"
assert_eq "0" "$(grep -c '2026-01-01' "$LOG_TMP")" "trace drop: first block gone"

# keep=0 disables rotation (file untouched).
printf '%s\n' '{"n":1}' '{"n":2}' '{"n":3}' > "$LOG_TMP"
log_tail_rotate "$LOG_TMP" 0 '^'
assert_eq 3 "$(wc -l < "$LOG_TMP" | tr -d ' ')" "keep=0 leaves file untouched"

# Missing file is a no-op (no error, no creation).
rm -f "$LOG_TMP"
log_tail_rotate "$LOG_TMP" 5 '^'
assert_eq "1" "$([[ ! -e "$LOG_TMP" ]] && echo 1 || echo 0)" "missing file → no-op"

echo
echo "Total: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
