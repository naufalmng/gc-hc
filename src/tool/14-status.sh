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

format_result() {
  local file="${1:?missing file}"
  local overall started finished
  local pass=0 warn=0 fail=0 skip=0
  local name state msg line

  overall="$(extract_json_value "$file" "overall")"
  started="$(extract_json_value "$file" "started")"
  finished="$(extract_json_value "$file" "finished")"

  pass="$(sed -n 's/.*"pass":\([0-9]*\).*/\1/p' "$file" | head -n 1)"
  warn="$(sed -n 's/.*"warn":\([0-9]*\).*/\1/p' "$file" | head -n 1)"
  fail="$(sed -n 's/.*"fail":\([0-9]*\).*/\1/p' "$file" | head -n 1)"
  skip="$(sed -n 's/.*"skip":\([0-9]*\).*/\1/p' "$file" | head -n 1)"
  : "${pass:=0}" "${warn:=0}" "${fail:=0}" "${skip:=0}"

  printf '  %s  overall: %s  (pass:%s warn:%s fail:%s skip:%s)\n' \
    "$(status_badge "$overall")" "$overall" "$pass" "$warn" "$fail" "$skip"
  printf '  ran: %s → %s\n\n' "$started" "$finished"

  printf '  %-16s %-6s %s\n' "CHECK" "STATE" "MESSAGE"
  printf '  %-16s %-6s %s\n' "────────────────" "──────" "────────────────────────────"

  while IFS= read -r line; do
    name="$(printf '%s' "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')"
    state="$(printf '%s' "$line" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')"
    msg="$(printf '%s' "$line" | sed -n 's/.*"msg":"\([^"]*\)".*/\1/p')"
    [[ -n "$name" ]] || continue

    local badge
    case "$state" in
      pass) badge="✓" ;;
      fail) badge="✗" ;;
      warn) badge="!" ;;
      skip) badge="–" ;;
      *)    badge=" " ;;
    esac

    printf '  %s %-14s %-6s %s\n' "$badge" "$name" "$state" "$msg"
  done < <(grep -o '{"name":"[^}]*}' "$file")
}

status_badge() {
  local value="${1:-n/a}"

  case "$value" in
    enabled|active|pass)  printf '✓ %s' "$value" ;;
    disabled|failed|fail|inactive) printf '✗ %s' "$value" ;;
    warn|warning)         printf '! %s' "$value" ;;
    *)                    printf '%s'   "$value" ;;
  esac
}

show_status() {
  local timer_state="n/a"
  local timer_status="n/a"
  local last_overall="n/a"
  local last_started="n/a"
  local last_finished="n/a"
  local next_run="n/a"
  local interval_display="n/a"
  local separator="────────────────────────────────────────────────────────"

  load_config || true

  if [[ "$MODE" == "system" ]] && command -v systemctl >/dev/null 2>&1; then
    timer_state="$(systemctl is-active "$TIMER_NAME"  2>/dev/null)" || true
    timer_status="$(systemctl is-enabled "$TIMER_NAME" 2>/dev/null)" || true
    : "${timer_state:=inactive}" "${timer_status:=disabled}"

    if systemctl list-timers "$TIMER_NAME" --no-legend --no-pager >/dev/null 2>&1; then
      next_run="$(systemctl list-timers "$TIMER_NAME" --no-legend --no-pager 2>/dev/null | awk 'NF {print $1" "$2" "$3" "$4; exit}')"
      next_run="$(trim "$next_run")"
      [[ -n "$next_run" ]] || next_run="n/a"
    fi
  fi

  # Interval source of truth: prefer the persisted/active value, otherwise the
  # in-memory default. Show both raw token and a friendlier expansion.
  if [[ -n "${GC_HC_INTERVAL:-}" ]]; then
    interval_display="$(format_interval "$GC_HC_INTERVAL")"
  fi

  last_overall="$(extract_json_value "$RESULT_FILE" "overall")"
  last_started="$(extract_json_value "$RESULT_FILE" "started")"
  last_finished="$(extract_json_value "$RESULT_FILE" "finished")"

  printf '\n%s\n' "$separator"
  printf '  gc-hc status\n'
  printf '%s\n' "$separator"
  printf '  %-13s: %s\n' "status"     "$(status_badge "$timer_status")"
  printf '  %-13s: %s\n' "timer"      "$(status_badge "$timer_state")"
  printf '  %-13s: %s\n' "last check" "$(status_badge "$last_overall")"
  printf '  %-13s: %s\n' "interval"   "$interval_display"
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
    printf '  last result:\n'
    format_result "$RESULT_FILE"
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
  gc-hc
EOF

    if ! confirm "Do you want to continue?" "n"; then
      info "cancelled"
      return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
      exec apt-get remove -y gc-hc
    fi

    if command -v dpkg >/dev/null 2>&1; then
      exec dpkg -r gc-hc
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
    ok "standalone data removed; use gc-hc remove --force to remove binary"
  fi
}
