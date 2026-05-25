# Top-level actions: install / uninstall / standalone.
# install_package builds a .deb in /var/tmp and feeds it to apt-get install.
# uninstall_package wraps apt-get remove for symmetry.
# standalone drops a self-contained runtime binary into ${PWD} for users who
# don't want the package management dance.

install_package() {
  local deb_path=""
  local keep_path=""

  LAST_STEP="install package"
  need_root
  need_cmd apt-get dpkg dpkg-query dpkg-deb install systemctl mktemp grep chmod

  print_banner

  step 1 4 "Pre-flight checks"
  check_short_command_conflict
  print_install_preview

  if ! apt_confirm "Do you want to continue?" "y"; then
    info "Abort."
    return 0
  fi

  step 2 4 "Building .deb package"
  info "Building local package ${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"
  deb_path="$(build_deb)"
  ok "Package built: $deb_path"

  step 3 4 "Installing via apt-get"
  if ! apt-get install -y "$deb_path"; then
    die "apt-get install failed"
    return 1
  fi

  if [[ "$KEEP_DEB" == "true" ]]; then
    keep_path="${PWD}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"
    cp -f "$deb_path" "$keep_path"
    chmod 0644 "$keep_path"
    ok "Debian package kept: $keep_path"
  fi

  step 4 4 "Done"
  cat <<EOF

${C_GREEN}${C_BOLD}gc-chkr installed successfully.${C_RESET}

  Main command:   ${C_BOLD}gc-chkr help${C_RESET}
  Short command:  ${C_BOLD}gchk help${C_RESET}

  Next step:
    ${C_BOLD}sudo gc-chkr onboard${C_RESET}

  Remove:
    sudo apt-get remove gc-chkr
EOF
}

uninstall_package() {
  LAST_STEP="uninstall package"
  need_root
  need_cmd apt-get dpkg-query grep

  print_banner
  print_uninstall_preview

  if ! is_installed; then
    return 0
  fi

  if ! apt_confirm "Do you want to continue?" "y"; then
    info "Abort."
    return 0
  fi

  apt-get remove -y "$PACKAGE_NAME"
}

standalone() {
  local target="${PWD}/gc-chkr"

  LAST_STEP="standalone"
  need_cmd chmod

  print_banner
  print_standalone_preview

  if [[ -e "$target" && "$FORCE" != "true" ]]; then
    die "$target already exists; use standalone --force"
    return 1
  fi

  if ! apt_confirm "Do you want to continue?" "y"; then
    info "Abort."
    return 0
  fi

  write_tool "$target"
  chmod 0755 "$target"

  cat <<EOF

${C_GREEN}${C_BOLD}Standalone gc-chkr created successfully.${C_RESET}

  Binary:
    ${target}

  Next:
    ./gc-chkr config
    ./gc-chkr check
EOF
}
