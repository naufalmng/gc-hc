# CLI surface: usage banner and argument parser.
# parse_args supports both verb form (`gc-hc check`) and long-option form
# (`gc-hc --check`) so users can pick whichever feels natural.

usage() {
  cat <<'EOF'
gc-hc - Grafana Cloud node-side healthcheck

Usage:
  gc-hc onboard              configure + enable systemd timer
  gc-hc config               create/update config
  gc-hc show-config          print sanitized config
  gc-hc check                run healthcheck once
  gc-hc status               show status
  gc-hc logs                 follow logs
  gc-hc enable               enable/start timer
  gc-hc disable              disable/stop timer
  gc-hc remove               remove package or standalone data
  gc-hc help                 show help

Short command:
  gchc onboard
  gchc config
  gchc check
  gchc status
  gchc logs

Long option style:
  gc-hc --onboard
  gc-hc --config
  gc-hc --check
  gc-hc --status
  gc-hc --logs
  gc-hc --remove

Options:
  -i, --interval 5m             timer interval: 1m, 5m, 15m, 1h
                                also via env: GC_HC_INTERVAL
  -t, --timeout 10              curl timeout seconds
                                also via env: GC_HC_TIMEOUT
  -q, --quiet                   less output
  -y, --yes                     assume yes
  -f, --force                   overwrite/remove where relevant
  --json                        JSON-only output for check
  --no-dns                      skip DNS check
  --no-tls                      skip TLS check
  --no-loki-write               skip Loki write check
  --no-prom-query               skip Prometheus query check
  --no-fleet                    skip Fleet check
  --trace                       force traceroute on every probe this run
  --no-trace                    disable traceroute even on failures

Environment overrides (also set via gc-hc config):
  GC_HC_INTERVAL    timer interval (1m, 5m, 15m, 1h)  default: 5m
  GC_HC_TIMEOUT     curl timeout seconds              default: 10
  GC_HC_RETRIES     retry count per probe             default: 2
  GC_HC_DNS         enable DNS check                  default: true
  GC_HC_TLS         enable TLS check                  default: true
  GC_HC_LOKI_WRITE  enable Loki write check           default: true
  GC_HC_PROM_QUERY  enable Prometheus query check     default: true
  GC_HC_FLEET       enable Fleet check                default: true
  GC_HC_LOG_KEEP    last N check entries kept (0=off) default: 100
  GC_HC_TRACE          auto|always|never              default: auto
  GC_HC_TRACE_TOOL     auto|traceroute|tracepath      default: auto
  GC_HC_TRACE_TIMEOUT  per-hop timeout (seconds)      default: 2
  GC_HC_TRACE_MAX_HOPS abort after N hops             default: 15
  GC_HC_TRACE_LOG_KEEP last N entries kept per probe  default: 50
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
        GC_HC_INTERVAL="$2"
        shift 2
        ;;
      -t|--timeout)
        if [[ $# -lt 2 ]]; then
          die "--timeout needs value"
          return 1
        fi
        TIMEOUT="$2"
        GC_HC_TIMEOUT="$2"
        shift 2
        ;;
      -q|--quiet) QUIET="true"; shift ;;
      -y|--yes) YES="true"; shift ;;
      -f|--force) FORCE="true"; shift ;;
      --json) JSON="true"; shift ;;
      --no-dns) GC_HC_DNS="false"; shift ;;
      --no-tls) GC_HC_TLS="false"; shift ;;
      --no-loki-write) GC_HC_LOKI_WRITE="false"; shift ;;
      --no-prom-query) GC_HC_PROM_QUERY="false"; shift ;;
      --no-fleet) GC_HC_FLEET="false"; shift ;;
      --trace) TRACE_FORCE="true"; GC_HC_TRACE="always"; shift ;;
      --no-trace) TRACE_FORCE="false"; GC_HC_TRACE="never"; shift ;;
      *)
        die "unknown option: $arg"
        return 1
        ;;
    esac
  done
}
