# Status, logs, and remove. These are read-mostly UX surfaces — they read
# the last persisted result and the system unit state, then render them as
# a human-friendly summary.

# Tiny pure-bash JSON value extractor — sufficient for our flat result schema
# (overall, started, finished). Not a general-purpose JSON parser; do not
# extend it beyond top-level string keys.
extract_json_value() {
  local file="${1:?missing file}"
  local key="${2:?missing key}"
  local value=""

  if [[ ! -s "$file" ]]; then
    printf 'n/a'
    return 0
  fi

  value="$(sed -n "s/.*\"${key}\":\"\\([^\"]*\\)\".*/\\1/p" "$file" | head -n 1)"
  value="$(trim "$value")"

  if [[ -z "$value" ]]; then
    printf 'n/a'
    return 0
  fi

  printf '%s' "$value"
}

status_badge() {
  local value="${1:-n/a}"

  case "$value" in
    enabled|active|pass)            printf '✓ %s' "$value" ;;
    disabled|inactive|failed|fail)  printf '✗ %s' "$value" ;;
    warn|warning)                   printf '! %s' "$value" ;;
    *)                              printf '%s'   "$value" ;;
  esac
}

show_status() {
  local timer_state="n/a"
  local timer_status="n/a"
  local service_state="n/a"
  local last_overall="n/a"
  local last_started="n/a"
  local last_finished="n/a"
  local next_run="n/a"
  local separator="────────────────────────────────────────────────────────"

  load_config || true

  if [[ "$MODE" == "system" ]] && command -v systemctl >/dev/null 2>&1; then
    timer_state="$(systemctl is-active "$TIMER_NAME"  2>/dev/null || printf 'inactive')"
    timer_status="$(systemctl is-enabled "$TIMER_NAME" 2>/dev/null || printf 'disabled')"
    service_state="$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || printf 'inactive')"

    if systemctl list-timers "$TIMER_NAME" --no-legend --no-pager >/dev/null 2>&1; then
      next_run="$(systemctl list-timers "$TIMER_NAME" --no-legend --no-pager 2>/dev/null | awk 'NF {print $1" "$2" "$3" "$4; exit}')"
      next_run="$(trim "$next_run")"
      [[ -n "$next_run" ]] || next_run="n/a"
    fi
  fi

  last_overall="$(extract_json_value "$RESULT_FILE" "overall")"
  last_started="$(extract_json_value "$RESULT_FILE" "started")"
  last_finished="$(extract_json_value "$RESULT_FILE" "finished")"

  printf '\n%s\n' "$separator"
  printf '  gc-chkr status\n'
  printf '%s\n' "$separator"
  printf '  %-13s: %s\n' "status"     "$(status_badge "$timer_status")"
  printf '  %-13s: %s\n' "timer"      "$(status_badge "$timer_state")"
  printf '  %-13s: %s\n' "service"    "$(status_badge "$service_state")"
  printf '  %-13s: %s\n' "last check" "$(status_badge "$last_overall")"
  printf '  %-13s: %s\n' "next run"   "$next_run"
  printf '%s\n' "$separator"
  printf '  %-13s: %s %s\n' "tool"   "$APP" "$VERSION"
  printf '  %-13s: %s\n'    "mode"   "$MODE"
  printf '  %-13s: %s\n'    "binary" "$SELF_PATH"
  printf '  %-13s: %s\n'    "config" "$CONFIG_FILE"
  printf '  %-13s: %s\n'    "state"  "$RESULT_FILE"
  printf '  %-13s: %s\n'    "log"    "$LOG_FILE"
  printf '%s\n' "$separator"
  printf '  %-13s: %s\n' "metrics" "${GCLOUD_HOSTED_METRICS_URL:-<unset>}"
  printf '  %-13s: %s\n' "logs"    "${GCLOUD_HOSTED_LOGS_URL:-<unset>}"
  printf '  %-13s: %s\n' "fleet"   "${GCLOUD_FM_URL:-<unset>}"
  printf '  %-13s: %s\n' "api key" "$(mask "${GCLOUD_RW_API_KEY:-}")"
  printf '%s\n' "$separator"
  printf '  %-13s: %s\n' "started"  "$last_started"
  printf '  %-13s: %s\n' "finished" "$last_finished"
  printf '%s\n\n' "$separator"

  if [[ -s "$RESULT_FILE" ]]; then
    printf 'last result:\n'
    cat "$RESULT_FILE"
    printf '\n'
  fi
}

# Logs prefer journalctl in system mode (gives us systemd context), and fall
# back to tailing the local log file otherwise.
show_logs() {
  if [[ "$MODE" == "system" ]] && command -v journalctl >/dev/null 2>&1; then
    journalctl -u "$SERVICE_NAME" -u "$TIMER_NAME" -f --no-pager
    return 0
  fi

  if [[ -s "$LOG_FILE" ]]; then
    tail -f "$LOG_FILE"
    return 0
  fi

  die "no logs found"
}

remove_self() {
  if [[ "$MODE" == "system" ]]; then
    need_root

    cat <<EOF
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following package will be REMOVED:
  gc-chkr
EOF

    if ! confirm "Do you want to continue?" "n"; then
      info "cancelled"
      return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
      exec apt-get remove -y gc-chkr
    fi

    if command -v dpkg >/dev/null 2>&1; then
      exec dpkg -r gc-chkr
    fi

    die "apt-get/dpkg not found"
    return 1
  fi

  cat <<EOF
The following standalone data will be removed:
  ${CONFIG_DIR}
  ${STATE_DIR}
  ${LOG_DIR}
EOF

  if ! confirm "Do you want to continue?" "n"; then
    info "cancelled"
    return 0
  fi

  rm -rf "$CONFIG_DIR" "$STATE_DIR" "$LOG_DIR"

  if [[ "$FORCE" == "true" ]]; then
    rm -f "$SELF_PATH"
    ok "standalone binary removed"
  else
    ok "standalone data removed; use gc-chkr remove --force to remove binary"
  fi
}
