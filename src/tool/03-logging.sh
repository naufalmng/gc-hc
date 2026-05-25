# Logging primitives. info/ok suppress under --quiet or --json; warn always
# routes to stderr so it never pollutes piped JSON. die returns non-zero so
# callers can chain `|| return 1` cleanly.

die() {
  printf '[ERROR] %s\n' "${1:-unknown error}" >&2
  return 1
}

info() {
  if [[ "$QUIET" != "true" && "$JSON" != "true" ]]; then
    printf '[INFO] %s\n' "${1:-}"
  fi
}

ok() {
  if [[ "$QUIET" != "true" && "$JSON" != "true" ]]; then
    printf '[OK] %s\n' "${1:-}"
  fi
}

warn() {
  if [[ "$JSON" != "true" ]]; then
    printf '[WARN] %s\n' "${1:-}" >&2
  fi
}
