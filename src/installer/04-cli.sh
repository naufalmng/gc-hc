# CLI surface for the installer.
# Action verbs match apt semantics so muscle memory transfers cleanly.

usage() {
  cat <<EOF
${C_BOLD}gc-hc installer${C_RESET}  ${C_DIM}v${PACKAGE_VERSION}${C_RESET}

${C_BOLD}Usage:${C_RESET}
  sudo bash ${0##*/} install
  sudo bash ${0##*/} uninstall
  bash ${0##*/} standalone

${C_BOLD}Options:${C_RESET}
  -y, --yes          assume yes
  -f, --force        overwrite existing standalone binary
      --keep-deb     keep generated .deb in current directory
      --no-color     disable ANSI colors
  -h, --help         show help

${C_BOLD}Pipe examples:${C_RESET}
  curl -fsSL ${PACKAGE_HOMEPAGE}/releases/latest/download/gc-hc.sh | sudo bash
  curl -fsSL ${PACKAGE_HOMEPAGE}/releases/latest/download/gc-hc.sh | sudo bash -s -- install
  curl -fsSL ${PACKAGE_HOMEPAGE}/releases/latest/download/gc-hc.sh | sudo bash -s -- install --yes
  curl -fsSL ${PACKAGE_HOMEPAGE}/releases/latest/download/gc-hc.sh | bash -s -- standalone

${C_BOLD}After install:${C_RESET}
  sudo gc-hc onboard
  gc-hc status
  gchc check
  sudo apt-get remove gc-hc
EOF
}

parse_installer_args() {
  local arg=""

  while (( $# > 0 )); do
    arg="$1"

    case "$arg" in
      install|uninstall|remove|standalone|help)
        ACTION="$arg"; shift ;;
      --install)            ACTION="install"; shift ;;
      --uninstall|--remove) ACTION="uninstall"; shift ;;
      --standalone)         ACTION="standalone"; shift ;;
      -y|--yes)             YES="true"; shift ;;
      -f|--force)           FORCE="true"; shift ;;
      --keep-deb)           KEEP_DEB="true"; shift ;;
      --no-color)           NO_COLOR="1"; shift ;;
      -h|--help)            ACTION="help"; shift ;;
      *)
        die "unknown argument: $arg"
        return 1
        ;;
    esac
  done

  if [[ -z "$ACTION" ]]; then
    ACTION="install"
  fi

  if [[ "$ACTION" == "remove" ]]; then
    ACTION="uninstall"
  fi
}
