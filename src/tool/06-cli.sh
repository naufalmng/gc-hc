# CLI surface: usage banner and argument parser.
# parse_args supports both verb form (`gc-chkr check`) and long-option form
# (`gc-chkr --check`) so users can pick whichever feels natural.

usage() {
  cat <<'EOF'
gc-chkr - Grafana Cloud node-side healthcheck

Usage:
  gc-chkr onboard              configure + enable systemd timer
  gc-chkr config               create/update config
  gc-chkr show-config          print sanitized config
  gc-chkr check                run healthcheck once
  gc-chkr status               show status
  gc-chkr logs                 follow logs
  gc-chkr enable               enable/start timer
  gc-chkr disable              disable/stop timer
  gc-chkr remove               remove package or standalone data
  gc-chkr help                 show help

Short command:
  gchk onboard
  gchk config
  gchk check
  gchk status
  gchk logs

Long option style:
  gc-chkr --onboard
  gc-chkr --config
  gc-chkr --check
  gc-chkr --status
  gc-chkr --logs
  gc-chkr --remove

Options:
  -i, --interval 5m             timer interval: 1m, 5m, 15m, 1h
  -t, --timeout 10              curl timeout seconds
  -q, --quiet                   less output
  -y, --yes                     assume yes
  -f, --force                   overwrite/remove where relevant
  --json                        JSON-only output for check
  --no-dns                      skip DNS check
  --no-tls                      skip TLS check
  --no-loki-write               skip Loki write check
  --no-prom-query               skip Prometheus query check
  --no-fleet                    skip Fleet check
EOF
}

parse_args() {
  local arg=""

  if (( $# == 0 )); then
    ACTION="help"
    return 0
  fi

  arg="$1"
  shift

  case "$arg" in
    --*) ACTION="${arg#--}" ;;
    *) ACTION="$arg" ;;
  esac

  # Aliases — accept common alternates so muscle memory wins.
  case "$ACTION" in
    init|setup) ACTION="onboard" ;;
    cfg) ACTION="config" ;;
    run|test) ACTION="check" ;;
    log) ACTION="logs" ;;
    rm|uninstall) ACTION="remove" ;;
    h) ACTION="help" ;;
    v) ACTION="version" ;;
  esac

  while (( $# > 0 )); do
    arg="$1"
    case "$arg" in
      -i|--interval)
        if [[ $# -lt 2 ]]; then
          die "--interval needs value"
          return 1
        fi
        INTERVAL="$2"
        shift 2
        ;;
      -t|--timeout)
        if [[ $# -lt 2 ]]; then
          die "--timeout needs value"
          return 1
        fi
        TIMEOUT="$2"
        GC_CHKR_TIMEOUT="$2"
        shift 2
        ;;
      -q|--quiet) QUIET="true"; shift ;;
      -y|--yes) YES="true"; shift ;;
      -f|--force) FORCE="true"; shift ;;
      --json) JSON="true"; shift ;;
      --no-dns) GC_CHKR_DNS="false"; shift ;;
      --no-tls) GC_CHKR_TLS="false"; shift ;;
      --no-loki-write) GC_CHKR_LOKI_WRITE="false"; shift ;;
      --no-prom-query) GC_CHKR_PROM_QUERY="false"; shift ;;
      --no-fleet) GC_CHKR_FLEET="false"; shift ;;
      *)
        die "unknown option: $arg"
        return 1
        ;;
    esac
  done
}
