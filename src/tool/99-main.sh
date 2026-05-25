# Tool entrypoint. Wires up traps, parses args, dispatches to the action
# handler. Keep this thin — actual logic lives in the per-domain modules.

main() {
  trap on_error  ERR
  trap on_exit   EXIT
  trap on_signal INT TERM

  parse_args "$@"

  case "$ACTION" in
    onboard)     onboard ;;
    config)      configure ;;
    show-config) show_config ;;
    check)       run_check ;;
    status)      show_status ;;
    logs)        show_logs ;;
    remove)      remove_self ;;
    enable)      enable_timer ;;
    disable)     disable_timer ;;
    help)        usage ;;
    version)     printf '%s %s\n' "$APP" "$VERSION" ;;
    *)
      die "unknown command: $ACTION"
      usage
      return 1
      ;;
  esac
}

main "$@"
