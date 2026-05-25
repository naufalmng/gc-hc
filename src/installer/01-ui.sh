# Visual polish: colors and an ASCII banner.
# Colors auto-disable on non-TTY stdout, NO_COLOR=1, or TERM=dumb so we never
# corrupt logs when the installer is piped into a file.

if [[ -t 1 && -z "${NO_COLOR}" && "${TERM:-}" != "dumb" ]]; then
  readonly C_RESET=$'\033[0m'
  readonly C_DIM=$'\033[2m'
  readonly C_BOLD=$'\033[1m'
  readonly C_RED=$'\033[31m'
  readonly C_GREEN=$'\033[32m'
  readonly C_YELLOW=$'\033[33m'
  readonly C_BLUE=$'\033[34m'
  readonly C_MAGENTA=$'\033[35m'
  readonly C_CYAN=$'\033[36m'
else
  readonly C_RESET=""
  readonly C_DIM=""
  readonly C_BOLD=""
  readonly C_RED=""
  readonly C_GREEN=""
  readonly C_YELLOW=""
  readonly C_BLUE=""
  readonly C_MAGENTA=""
  readonly C_CYAN=""
fi

print_banner() {
  printf '\n'
  printf '%s    ▄████   ▄████        ▄████ ██   ██ ██  ██ ██████%s\n'  "${C_CYAN}" "${C_RESET}"
  printf '%s   ██       ██           ██    ██   ██ ██ ██  ██   ██%s\n' "${C_CYAN}" "${C_RESET}"
  printf '%s   ██  ▄▄   ██           ██    ███████ ████   ██████%s\n'  "${C_CYAN}" "${C_RESET}"
  printf '%s   ██  ██   ██           ██    ██   ██ ██ ██  ██  ██%s\n'  "${C_CYAN}" "${C_RESET}"
  printf '%s    ▀████    ▀████  ▄    ██▄▄  ██   ██ ██  ██ ██   ██%s\n' "${C_CYAN}" "${C_RESET}"
  printf '\n'
  printf '   %sGrafana Cloud node-side healthcheck%s   %sv%s%s\n' \
    "${C_BOLD}" "${C_RESET}" "${C_DIM}" "${PACKAGE_VERSION}" "${C_RESET}"
  printf '   %s%s%s\n' "${C_DIM}" "${PACKAGE_HOMEPAGE}" "${C_RESET}"
  printf '\n'
}

# Step header used by install_package to chunk the install flow visually.
step() {
  local n="${1:?missing step number}"
  local total="${2:?missing total}"
  local label="${3:?missing label}"
  printf '\n%s[%s/%s]%s %s%s%s\n' \
    "${C_BLUE}" "$n" "$total" "${C_RESET}" "${C_BOLD}" "$label" "${C_RESET}"
}
