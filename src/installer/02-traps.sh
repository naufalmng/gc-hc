# Trap handlers: report failure with breadcrumb, clean up build temp dir.
# Distinct from tool runtime traps because the installer has its own lifecycle
# (TMP_BUILD_DIR, .deb retention via --keep-deb).

on_error() {
  local rc="$?"
  local line="${BASH_LINENO[0]:-unknown}"
  local cmd="${BASH_COMMAND:-unknown}"

  trap - ERR EXIT INT TERM

  printf '\n%s[ERROR]%s installer failed\n' "${C_RED}${C_BOLD}" "${C_RESET}" >&2
  printf '  exit_code : %s\n' "$rc"        >&2
  printf '  step      : %s\n' "$LAST_STEP" >&2
  printf '  line      : %s\n' "$line"      >&2
  printf '  command   : %s\n' "$cmd"       >&2

  if [[ -n "${TMP_BUILD_DIR:-}" && -d "$TMP_BUILD_DIR" ]]; then
    printf '  temp_dir  : %s\n' "$TMP_BUILD_DIR" >&2
  fi

  exit "$rc"
}

on_exit() {
  local rc="$?"
  trap - ERR EXIT INT TERM

  if [[ "$KEEP_DEB" != "true" && -n "${TMP_BUILD_DIR:-}" && -d "$TMP_BUILD_DIR" ]]; then
    rm -rf "$TMP_BUILD_DIR"
  fi

  exit "$rc"
}

on_signal() {
  printf '\n[ERROR] interrupted\n' >&2
  exit 130
}
