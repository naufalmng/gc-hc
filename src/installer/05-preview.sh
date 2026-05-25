# dpkg-aware helpers + apt-style preview output.
# The preview functions intentionally mimic apt-get's wording so a user
# piping `curl | sudo bash` into a server feels at home.

is_installed() {
  dpkg-query -W -f='${Status}' "$PACKAGE_NAME" 2>/dev/null | grep -q '^install ok installed$'
}

installed_version() {
  dpkg-query -W -f='${Version}' "$PACKAGE_NAME" 2>/dev/null || true
}

# Defensive: if /usr/bin/gchc already exists but isn't owned by *us*, abort.
# Saves a frustrated user from blowing away an unrelated tool.
check_short_command_conflict() {
  if [[ ! -e "$SHORT_BIN" ]]; then
    return 0
  fi

  if dpkg -S "$SHORT_BIN" >/dev/null 2>&1; then
    if dpkg -S "$SHORT_BIN" 2>/dev/null | grep -q "^${PACKAGE_NAME}:"; then
      return 0
    fi
  fi

  die "${SHORT_BIN} already exists and is owned by another package/file"
  return 1
}

print_install_preview() {
  local old_version=""

  printf 'Reading package lists... Done\n'
  printf 'Building dependency tree... Done\n'
  printf 'Reading state information... Done\n'

  if is_installed; then
    old_version="$(installed_version)"
    cat <<EOF
The following package will be upgraded/reinstalled:
  ${C_BOLD}${PACKAGE_NAME}${C_RESET}

Current version:
  ${PACKAGE_NAME} ${old_version}

New version:
  ${PACKAGE_NAME} ${PACKAGE_VERSION}
EOF
  else
    cat <<EOF
The following NEW package will be installed:
  ${C_BOLD}${PACKAGE_NAME}${C_RESET}
EOF
  fi

  cat <<EOF

The following command aliases will be available:
  ${C_GREEN}gc-hc${C_RESET}
  ${C_GREEN}gchc${C_RESET}

Package files:
  ${C_DIM}/usr/bin/gc-hc
  /usr/bin/gchc
  /lib/systemd/system/gc-hc.service
  /lib/systemd/system/gc-hc.timer
  /etc/gc-hc/
  /var/lib/gc-hc/
  /var/log/gc-hc/${C_RESET}

Recommended next step after installation:
  ${C_BOLD}sudo gc-hc onboard${C_RESET}

To remove:
  sudo apt-get remove gc-hc

EOF
}

print_uninstall_preview() {
  printf 'Reading package lists... Done\n'
  printf 'Building dependency tree... Done\n'
  printf 'Reading state information... Done\n'

  if is_installed; then
    cat <<EOF
The following package will be REMOVED:
  ${C_BOLD}${PACKAGE_NAME}${C_RESET}

The following managed paths will be removed:
  ${C_DIM}/etc/gc-hc/
  /var/lib/gc-hc/
  /var/log/gc-hc/${C_RESET}

EOF
    return 0
  fi

  cat <<EOF
Package ${PACKAGE_NAME} is not installed.

EOF
}

print_standalone_preview() {
  printf 'Reading package lists... Done\n'
  printf 'Building dependency tree... Done\n'
  printf 'Reading state information... Done\n'

  cat <<EOF
The following standalone executable will be created:
  ${C_BOLD}${PWD}/gc-hc${C_RESET}

No package will be installed.
No systemd service/timer will be installed.

Standalone data directory:
  ${C_DIM}${PWD}/.gc-hc/${C_RESET}

EOF
}
