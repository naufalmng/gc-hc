# Embedded asset emitters.
# These functions write the runtime tool, the gchk wrapper, the systemd units,
# and the dpkg maintainer scripts to the locations the .deb expects.
#
# The actual file contents are injected at build time by scripts/build.sh
# from assets/ and from the assembled tool runtime under src/tool/. Look for
# the __EMBED_*__ placeholders below.

write_tool() {
  local target="${1:?missing target}"

  cat > "$target" <<'GC_CHKR_TOOL'
__EMBED_TOOL__
GC_CHKR_TOOL

  chmod 0755 "$target"
}

write_short_wrapper() {
  local target="${1:?missing target}"

  cat > "$target" <<'GC_CHKR_SHORT'
#!/usr/bin/env bash
exec /usr/bin/gc-chkr "$@"
GC_CHKR_SHORT

  chmod 0755 "$target"
}

write_service_file() {
  local target="${1:?missing service target}"

  cat > "$target" <<'GC_CHKR_SERVICE'
__EMBED_SERVICE__
GC_CHKR_SERVICE
}

write_timer_file() {
  local target="${1:?missing timer target}"

  cat > "$target" <<'GC_CHKR_TIMER'
__EMBED_TIMER__
GC_CHKR_TIMER
}

write_maintainer_scripts() {
  local debian_dir="${1:?missing debian dir}"

  cat > "${debian_dir}/postinst" <<'GC_CHKR_POSTINST'
__EMBED_POSTINST__
GC_CHKR_POSTINST

  cat > "${debian_dir}/prerm" <<'GC_CHKR_PRERM'
__EMBED_PRERM__
GC_CHKR_PRERM

  cat > "${debian_dir}/postrm" <<'GC_CHKR_POSTRM'
__EMBED_POSTRM__
GC_CHKR_POSTRM

  chmod 0755 "${debian_dir}/postinst" "${debian_dir}/prerm" "${debian_dir}/postrm"
}
