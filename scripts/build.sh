#!/usr/bin/env bash
#
# scripts/build.sh — assemble dist artifacts from src/ + assets/.
#
# Outputs:
#   dist/gc-chkr.sh    self-contained installer (this is the curl-pipe target)
#   dist/gc-chkr       standalone runtime tool (drop-in /usr/local/bin)
#
# The installer embeds the tool runtime + systemd units + dpkg maintainer
# scripts via heredoc placeholders. Placeholder substitution is done with
# awk so binary-safe content is preserved verbatim.
#
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd -P)"
SRC_TOOL="${ROOT}/src/tool"
SRC_INSTALLER="${ROOT}/src/installer"
ASSETS="${ROOT}/assets"
DIST="${ROOT}/dist"

VERSION="$(cat "${ROOT}/VERSION" | tr -d '[:space:]')"
MAINTAINER="${PACKAGE_MAINTAINER:-Muhammad Naufal Hanif <naufal.hanif@binerteknologi.id>}"
HOMEPAGE="${PACKAGE_HOMEPAGE:-https://github.com/naufalmng/gc-chkr}"

c_blue=''; c_green=''; c_dim=''; c_reset=''
if [[ -t 1 ]]; then
  c_blue=$'\033[34m'; c_green=$'\033[32m'; c_dim=$'\033[2m'; c_reset=$'\033[0m'
fi

step()  { printf '%s==>%s %s\n' "$c_blue"  "$c_reset" "$*"; }
done_() { printf '%s ok%s %s\n'  "$c_green" "$c_reset" "$*"; }
note()  { printf '%s    %s%s\n' "$c_dim"   "$*" "$c_reset"; }

# Concatenate every *.sh in a directory in lexical order, skipping the
# shebang/header on every file *except* the first one. This keeps the
# combined output runnable while preserving per-module headers in source.
concat_modules() {
  local dir="${1:?missing dir}"
  local first=1
  local file=""

  for file in "${dir}"/*.sh; do
    [[ -f "$file" ]] || continue
    if (( first == 1 )); then
      cat "$file"
      first=0
    else
      printf '\n# ===== %s =====\n' "$(basename "$file")"
      # Strip leading shebang lines from subsequent modules; modules use a
      # plain `# foo` header, not `#!/usr/bin/env bash`, but we guard anyway.
      awk 'NR==1 && /^#!/ {next} {print}' "$file"
    fi
  done
}

# Replace a placeholder line (e.g. __EMBED_TOOL__) with the literal contents
# of FILE. Placeholder must be the only non-whitespace content on its line.
substitute_file() {
  local placeholder="${1:?missing placeholder}"
  local file="${2:?missing file}"
  local input="${3:?missing input}"
  local output="${4:?missing output}"

  awk -v ph="$placeholder" -v fp="$file" '
    $0 ~ "^[[:space:]]*"ph"[[:space:]]*$" {
      while ((getline line < fp) > 0) print line
      close(fp)
      next
    }
    { print }
  ' "$input" > "$output"
}

# Replace simple __NAME__ tokens with literal values (no escaping concerns
# because our values are alphanumeric/dot/email/URL).
substitute_token() {
  local token="${1:?missing token}"
  local value="${2-}"
  local file="${3:?missing file}"
  # Use a delimiter that won't appear in URL/email values.
  local delim=$'\001'
  sed -i "s${delim}${token}${delim}${value}${delim}g" "$file"
}

main() {
  step "preparing dist/"
  rm -rf "$DIST"
  mkdir -p "$DIST"

  # ---- 1. Build the runtime tool first --------------------------------
  step "assembling tool runtime from src/tool/"
  local tool_raw="${DIST}/.tool.raw.sh"
  local tool_out="${DIST}/gc-chkr"
  concat_modules "$SRC_TOOL" > "$tool_raw"
  cp "$tool_raw" "$tool_out"
  substitute_token "__PACKAGE_VERSION__" "$VERSION" "$tool_out"
  chmod 0755 "$tool_out"
  note "wrote $(realpath --relative-to="$ROOT" "$tool_out") ($(wc -l < "$tool_out") lines)"

  # ---- 2. Build the installer with everything embedded ----------------
  step "assembling installer from src/installer/"
  local inst_raw="${DIST}/.installer.raw.sh"
  local inst_out="${DIST}/gc-chkr.sh"
  concat_modules "$SRC_INSTALLER" > "$inst_raw"

  step "embedding assets into installer"
  # Tool runtime (already version-substituted above; re-use the rendered file).
  local stage="${DIST}/.stage.sh"
  cp "$inst_raw" "$stage"

  # Embed in dependency order. After every embed, mv stage forward.
  local embed_pairs=(
    "__EMBED_TOOL__|${tool_out}"
    "__EMBED_SERVICE__|${ASSETS}/systemd/gc-chkr.service"
    "__EMBED_TIMER__|${ASSETS}/systemd/gc-chkr.timer"
    "__EMBED_POSTINST__|${ASSETS}/debian/postinst"
    "__EMBED_PRERM__|${ASSETS}/debian/prerm"
    "__EMBED_POSTRM__|${ASSETS}/debian/postrm"
  )

  local pair ph fp tmp
  for pair in "${embed_pairs[@]}"; do
    ph="${pair%%|*}"
    fp="${pair#*|}"
    tmp="${stage}.next"
    substitute_file "$ph" "$fp" "$stage" "$tmp"
    mv "$tmp" "$stage"
    note "embedded ${ph} <- $(realpath --relative-to="$ROOT" "$fp")"
  done

  mv "$stage" "$inst_out"
  substitute_token "__PACKAGE_VERSION__"    "$VERSION"    "$inst_out"
  substitute_token "__PACKAGE_MAINTAINER__" "$MAINTAINER" "$inst_out"
  substitute_token "__PACKAGE_HOMEPAGE__"   "$HOMEPAGE"   "$inst_out"
  chmod 0755 "$inst_out"

  rm -f "$tool_raw" "$inst_raw"
  done_ "wrote $(realpath --relative-to="$ROOT" "$inst_out") ($(wc -l < "$inst_out") lines, $(stat -c%s "$inst_out" 2>/dev/null || stat -f%z "$inst_out") bytes)"

  # ---- 3. Quick syntax check ------------------------------------------
  step "syntax-checking dist artifacts"
  if bash -n "$inst_out"; then
    done_ "installer parses clean"
  else
    printf 'installer failed syntax check\n' >&2
    exit 1
  fi
  if bash -n "$tool_out"; then
    done_ "tool parses clean"
  else
    printf 'tool failed syntax check\n' >&2
    exit 1
  fi

  step "build complete"
  note "version    : ${VERSION}"
  note "maintainer : ${MAINTAINER}"
  note "homepage   : ${HOMEPAGE}"
  note "artifacts  : ${DIST}/gc-chkr.sh  ${DIST}/gc-chkr"
}

main "$@"
