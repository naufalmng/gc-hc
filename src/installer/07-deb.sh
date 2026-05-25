# Build a .deb on the fly from embedded assets, then hand it to apt-get.
# We deliberately go through apt rather than dpkg directly so dependency
# resolution still works (curl, ca-certificates, systemd).

build_deb() {
  local pkg_dir=""
  local debian_dir=""
  local deb_path=""

  LAST_STEP="build deb package"
  need_cmd dpkg-deb install chmod chown mktemp

  TMP_BUILD_DIR="$(mktemp -d -p /var/tmp "${PACKAGE_NAME}.XXXXXX")"
  chmod 0755 "$TMP_BUILD_DIR"

  pkg_dir="${TMP_BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}"
  debian_dir="${pkg_dir}/DEBIAN"
  deb_path="${TMP_BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"

  install -d -m 0755 "$debian_dir"
  install -d -m 0755 "${pkg_dir}/usr/bin"
  install -d -m 0755 "${pkg_dir}${SYSTEMD_DIR}"
  install -d -m 0750 "${pkg_dir}/etc/gc-hc"
  install -d -m 0750 "${pkg_dir}/var/lib/gc-hc"
  install -d -m 0750 "${pkg_dir}/var/log/gc-hc"

  write_tool              "${pkg_dir}${MAIN_BIN}"
  write_short_wrapper     "${pkg_dir}${SHORT_BIN}"
  write_service_file      "${pkg_dir}${SYSTEMD_DIR}/gc-hc.service"
  write_timer_file        "${pkg_dir}${SYSTEMD_DIR}/gc-hc.timer"
  write_maintainer_scripts "$debian_dir"

  cat > "${debian_dir}/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Section: admin
Priority: optional
Architecture: ${PACKAGE_ARCH}
Depends: bash, curl, ca-certificates, systemd
Maintainer: ${PACKAGE_MAINTAINER}
Homepage: ${PACKAGE_HOMEPAGE}
Description: Grafana Cloud node-side healthcheck with systemd timer
 A compact Bash healthcheck utility for validating node-side access
 to Grafana Cloud Prometheus remote_write, Loki push, DNS, TLS,
 and optional Fleet Management endpoints.
EOF

  if ! dpkg-deb --build "$pkg_dir" "$deb_path" >/dev/null; then
    die "failed to build deb package"
    return 1
  fi

  chmod 0644 "$deb_path"
  printf '%s\n' "$deb_path"
}
