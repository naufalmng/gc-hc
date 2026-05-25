# Input validators. Each returns non-zero (via die) on failure so callers can
# fail-fast at config-load time instead of mid-healthcheck.

valid_interval() {
  local value="${1:?missing interval}"

  if [[ ! "$value" =~ ^[0-9]+[smhd]$ ]]; then
    die "invalid interval: $value"
    return 1
  fi
}

valid_timeout() {
  local value="${1:?missing timeout}"

  if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 1 || value > 300 )); then
    die "invalid timeout: $value"
    return 1
  fi
}

# Translate `5m` / `30s` / `1h` style intervals into systemd OnCalendar syntax.
calendar_from_interval() {
  local value="${1:?missing interval}"
  local number="${value%?}"
  local unit="${value: -1}"

  case "$unit" in
    s) printf '*:*:0/%s\n' "$number" ;;
    m) printf '*:0/%s:00\n' "$number" ;;
    h) printf '*-*-* 0/%s:00:00\n' "$number" ;;
    d) printf '*-*-* 00:00:00\n' ;;
    *) die "unsupported interval: $value"; return 1 ;;
  esac
}

valid_url() {
  local key="${1:?missing key}"
  local value="${2:-}"

  if [[ -z "$value" ]]; then
    die "$key is empty"
    return 1
  fi

  if [[ "$value" != https://* ]]; then
    die "$key must start with https://"
    return 1
  fi

  if [[ "$value" =~ [[:space:]] ]] || grep -Eq '[<>"`{}|\\^]' <<< "$value"; then
    die "$key contains invalid character"
    return 1
  fi
}

valid_id() {
  local key="${1:?missing key}"
  local value="${2:-}"

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    die "$key must be numeric"
    return 1
  fi
}

valid_key() {
  local value="${1:-}"

  if [[ "$value" != glc_* ]]; then
    die "GCLOUD_RW_API_KEY must start with glc_"
    return 1
  fi

  if [[ "$value" =~ [[:space:]] ]] || grep -Eq '[<>"`{}|\\^]' <<< "$value"; then
    die "GCLOUD_RW_API_KEY contains invalid character"
    return 1
  fi
}
