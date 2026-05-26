# Healthcheck orchestrator. Runs every enabled probe, aggregates results into
# one JSON document, persists it, and exits with a code that reflects the
# overall verdict so systemd/cron alerting can trigger on it.

run_check() {
  local started=""
  local finished=""
  local host=""
  local overall="pass"
  local joined=""
  local item=""
  local result=""

  LAST_STEP="healthcheck"
  need_cmd curl awk sed grep date hostname getent

  if ! load_config; then
    die "config missing, run: gc-hc config"
    return 1
  fi

  validate_config
  valid_timeout "$GC_HC_TIMEOUT"

  CHECKS=()
  PASS=0
  WARN=0
  FAIL=0
  SKIP=0

  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  host="$(hostname -f 2>/dev/null || hostname)"

  if [[ "$GC_HC_DNS" == "true" ]]; then
    check_dns "prom" "$GCLOUD_HOSTED_METRICS_URL" || true
    check_dns "loki" "$GCLOUD_HOSTED_LOGS_URL" || true

    if [[ -n "${GCLOUD_FM_URL:-}" ]]; then
      check_dns "fleet" "$GCLOUD_FM_URL" || true
    fi
  else
    record "dns" "skip" "disabled" "" ""
  fi

  if [[ "$GC_HC_TLS" == "true" ]]; then
    check_tls "prom" "$GCLOUD_HOSTED_METRICS_URL" || true
    check_tls "loki" "$GCLOUD_HOSTED_LOGS_URL" || true

    if [[ -n "${GCLOUD_FM_URL:-}" ]]; then
      check_tls "fleet" "$GCLOUD_FM_URL" || true
    fi
  else
    record "tls" "skip" "disabled" "" ""
  fi

  check_prom_push  || true
  check_prom_query || true
  check_loki       || true
  check_fleet      || true

  # Verdict: any FAIL beats any WARN beats all-PASS.
  if (( FAIL > 0 )); then
    overall="fail"
  elif (( WARN > 0 )); then
    overall="warn"
  fi

  for item in "${CHECKS[@]}"; do
    if [[ -z "$joined" ]]; then
      joined="$item"
    else
      joined="${joined},${item}"
    fi
  done

  finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  result="$(printf '{"tool":"%s","version":"%s","mode":"%s","host":"%s","started":"%s","finished":"%s","overall":"%s","summary":{"pass":%s,"warn":%s,"fail":%s,"skip":%s},"checks":[%s]}\n' \
    "$APP" \
    "$VERSION" \
    "$MODE" \
    "$(json_escape "$host")" \
    "$started" \
    "$finished" \
    "$overall" \
    "$PASS" \
    "$WARN" \
    "$FAIL" \
    "$SKIP" \
    "$joined")"

  install -d -m 0750 "$STATE_DIR" "$LOG_DIR"
  printf '%s' "$result" > "$RESULT_FILE"
  printf '%s' "$result" >> "$LOG_FILE"
  chmod 0640 "$RESULT_FILE" "$LOG_FILE" 2>/dev/null || true

  # Output mode:
  #   --json or non-TTY (piped/redirected) → raw JSON (machine-readable)
  #   TTY interactive                       → human-readable table
  if [[ "$JSON" == "true" ]] || [[ ! -t 1 ]]; then
    printf '%s' "$result"
  else
    format_result "$RESULT_FILE"
  fi

  case "$overall" in
    pass) return 0 ;;
    warn) return 1 ;;
    fail) return 2 ;;
  esac
}
