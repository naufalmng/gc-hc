# Error / exit / signal traps. Stays silent in --json mode so machine-readable
# output isn't corrupted by diagnostics on stderr fan-in.

on_error() {
  local rc="$?"
  local line="${BASH_LINENO[0]:-unknown}"
  local cmd="${BASH_COMMAND:-unknown}"

  trap - ERR EXIT INT TERM

  if [[ "$JSON" != "true" ]]; then
    printf '\n[ERROR] %s failed\n' "$APP" >&2
    printf '  exit_code : %s\n' "$rc" >&2
    printf '  step      : %s\n' "$LAST_STEP" >&2
    printf '  line      : %s\n' "$line" >&2
    printf '  command   : %s\n' "$cmd" >&2
  fi

  exit "$rc"
}

on_exit() {
  trap - ERR EXIT INT TERM
}

on_signal() {
  printf '\n[ERROR] interrupted\n' >&2
  exit 130
}
