# Logging primitives + utility helpers.
# Color-aware; falls back to ASCII tags when piped or NO_COLOR is set.

die() {
  printf '%s[ERROR]%s %s\n' "${C_RED}${C_BOLD}" "${C_RESET}" "${1:-unknown error}" >&2
  return 1
}

info() {
  printf '%s[INFO]%s %s\n'  "${C_BLUE}"  "${C_RESET}" "${1:-}"
}

ok() {
  printf '%s[OK]%s %s\n'    "${C_GREEN}" "${C_RESET}" "${1:-}"
}

warn() {
  printf '%s[WARN]%s %s\n'  "${C_YELLOW}" "${C_RESET}" "${1:-}" >&2
}

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

tty_read() {
  local prompt="${1:?missing prompt}"
  local answer=""

  if [[ ! -r /dev/tty ]]; then
    return 2
  fi

  printf '%s' "$prompt" > /dev/tty

  if ! IFS= read -r answer < /dev/tty; then
    return 1
  fi

  answer="$(trim "$answer")"
  printf '%s' "$answer"
}

# apt-style yes/no prompt. Auto-yes via --yes to support unattended pipe
# install (`curl ... | sudo bash -s -- install --yes`).
apt_confirm() {
  local prompt="${1:-Do you want to continue?}"
  local default="${2:-y}"
  local suffix=""
  local answer=""

  if [[ "$YES" == "true" ]]; then
    printf '%s %s\n' "$prompt" "Y"
    return 0
  fi

  case "$default" in
    y|Y) suffix=" [Y/n] " ;;
    *)   suffix=" [y/N] " ;;
  esac

  while true; do
    if ! answer="$(tty_read "${prompt}${suffix}")"; then
      die "confirmation requires a TTY; rerun with --yes for non-interactive mode"
      return 1
    fi

    if [[ -z "$answer" ]]; then
      answer="$default"
    fi

    case "$answer" in
      y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No)    return 1 ;;
      *) printf 'Please answer yes or no.\n' >&2 ;;
    esac
  done
}
