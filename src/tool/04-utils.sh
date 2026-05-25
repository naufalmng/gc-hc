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
