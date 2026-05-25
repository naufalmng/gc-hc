# Individual probe routines — one per remote-side concern. Each one is its own
# function so we can selectively skip them via --no-* flags or env toggles.

check_dns() {
  local name="${1:?missing name}"
  local url="${2:?missing url}"
  local host=""
  local ip=""

  if ! host="$(host_from_url "$url")"; then
    record "${name}.dns" "fail" "bad_host" "$url" ""
    return 1
  fi

  if ! ip="$(getent ahosts "$host" | awk 'NR == 1 { print $1 }')"; then
    record "${name}.dns" "fail" "lookup_failed" "$host" ""
    return 1
  fi

  ip="$(trim "$ip")"

  if [[ -z "$ip" ]]; then
    record "${name}.dns" "fail" "empty_dns" "$host" ""
    return 1
  fi

  record "${name}.dns" "pass" "resolved" "$host" "$ip"
}

# TLS handshake check — captures `Verify return code:` from openssl s_client
# so we know we got a real cert chain back, not just "TCP open".
check_tls() {
  local name="${1:?missing name}"
  local url="${2:?missing url}"
  local host=""
  local port=""
  local result=""

  if ! command -v openssl >/dev/null 2>&1; then
    record "${name}.tls" "skip" "openssl_missing" "$url" ""
    return 0
  fi

  if ! command -v timeout >/dev/null 2>&1; then
    record "${name}.tls" "skip" "timeout_missing" "$url" ""
    return 0
  fi

  if ! host="$(host_from_url "$url")"; then
    record "${name}.tls" "fail" "bad_host" "$url" ""
    return 1
  fi

  port="$(port_from_url "$url")"

  if result="$(printf '' | timeout "$GC_HC_TIMEOUT" openssl s_client -servername "$host" -connect "${host}:${port}" -verify_return_error 2>/dev/null | awk '/Verify return code:/ { print; found=1 } END { if (!found) exit 2 }')"; then
    record "${name}.tls" "pass" "handshake_ok" "${host}:${port}" "$(trim "$result")"
    return 0
  fi

  record "${name}.tls" "fail" "handshake_failed" "${host}:${port}" ""
}

# Prometheus remote_write probe. We POST an empty body — Mimir/Cortex respond
# with 400 ("empty payload") for valid auth, which is genuinely the cheapest
# way to verify auth + reachability without sending real metrics.
check_prom_push() {
  local code=""

  if ! code="$(http_code "$GCLOUD_HOSTED_METRICS_URL" "$GCLOUD_HOSTED_METRICS_ID" "$GCLOUD_RW_API_KEY" "POST" "" "application/x-protobuf")"; then
    record "prom.push" "fail" "$code" "$GCLOUD_HOSTED_METRICS_URL" ""
    return 1
  fi

  case "$code" in
    200|202|204|400)
      record "prom.push" "pass" "reachable_http_${code}" "$GCLOUD_HOSTED_METRICS_URL" "400 can be normal for empty protobuf"
      ;;
    401|403)
      record "prom.push" "fail" "auth_http_${code}" "$GCLOUD_HOSTED_METRICS_URL" ""
      return 1
      ;;
    *)
      record "prom.push" "warn" "http_${code}" "$GCLOUD_HOSTED_METRICS_URL" ""
      ;;
  esac
}

check_prom_query() {
  local url=""
  local code=""

  if [[ "$GC_HC_PROM_QUERY" != "true" ]]; then
    record "prom.query" "skip" "disabled" "" ""
    return 0
  fi

  url="$(prom_query_url "$GCLOUD_HOSTED_METRICS_URL")"

  if ! code="$(http_code "$url" "$GCLOUD_HOSTED_METRICS_ID" "$GCLOUD_RW_API_KEY" "GET" "" "")"; then
    record "prom.query" "fail" "$code" "$url" ""
    return 1
  fi

  case "$code" in
    200) record "prom.query" "pass" "http_200" "$url" "" ;;
    401|403)
      record "prom.query" "fail" "auth_http_${code}" "$url" ""
      return 1
      ;;
    404|405) record "prom.query" "warn" "reachable_http_${code}" "$url" "" ;;
    *)       record "prom.query" "warn" "http_${code}" "$url" "" ;;
  esac
}

# Hand-roll a minimal Loki push payload. No jq dependency — we already have
# json_escape for safe interpolation.
loki_payload() {
  local ts=""
  local host=""
  local msg=""

  ts="$(date +%s%N)"
  host="$(hostname -f 2>/dev/null || hostname)"
  msg="gc-hc ${host} $(date -u +%Y-%m-%dT%H:%M:%SZ)"

  printf '{"streams":[{"stream":{"job":"gc-hc","host":"%s"},"values":[["%s","%s"]]}]}' \
    "$(json_escape "$host")" \
    "$ts" \
    "$(json_escape "$msg")"
}

check_loki() {
  local code=""
  local payload=""

  if [[ "$GC_HC_LOKI_WRITE" != "true" ]]; then
    record "loki.write" "skip" "disabled" "$GCLOUD_HOSTED_LOGS_URL" ""
    return 0
  fi

  payload="$(loki_payload)"

  if ! code="$(http_code "$GCLOUD_HOSTED_LOGS_URL" "$GCLOUD_HOSTED_LOGS_ID" "$GCLOUD_RW_API_KEY" "POST" "$payload" "application/json")"; then
    record "loki.write" "fail" "$code" "$GCLOUD_HOSTED_LOGS_URL" ""
    return 1
  fi

  case "$code" in
    200|202|204)
      record "loki.write" "pass" "accepted_http_${code}" "$GCLOUD_HOSTED_LOGS_URL" ""
      ;;
    401|403)
      record "loki.write" "fail" "auth_http_${code}" "$GCLOUD_HOSTED_LOGS_URL" ""
      return 1
      ;;
    400)
      record "loki.write" "fail" "bad_payload_http_400" "$GCLOUD_HOSTED_LOGS_URL" ""
      return 1
      ;;
    *)
      record "loki.write" "warn" "http_${code}" "$GCLOUD_HOSTED_LOGS_URL" ""
      ;;
  esac
}

# Fleet Management is optional, so empty/disabled states are skip-not-fail.
# Most reachable HTTP codes are accepted because the public FM endpoints often
# answer with 401/404 to anonymous probes — both prove the host is alive.
check_fleet() {
  local code=""

  if [[ "$GC_HC_FLEET" != "true" ]]; then
    record "fleet" "skip" "disabled" "${GCLOUD_FM_URL:-}" ""
    return 0
  fi

  if [[ -z "${GCLOUD_FM_URL:-}" ]]; then
    record "fleet" "skip" "empty" "" ""
    return 0
  fi

  if ! code="$(http_code "$GCLOUD_FM_URL" "" "" "GET" "" "")"; then
    record "fleet" "fail" "$code" "$GCLOUD_FM_URL" ""
    return 1
  fi

  case "$code" in
    200|204|301|302|307|308|401|403|404)
      record "fleet" "pass" "reachable_http_${code}" "$GCLOUD_FM_URL" ""
      ;;
    *)
      record "fleet" "warn" "http_${code}" "$GCLOUD_FM_URL" ""
      ;;
  esac
}
