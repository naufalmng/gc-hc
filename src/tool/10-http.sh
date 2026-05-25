# HTTP probe + result recorder.
# http_code is intentionally minimal: we only care about the response status
# code. Output is silenced; on transport error we emit `curl_error:<msg>` so
# the caller sees a discriminated failure mode.

http_code() {
  local url="${1:?missing url}"
  local user="${2:-}"
  local pass="${3:-}"
  local method="${4:-GET}"
  local data="${5:-}"
  local ctype="${6:-}"
  local output=""
  local args=(
    --silent
    --show-error
    --location
    --max-time "$GC_CHKR_TIMEOUT"
    --connect-timeout "$GC_CHKR_TIMEOUT"
    --retry "$GC_CHKR_RETRIES"
    --retry-delay "$GC_CHKR_RETRY_DELAY"
    --output /dev/null
    --write-out "%{http_code}"
    --request "$method"
  )

  if [[ -n "$user$pass" ]]; then
    args+=(--user "${user}:${pass}")
  fi

  if [[ -n "$ctype" ]]; then
    args+=(--header "Content-Type: ${ctype}")
  fi

  if [[ -n "$data" ]]; then
    args+=(--data "$data")
  fi

  if ! output="$(curl "${args[@]}" "$url" 2>&1)"; then
    printf 'curl_error:%s\n' "$(trim "$output")"
    return 1
  fi

  output="$(trim "$output")"

  if [[ ! "$output" =~ ^[0-9]{3}$ ]]; then
    printf 'curl_error:%s\n' "$output"
    return 1
  fi

  printf '%s\n' "$output"
}

# Append a structured check entry. State drives the summary counters and the
# overall pass/warn/fail verdict produced by run_check.
record() {
  local name="${1:?missing name}"
  local state="${2:?missing state}"
  local msg="${3:-}"
  local target="${4:-}"
  local detail="${5:-}"

  CHECKS+=("$(printf '{"name":"%s","state":"%s","msg":"%s","target":"%s","detail":"%s"}' \
    "$(json_escape "$name")" \
    "$(json_escape "$state")" \
    "$(json_escape "$msg")" \
    "$(json_escape "$target")" \
    "$(json_escape "$detail")")")

  case "$state" in
    pass) PASS=$((PASS + 1)) ;;
    warn) WARN=$((WARN + 1)) ;;
    fail) FAIL=$((FAIL + 1)) ;;
    skip) SKIP=$((SKIP + 1)) ;;
  esac
}
