# Installer entrypoint.

main() {
  trap on_error  ERR
  trap on_exit   EXIT
  trap on_signal INT TERM

  parse_installer_args "$@"

  case "$ACTION" in
    install)    install_package ;;
    uninstall)  uninstall_package ;;
    standalone) standalone ;;
    help)       usage ;;
    *)
      die "unknown action: $ACTION"
      usage
      return 1
      ;;
  esac
}

main "$@"
