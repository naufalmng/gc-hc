# Generic shell utilities: privilege check, command presence, string helpers,
# pure-bash JSON string escaping (no jq dependency), and secret masking.

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "run as root"
    return 1
  fi
}

need_cmd() {
  local missing=()
  local cmd=""

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    die "missing command(s): ${missing[*]}"
    return 1
  fi
}

trim() {
  local input="${1:-}"
  input="${input//$'\r'/}"
  input="${input#"${input%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]}"}"
  printf '%s' "$input"
}

json_escape() {
  local input="${1:-}"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  input="${input//$'\r'/\\r}"
  input="${input//$'\t'/\\t}"
  printf '%s' "$input"
}

# Escape a value for safe inclusion inside single-quoted shell env files.
quote_env() {
  local input="${1:-}"
  printf '%s' "$input" | sed "s/'/'\\\\''/g"
}

# Mask credentials for logs. Short values are fully obscured to avoid leaking
# entropy on prefix-only secrets.
mask() {
  local value="${1:-}"
  local len="${#value}"

  if [[ -z "$value" ]]; then
    printf '<empty>'
    return 0
  fi

  if (( len < 14 )); then
    printf '********'
    return 0
  fi

  printf '%s...%s' "${value:0:6}" "${value: -4}"
}

# Tail-rotate a line-oriented log file: keep the last N "blocks", where a block
# is delimited by a marker regex. Used by both the check JSONL log (block-per-
# line, marker = ^) and the trace logs (block-per-entry, marker = ^=== ).
#
# Args:
#   $1 path     - file to rotate
#   $2 keep     - max blocks to retain; 0 disables rotation entirely
#   $3 marker   - awk regex matching the start-of-block line (e.g. '^', '^=== ')
#
# Pure-function except for the filesystem; safe to call when file doesn't yet
# exist. Atomic via tmp+mv so a kill mid-rotate can't corrupt the log.
log_tail_rotate() {
  local path="${1:?missing path}"
  local keep="${2:-0}"
  local marker="${3:-^}"
  local tmp

  (( keep > 0 )) || return 0
  [[ -s "$path" ]] || return 0

  tmp="${path}.rot"
  awk -v keep="$keep" -v marker="$marker" '
    $0 ~ marker { blocks++; idx[blocks] = NR }
    { lines[NR] = $0; total = NR }
    END {
      if (blocks <= keep) {
        for (i = 1; i <= total; i++) print lines[i]
        exit
      }
      start = idx[blocks - keep + 1]
      for (i = start; i <= total; i++) print lines[i]
    }
  ' "$path" > "$tmp" 2>/dev/null && mv "$tmp" "$path" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}
