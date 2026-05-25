# URL parsing helpers — pure-bash, no curl/awk dependency for these.

host_from_url() {
  local url="${1:?missing url}"
  local host="${url#https://}"

  host="${host#http://}"
  host="${host%%/*}"
  host="${host%%:*}"

  if [[ -z "$host" ]]; then
    return 1
  fi

  printf '%s\n' "$host"
}

port_from_url() {
  local url="${1:?missing url}"
  local host_port="${url#https://}"

  host_port="${host_port#http://}"
  host_port="${host_port%%/*}"

  if [[ "$host_port" == *:* ]]; then
    printf '%s\n' "${host_port##*:}"
    return 0
  fi

  printf '443\n'
}

# Convert a Prometheus remote_write push URL into the equivalent buildinfo URL
# so we can probe the read side with a cheap GET.
prom_query_url() {
  local url="${1:?missing url}"

  url="${url%/}"

  if [[ "$url" == */api/prom/push ]]; then
    printf '%s/api/prom/api/v1/status/buildinfo\n' "${url%/api/prom/push}"
    return 0
  fi

  printf '%s\n' "$url"
}
